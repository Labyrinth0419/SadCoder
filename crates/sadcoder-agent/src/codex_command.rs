use anyhow::Context;
use serde::Deserialize;
use serde::Serialize;
use std::env;
use std::ffi::OsString;
use std::fs;
use std::io;
use std::path::Path;
use std::path::PathBuf;
use std::process::Command;

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct ResolvedCodexCommand {
    pub(crate) program: PathBuf,
    pub(crate) args: Vec<OsString>,
    pub(crate) path_prepend: Vec<PathBuf>,
    pub(crate) source: CodexCommandSource,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum CodexCommandSource {
    Cli,
    Env,
    Config,
    Path,
    AutoDiscovered,
}

impl ResolvedCodexCommand {
    pub(crate) fn command(&self) -> anyhow::Result<Command> {
        let mut command = Command::new(&self.program);
        command.args(&self.args);

        let inherited = env::var_os("PATH").unwrap_or_default();
        let mut paths = self.path_prepend.clone();
        paths.extend(env::split_paths(&inherited));
        command.env("PATH", env::join_paths(paths)?);
        Ok(command)
    }

    pub(crate) fn display_program(&self) -> String {
        self.program.display().to_string()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentConfig {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub(crate) codex: Option<CodexCommandConfig>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct CodexCommandConfig {
    pub(crate) program: PathBuf,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub(crate) args: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub(crate) path_prepend: Vec<PathBuf>,
}

impl CodexCommandConfig {
    pub(crate) fn from_program(program: PathBuf, path_prepend: Vec<PathBuf>) -> Self {
        let mut path_prepend = path_prepend;
        if let Some(parent) = program
            .parent()
            .filter(|parent| !parent.as_os_str().is_empty())
        {
            path_prepend.insert(0, parent.to_path_buf());
        }
        dedupe_paths(&mut path_prepend);
        Self {
            program,
            args: Vec::new(),
            path_prepend,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct CodexProbeFailure {
    pub(crate) kind: CodexProbeFailureKind,
    pub(crate) detail: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum CodexProbeFailureKind {
    ProgramNotFound,
    RuntimeNotFound,
    PermissionDenied,
    NonZeroExit,
    VersionOutputInvalid,
    ConfiguredPathMissing,
}

impl CodexProbeFailureKind {
    pub(crate) fn as_str(self) -> &'static str {
        match self {
            CodexProbeFailureKind::ProgramNotFound => "program-not-found",
            CodexProbeFailureKind::RuntimeNotFound => "runtime-not-found",
            CodexProbeFailureKind::PermissionDenied => "permission-denied",
            CodexProbeFailureKind::NonZeroExit => "non-zero-exit",
            CodexProbeFailureKind::VersionOutputInvalid => "version-output-invalid",
            CodexProbeFailureKind::ConfiguredPathMissing => "configured-path-missing",
        }
    }
}

impl CodexCommandSource {
    pub(crate) fn as_str(self) -> &'static str {
        match self {
            CodexCommandSource::Cli => "cli",
            CodexCommandSource::Env => "env",
            CodexCommandSource::Config => "config",
            CodexCommandSource::Path => "path",
            CodexCommandSource::AutoDiscovered => "auto-discovered",
        }
    }
}

impl CodexProbeFailure {
    pub(crate) fn message(&self) -> String {
        format!("{}: {}", self.kind.as_str(), self.detail)
    }
}

pub(crate) fn resolve_codex_command(
    cli_program: Option<PathBuf>,
) -> anyhow::Result<ResolvedCodexCommand> {
    if let Some(program) = cli_program {
        return Ok(command_from_program(
            program,
            Vec::new(),
            CodexCommandSource::Cli,
        ));
    }

    if let Some(program) = env::var_os("SADCODER_CODEX_PATH").filter(|value| !value.is_empty()) {
        return Ok(command_from_program(
            PathBuf::from(program),
            Vec::new(),
            CodexCommandSource::Env,
        ));
    }

    if let Some(config) = load_agent_config()?.codex {
        return Ok(ResolvedCodexCommand {
            program: config.program,
            args: config.args.into_iter().map(OsString::from).collect(),
            path_prepend: config.path_prepend,
            source: CodexCommandSource::Config,
        });
    }

    if let Some(discovered) = discover_codex_program() {
        let resolved =
            command_from_program(discovered, Vec::new(), CodexCommandSource::AutoDiscovered);
        let _ = persist_codex_command(&CodexCommandConfig {
            program: resolved.program.clone(),
            args: Vec::new(),
            path_prepend: resolved.path_prepend.clone(),
        });
        return Ok(resolved);
    }

    Ok(ResolvedCodexCommand {
        program: PathBuf::from("codex"),
        args: Vec::new(),
        path_prepend: Vec::new(),
        source: CodexCommandSource::Path,
    })
}

pub(crate) fn persist_codex_command(config: &CodexCommandConfig) -> anyhow::Result<PathBuf> {
    let path = agent_config_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }
    let config = AgentConfig {
        codex: Some(config.clone()),
    };
    let bytes = serde_json::to_vec_pretty(&config)?;
    fs::write(&path, bytes).with_context(|| format!("failed to write {}", path.display()))?;
    Ok(path)
}

pub(crate) fn probe_codex_version(
    codex: &ResolvedCodexCommand,
) -> Result<String, CodexProbeFailure> {
    if is_configured_filesystem_program(codex) && !codex.program.exists() {
        return Err(CodexProbeFailure {
            kind: CodexProbeFailureKind::ConfiguredPathMissing,
            detail: format!("{} does not exist", codex.program.display()),
        });
    }

    let output = codex
        .command()
        .map_err(|error| CodexProbeFailure {
            kind: CodexProbeFailureKind::NonZeroExit,
            detail: error.to_string(),
        })?
        .arg("--version")
        .output()
        .map_err(|error| classify_spawn_error(error, codex))?;

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if !output.status.success() {
        let detail = if stderr.is_empty() { stdout } else { stderr };
        return Err(CodexProbeFailure {
            kind: classify_non_zero_output(&detail),
            detail: if detail.is_empty() {
                format!("codex --version exited with {}", output.status)
            } else {
                detail
            },
        });
    }

    if !stdout.is_empty() {
        Ok(stdout)
    } else if !stderr.is_empty() {
        Ok(stderr)
    } else {
        Err(CodexProbeFailure {
            kind: CodexProbeFailureKind::VersionOutputInvalid,
            detail: "codex --version produced no output".to_string(),
        })
    }
}

pub(crate) fn agent_config_path() -> PathBuf {
    if cfg!(windows) {
        if let Some(local_app_data) = env::var_os("LOCALAPPDATA") {
            return PathBuf::from(local_app_data)
                .join("SadCoder")
                .join("agent.json");
        }
    } else if let Some(config_home) = env::var_os("XDG_CONFIG_HOME") {
        return PathBuf::from(config_home)
            .join("sadcoder")
            .join("agent.json");
    }

    let home = env::var_os(if cfg!(windows) { "USERPROFILE" } else { "HOME" })
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));
    if cfg!(windows) {
        home.join("AppData")
            .join("Local")
            .join("SadCoder")
            .join("agent.json")
    } else {
        home.join(".config").join("sadcoder").join("agent.json")
    }
}

fn load_agent_config() -> anyhow::Result<AgentConfig> {
    let path = agent_config_path();
    if !path.exists() {
        return Ok(AgentConfig::default());
    }
    let bytes = fs::read(&path).with_context(|| format!("failed to read {}", path.display()))?;
    serde_json::from_slice(&bytes).with_context(|| format!("failed to parse {}", path.display()))
}

fn command_from_program(
    program: PathBuf,
    extra_path_prepend: Vec<PathBuf>,
    source: CodexCommandSource,
) -> ResolvedCodexCommand {
    let mut path_prepend = extra_path_prepend;
    if let Some(parent) = program
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
    {
        path_prepend.insert(0, parent.to_path_buf());
    }
    dedupe_paths(&mut path_prepend);
    ResolvedCodexCommand {
        program,
        args: Vec::new(),
        path_prepend,
        source,
    }
}

fn discover_codex_program() -> Option<PathBuf> {
    let mut dirs = Vec::new();
    dirs.extend(
        env::var_os("PATH")
            .into_iter()
            .flat_map(|path| env::split_paths(&path).collect::<Vec<_>>()),
    );
    dirs.extend(common_codex_dirs());
    dedupe_paths(&mut dirs);
    dirs.into_iter().find_map(|dir| find_codex_in_dir(&dir))
}

fn common_codex_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();
    if cfg!(windows) {
        if let Some(appdata) = env::var_os("APPDATA").map(PathBuf::from) {
            dirs.push(appdata.join("npm"));
        }
        if let Some(program_files) = env::var_os("ProgramFiles").map(PathBuf::from) {
            dirs.push(program_files.join("nodejs"));
        }
        return dirs;
    }

    let Some(home) = env::var_os("HOME").map(PathBuf::from) else {
        return dirs;
    };
    dirs.push(home.join(".local").join("bin"));
    dirs.push(home.join(".cargo").join("bin"));
    dirs.push(home.join(".volta").join("bin"));
    dirs.push(home.join(".asdf").join("shims"));
    dirs.push(home.join(".local").join("share").join("mise").join("shims"));
    dirs.extend(nvm_node_bin_dirs(&home));
    dirs.push(PathBuf::from("/opt/homebrew/bin"));
    dirs.push(PathBuf::from("/usr/local/bin"));
    dirs
}

fn nvm_node_bin_dirs(home: &Path) -> Vec<PathBuf> {
    let versions = home.join(".nvm").join("versions").join("node");
    let Ok(entries) = fs::read_dir(versions) else {
        return Vec::new();
    };
    entries
        .filter_map(Result::ok)
        .map(|entry| entry.path().join("bin"))
        .collect()
}

fn find_codex_in_dir(dir: &Path) -> Option<PathBuf> {
    candidate_names().into_iter().find_map(|name| {
        let candidate = dir.join(name);
        candidate.exists().then_some(candidate)
    })
}

fn candidate_names() -> Vec<&'static str> {
    if cfg!(windows) {
        vec!["codex.cmd", "codex.exe", "codex.bat", "codex"]
    } else {
        vec!["codex"]
    }
}

fn dedupe_paths(paths: &mut Vec<PathBuf>) {
    let mut seen = Vec::<PathBuf>::new();
    paths.retain(|path| {
        if seen.iter().any(|existing| existing == path) {
            false
        } else {
            seen.push(path.clone());
            true
        }
    });
}

fn is_configured_filesystem_program(codex: &ResolvedCodexCommand) -> bool {
    matches!(
        codex.source,
        CodexCommandSource::Cli | CodexCommandSource::Env | CodexCommandSource::Config
    ) && has_path_separator(&codex.program)
}

fn has_path_separator(path: &Path) -> bool {
    path.components().count() > 1
}

fn classify_spawn_error(error: io::Error, codex: &ResolvedCodexCommand) -> CodexProbeFailure {
    let kind = match error.kind() {
        io::ErrorKind::NotFound if is_configured_filesystem_program(codex) => {
            CodexProbeFailureKind::ConfiguredPathMissing
        }
        io::ErrorKind::NotFound => CodexProbeFailureKind::ProgramNotFound,
        io::ErrorKind::PermissionDenied => CodexProbeFailureKind::PermissionDenied,
        _ => CodexProbeFailureKind::NonZeroExit,
    };
    CodexProbeFailure {
        kind,
        detail: error.to_string(),
    }
}

fn classify_non_zero_output(detail: &str) -> CodexProbeFailureKind {
    let lower = detail.to_ascii_lowercase();
    if lower.contains("node")
        || lower.contains("syntaxerror")
        || lower.contains("/usr/bin/env:")
        || lower.contains("bad interpreter")
    {
        CodexProbeFailureKind::RuntimeNotFound
    } else {
        CodexProbeFailureKind::NonZeroExit
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn command_prepends_configured_paths_to_inherited_path() {
        let codex = ResolvedCodexCommand {
            program: PathBuf::from("codex"),
            args: Vec::new(),
            path_prepend: vec![PathBuf::from("/opt/node/bin")],
            source: CodexCommandSource::Config,
        };

        let command = codex.command().expect("command");
        let path = command.get_envs().find_map(|(key, value)| {
            (key == "PATH").then(|| value.expect("path value").to_os_string())
        });
        let paths = env::split_paths(&path.expect("PATH")).collect::<Vec<_>>();

        assert_eq!(paths.first(), Some(&PathBuf::from("/opt/node/bin")));
    }

    #[test]
    fn config_uses_camel_case_codex_fields() {
        let config: AgentConfig = serde_json::from_str(
            r#"{
              "codex": {
                "program": "/home/me/.nvm/versions/node/v24.14.1/bin/codex",
                "args": [],
                "pathPrepend": ["/home/me/.nvm/versions/node/v24.14.1/bin"]
              }
            }"#,
        )
        .expect("config");

        let codex = config.codex.expect("codex");
        assert_eq!(
            codex.program,
            PathBuf::from("/home/me/.nvm/versions/node/v24.14.1/bin/codex")
        );
        assert_eq!(
            codex.path_prepend,
            vec![PathBuf::from("/home/me/.nvm/versions/node/v24.14.1/bin")]
        );
    }

    #[test]
    fn missing_configured_path_reports_specific_failure() {
        let codex = ResolvedCodexCommand {
            program: PathBuf::from("/definitely/missing/codex"),
            args: Vec::new(),
            path_prepend: Vec::new(),
            source: CodexCommandSource::Config,
        };

        let failure = probe_codex_version(&codex).expect_err("failure");

        assert_eq!(failure.kind, CodexProbeFailureKind::ConfiguredPathMissing);
    }
}
