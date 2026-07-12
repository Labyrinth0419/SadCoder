use sadcoder_protocol::JSONRPC_VERSION;
use sadcoder_protocol::JsonRpcError;
use sadcoder_protocol::JsonRpcRequest;
use sadcoder_protocol::JsonRpcResponse;
use serde_json::Value;
use serde_json::json;
use std::borrow::Cow;

const AGENT_RPC_ERROR_CODE: i64 = -32040;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum AgentRpcMethod {
    Hello,
    Health,
    Logs,
    Snapshot,
    Schema,
    SlashCommands,
    RestartBackend,
    StopBackend,
    Ping,
}

impl AgentRpcMethod {
    pub(crate) fn from_request(request: &JsonRpcRequest) -> Option<Self> {
        match request.method.as_str() {
            "agent/hello" => Some(Self::Hello),
            "agent/health" | "agent/status" => Some(Self::Health),
            "agent/logs" => Some(Self::Logs),
            "agent/snapshot" => Some(Self::Snapshot),
            "agent/schema" => Some(Self::Schema),
            "agent/slashCommands/list" => Some(Self::SlashCommands),
            "agent/restartBackend" => Some(Self::RestartBackend),
            "agent/stopBackend" => Some(Self::StopBackend),
            "agent/ping" => Some(Self::Ping),
            _ => None,
        }
    }
}

pub(crate) fn hello_result() -> Value {
    json!({
        "agentVersion": env!("CARGO_PKG_VERSION"),
        "protocolVersion": 1,
        "platformOs": std::env::consts::OS,
        "platformArch": std::env::consts::ARCH,
        "methods": agent_methods(),
        "capabilities": {
            "agentRpc": true,
            "health": true,
            "logs": true,
            "restartBackend": true,
            "stopBackend": true,
            "reconnectSnapshot": true,
            "reconnectSnapshotCursor": true,
            "schema": true,
            "slashCommands": true,
            "workspaceFiles": true
        }
    })
}

pub(crate) fn ping_result() -> Value {
    json!({
        "ok": true,
        "agentVersion": env!("CARGO_PKG_VERSION")
    })
}

pub(crate) fn success_response(request: &JsonRpcRequest, result: Value) -> JsonRpcResponse {
    JsonRpcResponse {
        jsonrpc: Cow::Borrowed(JSONRPC_VERSION),
        id: request.id.clone(),
        result: Some(result),
        error: None,
    }
}

pub(crate) fn error_response(
    request: &JsonRpcRequest,
    detail: impl Into<String>,
) -> JsonRpcResponse {
    JsonRpcResponse {
        jsonrpc: Cow::Borrowed(JSONRPC_VERSION),
        id: request.id.clone(),
        result: None,
        error: Some(JsonRpcError {
            code: AGENT_RPC_ERROR_CODE,
            message: format!("agent RPC failed: {}", detail.into()),
            data: None,
        }),
    }
}

fn agent_methods() -> Vec<&'static str> {
    vec![
        "agent/hello",
        "agent/health",
        "agent/status",
        "agent/logs",
        "agent/snapshot",
        "agent/schema",
        "agent/slashCommands/list",
        "agent/restartBackend",
        "agent/stopBackend",
        "agent/ping",
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use sadcoder_protocol::RequestId;

    #[test]
    fn classifies_agent_rpc_methods() {
        for (method, expected) in [
            ("agent/hello", AgentRpcMethod::Hello),
            ("agent/health", AgentRpcMethod::Health),
            ("agent/status", AgentRpcMethod::Health),
            ("agent/logs", AgentRpcMethod::Logs),
            ("agent/snapshot", AgentRpcMethod::Snapshot),
            ("agent/schema", AgentRpcMethod::Schema),
            ("agent/slashCommands/list", AgentRpcMethod::SlashCommands),
            ("agent/restartBackend", AgentRpcMethod::RestartBackend),
            ("agent/stopBackend", AgentRpcMethod::StopBackend),
            ("agent/ping", AgentRpcMethod::Ping),
        ] {
            let request = JsonRpcRequest::new(RequestId::Number(1), method, None);
            assert_eq!(AgentRpcMethod::from_request(&request), Some(expected));
        }
    }

    #[test]
    fn hello_advertises_agent_capabilities() {
        let result = hello_result();

        assert_eq!(result["capabilities"]["agentRpc"], true);
        assert_eq!(result["capabilities"]["logs"], true);
        assert_eq!(result["capabilities"]["stopBackend"], true);
        assert_eq!(result["capabilities"]["reconnectSnapshotCursor"], true);
        assert_eq!(result["capabilities"]["schema"], true);
        assert_eq!(result["capabilities"]["workspaceFiles"], true);
        assert!(
            result["methods"]
                .as_array()
                .expect("methods")
                .iter()
                .any(|method| method.as_str() == Some("agent/slashCommands/list"))
        );
    }
}
