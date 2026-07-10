use anyhow::Context;
use sadcoder_protocol::AgentCachedEvent;
use sadcoder_protocol::AgentCachedServerRequest;
use sadcoder_protocol::AgentStateSnapshot;
use serde_json::Value;
use std::fs;
use std::path::Path;
use std::path::PathBuf;

const DEFAULT_RECENT_EVENT_LIMIT: usize = 100;

#[derive(Debug, Clone)]
pub(crate) struct AgentStateCache {
    pub(crate) snapshot: AgentStateSnapshot,
    recent_event_limit: usize,
}

impl AgentStateCache {
    pub(crate) fn empty() -> Self {
        Self {
            snapshot: AgentStateSnapshot::default(),
            recent_event_limit: DEFAULT_RECENT_EVENT_LIMIT,
        }
    }

    pub(crate) fn load(path: &Path) -> anyhow::Result<Self> {
        if !path.exists() {
            return Ok(Self::empty());
        }
        let bytes = fs::read(path)
            .with_context(|| format!("failed to read agent state snapshot {}", path.display()))?;
        let snapshot = serde_json::from_slice(&bytes)
            .with_context(|| format!("agent state snapshot is invalid JSON: {}", path.display()))?;
        Ok(Self {
            snapshot,
            recent_event_limit: DEFAULT_RECENT_EVENT_LIMIT,
        })
    }

    pub(crate) fn save(&self, path: &Path) -> anyhow::Result<()> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).with_context(|| {
                format!(
                    "failed to create agent state directory {}",
                    parent.display()
                )
            })?;
        }
        let bytes = serde_json::to_vec_pretty(&self.snapshot)?;
        fs::write(path, bytes)
            .with_context(|| format!("failed to write agent state snapshot {}", path.display()))
    }

    pub(crate) fn into_snapshot(self) -> AgentStateSnapshot {
        self.snapshot
    }

    pub(crate) fn observe_server_line_bytes(&mut self, line: &[u8]) -> bool {
        let Ok(line) = std::str::from_utf8(line) else {
            return false;
        };
        self.observe_server_line(line)
    }

    pub(crate) fn observe_client_line_bytes(&mut self, line: &[u8]) -> bool {
        let Ok(line) = std::str::from_utf8(line) else {
            return false;
        };
        self.observe_client_line(line)
    }

    fn observe_client_line(&mut self, line: &str) -> bool {
        let Ok(value) = serde_json::from_str::<Value>(line.trim()) else {
            return false;
        };
        let Some(object) = value.as_object() else {
            return false;
        };
        if object.get("method").is_some() {
            return false;
        }
        let Some(id) = object.get("id") else {
            return false;
        };

        self.resolve_pending_approval_id(id)
    }

    fn observe_server_line(&mut self, line: &str) -> bool {
        let Ok(value) = serde_json::from_str::<Value>(line.trim()) else {
            return false;
        };
        let Some(object) = value.as_object() else {
            return false;
        };
        let Some(method) = object.get("method").and_then(Value::as_str) else {
            return false;
        };

        let params = object.get("params").cloned();
        let mut changed = false;
        if let Some(id) = object.get("id").cloned() {
            if is_reconnectable_server_request_method(method) {
                self.upsert_pending_approval(AgentCachedServerRequest {
                    id,
                    method: method.to_string(),
                    params,
                });
                changed = true;
            }
        } else {
            if method == "serverRequest/resolved" {
                self.apply_server_request_resolved(params.as_ref());
            }
            self.push_recent_event(AgentCachedEvent {
                method: method.to_string(),
                params,
            });
            changed = true;
        }

        changed
    }

    fn upsert_pending_approval(&mut self, request: AgentCachedServerRequest) {
        if let Some(existing) = self
            .snapshot
            .pending_approvals
            .iter_mut()
            .find(|approval| approval.id == request.id)
        {
            *existing = request;
        } else {
            self.snapshot.pending_approvals.push(request);
        }
    }

    fn apply_server_request_resolved(&mut self, params: Option<&Value>) -> bool {
        let Some(request_id) = params
            .and_then(Value::as_object)
            .and_then(|params| params.get("requestId"))
        else {
            return false;
        };

        self.resolve_pending_approval_id(request_id)
    }

    fn resolve_pending_approval_id(&mut self, request_id: &Value) -> bool {
        let before = self.snapshot.pending_approvals.len();
        self.snapshot
            .pending_approvals
            .retain(|approval| &approval.id != request_id);
        before != self.snapshot.pending_approvals.len()
    }

    fn push_recent_event(&mut self, event: AgentCachedEvent) {
        self.snapshot.recent_events.push(event);
        let overflow = self
            .snapshot
            .recent_events
            .len()
            .saturating_sub(self.recent_event_limit);
        if overflow > 0 {
            self.snapshot.recent_events.drain(0..overflow);
        }
    }
}

pub(crate) fn resolve_state_path(configured: Option<&Path>) -> PathBuf {
    if let Some(path) = configured {
        return path.to_path_buf();
    }
    if let Ok(path) = std::env::var("SADCODER_STATE_PATH") {
        return PathBuf::from(path);
    }
    if let Ok(path) = std::env::var("SADCODER_HOME") {
        return PathBuf::from(path).join("agent-state.json");
    }
    if let Ok(path) = std::env::var("HOME") {
        return PathBuf::from(path)
            .join(".sadcoder")
            .join("agent-state.json");
    }
    if let Ok(path) = std::env::var("USERPROFILE") {
        return PathBuf::from(path)
            .join(".sadcoder")
            .join("agent-state.json");
    }
    std::env::temp_dir().join("sadcoder-agent-state.json")
}

fn is_reconnectable_server_request_method(method: &str) -> bool {
    matches!(
        method,
        "item/commandExecution/requestApproval"
            | "item/fileChange/requestApproval"
            | "item/permissions/requestApproval"
            | "item/tool/requestUserInput"
            | "mcpServer/elicitation/request"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tracks_pending_approvals() {
        let mut cache = AgentStateCache::empty();

        let changed = cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":"approval-1","method":"item/commandExecution/requestApproval","params":{"command":"cargo test"}}"#,
        );

        assert!(changed);
        assert_eq!(cache.snapshot.pending_approvals.len(), 1);
        assert_eq!(
            cache.snapshot.pending_approvals[0].method,
            "item/commandExecution/requestApproval"
        );
        assert_eq!(
            cache.snapshot.pending_approvals[0].params.as_ref().unwrap()["command"],
            "cargo test"
        );
    }

    #[test]
    fn replaces_duplicate_pending_approval_ids() {
        let mut cache = AgentStateCache::empty();

        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":"approval-1","method":"item/commandExecution/requestApproval","params":{"command":"first"}}"#,
        );
        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":"approval-1","method":"item/commandExecution/requestApproval","params":{"command":"second"}}"#,
        );

        assert_eq!(cache.snapshot.pending_approvals.len(), 1);
        assert_eq!(
            cache.snapshot.pending_approvals[0].params.as_ref().unwrap()["command"],
            "second"
        );
    }

    #[test]
    fn resolves_pending_approvals_and_records_events() {
        let mut cache = AgentStateCache::empty();

        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":9,"method":"item/fileChange/requestApproval","params":{"grantRoot":"/repo"}}"#,
        );
        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","method":"serverRequest/resolved","params":{"requestId":9}}"#,
        );

        assert!(cache.snapshot.pending_approvals.is_empty());
        assert_eq!(cache.snapshot.recent_events.len(), 1);
        assert_eq!(
            cache.snapshot.recent_events[0].method,
            "serverRequest/resolved"
        );
    }

    #[test]
    fn resolves_pending_approvals_when_client_responds() {
        let mut cache = AgentStateCache::empty();

        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":"approval-1","method":"item/commandExecution/requestApproval","params":{"command":"cargo test"}}"#,
        );
        let changed = cache.observe_client_line(
            r#"{"jsonrpc":"2.0","id":"approval-1","result":{"decision":"accept"}}"#,
        );

        assert!(changed);
        assert!(cache.snapshot.pending_approvals.is_empty());
    }

    #[test]
    fn tracks_request_user_input_requests() {
        let mut cache = AgentStateCache::empty();

        let changed = cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":"input-1","method":"item/tool/requestUserInput","params":{"threadId":"thread-1","turnId":"turn-1","itemId":"item-1","questions":[{"id":"confirm_path","header":"Confirm","question":"Proceed?","isOther":true,"isSecret":false,"options":[{"label":"Yes (Recommended)","description":"Continue."},{"label":"No","description":"Stop."}]}],"autoResolutionMs":60000}}"#,
        );

        assert!(changed);
        assert_eq!(cache.snapshot.pending_approvals.len(), 1);
        let request = &cache.snapshot.pending_approvals[0];
        assert_eq!(request.method, "item/tool/requestUserInput");
        let params = request.params.as_ref().expect("params");
        assert_eq!(params["threadId"], "thread-1");
        assert_eq!(params["questions"][0]["id"], "confirm_path");
        assert_eq!(params["questions"][0]["isOther"], true);
        assert_eq!(
            params["questions"][0]["options"][0]["label"],
            "Yes (Recommended)"
        );
        assert_eq!(params["autoResolutionMs"], 60000);
    }

    #[test]
    fn resolves_request_user_input_when_client_responds() {
        let mut cache = AgentStateCache::empty();

        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":"input-1","method":"item/tool/requestUserInput","params":{"threadId":"thread-1","turnId":"turn-1","itemId":"item-1","questions":[{"id":"confirm_path","header":"Confirm","question":"Proceed?","isOther":true,"isSecret":false,"options":[{"label":"Yes","description":"Continue."}]}],"autoResolutionMs":null}}"#,
        );
        let changed = cache.observe_client_line(
            r#"{"jsonrpc":"2.0","id":"input-1","result":{"answers":{"confirm_path":{"answers":["Yes"]}}}}"#,
        );

        assert!(changed);
        assert!(cache.snapshot.pending_approvals.is_empty());
    }

    #[test]
    fn ignores_client_requests_when_tracking_pending_approvals() {
        let mut cache = AgentStateCache::empty();

        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":"approval-1","method":"item/commandExecution/requestApproval","params":{"command":"cargo test"}}"#,
        );
        let changed = cache.observe_client_line(
            r#"{"jsonrpc":"2.0","id":"approval-1","method":"model/list","params":{}}"#,
        );

        assert!(!changed);
        assert_eq!(cache.snapshot.pending_approvals.len(), 1);
    }

    #[test]
    fn caps_recent_events() {
        let mut cache = AgentStateCache::empty();
        cache.recent_event_limit = 2;

        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/one"}"#);
        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/two"}"#);
        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/three"}"#);

        let methods = cache
            .snapshot
            .recent_events
            .iter()
            .map(|event| event.method.as_str())
            .collect::<Vec<_>>();
        assert_eq!(methods, vec!["event/two", "event/three"]);
    }

    #[test]
    fn round_trips_snapshot_file() {
        let mut cache = AgentStateCache::empty();
        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":"input-1","method":"item/tool/requestUserInput","params":{"threadId":"thread-1","turnId":"turn-1","itemId":"item-1","questions":[{"id":"confirm_path","header":"Confirm","question":"Proceed?","isOther":true,"isSecret":false,"options":[{"label":"Yes","description":"Continue."}]}],"autoResolutionMs":60000}}"#,
        );
        let path = std::env::temp_dir().join(format!(
            "sadcoder-agent-state-test-{}-{}.json",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ));

        cache.save(&path).expect("save state");
        let loaded = AgentStateCache::load(&path).expect("load state");
        let _ = fs::remove_file(&path);

        assert_eq!(loaded.snapshot.pending_approvals.len(), 1);
        assert_eq!(
            loaded.snapshot.pending_approvals[0].method,
            "item/tool/requestUserInput"
        );
        let params = loaded.snapshot.pending_approvals[0]
            .params
            .as_ref()
            .expect("params");
        assert_eq!(params["questions"][0]["options"][0]["label"], "Yes");
    }
}
