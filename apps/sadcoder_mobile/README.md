# SadCoder Mobile

Flutter Android/iOS app for controlling Codex through a remote
`sadcoder-agent` over SSH.

Current M0 scope:

- Material 3 app shell with Hosts, Chat, Approvals, and Settings surfaces.
- SSH profile and remote command runner abstractions.
- `dartssh2`-backed command runner for password/private-key auth.
- Remote agent status service for `sadcoder-agent status --json`.
- Remote slash command manifest service for `sadcoder-agent slash-commands --json`.
- JSON-RPC transport abstraction.
- Line-delimited JSON-RPC stream transport for app-server stdio.
- SSH proxy connector for `${agentCommand} proxy`.
- Codex app-server client methods for `initialize`, `model/list`, and
  `thread/list`.
- Built-in slash command registry aligned with the shared manifest, including
  aliases, task availability, side-conversation availability, and mapping phase.
- Tests for the protocol client and app shell.

Run locally:

```powershell
flutter analyze
flutter test
```
