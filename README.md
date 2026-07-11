# SadCoder

SadCoder is a cross-platform mobile controller for Codex running on remote
servers. The mobile app connects to a server over SSH, starts or attaches to a
thin server-side agent, and then communicates with Codex through the official
app-server JSON-RPC protocol.

The design source of truth is [Plan.md](Plan.md).

## Repository Layout

- `apps/sadcoder_mobile` - Flutter + Material 3 Android/iOS app.
- `crates/sadcoder-agent` - Rust server-side binary for status, lifecycle, and
  app-server proxy commands.
- `crates/sadcoder-protocol` - Rust protocol DTOs shared by the agent and tests.
- `resources` - shared manifests used by both the mobile app and agent.
- `refs` - ignored local reference projects for Codex and HappyCoder.

## M0 Local Probe

The first implementation milestone focuses on proving the app-server protocol
boundary without reimplementing Codex semantics.

```powershell
cargo run -p sadcoder-agent -- status --json
cargo run -p sadcoder-agent -- probe --json
cargo run -p sadcoder-agent -- slash-commands --json
```

`probe --json` starts `codex app-server --listen stdio://`, sends
`initialize`, acknowledges `initialized`, then calls `model/list` and
`thread/list`.

The mobile app has an SSH command runner abstraction and a `dartssh2`
implementation for invoking remote agent commands.

For interactive Codex sessions, the mobile app opens an SSH exec channel to:

```powershell
sadcoder-agent proxy
```

`start` launches a long-lived `sadcoder-agent service` when needed. The service
owns `codex app-server --listen unix://...`; `proxy` connects the SSH channel to
that local service socket and bridges the app's JSONL messages to app-server
WebSocket text frames. The service is spawned in a detached Unix session or
Windows process group with job breakaway, so closing the mobile SSH channel only
stops the proxy subscription, not the app-server process owned by the service.

Backend selection is controlled by `--backend` or `SADCODER_BACKEND`:

- `auto` uses the SadCoder service backend when it can be prepared and falls
  back to stdio when the service path is unavailable; it does not call the
  official Codex app-server daemon.
- `stdio` forces the direct stdio debug path; SSH disconnect can end that
  app-server process.
- `daemon` is accepted for compatibility, but falls back to stdio because
  npm/NVM Codex CLIs can expose daemon commands that still require the official
  standalone installer layout.

`status` is non-mutating: in `auto` mode it reports the SadCoder service
readiness and notes the stdio fallback path. `start --json` and `proxy` use the
actual selected backend, falling back to stdio if the service cannot be
prepared.

## Codex Command Configuration

The mobile app only needs to find `sadcoder-agent`. The agent is the source of
truth for the Codex executable, runtime PATH, and version diagnostics.

The agent resolves Codex in this order:

1. `--codex-path` / `--codex-program`
2. `SADCODER_CODEX_PATH`
3. persisted agent config
4. inherited `PATH`
5. automatic discovery of common install locations

Persist a Codex command with:

```powershell
sadcoder-agent configure --codex /home/me/.nvm/versions/node/v24.14.1/bin/codex --path-prepend /home/me/.nvm/versions/node/v24.14.1/bin --json
```

Wrapper arguments can be persisted with repeated `--codex-arg` flags:

```powershell
sadcoder-agent configure --codex /opt/codex-wrapper --codex-arg --profile --codex-arg mobile --path-prepend /opt/node/bin --json
```

The resulting config is structured, for example:

```json
{
  "codex": {
    "program": "/home/me/.nvm/versions/node/v24.14.1/bin/codex",
    "args": [],
    "pathPrepend": ["/home/me/.nvm/versions/node/v24.14.1/bin"]
  }
}
```

Config file locations:

- Linux/macOS: `~/.config/sadcoder/agent.json`
- Windows: `%LOCALAPPDATA%\SadCoder\agent.json`

`slash-commands --json` prints the shared slash command manifest from
`resources/slash_commands_manifest.json`. The manifest tracks the current Codex
TUI slash command surface, aliases, availability rules, implementation phase,
and SadCoder mapping strategy so `/...` input is handled as a command rather
than silently sent as a normal prompt.

## Verification

```powershell
cargo fmt --all -- --check
cargo test --workspace
cd apps\sadcoder_mobile
dart format lib test
flutter analyze
flutter test
```
