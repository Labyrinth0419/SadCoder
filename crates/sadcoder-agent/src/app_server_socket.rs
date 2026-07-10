use std::io;
use std::io::Read;
use std::io::Write;
use std::path::Path;

const WEBSOCKET_HANDSHAKE_KEY: &str = "dGhlIHNhbXBsZSBub25jZQ==";
const MAX_HANDSHAKE_BYTES: usize = 8192;
const MAX_FRAME_PAYLOAD_BYTES: u64 = 64 * 1024 * 1024;
const CLIENT_MASK_KEY: [u8; 4] = [0x53, 0x43, 0x4f, 0x44];

#[cfg(unix)]
type LocalSocketStream = std::os::unix::net::UnixStream;

#[cfg(windows)]
type LocalSocketStream = uds_windows::UnixStream;

pub(crate) struct AppServerSocket {
    pub(crate) reader: AppServerSocketReader,
    pub(crate) writer: AppServerSocketWriter,
}

pub(crate) struct AppServerSocketReader {
    stream: LocalSocketStream,
}

pub(crate) struct AppServerSocketWriter {
    stream: LocalSocketStream,
}

impl AppServerSocket {
    pub(crate) fn connect(socket_path: &Path) -> io::Result<Self> {
        let mut stream = connect_local_socket(socket_path)?;
        websocket_handshake(&mut stream)?;
        let reader = clone_local_socket(&stream)?;
        Ok(Self {
            reader: AppServerSocketReader { stream: reader },
            writer: AppServerSocketWriter { stream },
        })
    }
}

impl AppServerSocketReader {
    pub(crate) fn read_text_message(&mut self) -> io::Result<Option<Vec<u8>>> {
        let mut fragmented_text = Vec::new();
        let mut reading_fragmented_text = false;
        loop {
            let frame = read_frame(&mut self.stream)?;
            match frame.opcode {
                OPCODE_TEXT => {
                    if frame.fin {
                        return Ok(Some(frame.payload));
                    }
                    fragmented_text.extend(frame.payload);
                    reading_fragmented_text = true;
                }
                OPCODE_CONTINUATION if reading_fragmented_text => {
                    fragmented_text.extend(frame.payload);
                    if frame.fin {
                        return Ok(Some(fragmented_text));
                    }
                }
                OPCODE_CLOSE => return Ok(None),
                OPCODE_PING | OPCODE_PONG => {}
                _ => {}
            }
        }
    }
}

impl AppServerSocketWriter {
    pub(crate) fn write_text_message(&mut self, payload: &[u8]) -> io::Result<()> {
        write_frame(&mut self.stream, OPCODE_TEXT, payload, true)
    }

    pub(crate) fn write_close(&mut self) -> io::Result<()> {
        write_frame(&mut self.stream, OPCODE_CLOSE, &[], true)
    }
}

#[cfg(unix)]
fn connect_local_socket(socket_path: &Path) -> io::Result<LocalSocketStream> {
    LocalSocketStream::connect(socket_path)
}

#[cfg(windows)]
fn connect_local_socket(socket_path: &Path) -> io::Result<LocalSocketStream> {
    LocalSocketStream::connect(socket_path)
}

#[cfg(unix)]
fn clone_local_socket(stream: &LocalSocketStream) -> io::Result<LocalSocketStream> {
    stream.try_clone()
}

#[cfg(windows)]
fn clone_local_socket(stream: &LocalSocketStream) -> io::Result<LocalSocketStream> {
    stream.try_clone()
}

fn websocket_handshake(stream: &mut LocalSocketStream) -> io::Result<()> {
    let request = format!(
        "GET / HTTP/1.1\r\n\
         Host: localhost\r\n\
         Upgrade: websocket\r\n\
         Connection: Upgrade\r\n\
         Sec-WebSocket-Key: {WEBSOCKET_HANDSHAKE_KEY}\r\n\
         Sec-WebSocket-Version: 13\r\n\
         \r\n"
    );
    stream.write_all(request.as_bytes())?;
    stream.flush()?;

    let response = read_http_response_header(stream)?;
    if !websocket_response_is_switching_protocols(&response) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            format!(
                "app-server socket did not accept websocket upgrade: {}",
                String::from_utf8_lossy(&response)
            ),
        ));
    }
    Ok(())
}

fn read_http_response_header(stream: &mut LocalSocketStream) -> io::Result<Vec<u8>> {
    let mut response = Vec::new();
    let mut byte = [0; 1];
    while response.len() < MAX_HANDSHAKE_BYTES {
        stream.read_exact(&mut byte)?;
        response.push(byte[0]);
        if response.ends_with(b"\r\n\r\n") {
            return Ok(response);
        }
    }
    Err(io::Error::new(
        io::ErrorKind::InvalidData,
        "websocket handshake response exceeded header limit",
    ))
}

fn websocket_response_is_switching_protocols(response: &[u8]) -> bool {
    response.starts_with(b"HTTP/1.1 101 ") || response.starts_with(b"HTTP/1.0 101 ")
}

const OPCODE_CONTINUATION: u8 = 0x0;
const OPCODE_TEXT: u8 = 0x1;
const OPCODE_CLOSE: u8 = 0x8;
const OPCODE_PING: u8 = 0x9;
const OPCODE_PONG: u8 = 0xa;

#[derive(Debug, Clone, PartialEq, Eq)]
struct WebSocketFrame {
    fin: bool,
    opcode: u8,
    payload: Vec<u8>,
}

fn read_frame(reader: &mut impl Read) -> io::Result<WebSocketFrame> {
    let mut header = [0; 2];
    reader.read_exact(&mut header)?;
    let fin = header[0] & 0x80 != 0;
    let opcode = header[0] & 0x0f;
    let masked = header[1] & 0x80 != 0;
    let mut payload_len = u64::from(header[1] & 0x7f);
    if payload_len == 126 {
        let mut extended = [0; 2];
        reader.read_exact(&mut extended)?;
        payload_len = u64::from(u16::from_be_bytes(extended));
    } else if payload_len == 127 {
        let mut extended = [0; 8];
        reader.read_exact(&mut extended)?;
        payload_len = u64::from_be_bytes(extended);
    }
    if payload_len > MAX_FRAME_PAYLOAD_BYTES {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            format!("websocket frame payload is too large: {payload_len} bytes"),
        ));
    }

    let mask_key = if masked {
        let mut key = [0; 4];
        reader.read_exact(&mut key)?;
        Some(key)
    } else {
        None
    };

    let mut payload = vec![0; payload_len as usize];
    reader.read_exact(&mut payload)?;
    if let Some(mask_key) = mask_key {
        apply_mask(&mut payload, mask_key);
    }
    Ok(WebSocketFrame {
        fin,
        opcode,
        payload,
    })
}

fn write_frame(
    writer: &mut impl Write,
    opcode: u8,
    payload: &[u8],
    masked: bool,
) -> io::Result<()> {
    let mut header = Vec::with_capacity(14);
    header.push(0x80 | (opcode & 0x0f));
    let mask_bit = if masked { 0x80 } else { 0 };
    if payload.len() < 126 {
        header.push(mask_bit | payload.len() as u8);
    } else if u16::try_from(payload.len()).is_ok() {
        header.push(mask_bit | 126);
        header.extend_from_slice(&(payload.len() as u16).to_be_bytes());
    } else {
        header.push(mask_bit | 127);
        header.extend_from_slice(&(payload.len() as u64).to_be_bytes());
    }

    writer.write_all(&header)?;
    if masked {
        writer.write_all(&CLIENT_MASK_KEY)?;
        let mut masked_payload = payload.to_vec();
        apply_mask(&mut masked_payload, CLIENT_MASK_KEY);
        writer.write_all(&masked_payload)?;
    } else {
        writer.write_all(payload)?;
    }
    writer.flush()
}

fn apply_mask(payload: &mut [u8], mask_key: [u8; 4]) {
    for (index, byte) in payload.iter_mut().enumerate() {
        *byte ^= mask_key[index % mask_key.len()];
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn masked_client_frame_round_trips() {
        let mut encoded = Vec::new();
        write_frame(&mut encoded, OPCODE_TEXT, b"{\"id\":1}", true).expect("write frame");

        assert_ne!(encoded[1] & 0x80, 0);
        let frame = read_frame(&mut Cursor::new(encoded)).expect("read frame");
        assert_eq!(frame.opcode, OPCODE_TEXT);
        assert_eq!(frame.payload, b"{\"id\":1}");
    }

    #[test]
    fn extended_payload_frame_decodes() {
        let payload = vec![b'a'; 130];
        let mut encoded = Vec::new();
        write_frame(&mut encoded, OPCODE_TEXT, &payload, false).expect("write frame");

        assert_eq!(encoded[1], 126);
        let frame = read_frame(&mut Cursor::new(encoded)).expect("read frame");
        assert_eq!(frame.payload, payload);
    }

    #[test]
    fn websocket_upgrade_response_requires_101() {
        assert!(websocket_response_is_switching_protocols(
            b"HTTP/1.1 101 Switching Protocols\r\n\r\n"
        ));
        assert!(!websocket_response_is_switching_protocols(
            b"HTTP/1.1 200 OK\r\n\r\n"
        ));
    }
}
