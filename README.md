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

`proxy` starts `codex app-server --listen stdio://` on the server and forwards
line-delimited JSON-RPC between the app and Codex. This keeps Codex execution on
the server side instead of tying task lifetime to the mobile process.

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
