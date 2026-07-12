use anyhow::Context;
use sadcoder_protocol::AgentCachedEvent;
use sadcoder_protocol::AgentCachedServerRequest;
use sadcoder_protocol::AgentCachedThread;
use sadcoder_protocol::AgentStateSnapshot;
use serde_json::Map;
use serde_json::Value;
use std::fs;
use std::path::Path;
use std::path::PathBuf;

const DEFAULT_RECENT_EVENT_LIMIT: usize = 100;
const DEFAULT_THREAD_SNAPSHOT_LIMIT: usize = 100;

#[derive(Debug, Clone)]
pub(crate) struct AgentStateCache {
    pub(crate) snapshot: AgentStateSnapshot,
    recent_event_limit: usize,
    thread_snapshot_limit: usize,
}

impl AgentStateCache {
    pub(crate) fn empty() -> Self {
        Self {
            snapshot: AgentStateSnapshot::default(),
            recent_event_limit: DEFAULT_RECENT_EVENT_LIMIT,
            thread_snapshot_limit: DEFAULT_THREAD_SNAPSHOT_LIMIT,
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
            thread_snapshot_limit: DEFAULT_THREAD_SNAPSHOT_LIMIT,
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
        snapshot_with_cursor_window(self.snapshot, false)
    }

    pub(crate) fn snapshot_since_cursor(&self, since_cursor: Option<&str>) -> AgentStateSnapshot {
        let Some(since_cursor) = normalized_cursor(since_cursor) else {
            return snapshot_with_cursor_window(self.snapshot.clone(), false);
        };
        let mut snapshot = snapshot_with_cursor_window(self.snapshot.clone(), false);
        let filtered = events_after_cursor(&snapshot.recent_events, since_cursor);
        snapshot.recent_events = filtered.events;
        snapshot.cursor_gap = filtered.cursor_gap;
        snapshot
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
                cursor: None,
            });
            changed = true;
        }

        changed
    }

    fn upsert_pending_approval(&mut self, request: AgentCachedServerRequest) {
        self.observe_thread_context(request.params.as_ref(), None);
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

    fn push_recent_event(&mut self, mut event: AgentCachedEvent) {
        let cursor = self.next_delivered_cursor();
        event.cursor = Some(cursor.clone());
        self.snapshot.delivered_cursor = Some(cursor);
        self.observe_thread_context(event.params.as_ref(), event.cursor.as_deref());
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

    fn next_delivered_cursor(&self) -> String {
        self.snapshot
            .delivered_cursor
            .as_deref()
            .and_then(|cursor| cursor.parse::<u64>().ok())
            .map_or(1, |cursor| cursor.saturating_add(1))
            .to_string()
    }

    fn observe_thread_context(&mut self, params: Option<&Value>, cursor: Option<&str>) {
        let Some(params) = params.and_then(Value::as_object) else {
            return;
        };
        let Some(thread_id) = string_param(params, &["threadId", "thread_id"])
            .or_else(|| nested_string_param(params, "thread", &["id", "threadId", "thread_id"]))
        else {
            return;
        };
        let turn_id = string_param(params, &["turnId", "turn_id"]);
        let item_id = string_param(params, &["itemId", "item_id"]);
        self.upsert_thread_context(thread_id, turn_id, item_id, cursor.map(str::to_string));
    }

    fn upsert_thread_context(
        &mut self,
        thread_id: String,
        turn_id: Option<String>,
        item_id: Option<String>,
        cursor: Option<String>,
    ) {
        let thread = self
            .snapshot
            .threads
            .iter_mut()
            .find(|thread| thread.thread_id == thread_id);
        let thread = match thread {
            Some(thread) => thread,
            None => {
                self.snapshot.threads.push(AgentCachedThread {
                    thread_id,
                    last_turn_id: None,
                    last_item_id: None,
                    last_event_cursor: None,
                });
                let overflow = self
                    .snapshot
                    .threads
                    .len()
                    .saturating_sub(self.thread_snapshot_limit);
                if overflow > 0 {
                    self.snapshot.threads.drain(0..overflow);
                }
                self.snapshot.threads.last_mut().expect("inserted thread")
            }
        };
        if turn_id.is_some() {
            thread.last_turn_id = turn_id;
        }
        if item_id.is_some() {
            thread.last_item_id = item_id;
        }
        if cursor.is_some() {
            thread.last_event_cursor = cursor;
        }
    }
}

fn string_param(params: &Map<String, Value>, keys: &[&str]) -> Option<String> {
    keys.iter().find_map(|key| {
        params
            .get(*key)
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string)
    })
}

fn nested_string_param(
    params: &Map<String, Value>,
    object_key: &str,
    keys: &[&str],
) -> Option<String> {
    params
        .get(object_key)
        .and_then(Value::as_object)
        .and_then(|nested| string_param(nested, keys))
}

#[derive(Debug, Clone)]
struct CursorFilteredEvents {
    events: Vec<AgentCachedEvent>,
    cursor_gap: bool,
}

fn events_after_cursor(events: &[AgentCachedEvent], since_cursor: &str) -> CursorFilteredEvents {
    if let Ok(since) = since_cursor.parse::<u64>() {
        let retained_floor = events
            .iter()
            .find_map(|event| event.cursor.as_deref()?.parse::<u64>().ok());
        let cursor_gap = retained_floor.is_some_and(|floor| floor > since.saturating_add(1));
        return CursorFilteredEvents {
            events: events
                .iter()
                .filter(|event| {
                    event
                        .cursor
                        .as_deref()
                        .and_then(|cursor| cursor.parse::<u64>().ok())
                        .is_some_and(|cursor| cursor > since)
                })
                .cloned()
                .collect(),
            cursor_gap,
        };
    }

    let Some(index) = events
        .iter()
        .position(|event| event.cursor.as_deref() == Some(since_cursor))
    else {
        return CursorFilteredEvents {
            events: events.to_vec(),
            cursor_gap: !events.is_empty(),
        };
    };
    CursorFilteredEvents {
        events: events.iter().skip(index + 1).cloned().collect(),
        cursor_gap: false,
    }
}

fn snapshot_with_cursor_window(
    mut snapshot: AgentStateSnapshot,
    cursor_gap: bool,
) -> AgentStateSnapshot {
    snapshot.retained_cursor_floor = snapshot
        .recent_events
        .iter()
        .find_map(|event| normalized_cursor(event.cursor.as_deref()).map(str::to_string));
    snapshot.cursor_gap = cursor_gap;
    snapshot
}

fn normalized_cursor(cursor: Option<&str>) -> Option<&str> {
    cursor.map(str::trim).filter(|cursor| !cursor.is_empty())
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
    fn tracks_thread_context_from_server_events_and_requests() {
        let mut cache = AgentStateCache::empty();

        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","method":"thread/turn/completed","params":{"threadId":"thread-1","turnId":"turn-1","itemId":"item-1"}}"#,
        );
        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","id":"input-1","method":"item/tool/requestUserInput","params":{"threadId":"thread-1","turnId":"turn-2","itemId":"item-2","questions":[]}}"#,
        );
        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","method":"thread/created","params":{"thread":{"id":"thread-2"}}}"#,
        );

        assert_eq!(cache.snapshot.threads.len(), 2);
        let first = cache
            .snapshot
            .threads
            .iter()
            .find(|thread| thread.thread_id == "thread-1")
            .expect("thread-1");
        assert_eq!(first.last_turn_id.as_deref(), Some("turn-2"));
        assert_eq!(first.last_item_id.as_deref(), Some("item-2"));
        assert_eq!(first.last_event_cursor.as_deref(), Some("1"));
        let second = cache
            .snapshot
            .threads
            .iter()
            .find(|thread| thread.thread_id == "thread-2")
            .expect("thread-2");
        assert_eq!(second.last_turn_id, None);
        assert_eq!(second.last_event_cursor.as_deref(), Some("2"));
    }

    #[test]
    fn caps_thread_contexts() {
        let mut cache = AgentStateCache::empty();
        cache.thread_snapshot_limit = 2;

        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","method":"thread/created","params":{"threadId":"thread-1"}}"#,
        );
        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","method":"thread/created","params":{"threadId":"thread-2"}}"#,
        );
        cache.observe_server_line(
            r#"{"jsonrpc":"2.0","method":"thread/created","params":{"threadId":"thread-3"}}"#,
        );

        let thread_ids = cache
            .snapshot
            .threads
            .iter()
            .map(|thread| thread.thread_id.as_str())
            .collect::<Vec<_>>();
        assert_eq!(thread_ids, vec!["thread-2", "thread-3"]);
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
        let cursors = cache
            .snapshot
            .recent_events
            .iter()
            .map(|event| event.cursor.as_deref())
            .collect::<Vec<_>>();
        assert_eq!(cursors, vec![Some("2"), Some("3")]);
        assert_eq!(cache.snapshot.delivered_cursor.as_deref(), Some("3"));
    }

    #[test]
    fn resumes_delivered_cursor_after_load() {
        let mut cache = AgentStateCache::empty();
        cache.snapshot.delivered_cursor = Some("41".to_string());

        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/next"}"#);

        assert_eq!(
            cache.snapshot.recent_events[0].cursor.as_deref(),
            Some("42")
        );
        assert_eq!(cache.snapshot.delivered_cursor.as_deref(), Some("42"));
    }

    #[test]
    fn filters_snapshot_events_after_numeric_cursor() {
        let mut cache = AgentStateCache::empty();
        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/one"}"#);
        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/two"}"#);
        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/three"}"#);

        let snapshot = cache.snapshot_since_cursor(Some("1"));

        let methods = snapshot
            .recent_events
            .iter()
            .map(|event| event.method.as_str())
            .collect::<Vec<_>>();
        assert_eq!(methods, vec!["event/two", "event/three"]);
        assert_eq!(snapshot.delivered_cursor.as_deref(), Some("3"));
        assert_eq!(snapshot.retained_cursor_floor.as_deref(), Some("1"));
        assert!(!snapshot.cursor_gap);
    }

    #[test]
    fn marks_cursor_gap_when_numeric_cursor_is_before_retained_window() {
        let mut cache = AgentStateCache::empty();
        cache.recent_event_limit = 2;
        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/one"}"#);
        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/two"}"#);
        cache.observe_server_line(r#"{"jsonrpc":"2.0","method":"event/three"}"#);

        let snapshot = cache.snapshot_since_cursor(Some("0"));

        let methods = snapshot
            .recent_events
            .iter()
            .map(|event| event.method.as_str())
            .collect::<Vec<_>>();
        assert_eq!(methods, vec!["event/two", "event/three"]);
        assert_eq!(snapshot.retained_cursor_floor.as_deref(), Some("2"));
        assert!(snapshot.cursor_gap);
    }

    #[test]
    fn filters_snapshot_events_after_matching_non_numeric_cursor() {
        let mut cache = AgentStateCache::empty();
        cache.snapshot.recent_events = vec![
            AgentCachedEvent {
                method: "event/one".to_string(),
                params: None,
                cursor: Some("event-1".to_string()),
            },
            AgentCachedEvent {
                method: "event/two".to_string(),
                params: None,
                cursor: Some("event-2".to_string()),
            },
        ];
        cache.snapshot.delivered_cursor = Some("event-2".to_string());

        let snapshot = cache.snapshot_since_cursor(Some("event-1"));

        assert_eq!(snapshot.recent_events.len(), 1);
        assert_eq!(snapshot.recent_events[0].method, "event/two");
        assert_eq!(snapshot.delivered_cursor.as_deref(), Some("event-2"));
        assert_eq!(snapshot.retained_cursor_floor.as_deref(), Some("event-1"));
        assert!(!snapshot.cursor_gap);
    }

    #[test]
    fn keeps_retained_snapshot_events_when_non_numeric_cursor_is_unknown() {
        let mut cache = AgentStateCache::empty();
        cache.snapshot.recent_events = vec![AgentCachedEvent {
            method: "event/one".to_string(),
            params: None,
            cursor: Some("event-1".to_string()),
        }];
        cache.snapshot.delivered_cursor = Some("event-1".to_string());

        let snapshot = cache.snapshot_since_cursor(Some("missing"));

        assert_eq!(snapshot.recent_events.len(), 1);
        assert_eq!(snapshot.recent_events[0].method, "event/one");
        assert_eq!(snapshot.retained_cursor_floor.as_deref(), Some("event-1"));
        assert!(snapshot.cursor_gap);
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
