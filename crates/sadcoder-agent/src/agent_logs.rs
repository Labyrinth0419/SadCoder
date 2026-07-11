use anyhow::Context;
use serde::Deserialize;
use serde::Serialize;
use serde_json::Value;
use std::fs;
use std::fs::File;
use std::io::Read;
use std::io::Seek;
use std::io::SeekFrom;
use std::path::Path;

use crate::service::resolve_service_paths;

pub(crate) const DEFAULT_LOG_TAIL_BYTES: u64 = 64 * 1024;
pub(crate) const MAX_LOG_TAIL_BYTES: u64 = 256 * 1024;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentLogsResult {
    pub(crate) schema_version: u32,
    pub(crate) max_tail_bytes: u64,
    pub(crate) logs: Vec<AgentLogEntry>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentLogEntry {
    pub(crate) name: String,
    pub(crate) path: String,
    pub(crate) exists: bool,
    pub(crate) size_bytes: u64,
    pub(crate) tail_bytes: usize,
    pub(crate) truncated: bool,
    pub(crate) content: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) error: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AgentLogsParams {
    #[serde(default, alias = "tail_bytes")]
    tail_bytes: Option<u64>,
}

pub(crate) fn collect_agent_logs(state_path: &Path, tail_bytes: u64) -> AgentLogsResult {
    let service_paths = resolve_service_paths(state_path);
    let tail_bytes = clamp_tail_bytes(tail_bytes);

    AgentLogsResult {
        schema_version: 1,
        max_tail_bytes: MAX_LOG_TAIL_BYTES,
        logs: vec![collect_log_entry(
            "app-server.stderr",
            &service_paths.stderr_log_path,
            tail_bytes,
        )],
    }
}

pub(crate) fn collect_agent_logs_from_params(
    state_path: &Path,
    params: Option<&Value>,
) -> anyhow::Result<AgentLogsResult> {
    let params = match params {
        None | Some(Value::Null) => AgentLogsParams::default(),
        Some(value) => serde_json::from_value::<AgentLogsParams>(value.clone())
            .context("invalid agent/logs params")?,
    };
    Ok(collect_agent_logs(
        state_path,
        params.tail_bytes.unwrap_or(DEFAULT_LOG_TAIL_BYTES),
    ))
}

fn clamp_tail_bytes(tail_bytes: u64) -> u64 {
    tail_bytes.min(MAX_LOG_TAIL_BYTES)
}

fn collect_log_entry(name: &str, path: &Path, tail_bytes: u64) -> AgentLogEntry {
    let path_display = path.display().to_string();
    let metadata = match fs::metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return AgentLogEntry {
                name: name.to_string(),
                path: path_display,
                exists: false,
                size_bytes: 0,
                tail_bytes: 0,
                truncated: false,
                content: String::new(),
                error: None,
            };
        }
        Err(error) => {
            return AgentLogEntry {
                name: name.to_string(),
                path: path_display,
                exists: false,
                size_bytes: 0,
                tail_bytes: 0,
                truncated: false,
                content: String::new(),
                error: Some(format!("failed to inspect log file: {error}")),
            };
        }
    };

    if !metadata.is_file() {
        return AgentLogEntry {
            name: name.to_string(),
            path: path_display,
            exists: true,
            size_bytes: metadata.len(),
            tail_bytes: 0,
            truncated: false,
            content: String::new(),
            error: Some("log path is not a regular file".to_string()),
        };
    }

    let size_bytes = metadata.len();
    match read_log_tail(path, size_bytes, tail_bytes) {
        Ok(bytes) => AgentLogEntry {
            name: name.to_string(),
            path: path_display,
            exists: true,
            size_bytes,
            tail_bytes: bytes.len(),
            truncated: size_bytes > tail_bytes,
            content: String::from_utf8_lossy(&bytes).to_string(),
            error: None,
        },
        Err(error) => AgentLogEntry {
            name: name.to_string(),
            path: path_display,
            exists: true,
            size_bytes,
            tail_bytes: 0,
            truncated: false,
            content: String::new(),
            error: Some(format!("failed to read log file: {error}")),
        },
    }
}

fn read_log_tail(path: &Path, size_bytes: u64, tail_bytes: u64) -> anyhow::Result<Vec<u8>> {
    let start = size_bytes.saturating_sub(tail_bytes);
    let capacity = (size_bytes - start).min(tail_bytes) as usize;
    let mut file =
        File::open(path).with_context(|| format!("failed to open {}", path.display()))?;
    file.seek(SeekFrom::Start(start))
        .with_context(|| format!("failed to seek {}", path.display()))?;
    let mut bytes = Vec::with_capacity(capacity);
    file.take(tail_bytes)
        .read_to_end(&mut bytes)
        .with_context(|| format!("failed to read {}", path.display()))?;
    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::time::SystemTime;
    use std::time::UNIX_EPOCH;

    fn unique_state_path(name: &str) -> std::path::PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("time")
            .as_nanos();
        std::env::temp_dir().join(format!(
            "sadcoder-agent-{name}-{}-{nanos}/agent-state.json",
            std::process::id()
        ))
    }

    #[test]
    fn missing_log_returns_empty_entry() {
        let state_path = unique_state_path("missing-log");

        let result = collect_agent_logs(&state_path, DEFAULT_LOG_TAIL_BYTES);

        assert_eq!(result.schema_version, 1);
        assert_eq!(result.logs.len(), 1);
        assert_eq!(result.logs[0].name, "app-server.stderr");
        assert!(!result.logs[0].exists);
        assert_eq!(result.logs[0].content, "");
        assert_eq!(result.logs[0].error, None);
    }

    #[test]
    fn log_tail_is_bounded_and_lossy_utf8() {
        let state_path = unique_state_path("tail-log");
        let paths = resolve_service_paths(&state_path);
        fs::create_dir_all(paths.stderr_log_path.parent().expect("parent")).expect("state dir");
        fs::write(&paths.stderr_log_path, b"0123456789\xfftail").expect("write log");

        let result = collect_agent_logs(&state_path, 5);
        let entry = &result.logs[0];

        assert!(entry.exists);
        assert_eq!(entry.size_bytes, 15);
        assert_eq!(entry.tail_bytes, 5);
        assert!(entry.truncated);
        assert_eq!(entry.content, "\u{fffd}tail");

        let _ = fs::remove_dir_all(paths.stderr_log_path.parent().expect("parent"));
    }

    #[test]
    fn rpc_params_accept_camel_and_snake_case_tail_bytes() {
        let state_path = unique_state_path("params-log");
        let paths = resolve_service_paths(&state_path);
        fs::create_dir_all(paths.stderr_log_path.parent().expect("parent")).expect("state dir");
        fs::write(&paths.stderr_log_path, b"abcdef").expect("write log");

        let camel = collect_agent_logs_from_params(&state_path, Some(&json!({ "tailBytes": 2 })))
            .expect("camel params");
        let snake = collect_agent_logs_from_params(&state_path, Some(&json!({ "tail_bytes": 3 })))
            .expect("snake params");

        assert_eq!(camel.logs[0].content, "ef");
        assert_eq!(snake.logs[0].content, "def");

        let _ = fs::remove_dir_all(paths.stderr_log_path.parent().expect("parent"));
    }
}
