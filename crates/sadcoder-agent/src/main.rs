use anyhow::Context;
use clap::Parser;
use clap::Subcommand;
use clap::ValueEnum;
use sadcoder_protocol::AgentReconnectCacheStatus;
use sadcoder_protocol::AgentStatus;
use sadcoder_protocol::BackendKind;
use sadcoder_protocol::BackendState;
use sadcoder_protocol::BackendStatus;
use sadcoder_protocol::CodexFailureStatus;
use sadcoder_protocol::JsonRpcNotification;
use sadcoder_protocol::JsonRpcRequest;
use sadcoder_protocol::JsonRpcResponse;
use sadcoder_protocol::RequestId;
use sadcoder_protocol::SlashCommandManifest;
use serde::Serialize;
use serde_json::Value;
use serde_json::json;
use std::ffi::OsString;
use std::io;
use std::io::BufRead;
use std::io::BufReader;
use std::io::Write;
use std::path::Path;
use std::path::PathBuf;
use std::process::Child;
use std::process::ChildStdin;
use std::process::ChildStdout;
use std::process::Stdio;
use std::sync::Arc;
use std::sync::Mutex;
use std::thread;

mod agent_logs;
mod agent_rpc;
mod agent_schema;
mod app_server_socket;
mod codex_command;
mod codex_maintenance;
mod service;
mod service_bridge;
mod state_cache;
mod workspace_files;

use agent_logs::DEFAULT_LOG_TAIL_BYTES;
use agent_logs::collect_agent_logs;
use agent_logs::collect_agent_logs_from_params;
use agent_rpc::AgentRpcMethod;
use agent_schema::AgentSchemaOptions;
use agent_schema::collect_agent_schema;
use agent_schema::collect_agent_schema_from_params;
use codex_command::CodexCommandConfig;
use codex_command::CodexCommandSource;
use codex_command::CodexProbeFailure;
use codex_command::ResolvedCodexCommand;
use codex_command::agent_config_path;
use codex_command::persist_codex_command;
use codex_command::probe_codex_version;
use codex_command::resolve_codex_command;
use codex_maintenance::CodexMaintenanceCommand;
use service::AgentServicePaths;
use service::load_service_info;
use service::resolve_service_paths;
use service::restart_service_process;
use service::run_service;
use service::service_is_ready;
use service::start_service_process;
use service_bridge::ServiceProxyConnection;
use service_bridge::connect_service_proxy;
use state_cache::AgentStateCache;
use state_cache::resolve_state_path;
use workspace_files::handle_workspace_request;

#[derive(Debug, Clone)]
struct AgentProxyContext {
    codex: ResolvedCodexCommand,
    backend: SelectedBackend,
    state_path: PathBuf,
}

#[derive(Debug, Parser)]
#[command(name = "sadcoder-agent")]
#[command(about = "SadCoder server-side lifecycle and proxy agent")]
struct Cli {
    #[arg(long = "codex-path", value_name = "PATH")]
    codex_path: Option<PathBuf>,

    #[arg(long = "codex-program", value_name = "PATH")]
    codex_program: Option<PathBuf>,

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
    Service,
    Stdio,
}

#[derive(Debug, Clone)]
struct ResolvedBackend {
    selection: SelectedBackend,
    status: BackendStatus,
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
    /// Stop the SadCoder service backend if it is running.
    Stop {
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
        #[arg(long = "since-cursor")]
        since_cursor: Option<String>,
    },
    /// Print bounded service and app-server logs.
    Logs {
        #[arg(long)]
        json: bool,
        #[arg(long = "tail-bytes", default_value_t = DEFAULT_LOG_TAIL_BYTES)]
        tail_bytes: u64,
    },
    /// Generate or summarize the cached Codex app-server JSON Schema bundle.
    Schema {
        #[arg(long)]
        json: bool,
        #[arg(long)]
        refresh: bool,
        #[arg(long)]
        experimental: bool,
    },
    /// Diagnose the resolved Codex executable and runtime environment.
    Doctor {
        #[arg(long)]
        json: bool,
    },
    /// Persist the Codex executable and runtime PATH configuration.
    Configure {
        #[arg(long = "codex", value_name = "PATH")]
        codex: PathBuf,
        #[arg(long = "codex-arg", value_name = "ARG", allow_hyphen_values = true)]
        codex_args: Vec<String>,
        #[arg(long = "path-prepend", value_name = "PATH")]
        path_prepend: Vec<PathBuf>,
        #[arg(long)]
        json: bool,
    },
    /// Run a fixed, auditable Codex maintenance or Cloud operation.
    Codex(CodexMaintenanceCommand),
    /// Run the long-lived SadCoder service that owns the app-server process.
    #[command(hide = true)]
    Service {
        #[arg(long = "resolved-codex-program", value_name = "PATH", hide = true)]
        resolved_codex_program: Option<PathBuf>,
        #[arg(
            long = "resolved-codex-arg",
            value_name = "ARG",
            allow_hyphen_values = true,
            hide = true
        )]
        resolved_codex_args: Vec<OsString>,
        #[arg(long = "resolved-codex-path-prepend", value_name = "PATH", hide = true)]
        resolved_codex_path_prepend: Vec<PathBuf>,
    },
    /// Proxy this process' stdin/stdout to the selected app-server backend.
    Proxy,
}

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let cli_codex_program = cli.codex_program.or(cli.codex_path);
    match cli.command {
        AgentCommand::Status { json } => {
            let codex = resolve_codex_command(cli_codex_program)?;
            print_status(&codex, cli.backend, cli.state_path.as_deref(), json)
        }
        AgentCommand::Start { json } => {
            let codex = resolve_codex_command(cli_codex_program)?;
            print_start(&codex, cli.backend, cli.state_path.as_deref(), json)
        }
        AgentCommand::Stop { json } => print_stop(cli.backend, cli.state_path.as_deref(), json),
        AgentCommand::Probe { json } => {
            let codex = resolve_codex_command(cli_codex_program)?;
            print_probe(&codex, json)
        }
        AgentCommand::SlashCommands { json } => print_slash_commands(json),
        AgentCommand::Snapshot { json, since_cursor } => {
            print_snapshot(cli.state_path.as_deref(), json, since_cursor.as_deref())
        }
        AgentCommand::Logs { json, tail_bytes } => {
            print_logs(cli.state_path.as_deref(), json, tail_bytes)
        }
        AgentCommand::Schema {
            json,
            refresh,
            experimental,
        } => {
            let codex = resolve_codex_command(cli_codex_program)?;
            print_schema(
                &codex,
                cli.state_path.as_deref(),
                AgentSchemaOptions {
                    refresh,
                    experimental,
                },
                json,
            )
        }
        AgentCommand::Doctor { json } => {
            let codex = resolve_codex_command(cli_codex_program)?;
            print_doctor(&codex, cli.backend, cli.state_path.as_deref(), json)
        }
        AgentCommand::Configure {
            codex,
            codex_args,
            path_prepend,
            json,
        } => configure_codex(codex, codex_args, path_prepend, json),
        AgentCommand::Codex(command) => {
            let codex = resolve_codex_command(cli_codex_program)?;
            let result = codex_maintenance::run(&codex, &command.operation);
            codex_maintenance::print_result(&result, command.json);
            Ok(())
        }
        AgentCommand::Service {
            resolved_codex_program,
            resolved_codex_args,
            resolved_codex_path_prepend,
        } => {
            let codex = match resolved_codex_program {
                Some(program) => ResolvedCodexCommand {
                    program,
                    args: resolved_codex_args,
                    path_prepend: resolved_codex_path_prepend,
                    source: CodexCommandSource::ServiceSnapshot,
                },
                None => resolve_codex_command(cli_codex_program)?,
            };
            run_service(&codex, &resolve_state_path(cli.state_path.as_deref()))
        }
        AgentCommand::Proxy => {
            let codex = resolve_codex_command(cli_codex_program)?;
            proxy_app_server(
                &codex,
                cli.backend,
                resolve_state_path(cli.state_path.as_deref()),
            )
        }
    }
}

const SLASH_COMMANDS_MANIFEST_JSON: &str =
    include_str!("../../../resources/slash_commands_manifest.json");

fn print_status(
    codex: &ResolvedCodexCommand,
    backend_mode: BackendMode,
    state_path: Option<&Path>,
    json: bool,
) -> anyhow::Result<()> {
    let state_path = resolve_state_path(state_path);
    let status = collect_status(codex, backend_mode, &state_path);
    print_agent_status(&status, json);
    Ok(())
}

fn print_start(
    codex: &ResolvedCodexCommand,
    backend_mode: BackendMode,
    state_path: Option<&Path>,
    json: bool,
) -> anyhow::Result<()> {
    let state_path = resolve_state_path(state_path);
    if let Err(failure) = probe_codex_version(codex) {
        let status = collect_status_with_backend(
            codex,
            backend_mode,
            &state_path,
            Some(unavailable_backend_status(&failure)),
        );
        print_agent_status(&status, json);
        return Ok(());
    }
    let backend = start_backend(codex, backend_mode, &state_path)?;
    let status =
        collect_status_with_backend(codex, backend_mode, &state_path, Some(backend.status));
    print_agent_status(&status, json);
    Ok(())
}

fn print_agent_status(status: &AgentStatus, json: bool) {
    if json {
        println!(
            "{}",
            serde_json::to_string_pretty(status).expect("serialize agent status")
        );
        return;
    }
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
        "reconnect cache: {} pending approvals, {} recent events, {} threads ({})",
        status.reconnect_cache.pending_approvals,
        status.reconnect_cache.recent_events,
        status.reconnect_cache.threads,
        status.reconnect_cache.state_path
    );
    if let Some(load_error) = &status.reconnect_cache.load_error {
        println!("reconnect cache load error: {load_error}");
    }
}

fn print_probe(codex: &ResolvedCodexCommand, json_output: bool) -> anyhow::Result<()> {
    let result = run_probe(codex)?;
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

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct CodexCommandDiagnostic {
    program: String,
    args: Vec<String>,
    path_prepend: Vec<String>,
    source: &'static str,
    available: bool,
    version: Option<String>,
    failure: Option<CodexCommandFailureDiagnostic>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct CodexCommandFailureDiagnostic {
    kind: &'static str,
    detail: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct DoctorResult {
    config_path: String,
    codex: CodexCommandDiagnostic,
    status: AgentStatus,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct ConfigureResult {
    config_path: String,
    codex: CodexCommandDiagnostic,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct StopResult {
    stopped: bool,
    backend: BackendStatus,
}

fn print_stop(
    backend_mode: BackendMode,
    state_path: Option<&Path>,
    json_output: bool,
) -> anyhow::Result<()> {
    let state_path = resolve_state_path(state_path);
    let result = stop_backend(backend_mode, &state_path)?;

    if json_output {
        println!("{}", serde_json::to_string_pretty(&result)?);
    } else {
        if result.stopped {
            println!("SadCoder service stopped.");
        } else {
            println!("SadCoder service was not running.");
        }
        println!(
            "backend: {:?} {:?}",
            result.backend.kind, result.backend.state
        );
        if let Some(detail) = &result.backend.detail {
            println!("backend detail: {detail}");
        }
    }
    Ok(())
}

fn print_doctor(
    codex: &ResolvedCodexCommand,
    backend_mode: BackendMode,
    state_path: Option<&Path>,
    json_output: bool,
) -> anyhow::Result<()> {
    let state_path = resolve_state_path(state_path);
    let result = collect_doctor_result(codex, backend_mode, &state_path);

    if json_output {
        println!("{}", serde_json::to_string_pretty(&result)?);
    } else {
        println!("agent config: {}", result.config_path);
        print_codex_diagnostic(&result.codex);
        println!(
            "backend: {:?} {:?}",
            result.status.backend.kind, result.status.backend.state
        );
        if let Some(detail) = &result.status.backend.detail {
            println!("backend detail: {detail}");
        }
        println!(
            "reconnect cache: {} pending approvals, {} recent events, {} threads ({})",
            result.status.reconnect_cache.pending_approvals,
            result.status.reconnect_cache.recent_events,
            result.status.reconnect_cache.threads,
            result.status.reconnect_cache.state_path
        );
        if let Some(load_error) = &result.status.reconnect_cache.load_error {
            println!("reconnect cache load error: {load_error}");
        }
    }
    Ok(())
}

fn collect_doctor_result(
    codex: &ResolvedCodexCommand,
    backend_mode: BackendMode,
    state_path: &Path,
) -> DoctorResult {
    DoctorResult {
        config_path: agent_config_path().display().to_string(),
        codex: collect_codex_diagnostic(codex),
        status: collect_status(codex, backend_mode, state_path),
    }
}

fn configure_codex(
    codex: PathBuf,
    codex_args: Vec<String>,
    path_prepend: Vec<PathBuf>,
    json_output: bool,
) -> anyhow::Result<()> {
    let mut config = CodexCommandConfig::from_program(codex, codex_args, path_prepend);
    let resolved = ResolvedCodexCommand {
        program: config.program.clone(),
        args: config
            .args
            .iter()
            .map(|arg| OsString::from(arg.as_str()))
            .collect(),
        path_prepend: config.path_prepend.clone(),
        source: CodexCommandSource::Config,
    };
    let diagnostic = collect_codex_diagnostic(&resolved);
    config.version.clone_from(&diagnostic.version);
    let config_path = persist_codex_command(&config)?;
    let result = ConfigureResult {
        config_path: config_path.display().to_string(),
        codex: diagnostic,
    };

    if json_output {
        println!("{}", serde_json::to_string_pretty(&result)?);
    } else {
        println!("saved Codex configuration: {}", result.config_path);
        print_codex_diagnostic(&result.codex);
    }
    Ok(())
}

fn collect_codex_diagnostic(codex: &ResolvedCodexCommand) -> CodexCommandDiagnostic {
    let probe = probe_codex_version(codex);
    CodexCommandDiagnostic {
        program: codex.display_program(),
        args: codex
            .args
            .iter()
            .map(|arg| arg.to_string_lossy().to_string())
            .collect(),
        path_prepend: codex
            .path_prepend
            .iter()
            .map(|path| path.display().to_string())
            .collect(),
        source: codex.source.as_str(),
        available: probe.is_ok(),
        version: probe.as_ref().ok().cloned(),
        failure: probe.err().map(|failure| CodexCommandFailureDiagnostic {
            kind: failure.kind.as_str(),
            detail: failure.detail,
        }),
    }
}

fn print_codex_diagnostic(diagnostic: &CodexCommandDiagnostic) {
    println!("codex program: {}", diagnostic.program);
    println!("codex source: {}", diagnostic.source);
    if diagnostic.path_prepend.is_empty() {
        println!("path prepend: <empty>");
    } else {
        println!("path prepend: {}", diagnostic.path_prepend.join(", "));
    }
    match (&diagnostic.version, &diagnostic.failure) {
        (Some(version), _) => println!("codex version: {version}"),
        (_, Some(failure)) => println!("codex failure: {}: {}", failure.kind, failure.detail),
        _ => println!("codex version: not available"),
    }
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

fn print_snapshot(
    state_path: Option<&Path>,
    json_output: bool,
    since_cursor: Option<&str>,
) -> anyhow::Result<()> {
    let state_path = resolve_state_path(state_path);
    let snapshot = AgentStateCache::load(&state_path)?.snapshot_since_cursor(since_cursor);
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

fn print_logs(state_path: Option<&Path>, json_output: bool, tail_bytes: u64) -> anyhow::Result<()> {
    let state_path = resolve_state_path(state_path);
    let logs = collect_agent_logs(&state_path, tail_bytes);
    if json_output {
        println!("{}", serde_json::to_string_pretty(&logs)?);
    } else {
        for log in &logs.logs {
            println!("{}: {}", log.name, log.path);
            if !log.exists {
                println!("missing");
                continue;
            }
            println!(
                "size: {} bytes, tail: {} bytes{}",
                log.size_bytes,
                log.tail_bytes,
                if log.truncated { " (truncated)" } else { "" }
            );
            if let Some(error) = &log.error {
                println!("error: {error}");
            }
            if !log.content.is_empty() {
                print!("{}", log.content);
                if !log.content.ends_with('\n') {
                    println!();
                }
            }
        }
    }
    Ok(())
}

fn print_schema(
    codex: &ResolvedCodexCommand,
    state_path: Option<&Path>,
    options: AgentSchemaOptions,
    json_output: bool,
) -> anyhow::Result<()> {
    let state_path = resolve_state_path(state_path);
    let result = collect_agent_schema(codex, &state_path, options)?;
    if json_output {
        println!("{}", serde_json::to_string_pretty(&result)?);
    } else {
        println!(
            "app-server schema: {} file(s), {} bytes{}",
            result.file_count,
            result.total_bytes,
            if result.generated { " (refreshed)" } else { "" }
        );
        if let Some(version) = &result.codex_version {
            println!("codex version: {version}");
        }
        if let Some(digest) = &result.digest {
            println!("digest: {digest}");
        }
        println!("cache: {}", result.cache_dir);
        if let Some(bundle_path) = &result.bundle_path {
            println!("bundle: {bundle_path}");
        }
    }
    Ok(())
}

fn collect_status(
    codex: &ResolvedCodexCommand,
    backend_mode: BackendMode,
    state_path: &Path,
) -> AgentStatus {
    collect_status_with_backend(codex, backend_mode, state_path, None)
}

fn collect_status_with_backend(
    codex: &ResolvedCodexCommand,
    backend_mode: BackendMode,
    state_path: &Path,
    backend_override: Option<BackendStatus>,
) -> AgentStatus {
    let codex_probe = probe_codex_version(codex);
    let codex_version = codex_probe.as_ref().ok().cloned();
    let codex_available = codex_probe.is_ok();
    let codex_failure = codex_probe
        .as_ref()
        .err()
        .map(|failure| CodexFailureStatus {
            kind: failure.kind.as_str().to_string(),
            detail: failure.detail.clone(),
        });
    let service_paths = resolve_service_paths(state_path);
    let backend = backend_override.unwrap_or_else(|| {
        collect_backend_status(codex_probe.as_ref().err(), backend_mode, &service_paths)
    });
    let reconnect_cache = collect_reconnect_cache_status(state_path);

    AgentStatus {
        agent_version: env!("CARGO_PKG_VERSION").to_string(),
        platform_os: std::env::consts::OS.to_string(),
        platform_arch: std::env::consts::ARCH.to_string(),
        codex_path: codex.display_program(),
        codex_available,
        codex_version,
        codex_failure,
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
                threads: snapshot.threads.len(),
                delivered_cursor: snapshot.delivered_cursor,
                load_error: None,
            }
        }
        Err(error) => AgentReconnectCacheStatus {
            state_path: state_path.display().to_string(),
            schema_version: 1,
            pending_approvals: 0,
            recent_events: 0,
            threads: 0,
            delivered_cursor: None,
            load_error: Some(error.to_string()),
        },
    }
}

fn collect_backend_status(
    codex_failure: Option<&CodexProbeFailure>,
    backend_mode: BackendMode,
    service_paths: &AgentServicePaths,
) -> BackendStatus {
    if let Some(failure) = codex_failure {
        return unavailable_backend_status(failure);
    }

    match backend_mode {
        BackendMode::Auto => collect_auto_backend_status(service_paths),
        BackendMode::Stdio => {
            stdio_backend_status("direct stdio debug backend; SSH disconnect can end app-server")
        }
        BackendMode::Daemon => stdio_backend_status(
            "compat daemon mode uses direct stdio fallback; official Codex daemon is not used",
        ),
    }
}

fn unavailable_backend_status(failure: &CodexProbeFailure) -> BackendStatus {
    BackendStatus {
        kind: BackendKind::Unknown,
        state: BackendState::Unavailable,
        detail: Some(failure.message()),
    }
}

fn stdio_backend_status(detail: impl Into<String>) -> BackendStatus {
    BackendStatus {
        kind: BackendKind::CodexAppServerStdio,
        state: BackendState::Ready,
        detail: Some(detail.into()),
    }
}

fn collect_auto_backend_status(service_paths: &AgentServicePaths) -> BackendStatus {
    let service_status = collect_service_backend_status(service_paths);
    if service_status.state == BackendState::Ready {
        return service_status;
    }

    let service_detail = service_status
        .detail
        .unwrap_or_else(|| "SadCoder service is not ready".to_string());
    BackendStatus {
        kind: service_status.kind,
        state: service_status.state,
        detail: Some(format!(
            "{service_detail}; auto will start and connect to the SadCoder service"
        )),
    }
}

fn collect_service_backend_status(service_paths: &AgentServicePaths) -> BackendStatus {
    if service_is_ready(service_paths) {
        return BackendStatus {
            kind: BackendKind::SadcoderAgentService,
            state: BackendState::Ready,
            detail: Some(format!(
                "SadCoder service is listening at {}",
                service_paths.socket_path.display()
            )),
        };
    }

    let detail = match load_service_info(service_paths) {
        Ok(Some(info)) => format!(
            "SadCoder service record exists but socket is not ready at {} (service pid {}, app-server pid {})",
            service_paths.socket_path.display(),
            info.service_pid,
            info.app_server_pid
        ),
        Ok(None) => format!(
            "SadCoder service is not running; run sadcoder-agent start (socket {})",
            service_paths.socket_path.display()
        ),
        Err(error) => format!("SadCoder service status could not be read: {error}"),
    };

    BackendStatus {
        kind: BackendKind::SadcoderAgentService,
        state: BackendState::NotStarted,
        detail: Some(detail),
    }
}

fn select_backend(backend_mode: BackendMode) -> Result<SelectedBackend, String> {
    match backend_mode {
        BackendMode::Auto => Ok(SelectedBackend::Service),
        BackendMode::Stdio => Ok(SelectedBackend::Stdio),
        BackendMode::Daemon => Ok(SelectedBackend::Stdio),
    }
}

fn start_backend(
    codex: &ResolvedCodexCommand,
    backend_mode: BackendMode,
    state_path: &Path,
) -> anyhow::Result<ResolvedBackend> {
    if let Err(failure) = probe_codex_version(codex) {
        anyhow::bail!(failure.message());
    }

    match select_backend(backend_mode) {
        Ok(SelectedBackend::Service) => {
            let service_paths = resolve_service_paths(state_path);
            match start_service_process(codex, state_path, &service_paths) {
                Ok(()) => Ok(ResolvedBackend {
                    selection: SelectedBackend::Service,
                    status: collect_service_backend_status(&service_paths),
                }),
                Err(error) => Err(error),
            }
        }
        Ok(SelectedBackend::Stdio) => Ok(ResolvedBackend {
            selection: SelectedBackend::Stdio,
            status: stdio_backend_status(
                "direct stdio debug backend; SSH disconnect can end app-server",
            ),
        }),
        Err(detail) => anyhow::bail!(detail),
    }
}

fn stop_backend(backend_mode: BackendMode, state_path: &Path) -> anyhow::Result<StopResult> {
    match select_backend(backend_mode) {
        Ok(SelectedBackend::Service) => {
            let service_paths = resolve_service_paths(state_path);
            let stopped = service_is_ready(&service_paths)
                || service_paths.info_path.exists()
                || service_paths.socket_path.exists()
                || service_paths.app_server_socket_path.exists();
            service::stop_service_process(&service_paths)?;
            Ok(StopResult {
                stopped,
                backend: collect_service_backend_status(&service_paths),
            })
        }
        Ok(SelectedBackend::Stdio) => anyhow::bail!(
            "sadcoder-agent stop is only available for the SadCoder service backend; stdio is a direct debug backend"
        ),
        Err(detail) => anyhow::bail!(detail),
    }
}

fn stop_backend_result(backend: SelectedBackend, state_path: &Path) -> anyhow::Result<Value> {
    match backend {
        SelectedBackend::Service => {
            let result = stop_backend(BackendMode::Auto, state_path)?;
            Ok(json!({
                "disconnectRequired": true,
                "stopped": result.stopped,
                "backend": result.backend
            }))
        }
        SelectedBackend::Stdio => anyhow::bail!(
            "agent/stopBackend is only available for the SadCoder service backend; stdio is a direct debug backend"
        ),
    }
}

fn restart_backend_result(
    codex: &ResolvedCodexCommand,
    backend: SelectedBackend,
    state_path: &Path,
) -> anyhow::Result<Value> {
    match backend {
        SelectedBackend::Service => {
            let service_paths = resolve_service_paths(state_path);
            restart_service_process(codex, state_path, &service_paths)?;
            Ok(json!({
                "reconnectRequired": true,
                "status": collect_status(codex, BackendMode::Auto, state_path)
            }))
        }
        SelectedBackend::Stdio => anyhow::bail!(
            "agent/restartBackend is only available for the SadCoder service backend; stdio is a direct debug backend"
        ),
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

fn run_probe(codex: &ResolvedCodexCommand) -> anyhow::Result<ProbeResult> {
    let mut command = codex.command()?;
    let mut child = command
        .args(["app-server", "--listen", "stdio://"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .with_context(|| {
            format!(
                "failed to spawn `{} app-server --listen stdio://`",
                codex.display_program()
            )
        })?;

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

fn proxy_app_server(
    codex: &ResolvedCodexCommand,
    backend_mode: BackendMode,
    state_path: PathBuf,
) -> anyhow::Result<()> {
    let backend = start_backend(codex, backend_mode, &state_path)?;
    match backend.selection {
        SelectedBackend::Service => {
            proxy_service_app_server(codex, state_path, SelectedBackend::Service)
        }
        SelectedBackend::Stdio => proxy_stdio_app_server(codex, state_path),
    }
}

fn proxy_service_app_server(
    codex: &ResolvedCodexCommand,
    state_path: PathBuf,
    backend: SelectedBackend,
) -> anyhow::Result<()> {
    let service_paths = resolve_service_paths(&state_path);
    let connection = connect_service_proxy(&service_paths.socket_path)?;
    proxy_service_connection(
        connection,
        AgentProxyContext {
            codex: codex.clone(),
            backend,
            state_path,
        },
    )
}

fn proxy_stdio_app_server(codex: &ResolvedCodexCommand, state_path: PathBuf) -> anyhow::Result<()> {
    let mut command = codex.command()?;
    let child = command
        .args(["app-server", "--listen", "stdio://"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .with_context(|| {
            format!(
                "failed to spawn `{} app-server --listen stdio://`",
                codex.display_program()
            )
        })?;

    proxy_child_process(
        child,
        AgentProxyContext {
            codex: codex.clone(),
            backend: SelectedBackend::Stdio,
            state_path,
        },
    )
}

fn proxy_child_process(mut child: Child, context: AgentProxyContext) -> anyhow::Result<()> {
    let mut child_stdin = child.stdin.take().context("child stdin was not piped")?;
    let mut child_stdout = child.stdout.take().context("child stdout was not piped")?;
    let stdout = Arc::new(Mutex::new(io::stdout()));
    let state_path = context.state_path.clone();
    let cache = Arc::new(Mutex::new(
        AgentStateCache::load(&state_path).unwrap_or_else(|_| AgentStateCache::empty()),
    ));

    let stdin_cache = Arc::clone(&cache);
    let stdin_state_path = state_path.clone();
    let stdin_stdout = Arc::clone(&stdout);
    let stdin_context = context.clone();
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
            if let Some(response) = local_response_from_client_line(&line, &stdin_context) {
                if write_proxy_json_response(&stdin_stdout, &response).is_err() {
                    break;
                }
                continue;
            }
            if child_stdin.write_all(&line).is_err() {
                break;
            }
            let _ = child_stdin.flush();
        }
    });
    let stdout_cache = Arc::clone(&cache);
    let stdout_state_path = state_path;
    let child_stdout_writer = Arc::clone(&stdout);
    let stdout_thread = thread::spawn(move || {
        let mut reader = BufReader::new(&mut child_stdout);
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
            if write_proxy_line(&child_stdout_writer, &line).is_err() {
                break;
            }
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

fn proxy_service_connection(
    connection: ServiceProxyConnection,
    context: AgentProxyContext,
) -> anyhow::Result<()> {
    let stdout = Arc::new(Mutex::new(io::stdout()));

    let mut service_writer = connection.writer;
    let stdin_stdout = Arc::clone(&stdout);
    let stdin_context = context.clone();
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
            if let Some(response) = local_response_from_client_line(&line, &stdin_context) {
                if write_proxy_json_response(&stdin_stdout, &response).is_err() {
                    break;
                }
                continue;
            }
            if service_writer.write_all(&line).is_err() {
                break;
            }
            let _ = service_writer.flush();
        }
        service_writer.shutdown();
    });

    let mut service_reader = connection.reader;
    let service_stdout = Arc::clone(&stdout);
    let stdout_thread = thread::spawn(move || {
        let mut reader = BufReader::new(&mut service_reader);
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
            if write_proxy_line(&service_stdout, &line).is_err() {
                break;
            }
        }
    });

    let _ = stdin_thread.join();
    let _ = stdout_thread.join();
    Ok(())
}

fn local_response_from_client_line(
    line: &[u8],
    context: &AgentProxyContext,
) -> Option<JsonRpcResponse> {
    let request = serde_json::from_slice::<JsonRpcRequest>(line).ok()?;
    if let Some(response) = handle_agent_request(&request, context) {
        return Some(response);
    }
    handle_workspace_request(&request)
}

fn handle_agent_request(
    request: &JsonRpcRequest,
    context: &AgentProxyContext,
) -> Option<JsonRpcResponse> {
    let method = AgentRpcMethod::from_request(request)?;
    let result = match method {
        AgentRpcMethod::Hello => Ok(agent_rpc::hello_result()),
        AgentRpcMethod::Ping => Ok(agent_rpc::ping_result()),
        AgentRpcMethod::Health => serde_json::to_value(collect_status(
            &context.codex,
            match context.backend {
                SelectedBackend::Service => BackendMode::Auto,
                SelectedBackend::Stdio => BackendMode::Stdio,
            },
            &context.state_path,
        ))
        .map_err(|error| error.to_string()),
        AgentRpcMethod::Logs => {
            collect_agent_logs_from_params(&context.state_path, request.params.as_ref())
                .and_then(|logs| serde_json::to_value(logs).map_err(Into::into))
                .map_err(|error| error.to_string())
        }
        AgentRpcMethod::Snapshot => AgentStateCache::load(&context.state_path)
            .map(|cache| {
                cache.snapshot_since_cursor(snapshot_since_cursor(request.params.as_ref()))
            })
            .and_then(|snapshot| serde_json::to_value(snapshot).map_err(Into::into))
            .map_err(|error| error.to_string()),
        AgentRpcMethod::Schema => collect_agent_schema_from_params(
            &context.codex,
            &context.state_path,
            request.params.as_ref(),
        )
        .and_then(|schema| serde_json::to_value(schema).map_err(Into::into))
        .map_err(|error| error.to_string()),
        AgentRpcMethod::SlashCommands => load_slash_command_manifest()
            .and_then(|manifest| serde_json::to_value(manifest).map_err(Into::into))
            .map_err(|error| error.to_string()),
        AgentRpcMethod::RestartBackend => {
            restart_backend_result(&context.codex, context.backend, &context.state_path)
                .map_err(|error| error.to_string())
        }
        AgentRpcMethod::StopBackend => stop_backend_result(context.backend, &context.state_path)
            .map_err(|error| error.to_string()),
    };

    Some(match result {
        Ok(result) => agent_rpc::success_response(request, result),
        Err(detail) => agent_rpc::error_response(request, detail),
    })
}

fn snapshot_since_cursor(params: Option<&Value>) -> Option<&str> {
    params
        .and_then(Value::as_object)
        .and_then(|params| {
            params
                .get("sinceCursor")
                .or_else(|| params.get("since_cursor"))
        })
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|cursor| !cursor.is_empty())
}

fn write_proxy_json_response(
    stdout: &Arc<Mutex<io::Stdout>>,
    response: &JsonRpcResponse,
) -> io::Result<()> {
    let mut line = serde_json::to_vec(response)
        .map_err(|error| io::Error::new(io::ErrorKind::Other, error))?;
    line.push(b'\n');
    write_proxy_line(stdout, &line)
}

fn write_proxy_line(stdout: &Arc<Mutex<io::Stdout>>, line: &[u8]) -> io::Result<()> {
    let mut stdout = stdout
        .lock()
        .map_err(|_| io::Error::new(io::ErrorKind::Other, "stdout lock poisoned"))?;
    stdout.write_all(line)?;
    stdout.flush()
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

    fn missing_configured_codex() -> ResolvedCodexCommand {
        ResolvedCodexCommand {
            program: std::env::temp_dir().join("definitely-missing-sadcoder-codex-binary"),
            args: Vec::new(),
            path_prepend: Vec::new(),
            source: CodexCommandSource::Config,
        }
    }

    fn available_codex_version_command() -> ResolvedCodexCommand {
        #[cfg(windows)]
        let (program, args) = (
            PathBuf::from("cmd"),
            vec![
                OsString::from("/D"),
                OsString::from("/C"),
                OsString::from("echo codex 1.2.3"),
            ],
        );
        #[cfg(not(windows))]
        let (program, args) = (
            PathBuf::from("sh"),
            vec![
                OsString::from("-c"),
                OsString::from("printf 'codex 1.2.3\\n'"),
            ],
        );

        ResolvedCodexCommand {
            program,
            args,
            path_prepend: Vec::new(),
            source: CodexCommandSource::Path,
        }
    }

    fn test_proxy_context(state_path: PathBuf) -> AgentProxyContext {
        AgentProxyContext {
            codex: missing_configured_codex(),
            backend: SelectedBackend::Service,
            state_path,
        }
    }

    fn request_line(method: &str, params: Option<Value>) -> Vec<u8> {
        let request = JsonRpcRequest::new(RequestId::Number(7), method, params);
        let mut line = serde_json::to_vec(&request).expect("serialize request");
        line.push(b'\n');
        line
    }

    fn response_json(response: JsonRpcResponse) -> Value {
        serde_json::to_value(response).expect("serialize response")
    }

    #[test]
    fn snapshot_since_cursor_accepts_camel_and_snake_case_params() {
        assert_eq!(
            snapshot_since_cursor(Some(&json!({ "sinceCursor": " 7 " }))),
            Some("7")
        );
        assert_eq!(
            snapshot_since_cursor(Some(&json!({ "since_cursor": " 8 " }))),
            Some("8")
        );
        assert_eq!(
            snapshot_since_cursor(Some(&json!({ "sinceCursor": " " }))),
            None
        );
    }

    #[test]
    fn snapshot_command_parses_since_cursor() {
        let cli = Cli::try_parse_from([
            "sadcoder-agent",
            "snapshot",
            "--since-cursor",
            "7",
            "--json",
        ])
        .expect("parse CLI");

        match cli.command {
            AgentCommand::Snapshot { json, since_cursor } => {
                assert!(json);
                assert_eq!(since_cursor.as_deref(), Some("7"));
            }
            command => panic!("unexpected command: {command:?}"),
        }
    }

    #[test]
    fn unavailable_codex_reports_unavailable_backend() {
        let codex = missing_configured_codex();
        let status = collect_status(
            &codex,
            BackendMode::Auto,
            Path::new("sadcoder-agent-test-state.json"),
        );

        assert!(!status.codex_available);
        assert_eq!(
            status
                .codex_failure
                .as_ref()
                .map(|failure| failure.kind.as_str()),
            Some("configured-path-missing")
        );
        assert!(status.codex_failure.as_ref().is_some_and(|failure| {
            failure
                .detail
                .contains("definitely-missing-sadcoder-codex-binary")
        }));
        assert_eq!(status.backend.kind, BackendKind::Unknown);
        assert_eq!(status.backend.state, BackendState::Unavailable);
        assert!(
            status
                .backend
                .detail
                .as_deref()
                .is_some_and(|detail| detail.contains("configured-path-missing"))
        );
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
                cursor: Some("1".to_string()),
            });
        cache
            .snapshot
            .threads
            .push(sadcoder_protocol::AgentCachedThread {
                thread_id: "thread-1".to_string(),
                last_turn_id: Some("turn-1".to_string()),
                last_item_id: None,
                last_event_cursor: Some("1".to_string()),
            });
        cache.snapshot.delivered_cursor = Some("1".to_string());

        cache.save(&path).expect("save cache");
        let codex = missing_configured_codex();
        let status = collect_status(&codex, BackendMode::Auto, &path);
        let _ = std::fs::remove_file(&path);

        assert_eq!(
            status.reconnect_cache.state_path,
            path.display().to_string()
        );
        assert_eq!(status.reconnect_cache.schema_version, 1);
        assert_eq!(status.reconnect_cache.pending_approvals, 1);
        assert_eq!(status.reconnect_cache.recent_events, 1);
        assert_eq!(status.reconnect_cache.threads, 1);
        assert_eq!(
            status.reconnect_cache.delivered_cursor.as_deref(),
            Some("1")
        );
        assert_eq!(status.reconnect_cache.load_error, None);
    }

    #[test]
    fn doctor_result_combines_codex_backend_and_reconnect_diagnostics() {
        let path = std::env::temp_dir().join(format!(
            "sadcoder-agent-doctor-test-{}-{}.json",
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
        cache.save(&path).expect("save cache");

        let codex = missing_configured_codex();
        let result = collect_doctor_result(&codex, BackendMode::Auto, &path);
        let encoded = serde_json::to_value(&result).expect("serialize doctor result");
        let _ = std::fs::remove_file(&path);

        assert!(result.config_path.ends_with("agent.json"));
        assert!(!result.codex.available);
        assert_eq!(
            result.codex.failure.as_ref().map(|failure| failure.kind),
            Some("configured-path-missing")
        );
        assert!(!result.status.codex_available);
        assert_eq!(result.status.backend.kind, BackendKind::Unknown);
        assert_eq!(result.status.backend.state, BackendState::Unavailable);
        assert_eq!(result.status.reconnect_cache.pending_approvals, 1);
        assert!(encoded["configPath"].is_string());
        assert_eq!(encoded["codex"]["available"], false);
        assert_eq!(encoded["status"]["codexAvailable"], false);
        assert_eq!(encoded["status"]["backend"]["kind"], "unknown");
        assert_eq!(encoded["status"]["reconnectCache"]["pendingApprovals"], 1);
    }

    #[test]
    fn backend_selection_uses_service_by_default_and_falls_back_from_daemon() {
        assert_eq!(
            select_backend(BackendMode::Auto),
            Ok(SelectedBackend::Service)
        );
        assert_eq!(
            select_backend(BackendMode::Stdio),
            Ok(SelectedBackend::Stdio)
        );
        assert_eq!(
            select_backend(BackendMode::Daemon),
            Ok(SelectedBackend::Stdio)
        );
    }

    #[test]
    fn auto_backend_errors_when_service_start_fails() {
        let blocked_base = std::env::temp_dir().join(format!(
            "sadcoder-agent-auto-backend-service-error-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ));
        std::fs::write(&blocked_base, b"not a directory").expect("write blocked service base");
        let state_path = blocked_base.join("agent-state.json");
        let error = start_backend(
            &available_codex_version_command(),
            BackendMode::Auto,
            &state_path,
        )
        .expect_err("auto backend should require the SadCoder service");
        let _ = std::fs::remove_file(&blocked_base);

        assert!(!error.to_string().is_empty());
    }

    #[test]
    fn auto_backend_does_not_fallback_when_codex_is_unavailable() {
        let base = std::env::temp_dir().join(format!(
            "sadcoder-agent-auto-backend-no-fallback-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ));
        let state_path = base.join("agent-state.json");
        let error = start_backend(&missing_configured_codex(), BackendMode::Auto, &state_path)
            .expect_err("unavailable Codex should not fall back");

        assert!(error.to_string().contains("configured-path-missing"));
    }

    #[test]
    fn stop_backend_cleans_stale_service_files_without_codex_probe() {
        let base = std::env::temp_dir().join(format!(
            "sadcoder-agent-stop-backend-stale-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ));
        let state_path = base.join("agent-state.json");
        let service_paths = resolve_service_paths(&state_path);
        std::fs::create_dir_all(&base).expect("create service base");
        std::fs::write(
            &service_paths.info_path,
            serde_json::to_vec(&json!({
                "schemaVersion": 2,
                "servicePid": 1,
                "appServerPid": 2,
                "socketPath": service_paths.socket_path,
                "appServerSocketPath": service_paths.app_server_socket_path,
                "listenUrl": "unix://stale",
                "startedAtUnixMs": 1
            }))
            .expect("serialize service info"),
        )
        .expect("write service info");
        std::fs::write(&service_paths.socket_path, b"stale").expect("write stale service socket");
        std::fs::write(&service_paths.app_server_socket_path, b"stale")
            .expect("write stale app-server socket");

        let result = stop_backend(BackendMode::Auto, &state_path).expect("stop stale backend");
        let _ = std::fs::remove_dir_all(&base);

        assert!(result.stopped);
        assert_eq!(result.backend.kind, BackendKind::SadcoderAgentService);
        assert_eq!(result.backend.state, BackendState::NotStarted);
    }

    #[test]
    fn stop_backend_rejects_stdio_debug_backend() {
        let error = stop_backend(
            BackendMode::Stdio,
            &std::env::temp_dir().join("sadcoder-agent-stop-stdio.json"),
        )
        .expect_err("stdio stop should be rejected");

        assert!(
            error
                .to_string()
                .contains("stdio is a direct debug backend")
        );
    }

    #[test]
    fn configure_command_parses_codex_args() {
        let cli = Cli::try_parse_from([
            "sadcoder-agent",
            "configure",
            "--codex",
            "node-bin/codex",
            "--codex-arg",
            "--profile",
            "--codex-arg",
            "mobile profile",
            "--path-prepend",
            "node-bin",
            "--json",
        ])
        .expect("parse configure command");

        match cli.command {
            AgentCommand::Configure {
                codex,
                codex_args,
                path_prepend,
                json,
            } => {
                assert_eq!(codex, PathBuf::from("node-bin/codex"));
                assert_eq!(
                    codex_args,
                    vec!["--profile".to_string(), "mobile profile".to_string()]
                );
                assert_eq!(path_prepend, vec![PathBuf::from("node-bin")]);
                assert!(json);
            }
            command => panic!("expected configure command, got {command:?}"),
        }
    }

    #[test]
    fn logs_command_parses_tail_bytes() {
        let cli = Cli::try_parse_from(["sadcoder-agent", "logs", "--tail-bytes", "8192", "--json"])
            .expect("parse logs command");

        match cli.command {
            AgentCommand::Logs { json, tail_bytes } => {
                assert!(json);
                assert_eq!(tail_bytes, 8192);
            }
            command => panic!("expected logs command, got {command:?}"),
        }
    }

    #[test]
    fn stop_command_parses_json_flag() {
        let cli =
            Cli::try_parse_from(["sadcoder-agent", "stop", "--json"]).expect("parse stop command");

        match cli.command {
            AgentCommand::Stop { json } => assert!(json),
            command => panic!("expected stop command, got {command:?}"),
        }
    }

    #[test]
    fn schema_command_parses_refresh_and_experimental_flags() {
        let cli = Cli::try_parse_from([
            "sadcoder-agent",
            "schema",
            "--refresh",
            "--experimental",
            "--json",
        ])
        .expect("parse schema command");

        match cli.command {
            AgentCommand::Schema {
                json,
                refresh,
                experimental,
            } => {
                assert!(json);
                assert!(refresh);
                assert!(experimental);
            }
            command => panic!("expected schema command, got {command:?}"),
        }
    }

    #[test]
    fn hidden_service_command_parses_resolved_codex_snapshot() {
        let cli = Cli::try_parse_from([
            "sadcoder-agent",
            "--state-path",
            "state/agent-state.json",
            "service",
            "--resolved-codex-program",
            "node-bin/codex",
            "--resolved-codex-arg",
            "--wrapper-flag",
            "--resolved-codex-arg",
            "value with spaces",
            "--resolved-codex-path-prepend",
            "node-bin",
            "--resolved-codex-path-prepend",
            "extra-runtime-bin",
        ])
        .expect("parse service snapshot");

        match cli.command {
            AgentCommand::Service {
                resolved_codex_program,
                resolved_codex_args,
                resolved_codex_path_prepend,
            } => {
                assert_eq!(
                    resolved_codex_program,
                    Some(PathBuf::from("node-bin/codex"))
                );
                assert_eq!(
                    resolved_codex_args,
                    vec![
                        OsString::from("--wrapper-flag"),
                        OsString::from("value with spaces"),
                    ]
                );
                assert_eq!(
                    resolved_codex_path_prepend,
                    vec![
                        PathBuf::from("node-bin"),
                        PathBuf::from("extra-runtime-bin"),
                    ]
                );
            }
            command => panic!("expected service command, got {command:?}"),
        }
    }

    #[test]
    fn auto_backend_reports_not_started_service_without_stdio_fallback_detail() {
        let base = std::env::temp_dir().join(format!(
            "sadcoder-agent-service-status-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ));
        let service_paths = resolve_service_paths(&base.join("agent-state.json"));

        let status = collect_backend_status(None, BackendMode::Auto, &service_paths);

        assert_eq!(status.kind, BackendKind::SadcoderAgentService);
        assert_eq!(status.state, BackendState::NotStarted);
        let detail = status.detail.as_deref().expect("detail");
        assert!(detail.contains("auto will start and connect"));
        assert!(!detail.contains("stdio fallback"));
    }

    #[test]
    fn daemon_backend_mode_reports_stdio_fallback_status() {
        let base = std::env::temp_dir().join(format!(
            "sadcoder-agent-daemon-fallback-status-test-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ));
        let service_paths = resolve_service_paths(&base.join("agent-state.json"));

        let status = collect_backend_status(None, BackendMode::Daemon, &service_paths);

        assert_eq!(status.kind, BackendKind::CodexAppServerStdio);
        assert_eq!(status.state, BackendState::Ready);
        assert!(
            status
                .detail
                .as_deref()
                .is_some_and(|detail| detail.contains("stdio"))
        );
    }

    #[test]
    fn local_proxy_handles_agent_hello_without_forwarding() {
        let context = test_proxy_context(std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-hello-{}.json",
            std::process::id()
        )));
        let response =
            local_response_from_client_line(&request_line("agent/hello", None), &context)
                .expect("local response");
        let response = response_json(response);

        assert_eq!(response["id"], 7);
        assert_eq!(response["result"]["capabilities"]["agentRpc"], true);
        assert!(
            response["result"]["methods"]
                .as_array()
                .expect("methods")
                .iter()
                .any(|method| method.as_str() == Some("agent/health"))
        );
    }

    #[test]
    fn local_proxy_handles_agent_health_with_status_shape() {
        let context = test_proxy_context(std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-health-{}.json",
            std::process::id()
        )));
        let response =
            local_response_from_client_line(&request_line("agent/health", None), &context)
                .expect("local response");
        let response = response_json(response);

        assert_eq!(response["id"], 7);
        assert_eq!(
            response["result"]["agentVersion"],
            env!("CARGO_PKG_VERSION")
        );
        assert_eq!(response["result"]["backend"]["state"], "unavailable");
        assert!(
            response["result"]["backend"]["detail"]
                .as_str()
                .expect("backend detail")
                .contains("configured-path-missing")
        );
    }

    #[test]
    fn local_proxy_handles_agent_logs_from_service_log_file() {
        let path = std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-logs-{}-{}/agent-state.json",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ));
        let service_paths = resolve_service_paths(&path);
        std::fs::create_dir_all(service_paths.stderr_log_path.parent().expect("parent"))
            .expect("create log dir");
        std::fs::write(&service_paths.stderr_log_path, b"first\nsecond\nthird")
            .expect("write service log");
        let context = test_proxy_context(path.clone());

        let response = local_response_from_client_line(
            &request_line("agent/logs", Some(json!({ "tailBytes": 5 }))),
            &context,
        )
        .expect("local response");
        let response = response_json(response);
        let _ = std::fs::remove_dir_all(service_paths.stderr_log_path.parent().expect("parent"));

        assert_eq!(response["id"], 7);
        assert_eq!(response["result"]["schemaVersion"], 1);
        assert_eq!(response["result"]["logs"][0]["name"], "app-server.stderr");
        assert_eq!(response["result"]["logs"][0]["exists"], true);
        assert_eq!(response["result"]["logs"][0]["truncated"], true);
        assert_eq!(response["result"]["logs"][0]["content"], "third");
    }

    #[test]
    fn local_proxy_handles_agent_snapshot_from_cache_file() {
        let path = std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-snapshot-{}-{}.json",
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
        cache.save(&path).expect("save cache");
        let context = test_proxy_context(path.clone());

        let response =
            local_response_from_client_line(&request_line("agent/snapshot", None), &context)
                .expect("local response");
        let response = response_json(response);
        let _ = std::fs::remove_file(&path);

        assert_eq!(
            response["result"]["pendingApprovals"][0]["id"],
            "approval-1"
        );
        assert_eq!(
            response["result"]["pendingApprovals"][0]["method"],
            "item/commandExecution/requestApproval"
        );
    }

    #[test]
    fn local_proxy_handles_agent_snapshot_since_cursor() {
        let path = std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-snapshot-cursor-{}-{}.json",
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
                method: "event/one".to_string(),
                params: Some(json!({ "threadId": "thr_1" })),
                cursor: Some("1".to_string()),
            });
        cache
            .snapshot
            .recent_events
            .push(sadcoder_protocol::AgentCachedEvent {
                method: "event/two".to_string(),
                params: Some(json!({ "threadId": "thr_1" })),
                cursor: Some("2".to_string()),
            });
        cache.snapshot.delivered_cursor = Some("2".to_string());
        cache.save(&path).expect("save cache");
        let context = test_proxy_context(path.clone());

        let response = local_response_from_client_line(
            &request_line("agent/snapshot", Some(json!({ "sinceCursor": "1" }))),
            &context,
        )
        .expect("local response");
        let response = response_json(response);
        let _ = std::fs::remove_file(&path);

        assert_eq!(
            response["result"]["pendingApprovals"][0]["id"],
            "approval-1"
        );
        assert_eq!(
            response["result"]["recentEvents"].as_array().unwrap().len(),
            1
        );
        assert_eq!(response["result"]["recentEvents"][0]["method"], "event/two");
        assert_eq!(response["result"]["recentEvents"][0]["cursor"], "2");
        assert_eq!(response["result"]["deliveredCursor"], "2");
        assert_eq!(response["result"]["retainedCursorFloor"], "1");
        assert!(response["result"].get("cursorGap").is_none());
    }

    #[test]
    fn local_proxy_handles_agent_schema_from_cache_file() {
        let path = std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-schema-{}-{}/agent-state.json",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ));
        let schema_dir = path
            .parent()
            .expect("state parent")
            .join("app-server-schema")
            .join("json");
        std::fs::create_dir_all(schema_dir.join("v2")).expect("create schema cache");
        std::fs::write(
            schema_dir.join("codex_app_server_protocol.schemas.json"),
            br#"{"schemaVersion":1}"#,
        )
        .expect("write schema bundle");
        std::fs::write(schema_dir.join("v2").join("ClientRequest.json"), b"{}")
            .expect("write schema file");
        std::fs::write(
            schema_dir.join("sadcoder-schema-cache.json"),
            br#"{"schemaVersion":1,"source":"codex app-server generate-json-schema","experimental":false,"codexVersion":"codex-cli 1.2.3","generatedAtUnixMs":9}"#,
        )
        .expect("write metadata");
        let context = test_proxy_context(path.clone());

        let response =
            local_response_from_client_line(&request_line("agent/schema", None), &context)
                .expect("local response");
        let response = response_json(response);
        let _ = std::fs::remove_dir_all(path.parent().expect("state parent"));

        assert_eq!(response["id"], 7);
        assert_eq!(response["result"]["schemaVersion"], 1);
        assert_eq!(response["result"]["generated"], false);
        assert_eq!(response["result"]["codexVersion"], "codex-cli 1.2.3");
        assert_eq!(response["result"]["fileCount"], 2);
        assert!(response["result"]["digest"].as_str().is_some());
    }

    #[test]
    fn local_proxy_handles_agent_slash_command_manifest() {
        let context = test_proxy_context(std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-slash-{}.json",
            std::process::id()
        )));
        let response = local_response_from_client_line(
            &request_line("agent/slashCommands/list", None),
            &context,
        )
        .expect("local response");
        let response = response_json(response);

        assert_eq!(response["result"]["schemaVersion"], 1);
        assert_eq!(response["result"]["commands"][0]["command"], "model");
    }

    #[test]
    fn local_proxy_rejects_restart_backend_for_stdio_debug_backend() {
        let mut context = test_proxy_context(std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-restart-{}.json",
            std::process::id()
        )));
        context.backend = SelectedBackend::Stdio;

        let response =
            local_response_from_client_line(&request_line("agent/restartBackend", None), &context)
                .expect("local response");
        let response = response_json(response);

        assert_eq!(response["id"], 7);
        assert!(
            response["error"]["message"]
                .as_str()
                .expect("error message")
                .contains("stdio is a direct debug backend")
        );
    }

    #[test]
    fn local_proxy_handles_agent_stop_backend_for_service_backend() {
        let context = test_proxy_context(std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-stop-{}.json",
            std::process::id()
        )));

        let response =
            local_response_from_client_line(&request_line("agent/stopBackend", None), &context)
                .expect("local response");
        let response = response_json(response);

        assert_eq!(response["id"], 7);
        assert_eq!(response["result"]["disconnectRequired"], true);
        assert_eq!(response["result"]["stopped"], false);
        assert_eq!(
            response["result"]["backend"]["kind"],
            "sadcoder-agent-service"
        );
        assert_eq!(response["result"]["backend"]["state"], "not-started");
    }

    #[test]
    fn local_proxy_rejects_stop_backend_for_stdio_debug_backend() {
        let mut context = test_proxy_context(std::env::temp_dir().join(format!(
            "sadcoder-agent-rpc-stop-stdio-{}.json",
            std::process::id()
        )));
        context.backend = SelectedBackend::Stdio;

        let response =
            local_response_from_client_line(&request_line("agent/stopBackend", None), &context)
                .expect("local response");
        let response = response_json(response);

        assert_eq!(response["id"], 7);
        assert!(
            response["error"]["message"]
                .as_str()
                .expect("error message")
                .contains("stdio is a direct debug backend")
        );
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
