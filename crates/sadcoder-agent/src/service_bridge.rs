use anyhow::Context;
use serde_json::Value;
use serde_json::json;
use std::collections::HashMap;
use std::io;
use std::io::BufRead;
use std::io::BufReader;
use std::io::Read;
use std::io::Write;
use std::net::Shutdown;
use std::path::Path;
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::atomic::AtomicBool;
use std::sync::atomic::Ordering;
use std::thread;
use std::time::Duration;

use crate::app_server_socket::AppServerSocket;
use crate::app_server_socket::AppServerSocketWriter;
use crate::state_cache::AgentStateCache;

const SERVICE_PROTOCOL_VERSION: u32 = 1;
const SERVICE_HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(2);
const SERVICE_ACCEPT_POLL_INTERVAL: Duration = Duration::from_millis(100);
const REWRITTEN_REQUEST_ID_PREFIX: &str = "sadcoder-client-";

#[cfg(unix)]
type LocalSocketListener = std::os::unix::net::UnixListener;
#[cfg(unix)]
type LocalSocketStream = std::os::unix::net::UnixStream;

#[cfg(windows)]
type LocalSocketListener = uds_windows::UnixListener;
#[cfg(windows)]
type LocalSocketStream = uds_windows::UnixStream;

pub(crate) struct ServiceProxyConnection {
    pub(crate) reader: ServiceProxyReader,
    pub(crate) writer: ServiceProxyWriter,
}

pub(crate) struct ServiceProxyReader {
    stream: LocalSocketStream,
}

pub(crate) struct ServiceProxyWriter {
    stream: LocalSocketStream,
}

pub(crate) struct ServiceBridge {
    listener: LocalSocketListener,
    upstream: AppServerSocket,
    state_path: PathBuf,
}

struct ActiveClient {
    generation: u64,
    writer: Arc<Mutex<LocalSocketStream>>,
}

struct PendingClientRequest {
    generation: u64,
    original_id: Value,
    method: String,
}

struct BridgeState {
    active_client: Option<ActiveClient>,
    next_generation: u64,
    next_request_id: u64,
    pending_requests: HashMap<String, PendingClientRequest>,
    initialize_response: Option<Value>,
    initialized_forwarded: bool,
}

impl BridgeState {
    fn new() -> Self {
        Self {
            active_client: None,
            next_generation: 1,
            next_request_id: 1,
            pending_requests: HashMap::new(),
            initialize_response: None,
            initialized_forwarded: false,
        }
    }

    fn activate_client(&mut self, writer: Arc<Mutex<LocalSocketStream>>) -> u64 {
        let generation = self.next_generation;
        self.next_generation = self.next_generation.saturating_add(1);
        if let Some(previous) = self
            .active_client
            .replace(ActiveClient { generation, writer })
        {
            shutdown_stream(&previous.writer);
            self.pending_requests.retain(|_, request| {
                request.generation != previous.generation || request.method == "initialize"
            });
        }
        generation
    }

    fn deactivate_client(&mut self, generation: u64) {
        if self
            .active_client
            .as_ref()
            .is_some_and(|client| client.generation == generation)
        {
            self.active_client = None;
        }
        self.pending_requests.retain(|_, request| {
            request.generation != generation || request.method == "initialize"
        });
    }

    fn active_writer(&self, generation: u64) -> Option<Arc<Mutex<LocalSocketStream>>> {
        self.active_client
            .as_ref()
            .filter(|client| client.generation == generation)
            .map(|client| Arc::clone(&client.writer))
    }

    fn current_writer(&self) -> Option<Arc<Mutex<LocalSocketStream>>> {
        self.active_client
            .as_ref()
            .map(|client| Arc::clone(&client.writer))
    }

    fn rewrite_request_id(
        &mut self,
        generation: u64,
        original_id: Value,
        method: String,
    ) -> String {
        let rewritten = format!("{REWRITTEN_REQUEST_ID_PREFIX}{}", self.next_request_id);
        self.next_request_id = self.next_request_id.saturating_add(1);
        self.pending_requests.insert(
            rewritten.clone(),
            PendingClientRequest {
                generation,
                original_id,
                method,
            },
        );
        rewritten
    }

    fn retarget_pending_initialize(&mut self, generation: u64, original_id: Value) -> bool {
        if let Some(request) = self
            .pending_requests
            .values_mut()
            .find(|request| request.method == "initialize")
        {
            request.generation = generation;
            request.original_id = original_id;
            true
        } else {
            false
        }
    }
}

impl ServiceBridge {
    pub(crate) fn bind(
        socket_path: &Path,
        upstream: AppServerSocket,
        state_path: &Path,
    ) -> anyhow::Result<Self> {
        let listener = LocalSocketListener::bind(socket_path).with_context(|| {
            format!(
                "failed to bind SadCoder service socket {}",
                socket_path.display()
            )
        })?;
        listener
            .set_nonblocking(true)
            .context("failed to configure SadCoder service socket")?;
        Ok(Self {
            listener,
            upstream,
            state_path: state_path.to_path_buf(),
        })
    }

    pub(crate) fn run(self) -> anyhow::Result<()> {
        let upstream_writer = Arc::new(Mutex::new(self.upstream.writer));
        let state = Arc::new(Mutex::new(BridgeState::new()));
        let cache = Arc::new(Mutex::new(
            AgentStateCache::load(&self.state_path).unwrap_or_else(|_| AgentStateCache::empty()),
        ));
        let upstream_alive = Arc::new(AtomicBool::new(true));

        let reader_state = Arc::clone(&state);
        let reader_cache = Arc::clone(&cache);
        let reader_state_path = self.state_path.clone();
        let reader_alive = Arc::clone(&upstream_alive);
        let mut upstream_reader = self.upstream.reader;
        let upstream_thread = thread::spawn(move || {
            loop {
                match upstream_reader.read_text_message() {
                    Ok(Some(payload)) => {
                        observe_server_payload(&reader_cache, &reader_state_path, &payload);
                        handle_upstream_payload(&reader_state, payload);
                    }
                    Ok(None) => break,
                    Err(_) => break,
                }
            }
            reader_alive.store(false, Ordering::Release);
            shutdown_active_client(&reader_state);
        });

        let mut client_threads = Vec::new();
        while upstream_alive.load(Ordering::Acquire) {
            match self.listener.accept() {
                Ok((stream, _)) => {
                    let client_state = Arc::clone(&state);
                    let client_cache = Arc::clone(&cache);
                    let client_state_path = self.state_path.clone();
                    let client_upstream = Arc::clone(&upstream_writer);
                    client_threads.push(thread::spawn(move || {
                        let _ = handle_service_connection(
                            stream,
                            client_state,
                            client_cache,
                            client_state_path,
                            client_upstream,
                        );
                    }));
                }
                Err(error) if error.kind() == io::ErrorKind::WouldBlock => {
                    thread::sleep(SERVICE_ACCEPT_POLL_INTERVAL);
                }
                Err(error) => {
                    upstream_alive.store(false, Ordering::Release);
                    shutdown_active_client(&state);
                    let _ = upstream_thread.join();
                    return Err(error).context("SadCoder service socket accept failed");
                }
            }
        }

        let _ = upstream_thread.join();
        for client_thread in client_threads {
            let _ = client_thread.join();
        }
        Ok(())
    }
}

pub(crate) fn connect_service_proxy(socket_path: &Path) -> anyhow::Result<ServiceProxyConnection> {
    let mut writer = LocalSocketStream::connect(socket_path).with_context(|| {
        format!(
            "failed to connect SadCoder proxy socket {}",
            socket_path.display()
        )
    })?;
    writer
        .set_read_timeout(Some(SERVICE_HANDSHAKE_TIMEOUT))
        .context("failed to configure SadCoder proxy handshake timeout")?;
    write_json_line(
        &mut writer,
        &json!({
            "kind": "proxy",
            "protocolVersion": SERVICE_PROTOCOL_VERSION
        }),
    )?;
    let response = read_json_line(&writer)?;
    if response.get("ok").and_then(Value::as_bool) != Some(true)
        || response.get("protocolVersion").and_then(Value::as_u64)
            != Some(u64::from(SERVICE_PROTOCOL_VERSION))
    {
        anyhow::bail!("SadCoder service rejected proxy handshake: {response}");
    }
    writer
        .set_read_timeout(None)
        .context("failed to clear SadCoder proxy handshake timeout")?;
    let reader = writer
        .try_clone()
        .context("failed to clone SadCoder proxy socket")?;
    Ok(ServiceProxyConnection {
        reader: ServiceProxyReader { stream: reader },
        writer: ServiceProxyWriter { stream: writer },
    })
}

pub(crate) fn service_socket_is_ready(socket_path: &Path) -> bool {
    let Ok(mut stream) = LocalSocketStream::connect(socket_path) else {
        return false;
    };
    if stream
        .set_read_timeout(Some(SERVICE_HANDSHAKE_TIMEOUT))
        .is_err()
    {
        return false;
    }
    if write_json_line(&mut stream, &json!({ "kind": "health" })).is_err() {
        return false;
    }
    read_json_line(&stream)
        .ok()
        .and_then(|value| value.get("ok").and_then(Value::as_bool))
        == Some(true)
}

impl Read for ServiceProxyReader {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        self.stream.read(buffer)
    }
}

impl Write for ServiceProxyWriter {
    fn write(&mut self, buffer: &[u8]) -> io::Result<usize> {
        self.stream.write(buffer)
    }

    fn flush(&mut self) -> io::Result<()> {
        self.stream.flush()
    }
}

impl ServiceProxyWriter {
    pub(crate) fn shutdown(&self) {
        let _ = self.stream.shutdown(Shutdown::Both);
    }
}

fn handle_service_connection(
    mut stream: LocalSocketStream,
    state: Arc<Mutex<BridgeState>>,
    cache: Arc<Mutex<AgentStateCache>>,
    state_path: PathBuf,
    upstream_writer: Arc<Mutex<AppServerSocketWriter>>,
) -> anyhow::Result<()> {
    stream
        .set_nonblocking(false)
        .context("failed to configure SadCoder service client socket")?;
    stream
        .set_read_timeout(Some(SERVICE_HANDSHAKE_TIMEOUT))
        .context("failed to configure SadCoder service handshake timeout")?;
    let handshake = read_json_line(&stream)?;
    match handshake.get("kind").and_then(Value::as_str) {
        Some("health") => {
            write_json_line(&mut stream, &json!({ "ok": true }))?;
            return Ok(());
        }
        Some("proxy")
            if handshake.get("protocolVersion").and_then(Value::as_u64)
                == Some(u64::from(SERVICE_PROTOCOL_VERSION)) => {}
        _ => {
            write_json_line(
                &mut stream,
                &json!({
                    "ok": false,
                    "error": "unsupported SadCoder service handshake"
                }),
            )?;
            return Ok(());
        }
    }

    stream
        .set_read_timeout(None)
        .context("failed to clear SadCoder service handshake timeout")?;
    let writer = Arc::new(Mutex::new(
        stream
            .try_clone()
            .context("failed to clone SadCoder service client socket")?,
    ));
    write_shared_json_line(
        &writer,
        &json!({
            "ok": true,
            "protocolVersion": SERVICE_PROTOCOL_VERSION
        }),
    )?;
    let generation = state
        .lock()
        .map_err(|_| anyhow::anyhow!("SadCoder bridge state lock poisoned"))?
        .activate_client(Arc::clone(&writer));

    let mut reader = BufReader::new(stream);
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
        if !client_is_active(&state, generation) {
            break;
        }
        if process_client_line(
            &line,
            generation,
            &writer,
            &state,
            &cache,
            &state_path,
            &upstream_writer,
        )
        .is_err()
        {
            break;
        }
    }

    if let Ok(mut state) = state.lock() {
        state.deactivate_client(generation);
    }
    Ok(())
}

fn process_client_line(
    line: &[u8],
    generation: u64,
    client_writer: &Arc<Mutex<LocalSocketStream>>,
    state: &Arc<Mutex<BridgeState>>,
    cache: &Arc<Mutex<AgentStateCache>>,
    state_path: &Path,
    upstream_writer: &Arc<Mutex<AppServerSocketWriter>>,
) -> anyhow::Result<()> {
    let mut value: Value =
        serde_json::from_slice(line).context("SadCoder proxy sent invalid JSON")?;
    let Some(object) = value.as_object_mut() else {
        anyhow::bail!("SadCoder proxy sent a non-object JSON-RPC message");
    };

    let method = object
        .get("method")
        .and_then(Value::as_str)
        .map(str::to_string);
    let id = object.get("id").cloned();

    if let (Some(method), Some(original_id)) = (method.as_deref(), id) {
        let mut bridge_state = state
            .lock()
            .map_err(|_| anyhow::anyhow!("SadCoder bridge state lock poisoned"))?;
        if bridge_state
            .active_client
            .as_ref()
            .is_none_or(|client| client.generation != generation)
        {
            return Ok(());
        }
        if method == "initialize" {
            if let Some(mut response) = bridge_state.initialize_response.clone() {
                response
                    .as_object_mut()
                    .context("cached initialize response is not an object")?
                    .insert("id".into(), original_id);
                drop(bridge_state);
                return write_shared_json_line(client_writer, &response).map_err(Into::into);
            }
            if bridge_state.retarget_pending_initialize(generation, original_id.clone()) {
                return Ok(());
            }
        }
        let rewritten =
            bridge_state.rewrite_request_id(generation, original_id, method.to_string());
        object.insert("id".into(), Value::String(rewritten));
    } else if method.as_deref() == Some("initialized") {
        let mut bridge_state = state
            .lock()
            .map_err(|_| anyhow::anyhow!("SadCoder bridge state lock poisoned"))?;
        if bridge_state.initialized_forwarded {
            return Ok(());
        }
        bridge_state.initialized_forwarded = true;
    } else if method.is_none() && object.get("id").is_some() {
        observe_client_payload(cache, state_path, line);
    }

    let payload = serde_json::to_vec(&value)?;
    upstream_writer
        .lock()
        .map_err(|_| anyhow::anyhow!("app-server writer lock poisoned"))?
        .write_text_message(&payload)
        .context("failed to forward JSON-RPC message to app-server")
}

fn handle_upstream_payload(state: &Arc<Mutex<BridgeState>>, payload: Vec<u8>) {
    let Ok(mut value) = serde_json::from_slice::<Value>(&payload) else {
        forward_to_current_client(state, &payload);
        return;
    };
    let Some(object) = value.as_object_mut() else {
        forward_to_current_client(state, &payload);
        return;
    };
    let response_id = object.get("id").and_then(Value::as_str).map(str::to_string);
    let is_response = object.get("method").is_none() && object.get("id").is_some();

    if is_response {
        if let Some(rewritten_id) = response_id {
            let pending = state
                .lock()
                .ok()
                .and_then(|mut state| state.pending_requests.remove(&rewritten_id));
            if let Some(pending) = pending {
                object.insert("id".into(), pending.original_id.clone());
                let initialize_succeeded =
                    pending.method == "initialize" && object.get("result").is_some();
                let initialize_template = if initialize_succeeded {
                    let mut template = value.clone();
                    if let Some(object) = template.as_object_mut() {
                        object.insert("id".into(), Value::String(rewritten_id));
                    }
                    Some(template)
                } else {
                    None
                };
                let restored = serde_json::to_vec(&value).unwrap_or(payload);
                if initialize_succeeded {
                    if let (Some(initialize_template), Ok(mut state)) =
                        (initialize_template, state.lock())
                    {
                        state.initialize_response = Some(initialize_template);
                    }
                }
                forward_to_client_generation(state, pending.generation, &restored);
                return;
            }
            if rewritten_id.starts_with(REWRITTEN_REQUEST_ID_PREFIX) {
                return;
            }
        }
    }

    forward_to_current_client(state, &payload);
}

fn observe_server_payload(cache: &Arc<Mutex<AgentStateCache>>, state_path: &Path, payload: &[u8]) {
    observe_and_save(cache, state_path, |cache| {
        cache.observe_server_line_bytes(payload)
    });
}

fn observe_client_payload(cache: &Arc<Mutex<AgentStateCache>>, state_path: &Path, payload: &[u8]) {
    observe_and_save(cache, state_path, |cache| {
        cache.observe_client_line_bytes(payload)
    });
}

fn observe_and_save(
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

fn client_is_active(state: &Arc<Mutex<BridgeState>>, generation: u64) -> bool {
    state
        .lock()
        .ok()
        .and_then(|state| state.active_writer(generation))
        .is_some()
}

fn forward_to_client_generation(state: &Arc<Mutex<BridgeState>>, generation: u64, payload: &[u8]) {
    let writer = state
        .lock()
        .ok()
        .and_then(|state| state.active_writer(generation));
    if let Some(writer) = writer {
        let _ = write_shared_line(&writer, payload);
    }
}

fn forward_to_current_client(state: &Arc<Mutex<BridgeState>>, payload: &[u8]) {
    let writer = state.lock().ok().and_then(|state| state.current_writer());
    if let Some(writer) = writer {
        let _ = write_shared_line(&writer, payload);
    }
}

fn shutdown_active_client(state: &Arc<Mutex<BridgeState>>) {
    let writer = state.lock().ok().and_then(|state| state.current_writer());
    if let Some(writer) = writer {
        shutdown_stream(&writer);
    }
}

fn shutdown_stream(stream: &Arc<Mutex<LocalSocketStream>>) {
    if let Ok(stream) = stream.lock() {
        let _ = stream.shutdown(Shutdown::Both);
    }
}

fn write_shared_json_line(stream: &Arc<Mutex<LocalSocketStream>>, value: &Value) -> io::Result<()> {
    let mut stream = stream
        .lock()
        .map_err(|_| io::Error::other("SadCoder client writer lock poisoned"))?;
    write_json_line(&mut stream, value)
}

fn write_shared_line(stream: &Arc<Mutex<LocalSocketStream>>, payload: &[u8]) -> io::Result<()> {
    let mut stream = stream
        .lock()
        .map_err(|_| io::Error::other("SadCoder client writer lock poisoned"))?;
    stream.write_all(payload)?;
    stream.write_all(b"\n")?;
    stream.flush()
}

fn write_json_line(stream: &mut LocalSocketStream, value: &Value) -> io::Result<()> {
    serde_json::to_writer(&mut *stream, value).map_err(io::Error::other)?;
    stream.write_all(b"\n")?;
    stream.flush()
}

fn read_json_line(stream: &LocalSocketStream) -> anyhow::Result<Value> {
    let mut reader = BufReader::new(
        stream
            .try_clone()
            .context("failed to clone SadCoder service handshake socket")?,
    );
    let mut line = String::new();
    let bytes = reader
        .read_line(&mut line)
        .context("failed to read SadCoder service handshake")?;
    if bytes == 0 {
        anyhow::bail!("SadCoder service closed during handshake");
    }
    serde_json::from_str(line.trim()).context("SadCoder service handshake was invalid JSON")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;
    use std::sync::mpsc;
    use std::time::SystemTime;
    use std::time::UNIX_EPOCH;

    #[test]
    fn rewrites_request_ids_and_replays_initialize_after_disconnect() {
        let backend_path = temp_socket_path("bridge-backend");
        let service_path = temp_socket_path("bridge-service");
        let state_path = temp_socket_path("bridge-state").with_extension("json");
        prepare_socket_parent(&backend_path);
        prepare_socket_parent(&service_path);
        let backend_listener = TestLocalSocketListener::bind(&backend_path).expect("bind backend");
        let connect_path = backend_path.clone();
        let connect_thread = thread::spawn(move || AppServerSocket::connect(&connect_path));
        let mut backend_stream = backend_listener.accept().expect("accept backend");
        accept_websocket_handshake(&mut backend_stream);
        let upstream = connect_thread
            .join()
            .expect("join connect")
            .expect("connect");

        let bridge =
            ServiceBridge::bind(&service_path, upstream, &state_path).expect("bind bridge");
        let bridge_thread = thread::spawn(move || bridge.run());

        let first = connect_service_proxy(&service_path).expect("first proxy");
        let mut first_writer = first.writer;
        let mut first_reader = BufReader::new(first.reader);
        first_writer
            .write_all(b"{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}\n")
            .expect("write initialize");
        first_writer.flush().expect("flush initialize");

        let initialize = read_client_websocket_value(&mut backend_stream);
        let rewritten_id = initialize["id"].as_str().expect("rewritten id").to_string();
        assert!(rewritten_id.starts_with(REWRITTEN_REQUEST_ID_PREFIX));
        write_server_websocket_value(
            &mut backend_stream,
            &json!({
                "jsonrpc": "2.0",
                "id": rewritten_id,
                "result": { "server": "ready" }
            }),
        );
        assert_eq!(read_line_value(&mut first_reader)["id"], 1);
        drop(first_writer);
        drop(first_reader);

        write_server_websocket_value(
            &mut backend_stream,
            &json!({
                "jsonrpc": "2.0",
                "method": "turn/completed",
                "params": { "threadId": "thr-offline" }
            }),
        );
        write_server_websocket_value(
            &mut backend_stream,
            &json!({
                "jsonrpc": "2.0",
                "id": "approval-offline",
                "method": "item/commandExecution/requestApproval",
                "params": { "command": "cargo test" }
            }),
        );
        wait_for_snapshot(&state_path, |snapshot| {
            snapshot.recent_events.len() == 1 && snapshot.pending_approvals.len() == 1
        });

        let second = connect_service_proxy(&service_path).expect("second proxy");
        let mut second_writer = second.writer;
        let mut second_reader = BufReader::new(second.reader);
        second_writer
            .write_all(b"{\"jsonrpc\":\"2.0\",\"id\":99,\"method\":\"initialize\",\"params\":{}}\n")
            .expect("write replay initialize");
        second_writer.flush().expect("flush replay initialize");
        let replay = read_line_value(&mut second_reader);
        assert_eq!(replay["id"], 99);
        assert_eq!(replay["result"]["server"], "ready");

        second_writer
            .write_all(b"{\"jsonrpc\":\"2.0\",\"method\":\"initialized\"}\n")
            .expect("write initialized");
        second_writer.flush().expect("flush initialized");
        let initialized = read_client_websocket_value(&mut backend_stream);
        assert_eq!(initialized["method"], "initialized");

        let (tx, rx) = mpsc::channel();
        backend_stream
            .set_read_timeout(Some(Duration::from_millis(200)))
            .expect("backend timeout");
        thread::spawn(move || {
            let duplicate = read_client_websocket_value_result(&mut backend_stream);
            let _ = tx.send((duplicate, backend_stream));
        });
        let (duplicate, mut backend_stream) = rx
            .recv_timeout(Duration::from_secs(1))
            .expect("read duplicate");
        assert!(duplicate.err().is_some_and(|error| matches!(
            error.kind(),
            io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
        )));

        drop(second_writer);
        drop(second_reader);
        write_server_close(&mut backend_stream);
        bridge_thread
            .join()
            .expect("join bridge")
            .expect("bridge result");
        cleanup_test_paths(&[backend_path, service_path, state_path]);
    }

    #[test]
    fn reconnect_reuses_inflight_initialize_request() {
        let backend_path = temp_socket_path("inflight-backend");
        let service_path = temp_socket_path("inflight-service");
        let state_path = temp_socket_path("inflight-state").with_extension("json");
        prepare_socket_parent(&backend_path);
        prepare_socket_parent(&service_path);
        let backend_listener = TestLocalSocketListener::bind(&backend_path).expect("bind backend");
        let connect_path = backend_path.clone();
        let connect_thread = thread::spawn(move || AppServerSocket::connect(&connect_path));
        let mut backend_stream = backend_listener.accept().expect("accept backend");
        accept_websocket_handshake(&mut backend_stream);
        let upstream = connect_thread
            .join()
            .expect("join connect")
            .expect("connect");

        let bridge =
            ServiceBridge::bind(&service_path, upstream, &state_path).expect("bind bridge");
        let bridge_thread = thread::spawn(move || bridge.run());

        let first = connect_service_proxy(&service_path).expect("first proxy");
        let mut first_writer = first.writer;
        first_writer
            .write_all(b"{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}\n")
            .expect("write first initialize");
        first_writer.flush().expect("flush first initialize");
        let initialize = read_client_websocket_value(&mut backend_stream);
        let rewritten_id = initialize["id"].as_str().expect("rewritten id").to_string();
        drop(first_writer);
        drop(first.reader);

        let second = connect_service_proxy(&service_path).expect("second proxy");
        let mut second_writer = second.writer;
        let mut second_reader = BufReader::new(second.reader);
        second_writer
            .write_all(b"{\"jsonrpc\":\"2.0\",\"id\":44,\"method\":\"initialize\",\"params\":{}}\n")
            .expect("write second initialize");
        second_writer.flush().expect("flush second initialize");

        backend_stream
            .set_read_timeout(Some(Duration::from_millis(200)))
            .expect("backend timeout");
        let duplicate = read_client_websocket_value_result(&mut backend_stream);
        assert!(duplicate.err().is_some_and(|error| matches!(
            error.kind(),
            io::ErrorKind::WouldBlock | io::ErrorKind::TimedOut
        )));
        backend_stream
            .set_read_timeout(None)
            .expect("clear backend timeout");

        write_server_websocket_value(
            &mut backend_stream,
            &json!({
                "jsonrpc": "2.0",
                "id": rewritten_id,
                "result": { "server": "ready" }
            }),
        );
        let response = read_line_value(&mut second_reader);
        assert_eq!(response["id"], 44);
        assert_eq!(response["result"]["server"], "ready");

        drop(second_writer);
        drop(second_reader);
        write_server_close(&mut backend_stream);
        bridge_thread
            .join()
            .expect("join bridge")
            .expect("bridge result");
        cleanup_test_paths(&[backend_path, service_path, state_path]);
    }

    #[test]
    fn health_checks_do_not_replace_the_active_proxy() {
        let backend_path = temp_socket_path("health-backend");
        let service_path = temp_socket_path("health-service");
        let state_path = temp_socket_path("health-state").with_extension("json");
        prepare_socket_parent(&backend_path);
        prepare_socket_parent(&service_path);
        let backend_listener = TestLocalSocketListener::bind(&backend_path).expect("bind backend");
        let connect_path = backend_path.clone();
        let connect_thread = thread::spawn(move || AppServerSocket::connect(&connect_path));
        let mut backend_stream = backend_listener.accept().expect("accept backend");
        accept_websocket_handshake(&mut backend_stream);
        let upstream = connect_thread
            .join()
            .expect("join connect")
            .expect("connect");

        let bridge =
            ServiceBridge::bind(&service_path, upstream, &state_path).expect("bind bridge");
        let bridge_thread = thread::spawn(move || bridge.run());
        let proxy = connect_service_proxy(&service_path).expect("proxy");

        assert!(service_socket_is_ready(&service_path));
        let mut writer = proxy.writer;
        writer
            .write_all(b"{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"model/list\"}\n")
            .expect("write request");
        writer.flush().expect("flush request");
        let request = read_client_websocket_value(&mut backend_stream);
        assert_eq!(request["method"], "model/list");

        drop(writer);
        drop(proxy.reader);
        write_server_close(&mut backend_stream);
        bridge_thread
            .join()
            .expect("join bridge")
            .expect("bridge result");
        cleanup_test_paths(&[backend_path, service_path, state_path]);
    }

    fn wait_for_snapshot(
        path: &Path,
        predicate: impl Fn(&sadcoder_protocol::AgentStateSnapshot) -> bool,
    ) {
        for _ in 0..50 {
            if let Ok(cache) = AgentStateCache::load(path) {
                if predicate(&cache.snapshot) {
                    return;
                }
            }
            thread::sleep(Duration::from_millis(20));
        }
        panic!("snapshot did not reach expected state");
    }

    fn read_line_value(reader: &mut impl BufRead) -> Value {
        let mut line = String::new();
        reader.read_line(&mut line).expect("read line");
        serde_json::from_str(line.trim()).expect("line json")
    }

    fn accept_websocket_handshake(stream: &mut LocalSocketStream) {
        let mut request = Vec::new();
        let mut byte = [0; 1];
        while !request.ends_with(b"\r\n\r\n") {
            stream.read_exact(&mut byte).expect("read handshake");
            request.push(byte[0]);
        }
        stream
            .write_all(
                b"HTTP/1.1 101 Switching Protocols\r\n\
                  Upgrade: websocket\r\n\
                  Connection: Upgrade\r\n\
                  \r\n",
            )
            .expect("write handshake");
        stream.flush().expect("flush handshake");
    }

    fn read_client_websocket_value(stream: &mut LocalSocketStream) -> Value {
        read_client_websocket_value_result(stream).expect("read websocket value")
    }

    fn read_client_websocket_value_result(stream: &mut LocalSocketStream) -> io::Result<Value> {
        let payload = read_test_frame(stream)?;
        serde_json::from_slice(&payload).map_err(io::Error::other)
    }

    fn write_server_websocket_value(stream: &mut LocalSocketStream, value: &Value) {
        let payload = serde_json::to_vec(value).expect("serialize server value");
        write_test_frame(stream, 0x1, &payload, false).expect("write server frame");
    }

    fn write_server_close(stream: &mut LocalSocketStream) {
        write_test_frame(stream, 0x8, &[], false).expect("write close");
    }

    fn read_test_frame(stream: &mut impl Read) -> io::Result<Vec<u8>> {
        let mut header = [0; 2];
        stream.read_exact(&mut header)?;
        let masked = header[1] & 0x80 != 0;
        let mut payload_len = u64::from(header[1] & 0x7f);
        if payload_len == 126 {
            let mut extended = [0; 2];
            stream.read_exact(&mut extended)?;
            payload_len = u64::from(u16::from_be_bytes(extended));
        } else if payload_len == 127 {
            let mut extended = [0; 8];
            stream.read_exact(&mut extended)?;
            payload_len = u64::from_be_bytes(extended);
        }
        let mut mask = [0; 4];
        if masked {
            stream.read_exact(&mut mask)?;
        }
        let mut payload = vec![0; payload_len as usize];
        stream.read_exact(&mut payload)?;
        if masked {
            for (index, byte) in payload.iter_mut().enumerate() {
                *byte ^= mask[index % mask.len()];
            }
        }
        Ok(payload)
    }

    fn write_test_frame(
        stream: &mut impl Write,
        opcode: u8,
        payload: &[u8],
        masked: bool,
    ) -> io::Result<()> {
        let mut encoded = Cursor::new(Vec::new());
        encoded.write_all(&[0x80 | opcode])?;
        let mask_bit = if masked { 0x80 } else { 0 };
        if payload.len() < 126 {
            encoded.write_all(&[mask_bit | payload.len() as u8])?;
        } else {
            encoded.write_all(&[mask_bit | 126])?;
            encoded.write_all(&(payload.len() as u16).to_be_bytes())?;
        }
        let mask = [1, 2, 3, 4];
        if masked {
            encoded.write_all(&mask)?;
            let mut masked_payload = payload.to_vec();
            for (index, byte) in masked_payload.iter_mut().enumerate() {
                *byte ^= mask[index % mask.len()];
            }
            encoded.write_all(&masked_payload)?;
        } else {
            encoded.write_all(payload)?;
        }
        stream.write_all(encoded.get_ref())?;
        stream.flush()
    }

    fn temp_socket_path(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "sadcoder-agent-{name}-{}-{}.sock",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("time")
                .as_nanos()
        ))
    }

    fn prepare_socket_parent(path: &Path) {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).expect("create socket parent");
        }
        let _ = std::fs::remove_file(path);
    }

    fn cleanup_test_paths(paths: &[PathBuf]) {
        for path in paths {
            let _ = std::fs::remove_file(path);
        }
    }

    #[cfg(unix)]
    struct TestLocalSocketListener(std::os::unix::net::UnixListener);

    #[cfg(unix)]
    impl TestLocalSocketListener {
        fn bind(path: &Path) -> io::Result<Self> {
            std::os::unix::net::UnixListener::bind(path).map(Self)
        }

        fn accept(&self) -> io::Result<LocalSocketStream> {
            self.0.accept().map(|(stream, _)| stream)
        }
    }

    #[cfg(windows)]
    struct TestLocalSocketListener(uds_windows::UnixListener);

    #[cfg(windows)]
    impl TestLocalSocketListener {
        fn bind(path: &Path) -> io::Result<Self> {
            uds_windows::UnixListener::bind(path).map(Self)
        }

        fn accept(&self) -> io::Result<LocalSocketStream> {
            self.0.accept().map(|(stream, _)| stream)
        }
    }
}
