use serde::Deserialize;
use serde::Serialize;
use serde_json::Value;
use std::borrow::Cow;

pub const JSONRPC_VERSION: &str = "2.0";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(untagged)]
pub enum RequestId {
    Number(i64),
    String(String),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JsonRpcRequest {
    pub jsonrpc: Cow<'static, str>,
    pub id: RequestId,
    pub method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<Value>,
}

impl JsonRpcRequest {
    pub fn new(id: RequestId, method: impl Into<String>, params: Option<Value>) -> Self {
        Self {
            jsonrpc: Cow::Borrowed(JSONRPC_VERSION),
            id,
            method: method.into(),
            params,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JsonRpcNotification {
    pub jsonrpc: Cow<'static, str>,
    pub method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<Value>,
}

impl JsonRpcNotification {
    pub fn new(method: impl Into<String>, params: Option<Value>) -> Self {
        Self {
            jsonrpc: Cow::Borrowed(JSONRPC_VERSION),
            method: method.into(),
            params,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct JsonRpcResponse {
    pub jsonrpc: Cow<'static, str>,
    pub id: RequestId,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<JsonRpcError>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct JsonRpcError {
    pub code: i64,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentStateSnapshot {
    pub schema_version: u32,
    pub pending_approvals: Vec<AgentCachedServerRequest>,
    pub recent_events: Vec<AgentCachedEvent>,
}

impl Default for AgentStateSnapshot {
    fn default() -> Self {
        Self {
            schema_version: 1,
            pending_approvals: Vec::new(),
            recent_events: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentCachedServerRequest {
    pub id: Value,
    pub method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentCachedEvent {
    pub method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<Value>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AgentStatus {
    pub agent_version: String,
    pub platform_os: String,
    pub platform_arch: String,
    pub codex_path: String,
    pub codex_available: bool,
    pub codex_version: Option<String>,
    pub backend: BackendStatus,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BackendStatus {
    pub kind: BackendKind,
    pub state: BackendState,
    pub detail: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum BackendKind {
    CodexAppServerStdio,
    CodexAppServerDaemon,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum BackendState {
    Ready,
    NotStarted,
    Unavailable,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SlashCommandManifest {
    pub schema_version: u32,
    pub source: String,
    pub commands: Vec<SlashCommandSpec>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SlashCommandSpec {
    pub command: String,
    pub aliases: Vec<String>,
    pub description: String,
    pub supports_inline_args: bool,
    pub available_during_task: bool,
    pub available_in_side_conversation: bool,
    pub platform_visibility: SlashPlatformVisibility,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub feature_flag: Option<String>,
    pub mapping_type: SlashCommandMappingType,
    pub mapping_target: String,
    pub phase: SlashCommandPhase,
    pub risk_level: SlashCommandRiskLevel,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SlashCommandMappingType {
    AppServer,
    UiOnly,
    AgentFallback,
    Topology,
    NotApplicable,
    Debug,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SlashCommandPhase {
    Mvp,
    SecondStage,
    SecondStageExperimental,
    ThirdStage,
    AdvancedDebug,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SlashCommandRiskLevel {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SlashPlatformVisibility {
    All,
    DesktopOnly,
    WindowsOnly,
    DebugOnly,
    TuiOnly,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn request_serializes_jsonrpc_version() {
        let request = JsonRpcRequest::new(
            RequestId::Number(1),
            "model/list",
            Some(serde_json::json!({ "limit": 10 })),
        );

        let encoded = serde_json::to_value(request).expect("serialize request");

        assert_eq!(encoded["jsonrpc"], "2.0");
        assert_eq!(encoded["id"], 1);
        assert_eq!(encoded["method"], "model/list");
        assert_eq!(encoded["params"]["limit"], 10);
    }

    #[test]
    fn agent_status_uses_camel_case_wire_keys() {
        let status = AgentStatus {
            agent_version: "0.1.0".to_string(),
            platform_os: "linux".to_string(),
            platform_arch: "x86_64".to_string(),
            codex_path: "codex".to_string(),
            codex_available: true,
            codex_version: Some("codex-cli 1.2.3".to_string()),
            backend: BackendStatus {
                kind: BackendKind::CodexAppServerStdio,
                state: BackendState::Ready,
                detail: None,
            },
        };

        let encoded = serde_json::to_value(status).expect("serialize status");

        assert_eq!(encoded["agentVersion"], "0.1.0");
        assert_eq!(encoded["codexAvailable"], true);
        assert_eq!(encoded["backend"]["kind"], "codex-app-server-stdio");
    }

    #[test]
    fn agent_state_snapshot_uses_camel_case_wire_keys() {
        let snapshot = AgentStateSnapshot {
            schema_version: 1,
            pending_approvals: vec![AgentCachedServerRequest {
                id: Value::String("approval-1".to_string()),
                method: "item/commandExecution/requestApproval".to_string(),
                params: Some(serde_json::json!({ "command": "cargo test" })),
            }],
            recent_events: vec![AgentCachedEvent {
                method: "thread/item".to_string(),
                params: Some(serde_json::json!({ "threadId": "thr_1" })),
            }],
        };

        let encoded = serde_json::to_value(snapshot).expect("serialize snapshot");

        assert_eq!(encoded["schemaVersion"], 1);
        assert_eq!(
            encoded["pendingApprovals"][0]["method"],
            "item/commandExecution/requestApproval"
        );
        assert_eq!(encoded["recentEvents"][0]["params"]["threadId"], "thr_1");
    }

    #[test]
    fn slash_command_manifest_uses_camel_case_wire_keys() {
        let manifest = SlashCommandManifest {
            schema_version: 1,
            source: "source.rs".to_string(),
            commands: vec![SlashCommandSpec {
                command: "model".to_string(),
                aliases: Vec::new(),
                description: "choose model".to_string(),
                supports_inline_args: false,
                available_during_task: true,
                available_in_side_conversation: false,
                platform_visibility: SlashPlatformVisibility::All,
                feature_flag: None,
                mapping_type: SlashCommandMappingType::AppServer,
                mapping_target: "model/list".to_string(),
                phase: SlashCommandPhase::Mvp,
                risk_level: SlashCommandRiskLevel::Low,
            }],
        };

        let encoded = serde_json::to_value(manifest).expect("serialize manifest");

        assert_eq!(encoded["schemaVersion"], 1);
        assert_eq!(encoded["commands"][0]["supportsInlineArgs"], false);
        assert_eq!(encoded["commands"][0]["mappingType"], "appServer");
        assert_eq!(encoded["commands"][0]["phase"], "mvp");
    }
}
