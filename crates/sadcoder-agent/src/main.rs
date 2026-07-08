use anyhow::Context;
use clap::Parser;
use clap::Subcommand;
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
use std::process::ChildStdin;
use std::process::ChildStdout;
use std::process::Command;
use std::process::Stdio;
use std::thread;

#[derive(Debug, Parser)]
#[command(name = "sadcoder-agent")]
#[command(about = "SadCoder server-side lifecycle and proxy agent")]
struct Cli {
    #[arg(long, env = "SADCODER_CODEX_PATH", default_value = "codex")]
    codex_path: String,

    #[command(subcommand)]
    command: AgentCommand,
}

#[derive(Debug, Subcommand)]
enum AgentCommand {
    /// Print machine-readable agent and Codex availability.
    Status {
        #[arg(long)]
        json: bool,
    },
    /// Prepare the backend. M0 uses on-demand stdio, so this is a health check.
    Start {
        #[arg(long)]
        json: bool,
    },
    /// Run initialize, model/list, and thread/list against a fresh app-server.
    Probe {
        #[arg(long)]
        json: bool,
    },
    /// Print the SadCoder slash command manifest for this agent build.
    SlashCommands {
        #[arg(long)]
        json: bool,
    },
    /// Proxy this process' stdin/stdout to `codex app-server --listen stdio://`.
    Proxy,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    match cli.command {
        AgentCommand::Status { json } => print_status(&cli.codex_path, json),
        AgentCommand::Start { json } => print_status(&cli.codex_path, json),
        AgentCommand::Probe { json } => print_probe(&cli.codex_path, json),
        AgentCommand::SlashCommands { json } => print_slash_commands(json),
        AgentCommand::Proxy => proxy_app_server(&cli.codex_path),
    }
}

const SLASH_COMMANDS_MANIFEST_JSON: &str =
    include_str!("../../../resources/slash_commands_manifest.json");

fn print_status(codex_path: &str, json: bool) -> anyhow::Result<()> {
    let status = collect_status(codex_path);
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
    }
    Ok(())
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

fn collect_status(codex_path: &str) -> AgentStatus {
    let codex_version = probe_codex_version(codex_path);
    let codex_available = codex_version.is_some();
    let backend = if codex_available {
        BackendStatus {
            kind: BackendKind::CodexAppServerStdio,
            state: BackendState::Ready,
            detail: Some("on-demand stdio backend; persistent service is a later milestone".into()),
        }
    } else {
        BackendStatus {
            kind: BackendKind::Unknown,
            state: BackendState::Unavailable,
            detail: Some("codex executable was not found or did not run".into()),
        }
    };

    AgentStatus {
        agent_version: env!("CARGO_PKG_VERSION").to_string(),
        platform_os: std::env::consts::OS.to_string(),
        platform_arch: std::env::consts::ARCH.to_string(),
        codex_path: codex_path.to_string(),
        codex_available,
        codex_version,
        backend,
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

    steps.push(probe_request(
        &mut stdin,
        &mut reader,
        JsonRpcRequest::new(RequestId::Number(2), "model/list", Some(json!({}))),
    )?);
    steps.push(probe_request(
        &mut stdin,
        &mut reader,
        JsonRpcRequest::new(
            RequestId::Number(3),
            "thread/list",
            Some(json!({ "limit": 1 })),
        ),
    )?);

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

fn proxy_app_server(codex_path: &str) -> anyhow::Result<()> {
    let mut child = Command::new(codex_path)
        .args(["app-server", "--listen", "stdio://"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .with_context(|| format!("failed to spawn `{codex_path} app-server --listen stdio://`"))?;

    let mut child_stdin = child.stdin.take().context("child stdin was not piped")?;
    let mut child_stdout = child.stdout.take().context("child stdout was not piped")?;

    let stdin_thread = thread::spawn(move || {
        let mut stdin = io::stdin().lock();
        let _ = io::copy(&mut stdin, &mut child_stdin);
    });
    let stdout_thread = thread::spawn(move || {
        let mut stdout = io::stdout().lock();
        let _ = io::copy(&mut child_stdout, &mut stdout);
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unavailable_codex_reports_unavailable_backend() {
        let status = collect_status("definitely-missing-sadcoder-codex-binary");

        assert!(!status.codex_available);
        assert_eq!(status.backend.kind, BackendKind::Unknown);
        assert_eq!(status.backend.state, BackendState::Unavailable);
    }

    #[test]
    fn embedded_slash_manifest_loads_aliases_and_topology_commands() {
        let manifest = load_slash_command_manifest().expect("manifest loads");

        assert_eq!(manifest.schema_version, 1);
        assert_eq!(manifest.commands.len(), 55);
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
