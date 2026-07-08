# SadCoder Mobile

Flutter Android/iOS app for controlling Codex through a remote
`sadcoder-agent` over SSH.

Current M0 scope:

- Material 3 app shell with Hosts, Chat, Approvals, and Settings surfaces.
- JSON-RPC transport abstraction.
- Codex app-server client methods for `initialize`, `model/list`, and
  `thread/list`.
- Tests for the protocol client and app shell.

Run locally:

```powershell
flutter analyze
flutter test
```
