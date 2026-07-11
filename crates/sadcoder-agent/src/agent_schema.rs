use anyhow::Context;
use serde::Deserialize;
use serde::Serialize;
use serde_json::Value;
use std::fs;
use std::path::Path;
use std::path::PathBuf;
use std::time::SystemTime;
use std::time::UNIX_EPOCH;

use crate::codex_command::ResolvedCodexCommand;
use crate::codex_command::probe_codex_version;

const SCHEMA_CACHE_DIR_NAME: &str = "app-server-schema";
const JSON_SCHEMA_DIR_NAME: &str = "json";
const EXPERIMENTAL_JSON_SCHEMA_DIR_NAME: &str = "json-experimental";
const SCHEMA_METADATA_FILE_NAME: &str = "sadcoder-schema-cache.json";
const JSON_SCHEMA_BUNDLE_FILE_NAME: &str = "codex_app_server_protocol.schemas.json";
const FNV_OFFSET_BASIS: u64 = 0xcbf29ce484222325;
const FNV_PRIME: u64 = 0x100000001b3;

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(crate) struct AgentSchemaOptions {
    pub(crate) refresh: bool,
    pub(crate) experimental: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentSchemaResult {
    pub(crate) schema_version: u32,
    pub(crate) source: String,
    pub(crate) experimental: bool,
    pub(crate) generated: bool,
    pub(crate) cache_dir: String,
    pub(crate) metadata_path: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) codex_version: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) generated_at_unix_ms: Option<u128>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) bundle_path: Option<String>,
    pub(crate) file_count: usize,
    pub(crate) total_bytes: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) digest: Option<String>,
    pub(crate) files: Vec<AgentSchemaFileSummary>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct AgentSchemaFileSummary {
    pub(crate) path: String,
    pub(crate) size_bytes: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) modified_at_unix_ms: Option<u128>,
    pub(crate) digest: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct AgentSchemaCacheMetadata {
    schema_version: u32,
    source: String,
    experimental: bool,
    codex_version: Option<String>,
    generated_at_unix_ms: u128,
}

pub(crate) fn collect_agent_schema_from_params(
    codex: &ResolvedCodexCommand,
    state_path: &Path,
    params: Option<&Value>,
) -> anyhow::Result<AgentSchemaResult> {
    let options = schema_options_from_params(params)?;
    collect_agent_schema(codex, state_path, options)
}

pub(crate) fn collect_agent_schema(
    codex: &ResolvedCodexCommand,
    state_path: &Path,
    options: AgentSchemaOptions,
) -> anyhow::Result<AgentSchemaResult> {
    let cache_dir = schema_cache_dir(state_path, options.experimental);
    let generated = if options.refresh || !schema_cache_has_bundle(&cache_dir) {
        generate_schema_cache(codex, &cache_dir, options.experimental)?;
        true
    } else {
        false
    };
    summarize_schema_cache(&cache_dir, options.experimental, generated)
}

fn schema_options_from_params(params: Option<&Value>) -> anyhow::Result<AgentSchemaOptions> {
    let Some(params) = params else {
        return Ok(AgentSchemaOptions::default());
    };
    let params = params
        .as_object()
        .context("agent/schema params must be an object")?;
    Ok(AgentSchemaOptions {
        refresh: optional_bool(params, "refresh")?.unwrap_or(false),
        experimental: optional_bool(params, "experimental")?.unwrap_or(false),
    })
}

fn optional_bool(
    params: &serde_json::Map<String, Value>,
    key: &str,
) -> anyhow::Result<Option<bool>> {
    match params.get(key) {
        Some(Value::Bool(value)) => Ok(Some(*value)),
        Some(Value::Null) | None => Ok(None),
        Some(_) => anyhow::bail!("agent/schema `{key}` must be a boolean"),
    }
}

fn schema_cache_dir(state_path: &Path, experimental: bool) -> PathBuf {
    let base = state_path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .map(Path::to_path_buf)
        .unwrap_or_else(std::env::temp_dir);
    base.join(SCHEMA_CACHE_DIR_NAME).join(if experimental {
        EXPERIMENTAL_JSON_SCHEMA_DIR_NAME
    } else {
        JSON_SCHEMA_DIR_NAME
    })
}

fn schema_cache_has_bundle(cache_dir: &Path) -> bool {
    cache_dir.join(JSON_SCHEMA_BUNDLE_FILE_NAME).is_file()
}

fn generate_schema_cache(
    codex: &ResolvedCodexCommand,
    cache_dir: &Path,
    experimental: bool,
) -> anyhow::Result<()> {
    let codex_version =
        probe_codex_version(codex).map_err(|failure| anyhow::anyhow!(failure.message()))?;
    if cache_dir.exists() {
        fs::remove_dir_all(cache_dir)
            .with_context(|| format!("failed to clear {}", cache_dir.display()))?;
    }
    fs::create_dir_all(cache_dir)
        .with_context(|| format!("failed to create {}", cache_dir.display()))?;

    let mut command = codex.command()?;
    command.args(["app-server", "generate-json-schema", "--out"]);
    command.arg(cache_dir);
    if experimental {
        command.arg("--experimental");
    }
    let output = command.output().with_context(|| {
        format!(
            "failed to spawn `{} app-server generate-json-schema --out {}`",
            codex.display_program(),
            cache_dir.display()
        )
    })?;
    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let detail = if stderr.is_empty() { stdout } else { stderr };
        anyhow::bail!(
            "codex app-server generate-json-schema failed with {}{}",
            output.status,
            if detail.is_empty() {
                String::new()
            } else {
                format!(": {detail}")
            }
        );
    }

    let metadata = AgentSchemaCacheMetadata {
        schema_version: 1,
        source: "codex app-server generate-json-schema".to_string(),
        experimental,
        codex_version: Some(codex_version),
        generated_at_unix_ms: now_unix_ms(),
    };
    let metadata_path = cache_dir.join(SCHEMA_METADATA_FILE_NAME);
    fs::write(&metadata_path, serde_json::to_vec_pretty(&metadata)?)
        .with_context(|| format!("failed to write {}", metadata_path.display()))?;
    Ok(())
}

fn summarize_schema_cache(
    cache_dir: &Path,
    experimental: bool,
    generated: bool,
) -> anyhow::Result<AgentSchemaResult> {
    let metadata_path = cache_dir.join(SCHEMA_METADATA_FILE_NAME);
    let metadata = read_schema_metadata(&metadata_path)?;
    let mut files = Vec::new();
    if cache_dir.exists() {
        collect_json_schema_files(cache_dir, cache_dir, &mut files)?;
    }
    files.sort_by(|left, right| left.path.cmp(&right.path));
    if files.is_empty() {
        anyhow::bail!(
            "app-server schema cache is empty at {}",
            cache_dir.display()
        );
    }
    let total_bytes = files.iter().map(|file| file.size_bytes).sum();
    let digest = combined_digest(&files);
    let bundle_path = cache_dir.join(JSON_SCHEMA_BUNDLE_FILE_NAME);
    Ok(AgentSchemaResult {
        schema_version: 1,
        source: metadata
            .as_ref()
            .map(|metadata| metadata.source.clone())
            .unwrap_or_else(|| "codex app-server generate-json-schema".to_string()),
        experimental: metadata
            .as_ref()
            .map(|metadata| metadata.experimental)
            .unwrap_or(experimental),
        generated,
        cache_dir: cache_dir.display().to_string(),
        metadata_path: metadata_path.display().to_string(),
        codex_version: metadata
            .as_ref()
            .and_then(|metadata| metadata.codex_version.clone()),
        generated_at_unix_ms: metadata
            .as_ref()
            .map(|metadata| metadata.generated_at_unix_ms),
        bundle_path: bundle_path
            .is_file()
            .then(|| bundle_path.display().to_string()),
        file_count: files.len(),
        total_bytes,
        digest: Some(digest),
        files,
    })
}

fn read_schema_metadata(path: &Path) -> anyhow::Result<Option<AgentSchemaCacheMetadata>> {
    if !path.exists() {
        return Ok(None);
    }
    let bytes = fs::read(path).with_context(|| format!("failed to read {}", path.display()))?;
    serde_json::from_slice(&bytes)
        .map(Some)
        .with_context(|| format!("failed to parse {}", path.display()))
}

fn collect_json_schema_files(
    cache_dir: &Path,
    dir: &Path,
    files: &mut Vec<AgentSchemaFileSummary>,
) -> anyhow::Result<()> {
    for entry in fs::read_dir(dir).with_context(|| format!("failed to read {}", dir.display()))? {
        let entry = entry?;
        let path = entry.path();
        let metadata = fs::symlink_metadata(&path)?;
        let file_type = metadata.file_type();
        if file_type.is_symlink() {
            continue;
        }
        if file_type.is_dir() {
            collect_json_schema_files(cache_dir, &path, files)?;
            continue;
        }
        if !file_type.is_file()
            || path.file_name().and_then(|name| name.to_str()) == Some(SCHEMA_METADATA_FILE_NAME)
            || path.extension().and_then(|extension| extension.to_str()) != Some("json")
        {
            continue;
        }
        let relative = path
            .strip_prefix(cache_dir)
            .unwrap_or(&path)
            .components()
            .map(|component| component.as_os_str().to_string_lossy())
            .collect::<Vec<_>>()
            .join("/");
        let bytes =
            fs::read(&path).with_context(|| format!("failed to read {}", path.display()))?;
        files.push(AgentSchemaFileSummary {
            path: relative,
            size_bytes: bytes.len() as u64,
            modified_at_unix_ms: modified_at_unix_ms(&metadata),
            digest: fnv64_hex(&bytes),
        });
    }
    Ok(())
}

fn combined_digest(files: &[AgentSchemaFileSummary]) -> String {
    let mut hash = FNV_OFFSET_BASIS;
    for file in files {
        fnv64_update(&mut hash, file.path.as_bytes());
        fnv64_update(&mut hash, &[0]);
        fnv64_update(&mut hash, file.digest.as_bytes());
        fnv64_update(&mut hash, &[0]);
    }
    format!("{hash:016x}")
}

fn fnv64_hex(bytes: &[u8]) -> String {
    let mut hash = FNV_OFFSET_BASIS;
    fnv64_update(&mut hash, bytes);
    format!("{hash:016x}")
}

fn fnv64_update(hash: &mut u64, bytes: &[u8]) {
    for byte in bytes {
        *hash ^= u64::from(*byte);
        *hash = hash.wrapping_mul(FNV_PRIME);
    }
}

fn modified_at_unix_ms(metadata: &fs::Metadata) -> Option<u128> {
    metadata
        .modified()
        .ok()?
        .duration_since(UNIX_EPOCH)
        .ok()
        .map(|duration| duration.as_millis())
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
    use crate::codex_command::CodexCommandSource;
    use std::ffi::OsString;
    use std::io;

    #[test]
    fn schema_options_parse_booleans() {
        let options = schema_options_from_params(Some(&serde_json::json!({
            "refresh": true,
            "experimental": true
        })))
        .expect("options");

        assert!(options.refresh);
        assert!(options.experimental);
    }

    #[test]
    fn schema_options_reject_non_boolean_values() {
        let error = schema_options_from_params(Some(&serde_json::json!({
            "refresh": "yes"
        })))
        .expect_err("invalid option");

        assert!(error.to_string().contains("refresh"));
    }

    #[test]
    fn summarizes_existing_schema_cache_without_generating() {
        let root = TempDir::new("schema-existing");
        let state_path = root.path().join("agent-state.json");
        let cache_dir = schema_cache_dir(&state_path, false);
        fs::create_dir_all(cache_dir.join("v2")).expect("create cache");
        fs::write(
            cache_dir.join(JSON_SCHEMA_BUNDLE_FILE_NAME),
            br#"{"schema":"root"}"#,
        )
        .expect("write bundle");
        fs::write(cache_dir.join("v2").join("ClientRequest.json"), b"{}").expect("write v2 schema");
        fs::write(
            cache_dir.join(SCHEMA_METADATA_FILE_NAME),
            br#"{"schemaVersion":1,"source":"codex app-server generate-json-schema","experimental":false,"codexVersion":"codex-cli 1.2.3","generatedAtUnixMs":7}"#,
        )
        .expect("write metadata");
        let codex = missing_codex();

        let result = collect_agent_schema(&codex, &state_path, AgentSchemaOptions::default())
            .expect("schema summary");

        assert!(!result.generated);
        assert_eq!(result.codex_version.as_deref(), Some("codex-cli 1.2.3"));
        assert_eq!(result.generated_at_unix_ms, Some(7));
        assert_eq!(result.file_count, 2);
        assert_eq!(
            result
                .files
                .iter()
                .map(|file| file.path.as_str())
                .collect::<Vec<_>>(),
            vec![JSON_SCHEMA_BUNDLE_FILE_NAME, "v2/ClientRequest.json"]
        );
        assert!(result.digest.is_some());
        assert!(
            result
                .bundle_path
                .as_deref()
                .is_some_and(|path| { path.ends_with(JSON_SCHEMA_BUNDLE_FILE_NAME) })
        );
    }

    #[test]
    fn schema_summary_skips_symlinked_cache_entries_when_supported() {
        let root = TempDir::new("schema-symlink");
        let state_path = root.path().join("agent-state.json");
        let cache_dir = schema_cache_dir(&state_path, false);
        fs::create_dir_all(&cache_dir).expect("create cache");
        fs::write(cache_dir.join(JSON_SCHEMA_BUNDLE_FILE_NAME), b"{}").expect("write bundle");
        let outside = root.path().join("outside.json");
        fs::write(&outside, b"{}").expect("write outside");
        if !create_file_symlink(&outside, &cache_dir.join("Linked.json")) {
            return;
        }

        let result =
            collect_agent_schema(&missing_codex(), &state_path, AgentSchemaOptions::default())
                .expect("schema summary");

        assert_eq!(result.file_count, 1);
        assert_eq!(result.files[0].path, JSON_SCHEMA_BUNDLE_FILE_NAME);
    }

    #[test]
    fn refresh_generates_schema_with_resolved_codex_command() {
        let root = TempDir::new("schema-generate");
        let state_path = root.path().join("agent-state.json");
        let codex = fake_codex(root.path());

        let result = collect_agent_schema(
            &codex,
            &state_path,
            AgentSchemaOptions {
                refresh: true,
                experimental: true,
            },
        )
        .expect("generated schema");

        assert!(result.generated);
        assert!(result.experimental);
        assert_eq!(result.codex_version.as_deref(), Some("codex-cli 1.2.3"));
        assert_eq!(result.file_count, 2);
        assert!(
            result
                .files
                .iter()
                .any(|file| file.path == "Experimental.json")
        );
    }

    fn missing_codex() -> ResolvedCodexCommand {
        ResolvedCodexCommand {
            program: PathBuf::from("definitely-missing-sadcoder-codex"),
            args: Vec::new(),
            path_prepend: Vec::new(),
            source: CodexCommandSource::Path,
        }
    }

    fn fake_codex(dir: &Path) -> ResolvedCodexCommand {
        #[cfg(windows)]
        let (program, script) = (
            dir.join("codex.cmd"),
            r#"@echo off
if "%1"=="--version" (
  echo codex-cli 1.2.3
  exit /b 0
)
if "%1"=="app-server" if "%2"=="generate-json-schema" if "%3"=="--out" (
  if not exist "%~4" mkdir "%~4"
  echo {"schemaVersion":1}> "%~4\codex_app_server_protocol.schemas.json"
  if "%5"=="--experimental" echo {"experimental":true}> "%~4\Experimental.json"
  exit /b 0
)
echo unexpected %*
exit /b 2
"#,
        );
        #[cfg(not(windows))]
        let (program, script) = (
            dir.join("codex"),
            r#"#!/bin/sh
if [ "$1" = "--version" ]; then
  printf 'codex-cli 1.2.3\n'
  exit 0
fi
if [ "$1" = "app-server" ] && [ "$2" = "generate-json-schema" ] && [ "$3" = "--out" ]; then
  mkdir -p "$4"
  printf '{"schemaVersion":1}\n' > "$4/codex_app_server_protocol.schemas.json"
  if [ "$5" = "--experimental" ]; then
    printf '{"experimental":true}\n' > "$4/Experimental.json"
  fi
  exit 0
fi
printf 'unexpected %s\n' "$*" >&2
exit 2
"#,
        );
        fs::write(&program, script).expect("write fake codex");
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mut permissions = fs::metadata(&program).expect("metadata").permissions();
            permissions.set_mode(0o755);
            fs::set_permissions(&program, permissions).expect("chmod fake codex");
        }
        ResolvedCodexCommand {
            program,
            args: Vec::<OsString>::new(),
            path_prepend: Vec::new(),
            source: CodexCommandSource::Config,
        }
    }

    fn create_file_symlink(target: &Path, link: &Path) -> bool {
        #[cfg(unix)]
        {
            std::os::unix::fs::symlink(target, link).is_ok()
        }
        #[cfg(windows)]
        {
            std::os::windows::fs::symlink_file(target, link).is_ok()
        }
        #[cfg(not(any(unix, windows)))]
        {
            let _ = (target, link);
            false
        }
    }

    struct TempDir {
        path: PathBuf,
    }

    impl TempDir {
        fn new(name: &str) -> Self {
            let path = std::env::temp_dir().join(format!(
                "sadcoder-agent-{name}-{}-{}",
                std::process::id(),
                now_unix_ms()
            ));
            fs::create_dir_all(&path).expect("create temp dir");
            Self { path }
        }

        fn path(&self) -> &Path {
            &self.path
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            if let Err(error) = fs::remove_dir_all(&self.path) {
                if error.kind() != io::ErrorKind::NotFound {
                    panic!("failed to remove {}: {error}", self.path.display());
                }
            }
        }
    }
}
