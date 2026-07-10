use anyhow::Context;
use serde::Deserialize;
use serde::Serialize;
use std::fs;
use std::fs::File;
use std::path::Path;
use std::path::PathBuf;
use std::process::Command;
use std::process::Stdio;
use std::thread;
use std::time::Duration;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

use crate::app_server_socket::AppServerSocket;
use crate::codex_command::CodexCommandSource;
use crate::codex_command::ResolvedCodexCommand;

const SERVICE_INFO_FILE_NAME: &str = "agent-service.json";
const SERVICE_SOCKET_FILE_NAME: &str = "app-server.sock";
const SERVICE_STDERR_FILE_NAME: &str = "app-server.stderr.log";
const SERVICE_START_TIMEOUT: Duration = Duration::from_secs(10);
const SERVICE_POLL_INTERVAL: Duration = Duration::from_millis(100);

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentServiceInfo {
    pub(crate) schema_version: u32,
    pub(crate) service_pid: u32,
    pub(crate) app_server_pid: u32,
    pub(crate) socket_path: PathBuf,
    pub(crate) listen_url: String,
    pub(crate) started_at_unix_ms: u128,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct AgentServicePaths {
    pub(crate) info_path: PathBuf,
    pub(crate) socket_path: PathBuf,
    pub(crate) stderr_log_path: PathBuf,
}

pub(crate) fn resolve_service_paths(state_path: &Path) -> AgentServicePaths {
    let base = state_path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .map(Path::to_path_buf)
        .unwrap_or_else(std::env::temp_dir);
    AgentServicePaths {
        info_path: base.join(SERVICE_INFO_FILE_NAME),
        socket_path: base.join(SERVICE_SOCKET_FILE_NAME),
        stderr_log_path: base.join(SERVICE_STDERR_FILE_NAME),
    }
}

pub(crate) fn load_service_info(
    paths: &AgentServicePaths,
) -> anyhow::Result<Option<AgentServiceInfo>> {
    if !paths.info_path.exists() {
        return Ok(None);
    }
    let bytes = fs::read(&paths.info_path)
        .with_context(|| format!("failed to read {}", paths.info_path.display()))?;
    serde_json::from_slice(&bytes)
        .map(Some)
        .with_context(|| format!("failed to parse {}", paths.info_path.display()))
}

pub(crate) fn service_is_ready(paths: &AgentServicePaths) -> bool {
    let Some(info) = load_service_info(paths).ok().flatten() else {
        return false;
    };
    if info.socket_path != paths.socket_path {
        return false;
    }
    match AppServerSocket::connect(&paths.socket_path) {
        Ok(mut socket) => {
            let _ = socket.writer.write_close();
            true
        }
        Err(_) => false,
    }
}

pub(crate) fn wait_for_service_ready(paths: &AgentServicePaths, timeout: Duration) -> bool {
    let started = std::time::Instant::now();
    while started.elapsed() < timeout {
        if service_is_ready(paths) {
            return true;
        }
        thread::sleep(SERVICE_POLL_INTERVAL);
    }
    service_is_ready(paths)
}

pub(crate) fn start_service_process(
    codex: &ResolvedCodexCommand,
    state_path: &Path,
    paths: &AgentServicePaths,
) -> anyhow::Result<()> {
    if service_is_ready(paths) {
        return Ok(());
    }
    cleanup_unready_service_files(paths)?;

    if let Some(parent) = paths.info_path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    let current_exe = std::env::current_exe().context("failed to resolve sadcoder-agent path")?;
    let mut command = Command::new(current_exe);
    if !matches!(codex.source, CodexCommandSource::Config) {
        command.arg("--codex-program").arg(&codex.program);
    }
    command
        .arg("--state-path")
        .arg(state_path)
        .arg("service")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    command
        .spawn()
        .context("failed to spawn sadcoder-agent service")?;

    if wait_for_service_ready(paths, SERVICE_START_TIMEOUT) {
        Ok(())
    } else {
        anyhow::bail!(
            "sadcoder-agent service did not become ready at {} within {} seconds",
            paths.socket_path.display(),
            SERVICE_START_TIMEOUT.as_secs()
        )
    }
}

pub(crate) fn run_service(codex: &ResolvedCodexCommand, state_path: &Path) -> anyhow::Result<()> {
    let paths = resolve_service_paths(state_path);
    if let Some(parent) = paths.info_path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    let stderr_log = File::create(&paths.stderr_log_path)
        .with_context(|| format!("failed to create {}", paths.stderr_log_path.display()))?;
    let listen_url = format!("unix://{}", paths.socket_path.display());
    let mut command = codex.command()?;
    let mut child = command
        .args(["app-server", "--listen"])
        .arg(&listen_url)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::from(stderr_log))
        .spawn()
        .with_context(|| {
            format!(
                "failed to spawn `{} app-server --listen {listen_url}`",
                codex.display_program()
            )
        })?;

    let info = AgentServiceInfo {
        schema_version: 1,
        service_pid: std::process::id(),
        app_server_pid: child.id(),
        socket_path: paths.socket_path.clone(),
        listen_url,
        started_at_unix_ms: now_unix_ms(),
    };
    write_service_info(&paths.info_path, &info)?;

    let status = child.wait().context("failed to wait for app-server")?;
    remove_file_if_exists(&paths.info_path)?;
    remove_file_if_exists(&paths.socket_path)?;
    if status.success() {
        Ok(())
    } else {
        anyhow::bail!("app-server exited with status {status}")
    }
}

fn write_service_info(path: &Path, info: &AgentServiceInfo) -> anyhow::Result<()> {
    let bytes = serde_json::to_vec_pretty(info)?;
    fs::write(path, bytes).with_context(|| format!("failed to write {}", path.display()))
}

fn remove_file_if_exists(path: &Path) -> anyhow::Result<()> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error).with_context(|| format!("failed to remove {}", path.display())),
    }
}

fn cleanup_unready_service_files(paths: &AgentServicePaths) -> anyhow::Result<()> {
    remove_file_if_exists(&paths.info_path)?;
    remove_file_if_exists(&paths.socket_path)
}

fn now_unix_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn service_paths_live_next_to_state_snapshot() {
        let base = std::env::temp_dir().join("sadcoder-agent-service-path-test");
        let paths = resolve_service_paths(&base.join("agent-state.json"));

        assert_eq!(paths.info_path, base.join(SERVICE_INFO_FILE_NAME));
        assert_eq!(paths.socket_path, base.join(SERVICE_SOCKET_FILE_NAME));
        assert_eq!(paths.stderr_log_path, base.join(SERVICE_STDERR_FILE_NAME));
    }

    #[test]
    fn missing_service_info_is_not_ready() {
        let base = std::env::temp_dir().join(format!(
            "sadcoder-agent-missing-service-{}",
            std::process::id()
        ));
        let paths = resolve_service_paths(&base.join("agent-state.json"));

        assert!(!service_is_ready(&paths));
    }

    #[test]
    fn stale_service_record_and_socket_file_are_not_ready() {
        let base = std::env::temp_dir().join(format!(
            "sadcoder-agent-stale-service-{}-{}",
            std::process::id(),
            now_unix_ms()
        ));
        let paths = resolve_service_paths(&base.join("agent-state.json"));
        fs::create_dir_all(&base).expect("create state dir");
        let info = AgentServiceInfo {
            schema_version: 1,
            service_pid: 1,
            app_server_pid: 2,
            socket_path: paths.socket_path.clone(),
            listen_url: format!("unix://{}", paths.socket_path.display()),
            started_at_unix_ms: now_unix_ms(),
        };
        write_service_info(&paths.info_path, &info).expect("write service info");
        fs::write(&paths.socket_path, b"stale").expect("write stale socket file");

        assert!(!service_is_ready(&paths));

        let _ = fs::remove_dir_all(&base);
    }
}
