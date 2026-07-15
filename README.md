# Sad

**中文** | [English](README-en.md)

Sad 是一个 API-first 的 Codex 移动客户端。手机通过 SSH 连接服务端，服务端运行 sadcoder-agent，由它管理 Codex app-server 并提供可恢复的代理连接。

## 快速开始

### 服务端准备

服务端需要：

- Linux、macOS 或 Windows。
- 已安装并可执行的 Codex CLI。
- Rust stable，用于从源码构建 sadcoder-agent。
- 一个允许手机通过 SSH 登录的用户。

先确认 Codex 可用：

~~~powershell
codex --version
~~~

### 构建并安装 sadcoder-agent

在仓库根目录执行：

~~~powershell
cargo install --path crates/sadcoder-agent --locked
sadcoder-agent --help
~~~

如果不想安装到用户目录，也可以构建后直接使用：

~~~powershell
cargo build -p sadcoder-agent --release
~~~

生成位置：

- Linux/macOS：target/release/sadcoder-agent
- Windows：target/release/sadcoder-agent.exe

确保 sadcoder-agent 位于 SSH 登录用户的 PATH 中。若 Codex 不在默认 PATH，显式保存其路径：

~~~powershell
sadcoder-agent configure --codex /path/to/codex --path-prepend /path/to/node/bin --json
~~~

Windows 示例：

~~~powershell
sadcoder-agent configure --codex C:\Users\me\AppData\Roaming\npm\codex.cmd --json
~~~

### 启用服务端 service

检查 Codex 和 agent：

~~~powershell
sadcoder-agent doctor --json
sadcoder-agent status --json
~~~

启动 SadCoder service：

~~~powershell
sadcoder-agent start --json
~~~

start 会启动或复用长期运行的 sadcoder-agent service，由 service 持有 Codex app-server。手机 SSH 断开后，服务端的 Codex 任务不会因为 proxy channel 关闭而被直接终止。

再次检查运行状态：

~~~powershell
sadcoder-agent status --json
~~~

停止 service：

~~~powershell
sadcoder-agent stop --json
~~~

Sad 的生产默认 backend 是 auto，只连接 SadCoder service：

~~~powershell
$env:SADCODER_BACKEND = "auto"
sadcoder-agent start --json
~~~

只有调试或兼容旧环境时才显式使用 direct stdio：

~~~powershell
$env:SADCODER_BACKEND = "stdio"
sadcoder-agent probe --json
~~~

### SSH proxy

Sad App 会在 SSH exec channel 中执行：

~~~powershell
sadcoder-agent proxy
~~~

一般不需要手动执行 proxy。在 App 中添加服务端 SSH 主机后，App 会先调用 start --json，再打开 proxy 通道。

## 使用 App

### 使用发布版 APK

从 [Sad 1.0.0 Release](https://github.com/Labyrinth0419/SadCoder/releases/tag/v1.0.0) 下载与设备 ABI 对应的 APK：

- app-arm64-v8a-release.apk：绝大多数现代 Android 手机。
- app-armeabi-v7a-release.apk：32 位 ARM 设备。
- app-x86_64-release.apk：x86_64 Android 模拟器或设备。

安装后：

1. 在 Hosts 中添加服务端 SSH 地址、端口、用户名和认证信息。
2. 选择该主机并连接。
3. 打开会话列表，选择历史 session，或点击新建对话。
4. 在对话区发送普通文本 turn。

Sad 不要求把登录作为主要流程；核心使用方式是连接你自己的 Codex 服务端 API。

## 本地构建 App

准备 Flutter stable 和 Android SDK 后，在仓库根目录执行：

~~~powershell
cd apps\sadcoder_mobile
flutter pub get
flutter analyze
flutter test
~~~

构建 debug APK：

~~~powershell
flutter build apk --debug
~~~

构建 split-ABI release APK：

~~~powershell
flutter build apk --release --split-per-abi
~~~

输出目录：

~~~text
apps/sadcoder_mobile/build/app/outputs/flutter-apk/
~~~

生成：

- app-arm64-v8a-release.apk
- app-armeabi-v7a-release.apk
- app-x86_64-release.apk

构建 iOS：

~~~powershell
cd apps\sadcoder_mobile
flutter build ios --release
~~~

## 服务端诊断

~~~powershell
sadcoder-agent status --json
sadcoder-agent doctor --json
sadcoder-agent probe --json
sadcoder-agent schema --json
sadcoder-agent logs --json
~~~

status 和 doctor 不修改服务端状态。probe 会验证 Codex app-server 的初始化和核心读取能力。schema 生成或读取当前 Codex 版本的 app-server JSON Schema 缓存。

## 配置位置

- Linux/macOS：~/.config/sadcoder/agent.json
- Windows：%LOCALAPPDATA%\SadCoder\agent.json

可通过 SADCODER_STATE_PATH 指定 agent 状态和 service 缓存目录。
