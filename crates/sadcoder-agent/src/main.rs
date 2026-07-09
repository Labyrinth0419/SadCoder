use anyhow::Context;
use clap::Parser;
use clap::Subcommand;
use clap::ValueEnum;
use sadcoder_protocol::AgentReconnectCacheStatus;
use sadcoder_protocol::AgentStatus;
use sadcoder_protocol::BackendKind;
use sadcoder_protocol::BackendState;
use sadcoder_protocol::BackendStatus;
use sadcoder_protocol::JsonRpcNotification;
use sadcoder_protocol::JsonRpcRequest;
use sadcoder_protocol::RequestId;
use sadcoder_protocol::SlashCommandManifest;
use serde::Serialize;
use serde_json::Value;
use serde_json::json;
use std::io;
use std::io::BufRead;
use std::io::BufReader;
use std::io::Write;
use std::path::Path;
use std::path::PathBuf;
use std::process::ChildStdin;
use std::process::ChildStdout;
use std::process::Command;
use std::process::Stdio;
use std::sync::Arc;
use std::sync::Mutex;
use std::thread;

mod state_cache;

use state_cache::AgentStateCache;
use state_cache::resolve_state_path;

#[derive(Debug, Parser)]
#[command(name = "sadcoder-agent")]
#[command(about = "SadCoder server-side lifecycle and proxy agent")]
struct Cli {
    #[arg(long, env = "SADCODER_CODEX_PATH", default_value = "codex")]
    codex_path: String,

    #[arg(long, env = "SADCODER_BACKEND", value_enum, default_value_t = BackendMode::Auto)]
    backend: BackendMode,

    #[arg(long, env = "SADCODER_STATE_PATH", value_name = "PATH")]
    state_path: Option<PathBuf>,

    #[command(subcommand)]
    command: AgentCommand,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, ValueEnum)]
enum BackendMode {
    Auto,
    Stdio,
    Daemon,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SelectedBackend {
    Stdio,
    Daemon,
}

#[derive(Debug, Subcommand)]
enum AgentCommand {
    /// Print machine-readable agent and Codex availability.
    Status {
        #[arg(long)]
        json: bool,
    },
    /// Prepare the selected backend.
    Start {
        #[arg(long)]
        json: bool,
    },
    /// Run initialize and core read probes against a fresh app-server.
    Probe {
        #[arg(long)]
        json: bool,
    },
    /// Print the SadCoder slash command manifest for this agent build.
    SlashCommands {
        #[arg(long)]
        json: bool,
    },
    /// Print the agent's cached reconnect snapshot.
    Snapshot {
        #[arg(long)]
        json: bool,
    },
    /// Proxy this process' stdin/stdout to the selected app-server backend.
    Proxy,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    match cli.command {
        AgentCommand::Status { json } => print_status(
            &cli.codex_path,
            cli.backend,
            cli.state_path.as_deref(),
            json,
        ),
        AgentCommand::Start { json } => print_start(
            &cli.codex_path,
            cli.backend,
            cli.state_path.as_deref(),
            json,
        ),
        AgentCommand::Probe { json } => print_probe(&cli.codex_path, json),
        AgentCommand::SlashCommands { json } => print_slash_commands(json),
        AgentCommand::Snapshot { json } => print_snapshot(cli.state_path.as_deref(), json),
        AgentCommand::Proxy => proxy_app_server(
            &cli.codex_path,
            cli.backend,
            resolve_state_path(cli.state_path.as_deref()),
        ),
    }
}

const SLASH_COMMANDS_MANIFEST_JSON: &str =
    include_str!("../../../resources/slash_commands_manifest.json");

fn print_status(
    codex_path: &str,
    backend_mode: BackendMode,
    state_path: Option<&Path>,
    json: bool,
) -> anyhow::Result<()> {
    let state_path = resolve_state_path(state_path);
    let status = collect_status(codex_path, backend_mode, &state_path);
    if json {
        println!("{}", serde_json::to_string_pretty(&status)?);
    } else {
        println!("SadCoder agent {}", status.agent_version);
        println!("platform: {} {}", status.platform_os, status.platform_arch);
        println!(
            "codex: {}",
            status.codex_version.as_deref().unwrap_or("not available")
        );
        println!(
            "backend: {:?} {:?}",
            status.backend.kind, status.backend.state
        );
        println!(
            "reconnect cache: {} pending approvals, {} recent events ({})",
            status.reconnect_cache.pending_approvals,
            status.reconnect_cache.recent_events,
            status.reconnect_cache.state_path
        );
        if let Some(load_error) = &status.reconnect_cache.load_error {
            println!("reconnect cache load error: {load_error}");
        }
    }
    Ok(())
}

fn print_start(
    codex_path: &str,
    backend_mode: BackendMode,
    state_path: Option<&Path>,
    json: bool,
) -> anyhow::Result<()> {
    start_backend(codex_path, backend_mode)?;
    print_status(codex_path, backend_mode, state_path, json)
}

fn print_probe(codex_path: &str, json_output: bool) -> anyhow::Result<()> {
    let result = run_probe(codex_path)?;
    if json_output {
        println!("{}", serde_json::to_string_pretty(&result)?);
    } else {
        println!("probe status: {}", result.status);
        for step in &result.steps {
            println!(
                "{}: {}{}",
                step.method,
                if step.ok { "ok" } else { "failed" },
                step.detail
                    .as_deref()
                    .map(|detail| format!(" ({detail})"))
                    .unwrap_or_default()
            );
        }
    }
    Ok(())
}

fn print_slash_commands(json_output: bool) -> anyhow::Result<()> {
    let manifest = load_slash_command_manifest()?;
    if json_output {
        println!("{}", serde_json::to_string_pretty(&manifest)?);
    } else {
        println!(
            "slash command manifest v{} ({})",
            manifest.schema_version, manifest.source
        );
        for command in &manifest.commands {
            let aliases = if command.aliases.is_empty() {
                String::new()
            } else {
                format!(" aliases: {}", command.aliases.join(", "))
            };
            println!(
                "/{:<24} {}{}",
                command.command, command.description, aliases
            );
        }
    }
    Ok(())
}

fn load_slash_command_manifest() -> anyhow::Result<SlashCommandManifest> {
    serde_json::from_str(SLASH_COMMANDS_MANIFEST_JSON)
        .context("embedded slash command manifest is invalid")
}

fn print_snapshot(state_path: Option<&Path>, json_output: bool) -> anyhow::Result<()> {
    let state_path = resolve_state_path(state_path);
    let snapshot = AgentStateCache::load(&state_path)?.into_snapshot();
    if json_output {
        println!("{}", serde_json::to_string_pretty(&snapshot)?);
    } else {
        println!(
            "agent snapshot v{}: {} pending approvals, {} recent events",
            snapshot.schema_version,
            snapshot.pending_approvals.len(),
            snapshot.recent_events.len()
        );
        println!("{}", state_path.display());
    }
    Ok(())
}

fn collect_status(codex_path: &str, backend_mode: BackendMode, state_path: &Path) -> AgentStatus {
    let codex_version = probe_codex_version(codex_path);
    let codex_available = codex_version.is_some();
    let backend = collect_backend_status(codex_path, codex_available, backend_mode);
    let reconnect_cache = collect_reconnect_cache_status(state_path);

    AgentStatus {
        agent_version: env!("CARGO_PKG_VERSION").to_string(),
        platform_os: std::env::consts::OS.to_string(),
        platform_arch: std::env::consts::ARCH.to_string(),
        codex_path: codex_path.to_string(),
        codex_available,
        codex_version,
        backend,
        reconnect_cache,
    }
}

fn collect_reconnect_cache_status(state_path: &Path) -> AgentReconnectCacheStatus {
    match AgentStateCache::load(state_path) {
        Ok(cache) => {
            let snapshot = cache.into_snapshot();
            AgentReconnectCacheStatus {
                state_path: state_path.display().to_string(),
                schema_version: snapshot.schema_version,
                pending_approvals: snapshot.pending_approvals.len(),
                recent_events: snapshot.recent_events.len(),
                load_error: None,
            }
        }
        Err(error) => AgentReconnectCacheStatus {
            state_path: state_path.display().to_string(),
            schema_version: 1,
            pending_approvals: 0,
            recent_events: 0,
            load_error: Some(error.to_string()),
        },
    }
}

fn collect_backend_status(
    codex_path: &str,
    codex_available: bool,
    backend_mode: BackendMode,
) -> BackendStatus {
    if !codex_available {
        return BackendStatus {
            kind: BackendKind::Unknown,
            state: BackendState::Unavailable,
            detail: Some("codex executable was not found or did not run".into()),
        };
    }

    match select_backend(backend_mode, daemon_supported()) {
        Ok(SelectedBackend::Stdio) => BackendStatus {
            kind: BackendKind::CodexAppServerStdio,
            state: BackendState::Ready,
            detail: Some("on-demand stdio fallback; SSH disconnect can end this backend".into()),
        },
        Ok(SelectedBackend::Daemon) => {
            if probe_daemon_version(codex_path).is_some() {
                BackendStatus {
                    kind: BackendKind::CodexAppServerDaemon,
                    state: BackendState::Ready,
                    detail: Some("official Codex app-server daemon is running".into()),
                }
            } else {
                BackendStatus {
                    kind: BackendKind::CodexAppServerDaemon,
                    state: BackendState::NotStarted,
                    detail: Some(
                        "official daemon backend is preferred; run sadcoder-agent start".into(),
                    ),
                }
            }
        }
        Err(detail) => BackendStatus {
            kind: BackendKind::Unknown,
            state: BackendState::Unavailable,
            detail: Some(detail),
        },
    }
}

fn select_backend(
    backend_mode: BackendMode,
    daemon_supported: bool,
) -> Result<SelectedBackend, String> {
    match backend_mode {
        BackendMode::Stdio => Ok(SelectedBackend::Stdio),
        BackendMode::Daemon if daemon_supported => Ok(SelectedBackend::Daemon),
        BackendMode::Daemon => {
            Err("Codex app-server daemon is not supported on this platform".into())
        }
        BackendMode::Auto if daemon_supported => Ok(SelectedBackend::Daemon),
        BackendMode::Auto => Ok(SelectedBackend::Stdio),
    }
}

fn start_backend(codex_path: &str, backend_mode: BackendMode) -> anyhow::Result<()> {
    match select_backend(backend_mode, daemon_supported()) {
        Ok(SelectedBackend::Stdio) => Ok(()),
        Ok(SelectedBackend::Daemon) => {
            let status = Command::new(codex_path)
                .args(["app-server", "daemon", "start"])
                .status()
                .context("failed to start Codex app-server daemon")?;
            if status.success() {
                Ok(())
            } else {
                anyhow::bail!("Codex app-server daemon start exited with status {status}")
            }
        }
        Err(detail) => anyhow::bail!(detail),
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProbeResult {
    status: &'static str,
    steps: Vec<ProbeStep>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProbeStep {
    method: String,
    ok: bool,
    detail: Option<String>,
}

fn run_probe(codex_path: &str) -> anyhow::Result<ProbeResult> {
    let mut child = Command::new(codex_path)
        .args(["app-server", "--listen", "stdio://"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .with_context(|| format!("failed to spawn `{codex_path} app-server --listen stdio://`"))?;

    let mut stdin = child.stdin.take().context("child stdin was not piped")?;
    let stdout = child.stdout.take().context("child stdout was not piped")?;
    let mut reader = BufReader::new(stdout);
    let mut steps = Vec::new();

    let initialize = JsonRpcRequest::new(
        RequestId::Number(1),
        "initialize",
        Some(json!({
            "clientInfo": {
                "name": "sadcoder_agent",
                "title": "SadCoder Agent Probe",
                "version": env!("CARGO_PKG_VERSION")
            },
            "capabilities": {
                "experimentalApi": true
            }
        })),
    );
    steps.push(probe_request(&mut stdin, &mut reader, initialize)?);
    write_notification(&mut stdin, JsonRpcNotification::new("initialized", None))?;

    for request in probe_read_requests() {
        steps.push(probe_request(&mut stdin, &mut reader, request)?);
    }

    drop(stdin);
    let _ = child.kill();
    let _ = child.wait();

    let status = if steps.iter().all(|step| step.ok) {
        "ok"
    } else {
        "failed"
    };

    Ok(ProbeResult { status, steps })
}

fn probe_read_requests() -> Vec<JsonRpcRequest> {
    vec![
        JsonRpcRequest::new(
            RequestId::Number(2),
            "account/read",
            Some(json!({ "refreshToken": false })),
        ),
        JsonRpcRequest::new(RequestId::Number(3), "model/list", Some(json!({}))),
        JsonRpcRequest::new(
            RequestId::Number(4),
            "config/read",
            Some(json!({ "includeLayers": true })),
        ),
        JsonRpcRequest::new(
            RequestId::Number(5),
            "permissionProfile/list",
            Some(json!({})),
        ),
        JsonRpcRequest::new(
            RequestId::Number(6),
            "thread/list",
            Some(json!({ "limit": 1 })),
        ),
    ]
}

fn probe_request(
    stdin: &mut ChildStdin,
    reader: &mut BufReader<ChildStdout>,
    request: JsonRpcRequest,
) -> anyhow::Result<ProbeStep> {
    let method = request.method.clone();
    let id = request.id.clone();
    write_json_line(stdin, &request)?;
    let response = read_response_for_id(reader, &id)
        .with_context(|| format!("failed while waiting for `{method}` response"))?;

    if let Some(error) = response.get("error") {
        return Ok(ProbeStep {
            method,
            ok: false,
            detail: Some(error.to_string()),
        });
    }

    Ok(ProbeStep {
        method,
        ok: response.get("result").is_some(),
        detail: None,
    })
}

fn write_notification(
    stdin: &mut ChildStdin,
    notification: JsonRpcNotification,
) -> anyhow::Result<()> {
    write_json_line(stdin, &notification)
}

fn write_json_line<T: Serialize>(stdin: &mut ChildStdin, value: &T) -> anyhow::Result<()> {
    serde_json::to_writer(&mut *stdin, value)?;
    stdin.write_all(b"\n")?;
    stdin.flush()?;
    Ok(())
}

fn read_response_for_id(
    reader: &mut BufReader<ChildStdout>,
    expected_id: &RequestId,
) -> anyhow::Result<Value> {
    let mut line = String::new();
    loop {
        line.clear();
        let bytes = reader.read_line(&mut line)?;
        if bytes == 0 {
            anyhow::bail!("app-server closed stdout before response");
        }
        if line.trim().is_empty() {
            continue;
        }

        let value: Value = serde_json::from_str(&line)
            .with_context(|| format!("app-server emitted non-json stdout: {line:?}"))?;
        let Some(id) = value.get("id") else {
            continue;
        };
        if json_id_matches(id, expected_id) {
            return Ok(value);
        }
    }
}

fn json_id_matches(id: &Value, expected_id: &RequestId) -> bool {
    match (id, expected_id) {
        (Value::Number(number), RequestId::Number(expected)) => number.as_i64() == Some(*expected),
        (Value::String(actual), RequestId::String(expected)) => actual == expected,
        _ => false,
    }
}

fn probe_codex_version(codex_path: &str) -> Option<String> {
    let output = Command::new(codex_path).arg("--version").output().ok()?;
    if !output.status.success() {
        return None;
    }
    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if !stdout.is_empty() {
        Some(stdout)
    } else if !stderr.is_empty() {
        Some(stderr)
    } else {
        Some("codex version unknown".to_string())
    }
}

fn probe_daemon_version(codex_path: &str) -> Option<Value> {
    let output = Command::new(codex_path)
        .args(["app-server", "daemon", "version"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    serde_json::from_slice(&output.stdout).ok()
}

fn daemon_supported() -> bool {
    cfg!(unix)
}

fn proxy_app_server(
    codex_path: &str,
    backend_mode: BackendMode,
    state_path: PathBuf,
) -> anyhow::Result<()> {
    match select_backend(backend_mode, daemon_supported()) {
        Ok(SelectedBackend::Stdio) => proxy_stdio_app_server(codex_path, state_path),
        Ok(SelectedBackend::Daemon) => proxy_daemon_app_server(codex_path),
        Err(detail) => anyhow::bail!(detail),
    }
}

fn proxy_daemon_app_server(codex_path: &str) -> anyhow::Result<()> {
    start_backend(codex_path, BackendMode::Daemon)?;
    let status = Command::new(codex_path)
        .args(["app-server", "proxy"])
        .status()
        .context("failed to proxy to Codex app-server daemon")?;

    if status.success() {
        Ok(())
    } else {
        anyhow::bail!("Codex app-server proxy exited with status {status}")
    }
}

fn proxy_stdio_app_server(codex_path: &str, state_path: PathBuf) -> anyhow::Result<()> {
    let mut child = Command::new(codex_path)
        .args(["app-server", "--listen", "stdio://"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .with_context(|| format!("failed to spawn `{codex_path} app-server --listen stdio://`"))?;

    let mut child_stdin = child.stdin.take().context("child stdin was not piped")?;
    let mut child_stdout = child.stdout.take().context("child stdout was not piped")?;
    let cache = Arc::new(Mutex::new(
        AgentStateCache::load(&state_path).unwrap_or_else(|_| AgentStateCache::empty()),
    ));

    let stdin_cache = Arc::clone(&cache);
    let stdin_state_path = state_path.clone();
    let stdin_thread = thread::spawn(move || {
        let mut reader = BufReader::new(io::stdin().lock());
        let mut line = Vec::new();
        loop {
            line.clear();
            let bytes = match reader.read_until(b'\n', &mut line) {
                Ok(bytes) => bytes,
                Err(_) => break,
            };
            if bytes == 0 {
                break;
            }
            observe_and_save_cache(&stdin_cache, &stdin_state_path, |cache| {
                cache.observe_client_line_bytes(&line)
            });
            if child_stdin.write_all(&line).is_err() {
                break;
            }
            let _ = child_stdin.flush();
        }
    });
    let stdout_cache = Arc::clone(&cache);
    let stdout_state_path = state_path;
    let stdout_thread = thread::spawn(move || {
        let mut reader = BufReader::new(&mut child_stdout);
        let mut stdout = io::stdout().lock();
        let mut line = Vec::new();
        loop {
            line.clear();
            let bytes = match reader.read_until(b'\n', &mut line) {
                Ok(bytes) => bytes,
                Err(_) => break,
            };
            if bytes == 0 {
                break;
            }
            observe_and_save_cache(&stdout_cache, &stdout_state_path, |cache| {
                cache.observe_server_line_bytes(&line)
            });
            if stdout.write_all(&line).is_err() {
                break;
            }
            let _ = stdout.flush();
        }
    });

    let status = child.wait().context("failed to wait for app-server")?;
    let _ = stdin_thread.join();
    let _ = stdout_thread.join();

    if status.success() {
        Ok(())
    } else {
        anyhow::bail!("app-server exited with status {status}")
    }
}

fn observe_and_save_cache(
    cache: &Arc<Mutex<AgentStateCache>>,
    state_path: &Path,
    observe: impl FnOnce(&mut AgentStateCache) -> bool,
) {
    let Ok(mut cache) = cache.lock() else {
        return;
    };
    if observe(&mut cache) {
        let _ = cache.save(state_path);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unavailable_codex_reports_unavailable_backend() {
        let status = collect_status(
            "definitely-missing-sadcoder-codex-binary",
            BackendMode::Auto,
            Path::new("sadcoder-agent-test-state.json"),
        );

        assert!(!status.codex_available);
        assert_eq!(status.backend.kind, BackendKind::Unknown);
        assert_eq!(status.backend.state, BackendState::Unavailable);
    }

    #[test]
    fn status_reports_reconnect_cache_counts() {
        let path = std::env::temp_dir().join(format!(
            "sadcoder-agent-status-cache-test-{}-{}.json",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ));
        let mut cache = AgentStateCache::empty();
        cache
            .snapshot
            .pending_approvals
            .push(sadcoder_protocol::AgentCachedServerRequest {
                id: json!("approval-1"),
                method: "item/commandExecution/requestApproval".to_string(),
                params: Some(json!({ "command": "cargo test" })),
            });
        cache
            .snapshot
            .recent_events
            .push(sadcoder_protocol::AgentCachedEvent {
                method: "thread/item".to_string(),
                params: None,
            });

        cache.save(&path).expect("save cache");
        let status = collect_status(
            "definitely-missing-sadcoder-codex-binary",
            BackendMode::Auto,
            &path,
        );
        let _ = std::fs::remove_file(&path);

        assert_eq!(
            status.reconnect_cache.state_path,
            path.display().to_string()
        );
        assert_eq!(status.reconnect_cache.schema_version, 1);
        assert_eq!(status.reconnect_cache.pending_approvals, 1);
        assert_eq!(status.reconnect_cache.recent_events, 1);
        assert_eq!(status.reconnect_cache.load_error, None);
    }

    #[test]
    fn backend_selection_prefers_daemon_only_when_supported() {
        assert_eq!(
            select_backend(BackendMode::Auto, true),
            Ok(SelectedBackend::Daemon)
        );
        assert_eq!(
            select_backend(BackendMode::Auto, false),
            Ok(SelectedBackend::Stdio)
        );
        assert_eq!(
            select_backend(BackendMode::Stdio, true),
            Ok(SelectedBackend::Stdio)
        );
        assert!(select_backend(BackendMode::Daemon, false).is_err());
    }

    #[test]
    fn probe_read_requests_cover_core_capability_checks() {
        let requests = probe_read_requests();
        let encoded = requests
            .iter()
            .map(|request| serde_json::to_value(request).expect("serialize request"))
            .collect::<Vec<_>>();

        assert_eq!(
            encoded
                .iter()
                .map(|request| request["method"].as_str().expect("method"))
                .collect::<Vec<_>>(),
            vec![
                "account/read",
                "model/list",
                "config/read",
                "permissionProfile/list",
                "thread/list",
            ]
        );
        assert_eq!(encoded[0]["params"]["refreshToken"], false);
        assert_eq!(encoded[2]["params"]["includeLayers"], true);
        assert_eq!(encoded[4]["params"]["limit"], 1);
    }

    #[test]
    fn embedded_slash_manifest_loads_aliases_and_topology_commands() {
        let manifest = load_slash_command_manifest().expect("manifest loads");

        assert_eq!(manifest.schema_version, 1);
        assert_eq!(manifest.commands.len(), 57);
        assert_eq!(
            manifest
                .commands
                .first()
                .map(|command| command.command.as_str()),
            Some("model")
        );

        let stop = manifest
            .commands
            .iter()
            .find(|command| command.command == "stop")
            .expect("stop command");
        assert_eq!(stop.aliases, vec!["clean".to_string()]);

        let duplicate = manifest
            .commands
            .iter()
            .find(|command| command.command == "duplicate")
            .expect("duplicate command");
        assert!(!duplicate.supports_inline_args);
        assert_eq!(duplicate.mapping_target, "thread/fork");

        let rewind = manifest
            .commands
            .iter()
            .find(|command| command.command == "rewind")
            .expect("rewind command");
        assert!(rewind.supports_inline_args);
        assert_eq!(rewind.mapping_target, "thread/fork lastTurnId");

        let side = manifest
            .commands
            .iter()
            .find(|command| command.command == "side")
            .expect("side command");
        assert!(side.supports_inline_args);
        assert_eq!(
            side.mapping_target,
            "thread/fork ephemeral=true + side boundary prompt"
        );
    }
}
