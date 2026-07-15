# Sad

[中文](README.md) | **English**

Sad is an API-first mobile client for Codex. The phone connects to a server over SSH, the server runs sadcoder-agent, and the agent owns the Codex app-server process while exposing a recoverable proxy connection.

## Quick Start

### Prepare The Server

The server needs:

- Linux, macOS, or Windows.
- An installed Codex CLI that the SSH user can execute.
- Rust stable to build sadcoder-agent from source.
- An SSH user that the phone can log in as.

Verify Codex first:

~~~powershell
codex --version
~~~

### Build And Install sadcoder-agent

From the repository root:

~~~powershell
cargo install --path crates/sadcoder-agent --locked
sadcoder-agent --help
~~~

You can also build without installing into the user directory:

~~~powershell
cargo build -p sadcoder-agent --release
~~~

The binary is written to:

- Linux/macOS: target/release/sadcoder-agent
- Windows: target/release/sadcoder-agent.exe

Make sure sadcoder-agent is on the SSH user's PATH. If Codex is not on the default PATH, persist its location:

~~~powershell
sadcoder-agent configure --codex /path/to/codex --path-prepend /path/to/node/bin --json
~~~

Windows example:

~~~powershell
sadcoder-agent configure --codex C:\Users\me\AppData\Roaming\npm\codex.cmd --json
~~~

### Enable The Server Service

Check Codex and the agent:

~~~powershell
sadcoder-agent doctor --json
sadcoder-agent status --json
~~~

Start the SadCoder service:

~~~powershell
sadcoder-agent start --json
~~~

start starts or reuses a long-lived sadcoder-agent service. The service owns the Codex app-server process, so closing the phone's SSH proxy channel does not directly terminate the server-side Codex task.

Check the service again:

~~~powershell
sadcoder-agent status --json
~~~

Stop the service:

~~~powershell
sadcoder-agent stop --json
~~~

Sad uses the auto backend in production. It connects only to the SadCoder service:

~~~powershell
$env:SADCODER_BACKEND = "auto"
sadcoder-agent start --json
~~~

Use direct stdio only for debugging or compatibility testing:

~~~powershell
$env:SADCODER_BACKEND = "stdio"
sadcoder-agent probe --json
~~~

### SSH Proxy

The Sad App opens an SSH exec channel and runs:

~~~powershell
sadcoder-agent proxy
~~~

You normally do not run proxy manually. After you add a server in the App, the App calls start --json and then opens the proxy channel.

## Using The App

### Install A Release APK

Download the APK matching the device ABI from the [Sad 1.0.0 Release](https://github.com/Labyrinth0419/SadCoder/releases/tag/v1.0.0):

- app-arm64-v8a-release.apk: most modern Android phones.
- app-armeabi-v7a-release.apk: 32-bit ARM devices.
- app-x86_64-release.apk: x86_64 Android emulators or devices.

After installation:

1. Add the server SSH address, port, username, and authentication details in Hosts.
2. Select the host and connect.
3. Open the session list, select a history session, or start a new conversation.
4. Send ordinary text turns from the chat composer.

Sad does not make account login the primary workflow. The main path is connecting to your own Codex server API.

## Build The App Locally

Install Flutter stable and the Android SDK, then run from the repository root:

~~~powershell
cd apps\sadcoder_mobile
flutter pub get
flutter analyze
flutter test
~~~

Build a debug APK:

~~~powershell
flutter build apk --debug
~~~

Build split-ABI release APKs:

~~~powershell
flutter build apk --release --split-per-abi
~~~

Outputs are written to:

~~~text
apps/sadcoder_mobile/build/app/outputs/flutter-apk/
~~~

The split build produces:

- app-arm64-v8a-release.apk
- app-armeabi-v7a-release.apk
- app-x86_64-release.apk

Build iOS:

~~~powershell
cd apps\sadcoder_mobile
flutter build ios --release
~~~

## Server Diagnostics

~~~powershell
sadcoder-agent status --json
sadcoder-agent doctor --json
sadcoder-agent probe --json
sadcoder-agent schema --json
sadcoder-agent logs --json
~~~

status and doctor are non-mutating. probe verifies Codex app-server initialization and core reads. schema generates or reads the app-server JSON Schema cache for the resolved Codex version.

## Configuration Paths

- Linux/macOS: ~/.config/sadcoder/agent.json
- Windows: %LOCALAPPDATA%\SadCoder\agent.json

Set SADCODER_STATE_PATH to choose the agent state and service cache directory.
