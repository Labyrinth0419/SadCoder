use crate::codex_command::ResolvedCodexCommand;
use clap::Args;
use clap::Subcommand;
use serde::Serialize;

/// Fixed, auditable Codex maintenance operations exposed to the mobile client.
///
/// This intentionally does not expose a raw command or arbitrary argument list.
/// Every user-controlled value is passed to `Command::arg` by `run`.
#[derive(Debug, Clone, Subcommand)]
pub(crate) enum CodexMaintenanceOperation {
    /// Run the upstream read-only Codex diagnostic report.
    Doctor,
    /// Update the Codex installation. The backend must be restarted afterwards.
    Update,
    /// Apply a legacy Codex agent task diff to the current workspace.
    Apply {
        #[arg(value_name = "TASK_ID")]
        task_id: String,
        #[arg(long = "cwd", value_name = "PATH")]
        cwd: Option<std::path::PathBuf>,
    },
    /// List Codex Cloud tasks. This requires the server's ChatGPT auth.
    CloudList {
        #[arg(long = "env", value_name = "ENV_ID")]
        environment: Option<String>,
        #[arg(long = "limit", default_value_t = 20)]
        limit: u8,
        #[arg(long = "cursor", value_name = "CURSOR")]
        cursor: Option<String>,
    },
    /// Read a Codex Cloud task status. This requires the server's ChatGPT auth.
    CloudStatus {
        #[arg(value_name = "TASK_ID")]
        task_id: String,
    },
    /// Read a Codex Cloud unified diff. This requires the server's ChatGPT auth.
    CloudDiff {
        #[arg(value_name = "TASK_ID")]
        task_id: String,
        #[arg(long = "attempt")]
        attempt: Option<u8>,
    },
    /// Apply a Codex Cloud diff to the current workspace.
    CloudApply {
        #[arg(value_name = "TASK_ID")]
        task_id: String,
        #[arg(long = "attempt")]
        attempt: Option<u8>,
        #[arg(long = "cwd", value_name = "PATH")]
        cwd: Option<std::path::PathBuf>,
    },
}

#[derive(Debug, Args)]
pub(crate) struct CodexMaintenanceCommand {
    /// Emit a machine-readable result. The mobile client always uses this mode.
    #[arg(long, default_value_t = false)]
    pub(crate) json: bool,

    #[command(subcommand)]
    pub(crate) operation: CodexMaintenanceOperation,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct CodexMaintenanceResult {
    pub(crate) operation: &'static str,
    pub(crate) success: bool,
    pub(crate) exit_code: Option<i32>,
    pub(crate) stdout: String,
    pub(crate) stderr: String,
    pub(crate) restart_required: bool,
    pub(crate) requires_chatgpt_auth: bool,
}

impl CodexMaintenanceOperation {
    pub(crate) fn name(&self) -> &'static str {
        match self {
            Self::Doctor => "doctor",
            Self::Update => "update",
            Self::Apply { .. } => "apply",
            Self::CloudList { .. } => "cloud-list",
            Self::CloudStatus { .. } => "cloud-status",
            Self::CloudDiff { .. } => "cloud-diff",
            Self::CloudApply { .. } => "cloud-apply",
        }
    }

    pub(crate) fn restart_required(&self) -> bool {
        matches!(self, Self::Update)
    }

    pub(crate) fn requires_chatgpt_auth(&self) -> bool {
        matches!(
            self,
            Self::CloudList { .. }
                | Self::CloudStatus { .. }
                | Self::CloudDiff { .. }
                | Self::CloudApply { .. }
        )
    }

    fn validate(&self) -> Result<(), String> {
        match self {
            Self::Apply { task_id, .. } | Self::CloudStatus { task_id } => {
                validate_identifier("task id", task_id)
            }
            Self::CloudList {
                environment,
                limit,
                cursor,
            } => {
                if let Some(environment) = environment {
                    validate_identifier("environment id", environment)?;
                }
                if *limit == 0 || *limit > 20 {
                    return Err("limit must be between 1 and 20".to_string());
                }
                if let Some(cursor) = cursor {
                    validate_identifier("cursor", cursor)?;
                }
                Ok(())
            }
            Self::CloudDiff {
                task_id, attempt, ..
            }
            | Self::CloudApply {
                task_id, attempt, ..
            } => {
                validate_identifier("task id", task_id)?;
                if let Some(attempt) = attempt {
                    if *attempt == 0 || *attempt > 4 {
                        return Err("attempt must be between 1 and 4".to_string());
                    }
                }
                Ok(())
            }
            Self::Doctor | Self::Update => Ok(()),
        }
    }
}

fn validate_identifier(label: &str, value: &str) -> Result<(), String> {
    let value = value.trim();
    if value.is_empty() {
        return Err(format!("{label} is required"));
    }
    if value.chars().any(char::is_control) {
        return Err(format!("{label} cannot contain control characters"));
    }
    Ok(())
}

pub(crate) fn run(
    codex: &ResolvedCodexCommand,
    operation: &CodexMaintenanceOperation,
) -> CodexMaintenanceResult {
    let operation_name = operation.name();
    let mut result = CodexMaintenanceResult {
        operation: operation_name,
        success: false,
        exit_code: None,
        stdout: String::new(),
        stderr: String::new(),
        restart_required: operation.restart_required(),
        requires_chatgpt_auth: operation.requires_chatgpt_auth(),
    };

    if let Err(error) = operation.validate() {
        result.stderr = error;
        return result;
    }

    let mut command = match codex.command() {
        Ok(command) => command,
        Err(error) => {
            result.stderr = error.to_string();
            return result;
        }
    };
    command.env("NO_COLOR", "1");

    let cwd = match operation {
        CodexMaintenanceOperation::Apply { cwd, .. }
        | CodexMaintenanceOperation::CloudApply { cwd, .. } => cwd.as_deref(),
        _ => None,
    };
    if let Some(cwd) = cwd {
        if !cwd.is_dir() {
            result.stderr = format!("working directory does not exist: {}", cwd.display());
            return result;
        }
        command.current_dir(cwd);
    }

    append_args(&mut command, operation);
    match command.output() {
        Ok(output) => {
            result.exit_code = output.status.code();
            result.success = output.status.success();
            result.stdout = String::from_utf8_lossy(&output.stdout).into_owned();
            result.stderr = String::from_utf8_lossy(&output.stderr).into_owned();
        }
        Err(error) => result.stderr = error.to_string(),
    }
    result
}

fn append_args(command: &mut std::process::Command, operation: &CodexMaintenanceOperation) {
    match operation {
        CodexMaintenanceOperation::Doctor => {
            command.args(["doctor", "--json"]);
        }
        CodexMaintenanceOperation::Update => {
            command.arg("update");
        }
        CodexMaintenanceOperation::Apply { task_id, .. } => {
            command.args(["apply", task_id]);
        }
        CodexMaintenanceOperation::CloudList {
            environment,
            limit,
            cursor,
        } => {
            command.args(["cloud", "list"]);
            if let Some(environment) = environment {
                command.args(["--env", environment]);
            }
            command.args(["--limit", &limit.to_string()]);
            if let Some(cursor) = cursor {
                command.args(["--cursor", cursor]);
            }
            command.arg("--json");
        }
        CodexMaintenanceOperation::CloudStatus { task_id } => {
            command.args(["cloud", "status", task_id]);
        }
        CodexMaintenanceOperation::CloudDiff { task_id, attempt } => {
            command.args(["cloud", "diff", task_id]);
            if let Some(attempt) = attempt {
                command.args(["--attempt", &attempt.to_string()]);
            }
        }
        CodexMaintenanceOperation::CloudApply {
            task_id, attempt, ..
        } => {
            command.args(["cloud", "apply", task_id]);
            if let Some(attempt) = attempt {
                command.args(["--attempt", &attempt.to_string()]);
            }
        }
    }
}

pub(crate) fn print_result(result: &CodexMaintenanceResult, json_output: bool) {
    if json_output {
        println!(
            "{}",
            serde_json::to_string_pretty(result).expect("serialize maintenance result")
        );
        return;
    }
    println!("operation: {}", result.operation);
    println!("status: {}", if result.success { "ok" } else { "failed" });
    if result.restart_required {
        println!("restart required: yes");
    }
    if result.requires_chatgpt_auth {
        println!("requires server ChatGPT auth: yes");
    }
    if !result.stdout.trim().is_empty() {
        print!("{}", result.stdout);
    }
    if !result.stderr.trim().is_empty() {
        eprintln!("{}", result.stderr);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::codex_command::{CodexCommandSource, ResolvedCodexCommand};
    use std::ffi::OsString;
    use std::path::PathBuf;

    fn command() -> ResolvedCodexCommand {
        ResolvedCodexCommand {
            program: PathBuf::from("codex"),
            args: vec![OsString::from("--config"), OsString::from("profile=api")],
            path_prepend: Vec::new(),
            source: CodexCommandSource::Path,
        }
    }

    #[test]
    fn operation_metadata_marks_mutating_and_cloud_actions() {
        assert!(CodexMaintenanceOperation::Update.restart_required());
        assert!(
            !CodexMaintenanceOperation::Apply {
                task_id: "task".to_string(),
                cwd: None,
            }
            .restart_required()
        );
        assert!(
            CodexMaintenanceOperation::CloudStatus {
                task_id: "task".to_string()
            }
            .requires_chatgpt_auth()
        );
    }

    #[test]
    fn validation_rejects_control_characters_and_out_of_range_values() {
        let invalid = CodexMaintenanceOperation::CloudStatus {
            task_id: "task\n1".to_string(),
        };
        assert!(invalid.validate().is_err());
        let invalid = CodexMaintenanceOperation::CloudList {
            environment: None,
            limit: 21,
            cursor: None,
        };
        assert!(invalid.validate().is_err());
        let invalid = CodexMaintenanceOperation::CloudDiff {
            task_id: "task".to_string(),
            attempt: Some(5),
        };
        assert!(invalid.validate().is_err());
    }

    #[test]
    fn missing_cwd_is_reported_without_spawning_codex() {
        let result = run(
            &command(),
            &CodexMaintenanceOperation::CloudApply {
                task_id: "task".to_string(),
                attempt: None,
                cwd: Some(PathBuf::from("this-directory-does-not-exist")),
            },
        );
        assert!(!result.success);
        assert!(result.stderr.contains("working directory"));
    }
}
