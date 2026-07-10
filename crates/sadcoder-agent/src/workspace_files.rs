use sadcoder_protocol::JSONRPC_VERSION;
use sadcoder_protocol::JsonRpcError;
use sadcoder_protocol::JsonRpcRequest;
use sadcoder_protocol::JsonRpcResponse;
use serde_json::Value;
use serde_json::json;
use std::borrow::Cow;
use std::cmp::min;
use std::fs;
use std::fs::File;
use std::io::Read;
use std::io::Seek;
use std::io::SeekFrom;
use std::path::Component;
use std::path::Path;
use std::path::PathBuf;
use std::time::UNIX_EPOCH;

const DEFAULT_DIRECTORY_LIMIT: usize = 100;
const MAX_DIRECTORY_LIMIT: usize = 500;
const DEFAULT_FILE_READ_LIMIT: usize = 64 * 1024;
const MAX_FILE_READ_LIMIT: usize = 1024 * 1024;
const BINARY_SAMPLE_LIMIT: usize = 8000;

pub(crate) fn handle_workspace_request(request: &JsonRpcRequest) -> Option<JsonRpcResponse> {
    let result = match request.method.as_str() {
        "workspace/directoryList" => Some(list_directory(request.params.as_ref())),
        "workspace/fileStat" => Some(stat_file(request.params.as_ref())),
        "workspace/fileRead" => Some(read_file(request.params.as_ref())),
        _ => None,
    }?;

    Some(match result {
        Ok(result) => success_response(request, result),
        Err(error) => error_response(request, error),
    })
}

fn success_response(request: &JsonRpcRequest, result: Value) -> JsonRpcResponse {
    JsonRpcResponse {
        jsonrpc: Cow::Borrowed(JSONRPC_VERSION),
        id: request.id.clone(),
        result: Some(result),
        error: None,
    }
}

fn error_response(request: &JsonRpcRequest, error: WorkspaceFileRpcError) -> JsonRpcResponse {
    JsonRpcResponse {
        jsonrpc: Cow::Borrowed(JSONRPC_VERSION),
        id: request.id.clone(),
        result: None,
        error: Some(JsonRpcError {
            code: error.json_rpc_code(),
            message: error.message(),
        }),
    }
}

fn list_directory(params: Option<&Value>) -> Result<Value, WorkspaceFileRpcError> {
    let params = object_params(params)?;
    let workspace_path = WorkspacePath::from_params(params, true)?;
    let resolved = workspace_path.resolve_existing_path(false)?;
    let metadata = fs::metadata(&resolved.path).map_err(WorkspaceFileRpcError::from_io)?;
    if !metadata.is_dir() {
        return Err(WorkspaceFileRpcError::ReadFailed(
            "workspace path is not a directory".to_string(),
        ));
    }

    let include_hidden = optional_bool(params, "includeHidden").unwrap_or(false);
    let limit = optional_usize(params, "limit")?
        .filter(|limit| *limit > 0)
        .unwrap_or(DEFAULT_DIRECTORY_LIMIT)
        .min(MAX_DIRECTORY_LIMIT);
    let cursor = optional_usize_from_string(params, "cursor")?.unwrap_or(0);

    let mut entries = fs::read_dir(&resolved.path)
        .map_err(WorkspaceFileRpcError::from_io)?
        .map(|entry| directory_entry(&workspace_path, entry))
        .collect::<Result<Vec<_>, _>>()?;
    entries.retain(|entry| include_hidden || !entry.is_hidden);
    entries.sort_by(compare_directory_entries);

    let start = cursor.min(entries.len());
    let end = min(start + limit, entries.len());
    let next_cursor = (end < entries.len()).then(|| end.to_string());
    let page_entries = entries[start..end]
        .iter()
        .map(WorkspaceDirectoryEntry::to_json)
        .collect::<Vec<_>>();

    Ok(json!({
        "root": workspace_path.root_display,
        "path": workspace_path.relative_path,
        "entries": page_entries,
        "nextCursor": next_cursor,
    }))
}

fn stat_file(params: Option<&Value>) -> Result<Value, WorkspaceFileRpcError> {
    let params = object_params(params)?;
    let workspace_path = WorkspacePath::from_params(params, false)?;
    let resolved = workspace_path.resolve_existing_path(true)?;
    let metadata = fs::symlink_metadata(&resolved.path).map_err(WorkspaceFileRpcError::from_io)?;
    Ok(file_stat_json(&workspace_path, &resolved.path, &metadata))
}

fn read_file(params: Option<&Value>) -> Result<Value, WorkspaceFileRpcError> {
    let params = object_params(params)?;
    let workspace_path = WorkspacePath::from_params(params, false)?;
    let offset = optional_u64(params, "offset")?.unwrap_or(0);
    let requested_limit = optional_usize(params, "limitBytes")?.unwrap_or(DEFAULT_FILE_READ_LIMIT);
    if requested_limit == 0 {
        return Err(WorkspaceFileRpcError::ReadFailed(
            "read limit must be positive".to_string(),
        ));
    }
    if requested_limit > MAX_FILE_READ_LIMIT {
        return Err(WorkspaceFileRpcError::TooLarge(format!(
            "read limit exceeds the maximum of {MAX_FILE_READ_LIMIT} bytes"
        )));
    }
    let limit = requested_limit;
    let encoding = optional_string(params, "encoding")?.unwrap_or_else(|| "utf-8".to_string());
    if !is_utf8_encoding(&encoding) {
        return Err(WorkspaceFileRpcError::ReadFailed(format!(
            "unsupported encoding: {encoding}"
        )));
    }

    let resolved = workspace_path.resolve_existing_path(false)?;
    let metadata = fs::metadata(&resolved.path).map_err(WorkspaceFileRpcError::from_io)?;
    if metadata.is_dir() {
        return Err(WorkspaceFileRpcError::ReadFailed(
            "workspace path is a directory".to_string(),
        ));
    }
    if !metadata.is_file() {
        return Err(WorkspaceFileRpcError::NotFound(
            "workspace path was not found".to_string(),
        ));
    }
    if file_looks_binary(&resolved.path)? {
        return Err(WorkspaceFileRpcError::BinaryNotPreviewable);
    }

    let chunk = read_utf8_chunk(&resolved.path, metadata.len(), offset, limit)?;
    Ok(json!({
        "root": workspace_path.root_display,
        "path": workspace_path.relative_path,
        "sizeBytes": metadata.len(),
        "offset": chunk.offset,
        "bytesRead": chunk.bytes_read,
        "nextOffset": chunk.next_offset,
        "hasMore": chunk.has_more,
        "encoding": "utf-8",
        "isBinary": false,
        "content": chunk.content,
        "contentVersion": content_version(&metadata),
    }))
}

#[derive(Debug, Clone)]
struct WorkspacePath {
    root_display: String,
    relative_path: String,
    canonical_root: PathBuf,
    segments: Vec<String>,
}

#[derive(Debug, Clone)]
struct ResolvedWorkspacePath {
    path: PathBuf,
}

impl WorkspacePath {
    fn from_params(
        params: &serde_json::Map<String, Value>,
        default_path_to_root: bool,
    ) -> Result<Self, WorkspaceFileRpcError> {
        let root_display = required_string(params, "root")?;
        validate_absolute_root(&root_display)?;
        let canonical_root = fs::canonicalize(&root_display)
            .map_err(|error| WorkspaceFileRpcError::from_root_io(&root_display, error))?;
        let root_metadata =
            fs::metadata(&canonical_root).map_err(WorkspaceFileRpcError::from_io)?;
        if !root_metadata.is_dir() {
            return Err(WorkspaceFileRpcError::NoCwd(
                "workspace root is not a directory".to_string(),
            ));
        }

        let raw_path = optional_string(params, "path")?;
        let segments = normalize_relative_segments(raw_path.as_deref(), default_path_to_root)?;
        let relative_path = segments.join("/");
        Ok(Self {
            root_display,
            relative_path,
            canonical_root,
            segments,
        })
    }

    fn resolve_existing_path(
        &self,
        allow_target_symlink: bool,
    ) -> Result<ResolvedWorkspacePath, WorkspaceFileRpcError> {
        let mut current = self.canonical_root.clone();
        for (index, segment) in self.segments.iter().enumerate() {
            current.push(segment);
            let metadata =
                fs::symlink_metadata(&current).map_err(WorkspaceFileRpcError::from_io)?;
            let is_target = index + 1 == self.segments.len();
            if metadata.file_type().is_symlink() {
                if is_target && allow_target_symlink {
                    return Ok(ResolvedWorkspacePath { path: current });
                }
                return Err(WorkspaceFileRpcError::PathOutsideRoot(
                    "workspace path contains a symbolic link".to_string(),
                ));
            }
        }

        if self.segments.is_empty() {
            current = self.canonical_root.clone();
        }
        let canonical_target =
            fs::canonicalize(&current).map_err(WorkspaceFileRpcError::from_io)?;
        if !canonical_target.starts_with(&self.canonical_root) {
            return Err(WorkspaceFileRpcError::PathOutsideRoot(
                "workspace path resolves outside the workspace root".to_string(),
            ));
        }
        Ok(ResolvedWorkspacePath {
            path: canonical_target,
        })
    }
}

#[derive(Debug, Clone)]
struct WorkspaceDirectoryEntry {
    name: String,
    relative_path: String,
    entry_type: &'static str,
    size_bytes: Option<u64>,
    modified_at_ms: Option<u64>,
    is_hidden: bool,
    is_symlink: bool,
}

impl WorkspaceDirectoryEntry {
    fn to_json(&self) -> Value {
        json!({
            "name": self.name,
            "path": self.relative_path,
            "type": self.entry_type,
            "sizeBytes": self.size_bytes,
            "modifiedAtMs": self.modified_at_ms,
            "isHidden": self.is_hidden,
            "isSymlink": self.is_symlink,
        })
    }
}

fn directory_entry(
    parent_path: &WorkspacePath,
    entry: Result<fs::DirEntry, std::io::Error>,
) -> Result<WorkspaceDirectoryEntry, WorkspaceFileRpcError> {
    let entry = entry.map_err(WorkspaceFileRpcError::from_io)?;
    let name = entry.file_name().to_string_lossy().to_string();
    if name.is_empty() {
        return Err(WorkspaceFileRpcError::ReadFailed(
            "directory entry name is empty".to_string(),
        ));
    }
    let metadata = fs::symlink_metadata(entry.path()).map_err(WorkspaceFileRpcError::from_io)?;
    let file_type = metadata.file_type();
    let mut segments = parent_path.segments.clone();
    segments.push(name.clone());
    Ok(WorkspaceDirectoryEntry {
        is_hidden: is_hidden_name(&name),
        name,
        relative_path: segments.join("/"),
        entry_type: metadata_kind(&metadata),
        size_bytes: file_type.is_file().then_some(metadata.len()),
        modified_at_ms: modified_at_ms(&metadata),
        is_symlink: file_type.is_symlink(),
    })
}

fn compare_directory_entries(
    left: &WorkspaceDirectoryEntry,
    right: &WorkspaceDirectoryEntry,
) -> std::cmp::Ordering {
    let left_rank = if left.entry_type == "directory" { 0 } else { 1 };
    let right_rank = if right.entry_type == "directory" {
        0
    } else {
        1
    };
    left_rank
        .cmp(&right_rank)
        .then_with(|| left.name.to_lowercase().cmp(&right.name.to_lowercase()))
        .then_with(|| left.name.cmp(&right.name))
}

fn file_stat_json(workspace_path: &WorkspacePath, path: &Path, metadata: &fs::Metadata) -> Value {
    let is_file = metadata.is_file();
    let is_symlink = metadata.file_type().is_symlink();
    let is_binary = if is_file {
        file_looks_binary(path).ok()
    } else {
        None
    };
    json!({
        "root": workspace_path.root_display,
        "path": workspace_path.relative_path,
        "type": metadata_kind(metadata),
        "isDirectory": metadata.is_dir(),
        "isFile": is_file,
        "isSymlink": is_symlink,
        "sizeBytes": is_file.then_some(metadata.len()),
        "modifiedAtMs": modified_at_ms(metadata),
        "isHidden": workspace_path
            .segments
            .last()
            .is_some_and(|name| is_hidden_name(name)),
        "isBinary": is_binary,
        "language": language_from_path(&workspace_path.relative_path),
        "mimeType": mime_type_from_path(&workspace_path.relative_path),
        "contentVersion": content_version(metadata),
    })
}

fn metadata_kind(metadata: &fs::Metadata) -> &'static str {
    if metadata.is_dir() {
        "directory"
    } else if metadata.is_file() {
        "file"
    } else {
        "unknown"
    }
}

#[derive(Debug, Clone)]
struct Utf8Chunk {
    offset: u64,
    bytes_read: usize,
    next_offset: Option<u64>,
    has_more: bool,
    content: String,
}

fn read_utf8_chunk(
    path: &Path,
    size_bytes: u64,
    requested_offset: u64,
    limit: usize,
) -> Result<Utf8Chunk, WorkspaceFileRpcError> {
    let mut file = File::open(path).map_err(WorkspaceFileRpcError::from_io)?;
    let start = requested_offset.min(size_bytes);
    file.seek(SeekFrom::Start(start))
        .map_err(WorkspaceFileRpcError::from_io)?;

    let readable = (size_bytes - start).min((limit + 4) as u64) as usize;
    let mut buffer = vec![0; readable];
    let bytes_read = file
        .read(&mut buffer)
        .map_err(WorkspaceFileRpcError::from_io)?;
    buffer.truncate(bytes_read);

    let mut local_start = 0;
    while local_start < buffer.len() && is_utf8_continuation_byte(buffer[local_start]) {
        local_start += 1;
    }
    let adjusted_offset = start + local_start as u64;
    if adjusted_offset >= size_bytes || local_start == buffer.len() {
        return Ok(Utf8Chunk {
            offset: adjusted_offset,
            bytes_read: 0,
            next_offset: None,
            has_more: false,
            content: String::new(),
        });
    }

    let requested_end = min(buffer.len(), local_start + limit);
    for candidate_end in (local_start + 1..=requested_end).rev() {
        if let Ok(content) = std::str::from_utf8(&buffer[local_start..candidate_end]) {
            return utf8_chunk_from_slice(adjusted_offset, size_bytes, content);
        }
    }

    let extended_end = min(buffer.len(), local_start + limit + 4);
    for candidate_end in requested_end + 1..=extended_end {
        if let Ok(content) = std::str::from_utf8(&buffer[local_start..candidate_end]) {
            return utf8_chunk_from_slice(adjusted_offset, size_bytes, content);
        }
    }

    Err(WorkspaceFileRpcError::BinaryNotPreviewable)
}

fn utf8_chunk_from_slice(
    offset: u64,
    size_bytes: u64,
    content: &str,
) -> Result<Utf8Chunk, WorkspaceFileRpcError> {
    let bytes_read = content.len();
    let next_offset = offset + bytes_read as u64;
    Ok(Utf8Chunk {
        offset,
        bytes_read,
        next_offset: (next_offset < size_bytes).then_some(next_offset),
        has_more: next_offset < size_bytes,
        content: content.to_string(),
    })
}

fn file_looks_binary(path: &Path) -> Result<bool, WorkspaceFileRpcError> {
    let mut file = File::open(path).map_err(WorkspaceFileRpcError::from_io)?;
    let mut sample = vec![0; BINARY_SAMPLE_LIMIT];
    let bytes_read = file
        .read(&mut sample)
        .map_err(WorkspaceFileRpcError::from_io)?;
    sample.truncate(bytes_read);
    Ok(looks_binary(&sample))
}

fn looks_binary(bytes: &[u8]) -> bool {
    if bytes.is_empty() {
        return false;
    }
    let sample_len = bytes.len().min(BINARY_SAMPLE_LIMIT);
    let mut suspicious = 0usize;
    for byte in bytes.iter().take(sample_len).copied() {
        if byte == 0 {
            return true;
        }
        let allowed_control = matches!(byte, 7 | 8 | 9 | 10 | 12 | 13 | 27);
        if byte < 32 && !allowed_control {
            suspicious += 1;
        }
    }
    suspicious * 10 > sample_len * 3
}

fn is_utf8_continuation_byte(byte: u8) -> bool {
    (0x80..=0xbf).contains(&byte)
}

fn object_params(
    params: Option<&Value>,
) -> Result<&serde_json::Map<String, Value>, WorkspaceFileRpcError> {
    params
        .and_then(Value::as_object)
        .ok_or_else(|| WorkspaceFileRpcError::ReadFailed("params must be an object".to_string()))
}

fn required_string(
    params: &serde_json::Map<String, Value>,
    key: &str,
) -> Result<String, WorkspaceFileRpcError> {
    optional_string(params, key)?
        .filter(|value| !value.is_empty())
        .ok_or_else(|| {
            WorkspaceFileRpcError::NoCwd(format!("required string param `{key}` is missing"))
        })
}

fn optional_string(
    params: &serde_json::Map<String, Value>,
    key: &str,
) -> Result<Option<String>, WorkspaceFileRpcError> {
    match params.get(key) {
        Some(Value::String(value)) => {
            if value.contains('\0') {
                return Err(WorkspaceFileRpcError::PathOutsideRoot(
                    "workspace path contains a NUL byte".to_string(),
                ));
            }
            Ok(Some(value.trim().to_string()))
        }
        Some(Value::Null) | None => Ok(None),
        Some(_) => Err(WorkspaceFileRpcError::ReadFailed(format!(
            "`{key}` must be a string"
        ))),
    }
}

fn optional_bool(params: &serde_json::Map<String, Value>, key: &str) -> Option<bool> {
    params.get(key).and_then(Value::as_bool)
}

fn optional_u64(
    params: &serde_json::Map<String, Value>,
    key: &str,
) -> Result<Option<u64>, WorkspaceFileRpcError> {
    match params.get(key) {
        Some(value) => value.as_u64().map(Some).ok_or_else(|| {
            WorkspaceFileRpcError::ReadFailed(format!("`{key}` must be a non-negative integer"))
        }),
        None => Ok(None),
    }
}

fn optional_usize(
    params: &serde_json::Map<String, Value>,
    key: &str,
) -> Result<Option<usize>, WorkspaceFileRpcError> {
    Ok(optional_u64(params, key)?.map(|value| value.min(usize::MAX as u64) as usize))
}

fn optional_usize_from_string(
    params: &serde_json::Map<String, Value>,
    key: &str,
) -> Result<Option<usize>, WorkspaceFileRpcError> {
    match optional_string(params, key)? {
        Some(value) if value.is_empty() => Ok(None),
        Some(value) => value.parse::<usize>().map(Some).map_err(|_| {
            WorkspaceFileRpcError::ReadFailed(format!("`{key}` must be a non-negative offset"))
        }),
        None => Ok(None),
    }
}

fn validate_absolute_root(root: &str) -> Result<(), WorkspaceFileRpcError> {
    if root.is_empty() {
        return Err(WorkspaceFileRpcError::NoCwd(
            "root param is empty".to_string(),
        ));
    }
    if root.contains('\0') {
        return Err(WorkspaceFileRpcError::PathOutsideRoot(
            "workspace root contains a NUL byte".to_string(),
        ));
    }
    if !Path::new(root).is_absolute() && !is_windows_absolute_path(root) && !root.starts_with('/') {
        return Err(WorkspaceFileRpcError::NoCwd(
            "workspace root must be an absolute path".to_string(),
        ));
    }
    Ok(())
}

fn normalize_relative_segments(
    raw_path: Option<&str>,
    default_path_to_root: bool,
) -> Result<Vec<String>, WorkspaceFileRpcError> {
    let Some(raw_path) = raw_path else {
        return Ok(Vec::new());
    };
    let trimmed = raw_path.trim();
    if trimmed.is_empty() {
        return Ok(Vec::new());
    }
    if trimmed == "." && default_path_to_root {
        return Ok(Vec::new());
    }
    if is_absolute_child_path(trimmed) {
        return Err(WorkspaceFileRpcError::PathOutsideRoot(
            "workspace child path must be relative".to_string(),
        ));
    }

    let mut segments = Vec::new();
    for segment in trimmed.split(['/', '\\']) {
        if segment.is_empty() || segment == "." {
            continue;
        }
        if segment == ".." {
            return Err(WorkspaceFileRpcError::PathOutsideRoot(
                "workspace path traversal is not allowed".to_string(),
            ));
        }
        if segment.contains('\0') {
            return Err(WorkspaceFileRpcError::PathOutsideRoot(
                "workspace path contains a NUL byte".to_string(),
            ));
        }
        if Path::new(segment)
            .components()
            .any(|component| !matches!(component, Component::Normal(_)))
        {
            return Err(WorkspaceFileRpcError::PathOutsideRoot(
                "workspace path contains an unsafe component".to_string(),
            ));
        }
        segments.push(segment.to_string());
    }
    Ok(segments)
}

fn is_absolute_child_path(path: &str) -> bool {
    path.starts_with('/') || path.starts_with('\\') || is_windows_absolute_path(path)
}

fn is_windows_absolute_path(path: &str) -> bool {
    let bytes = path.as_bytes();
    bytes.len() >= 3
        && bytes[0].is_ascii_alphabetic()
        && bytes[1] == b':'
        && matches!(bytes[2], b'/' | b'\\')
}

fn is_hidden_name(name: &str) -> bool {
    name.starts_with('.')
}

fn modified_at_ms(metadata: &fs::Metadata) -> Option<u64> {
    metadata
        .modified()
        .ok()?
        .duration_since(UNIX_EPOCH)
        .ok()?
        .as_millis()
        .try_into()
        .ok()
}

fn content_version(metadata: &fs::Metadata) -> Option<String> {
    let modified = modified_at_ms(metadata)?;
    Some(format!("{modified}-{}", metadata.len()))
}

fn is_utf8_encoding(encoding: &str) -> bool {
    let normalized = encoding.trim().to_ascii_lowercase().replace('_', "-");
    normalized == "utf-8" || normalized == "utf8"
}

fn language_from_path(path: &str) -> Option<&'static str> {
    let file_name = path.rsplit('/').next().unwrap_or(path);
    let extension = file_name.rsplit_once('.')?.1.to_ascii_lowercase();
    match extension.as_str() {
        "dart" => Some("dart"),
        "rs" => Some("rust"),
        "md" | "markdown" => Some("markdown"),
        "txt" => Some("text"),
        "json" => Some("json"),
        "yaml" | "yml" => Some("yaml"),
        "toml" => Some("toml"),
        "js" => Some("javascript"),
        "ts" => Some("typescript"),
        "jsx" => Some("javascriptreact"),
        "tsx" => Some("typescriptreact"),
        "html" => Some("html"),
        "css" => Some("css"),
        "sh" | "bash" => Some("shell"),
        "ps1" => Some("powershell"),
        "py" => Some("python"),
        _ => None,
    }
}

fn mime_type_from_path(path: &str) -> Option<&'static str> {
    let file_name = path.rsplit('/').next().unwrap_or(path);
    let extension = file_name.rsplit_once('.')?.1.to_ascii_lowercase();
    match extension.as_str() {
        "md" | "markdown" => Some("text/markdown"),
        "txt" => Some("text/plain"),
        "json" => Some("application/json"),
        "yaml" | "yml" => Some("application/yaml"),
        "toml" => Some("application/toml"),
        "html" => Some("text/html"),
        "css" => Some("text/css"),
        "js" | "jsx" => Some("text/javascript"),
        "ts" | "tsx" => Some("text/typescript"),
        _ => None,
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
enum WorkspaceFileRpcError {
    NoCwd(String),
    NotFound(String),
    PermissionDenied(String),
    PathOutsideRoot(String),
    BinaryNotPreviewable,
    TooLarge(String),
    ReadFailed(String),
}

impl WorkspaceFileRpcError {
    fn from_root_io(root: &str, error: std::io::Error) -> Self {
        match error.kind() {
            std::io::ErrorKind::NotFound => Self::NoCwd(format!("root path was not found: {root}")),
            std::io::ErrorKind::PermissionDenied => {
                Self::PermissionDenied(format!("permission denied reading workspace root: {root}"))
            }
            _ => Self::ReadFailed(error.to_string()),
        }
    }

    fn from_io(error: std::io::Error) -> Self {
        match error.kind() {
            std::io::ErrorKind::NotFound => {
                Self::NotFound("workspace path was not found".to_string())
            }
            std::io::ErrorKind::PermissionDenied => {
                Self::PermissionDenied("permission denied while reading workspace path".to_string())
            }
            _ => Self::ReadFailed(error.to_string()),
        }
    }

    fn json_rpc_code(&self) -> i64 {
        match self {
            Self::NoCwd(_) => -32020,
            Self::NotFound(_) => -32021,
            Self::PermissionDenied(_) => -32022,
            Self::PathOutsideRoot(_) => -32023,
            Self::BinaryNotPreviewable => -32024,
            Self::TooLarge(_) => -32026,
            Self::ReadFailed(_) => -32025,
        }
    }

    fn message(&self) -> String {
        match self {
            Self::NoCwd(detail) => format!("workspace root is not available: {detail}"),
            Self::NotFound(detail) => format!("workspace path was not found: {detail}"),
            Self::PermissionDenied(detail) => {
                format!("permission denied while reading workspace path: {detail}")
            }
            Self::PathOutsideRoot(detail) => {
                format!("workspace path is outside the workspace root: {detail}")
            }
            Self::BinaryNotPreviewable => "binary file is not previewable as text".to_string(),
            Self::TooLarge(detail) => format!("workspace file is too large to preview: {detail}"),
            Self::ReadFailed(detail) => format!("workspace file request failed: {detail}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sadcoder_protocol::RequestId;
    use std::time::SystemTime;

    #[test]
    fn directory_list_filters_hidden_entries_and_paginates() {
        let root = TempWorkspace::new("directory-list");
        root.write("src/main.rs", "fn main() {}\n");
        root.write("README.md", "# test\n");
        root.write(".env", "secret\n");
        fs::create_dir_all(root.path().join("src/bin")).expect("create nested dir");

        let first = workspace_result(
            "workspace/directoryList",
            json!({
                "root": root.path_string(),
                "path": ".",
                "limit": 2,
                "includeHidden": false,
            }),
        );
        let entries = first["entries"].as_array().expect("entries");
        assert_eq!(
            entries
                .iter()
                .map(|entry| entry["name"].as_str().expect("name"))
                .collect::<Vec<_>>(),
            vec!["src", "README.md"]
        );
        assert_eq!(first["nextCursor"].as_str(), None);

        let hidden = workspace_result(
            "workspace/directoryList",
            json!({
                "root": root.path_string(),
                "limit": 2,
                "includeHidden": true,
            }),
        );
        assert_eq!(hidden["nextCursor"].as_str(), Some("2"));
    }

    #[test]
    fn file_stat_reports_metadata_and_binary_hint() {
        let root = TempWorkspace::new("file-stat");
        root.write("src/main.rs", "fn main() {}\n");
        root.write_bytes("image.bin", &[0, 1, 2, 3]);

        let source = workspace_result(
            "workspace/fileStat",
            json!({"root": root.path_string(), "path": "src/main.rs"}),
        );
        assert_eq!(source["type"], "file");
        assert_eq!(source["isFile"], true);
        assert_eq!(source["language"], "rust");
        assert_eq!(source["isBinary"], false);

        let binary = workspace_result(
            "workspace/fileStat",
            json!({"root": root.path_string(), "path": "image.bin"}),
        );
        assert_eq!(binary["isBinary"], true);
    }

    #[test]
    fn file_read_returns_utf8_range_chunks_on_character_boundaries() {
        let root = TempWorkspace::new("file-read");
        root.write("README.md", "a🙂b");

        let first = workspace_result(
            "workspace/fileRead",
            json!({
                "root": root.path_string(),
                "path": "README.md",
                "offset": 0,
                "limitBytes": 2,
                "encoding": "UTF_8",
            }),
        );
        assert_eq!(first["content"], "a");
        assert_eq!(first["offset"], 0);
        assert_eq!(first["bytesRead"], 1);
        assert_eq!(first["nextOffset"], 1);
        assert_eq!(first["hasMore"], true);

        let second = workspace_result(
            "workspace/fileRead",
            json!({
                "root": root.path_string(),
                "path": "README.md",
                "offset": 1,
                "limitBytes": 2,
            }),
        );
        assert_eq!(second["content"], "🙂");
        assert_eq!(second["offset"], 1);
        assert_eq!(second["bytesRead"], 4);
        assert_eq!(second["nextOffset"], 5);
        assert_eq!(second["hasMore"], true);
    }

    #[test]
    fn file_read_rejects_binary_content() {
        let root = TempWorkspace::new("file-read-binary");
        root.write_bytes("image.bin", &[0, 1, 2, 3]);

        let error = workspace_error(
            "workspace/fileRead",
            json!({"root": root.path_string(), "path": "image.bin"}),
        );

        assert!(
            error["message"]
                .as_str()
                .expect("message")
                .contains("binary")
        );
    }

    #[test]
    fn file_read_rejects_overlarge_single_read_limits() {
        let root = TempWorkspace::new("file-read-too-large");
        root.write("README.md", "ok\n");

        let error = workspace_error(
            "workspace/fileRead",
            json!({
                "root": root.path_string(),
                "path": "README.md",
                "limitBytes": MAX_FILE_READ_LIMIT + 1,
            }),
        );

        assert_eq!(error["code"].as_i64(), Some(-32026));
        assert!(
            error["message"]
                .as_str()
                .expect("message")
                .contains("too large")
        );
    }

    #[test]
    fn path_traversal_and_absolute_child_paths_are_rejected() {
        let root = TempWorkspace::new("path-traversal");
        root.write("README.md", "ok\n");

        let traversal = workspace_error(
            "workspace/fileStat",
            json!({"root": root.path_string(), "path": "../README.md"}),
        );
        assert!(
            traversal["message"]
                .as_str()
                .expect("message")
                .contains("outside")
        );

        let absolute = workspace_error(
            "workspace/fileStat",
            json!({"root": root.path_string(), "path": root.path_string()}),
        );
        assert!(
            absolute["message"]
                .as_str()
                .expect("message")
                .contains("outside")
        );
    }

    #[test]
    fn missing_path_reports_not_found() {
        let root = TempWorkspace::new("missing-path");

        let error = workspace_error(
            "workspace/fileStat",
            json!({"root": root.path_string(), "path": "missing.txt"}),
        );

        assert!(
            error["message"]
                .as_str()
                .expect("message")
                .contains("not found")
        );
    }

    #[test]
    fn symlink_ancestors_are_rejected_when_supported() {
        let root = TempWorkspace::new("symlink-ancestor");
        let outside = TempWorkspace::new("symlink-outside");
        outside.write("secret.txt", "secret\n");

        if !create_dir_symlink(outside.path(), &root.path().join("linked")) {
            return;
        }

        let error = workspace_error(
            "workspace/fileRead",
            json!({"root": root.path_string(), "path": "linked/secret.txt"}),
        );
        assert!(
            error["message"]
                .as_str()
                .expect("message")
                .contains("outside")
        );
    }

    fn workspace_result(method: &str, params: Value) -> Value {
        let response = workspace_response(method, params);
        assert!(
            response.error.is_none(),
            "unexpected error: {:?}",
            response.error
        );
        response.result.expect("result")
    }

    fn workspace_error(method: &str, params: Value) -> Value {
        let response = workspace_response(method, params);
        serde_json::to_value(response.error.expect("error")).expect("serialize error")
    }

    fn workspace_response(method: &str, params: Value) -> JsonRpcResponse {
        let request = JsonRpcRequest::new(RequestId::Number(1), method, Some(params));
        handle_workspace_request(&request).expect("workspace response")
    }

    fn create_dir_symlink(target: &Path, link: &Path) -> bool {
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(target, link).is_ok()
        }
        #[cfg(windows)]
        {
            std::os::windows::fs::symlink_dir(target, link).is_ok()
        }
    }

    struct TempWorkspace {
        path: PathBuf,
    }

    impl TempWorkspace {
        fn new(name: &str) -> Self {
            let path = std::env::temp_dir().join(format!(
                "sadcoder-agent-workspace-{name}-{}-{}",
                std::process::id(),
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .expect("time")
                    .as_nanos()
            ));
            fs::create_dir_all(&path).expect("create temp workspace");
            Self { path }
        }

        fn path(&self) -> &Path {
            &self.path
        }

        fn path_string(&self) -> String {
            self.path.display().to_string()
        }

        fn write(&self, relative_path: &str, content: &str) {
            self.write_bytes(relative_path, content.as_bytes());
        }

        fn write_bytes(&self, relative_path: &str, bytes: &[u8]) {
            let path = self.path.join(relative_path);
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent).expect("create parent");
            }
            fs::write(path, bytes).expect("write file");
        }
    }

    impl Drop for TempWorkspace {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.path);
        }
    }
}
