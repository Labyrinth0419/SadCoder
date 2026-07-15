# 技术栈与系统架构

## 3. 技术栈选择

### 3.1 推荐客户端技术栈

App 端推荐：

- Flutter
- Material 3
- Dart `json_serializable` / `freezed`
- `drift` 或 `sqlite3` 做本地缓存
- `flutter_secure_storage` / Keychain / Android Keystore 做敏感信息存储
- `dartssh2` 作为 SSH 库

理由：

- 需要同时兼顾 Android 和 iOS，Flutter 的跨平台移动端成熟度、构建链、Material 3、深色模式、i18n、列表性能和包生态更直接。
- iOS 不是首要商店发布目标，用户自行编译安装即可；Flutter 对这种模式足够简单。
- React Native/Expo 可以参考 Happy 的产品形态，但 SSH 长连接和原生后台限制会更依赖 native module。
- Tauri mobile 可作为长期备选，但 MVP 会更容易陷入 Rust/WebView/移动端插件三套边界。

通信核心保持在 Dart/Flutter 边界内；只有出现可测量的复杂度或性能瓶颈时才评估 Rust 抽取，相关条件性工作见 [TODO](../TODO.md#p2-条件性增强)。

### 3.2 推荐服务端技术栈

服务端推荐新增一个跨平台 Rust 二进制：

```sh
sadcoder-agent install
sadcoder-agent service
sadcoder-agent status --json
sadcoder-agent start --json
sadcoder-agent stop --json
sadcoder-agent proxy
```

`sadcoder-agent` 的职责：

- 在 Linux 和 Windows 上统一管理 Codex app-server 生命周期。
- 解析结构化 Codex 启动配置，执行版本/运行时诊断，返回登录状态、配置路径、平台能力。
- 启动并持有 `codex app-server`，避免移动端 SSH 断开时直接杀掉 Codex。
- 对移动端暴露稳定的 stdio proxy：App 通过 SSH 执行 `sadcoder-agent proxy`，后续发 app-server JSON-RPC。
- 缓冲关键事件和 pending approval，支持移动端断线后恢复。
- 提供 `agent/*` 命名空间用于健康检查、安装诊断、日志、服务重启。

平台实现：

- Linux：`sadcoder-agent service` 独立于 SSH channel 启动并长期持有 `codex app-server --listen unix://...`；`proxy` 在 `auto` 模式只连接 service socket，direct stdio 仅作为显式调试/兼容 backend。
- Windows：`sadcoder-agent service` 使用用户级后台进程/计划任务等方式管理 `codex app-server` 子进程，并通过 named pipe 或 localhost control channel 给 `proxy` 连接。

这比完全依赖官方 daemon 多一个 SadCoder 二进制，但换来 Windows/Linux 一致的保活、诊断、重连和能力探测。Codex 本体仍然不 fork，仍然安装官方 `codex`，但 Codex 路径、Node/PATH 运行时和版本检测都由 agent 统一解析。

## 4. 推荐架构

### 4.1 生产模式：sadcoder-agent over SSH

启动流程：

1. App 读取用户配置的 SSH profile。
2. 建立 SSH 连接并完成 host key 校验。
3. 检查远端 shell 可以执行非交互命令。
4. 执行 `sadcoder-agent status --json`，从 agent status 获取 Codex path、availability、version、backend 状态。
5. 如 service 未运行，执行 `sadcoder-agent start`；若 start 失败，生产 `auto` 流程必须返回结构化错误，不能隐式降级到 direct stdio。
6. 新开一个 SSH exec channel，执行 `sadcoder-agent proxy`。
7. App 在该 channel 上发送 app-server JSON-RPC；agent 在 `auto` 模式连接本地 service socket，并做 id 重写、转发、事件缓存和恢复；只有显式 debug/compat backend 才直连 stdio app-server。
8. App 发送 `initialize`，随后发送 `initialized` notification。
9. 后续 Codex 功能都优先走 app-server JSON-RPC；agent 自身能力走 `agent/*` RPC。

数据流：

```text
Compose UI
  -> ViewModel / Store
  -> SadCoder Codex Client
  -> JSON-RPC dispatcher
  -> JSONL / stream codec
  -> SSH exec channel: sadcoder-agent proxy
  -> sadcoder-agent service
  -> codex app-server backend
```

优点：

- 手机断线不会直接杀掉 agent-managed app-server。
- 可以重连后重新 `initialize`，再 `thread/resume` 或 `thread/read` 回填状态。
- Linux/Windows 使用一致的 SadCoder service 生命周期，不需要 App 理解 Codex、Node、PATH 或 shell profile 差异。
- App 不需要为 Windows/Linux 分别理解不同 Codex 启动细节。

限制：

- 需要维护一个 `sadcoder-agent` 二进制。
- agent 需要实现 JSON-RPC 代理、事件缓存、审批转发和服务安装。
- Windows 服务安装方式要尽量支持非管理员路径，必要时用用户级计划任务。

### 4.2 调试模式：直接 stdio

调试/兜底流程：

```sh
codex app-server --listen stdio://
```

App 通过 SSH exec channel 的 stdin/stdout 直接收发 newline-delimited JSON。

优点：

- 实现最简单。
- 适合本地验证 JSON-RPC、事件映射和 UI。
- 当 agent/daemon 不可用时可临时使用。

缺点：

- SSH channel 断开通常会终止 app-server。
- 不适合长任务、弱网、后台运行。
- 不满足“手机断线不影响任务继续执行”的硬约束，不允许作为生产默认模式。

### 4.3 统一 service backend 与 direct stdio fallback

生产默认 backend 是 SadCoder 自己的 service：

```sh
sadcoder-agent start
sadcoder-agent proxy
```

`sadcoder-agent start` 负责启动或复用长期 service；service 再启动并持有 `codex app-server --listen unix://...` 或平台等价本地监听。`sadcoder-agent configure` 负责持久化 Codex program、args 和 PATH prepend，供后续 `status` / `doctor` / `start` / `proxy` 统一复用同一份解析结果。`sadcoder-agent proxy` 只连接本地 service socket，因此手机 SSH channel 断开不会终止 app-server。

direct stdio fallback 只用于显式调试或兼容 backend：

```sh
codex app-server --listen stdio://
```

fallback 不满足“手机断线不影响任务继续执行”的生产硬约束，UI 必须明确标识风险，`--backend auto` 不得在 service 启动或 proxy 失败时静默退到 fallback。官方 `codex app-server daemon/proxy` 不作为 SadCoder 生产依赖，避免 npm/NVM CLI 与 standalone daemon 路径要求不一致。

fallback 的前置条件是 agent 已经用同一个 `ResolvedCodexCommand` 成功完成 Codex 版本/运行时 probe；如果 Codex 程序缺失、Node 运行时错误、权限错误或版本输出异常，`auto` 只能返回 unavailable 诊断，不能把 direct stdio 标成可用后端。

自动发现 common install locations 时，agent 只能缓存已经通过同一套 `ResolvedCodexCommand` 版本/运行时 probe 的候选项；坏的 `codex` wrapper、错误 Node 运行时或非 Codex 同名程序必须被跳过，不能写入持久化配置。

### 4.4 Agent 内部设计

```text
Android/iOS App -> SSH -> sadcoder-agent proxy -> sadcoder-agent service -> codex app-server
```

agent 负责：

- 启动/重启 app-server。
- 代理 app-server JSON-RPC。
- 管理 keepalive、日志、版本、安装状态。
- 缓冲最近事件，记录最后 delivered cursor。
- 管理 pending approval；移动端断开时默认无限期等待用户重连后决策，不自动拒绝、不自动取消、不触发 `turn/interrupt`。
- 提供 `agent/health`、`agent/logs`、`agent/restartBackend`、`agent/stopBackend` 等额外 RPC；`agent/logs` 返回 service/app-server 日志的有界尾部内容，App 设置诊断页可读取展示。受控 Codex 安装自动化尚未进入该边界，见 [TODO](../TODO.md#p1-协议与后端)。
