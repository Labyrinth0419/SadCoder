# SadCoder 跨平台移动 App 设计计划

## 0. 目标摘要

SadCoder 的目标不是在手机上“模拟一个终端”，而是让移动 App 通过 SSH 直连服务器，并以结构化协议监管服务器上的 Codex：能查看会话、发送消息、接收流式事件、处理审批、管理线程、执行命令、调整配置，并尽量覆盖 Codex CLI 暴露的能力。

推荐方向：

1. App 端兼顾 Android 和 iOS；Android 是主要发布目标，iOS 用户可以自行编译安装。
2. 服务端兼顾 Linux 和 Windows；为跨平台保活与生命周期管理，引入 `sadcoder-agent` 作为轻量 Rust 常驻层。
3. Codex 业务协议仍以官方 `app-server` JSON-RPC 为核心；`sadcoder-agent` 负责启动、持有、代理和恢复 app-server 连接。
4. Linux/Windows 统一由 `sadcoder-agent service` 管理长期 app-server；direct stdio 只作为显式调试/兼容 backend，不作为 `auto` 隐式降级，不依赖官方 standalone daemon。
5. SSH 只做认证、加密、远程命令启动和字节传输，不做业务协议。

一句话架构：

```text
Android/iOS App
  -> SSH auth / exec channel
  -> sadcoder-agent proxy
  -> sadcoder-agent service
  -> Codex app-server JSON-RPC
  -> Codex core / tools / MCP / filesystem / shell
```

## 1. 参考项目结论

### 1.1 Codex 项目结论

`refs/codex` 中最关键的接口是 `codex app-server`：

- 它是 Codex VS Code/桌面等富客户端使用的接口。
- 协议是 JSON-RPC 2.0，支持 stdio、Unix socket、WebSocket 等传输。
- 核心模型是 `Thread -> Turn -> Item`。
- 覆盖会话、流式输出、审批、文件、命令、模型、账号、配置、MCP、插件、技能、Hook、Review、Goal、历史、归档、删除等能力。
- 它可以生成 TypeScript/JSON Schema：`codex app-server generate-ts` 与 `generate-json-schema`，适合客户端按 Codex 版本做能力适配。
- `codex app-server daemon/proxy` 是官方 Unix-only 生命周期管理层，但 npm/NVM 版 CLI 可能暴露命令却要求 installer-managed standalone 路径；SadCoder 不把它作为生产依赖。
- SadCoder 生产路径改为 `sadcoder-agent service/proxy`：service 长期持有 `codex app-server --listen unix://...`，proxy 只连接本地 service socket；官方 daemon 仅作为兼容/诊断背景。
- TUI 斜杠命令集中定义在 `refs/codex/codex-rs/tui/src/slash_command.rs`，包含命令名、别名、描述、是否支持 inline args、active turn 中是否可用、平台/调试可见性等规则；SadCoder 需要把这些规则转成移动端命令面板和结构化调用。

因此，第一性原理上不应该抓取 TUI 屏幕或模拟按键，也不应该先自造一套 Codex 协议。最稳的语义边界是 app-server。

### 1.2 HappyCoder 项目结论

`refs/happy` 提供了几个有价值的参考：

- Happy 的 Codex 集成也是手写 app-server JSON-RPC 客户端，而不是单纯 wrap `codex exec`。
- 它把 Codex app-server 事件转换成移动端 UI 能消费的会话事件。
- 它处理了移动端常见问题：保活、重连、审批、权限模式、模型/effort 覆盖、附件、后台 session、daemon、fork/duplicate。
- Happy 的主架构依赖云端同步服务器和端到端加密消息流；本项目主要目标是移动 App 通过 SSH 直连服务器，所以不引入 Happy Server 这种云中转。
- Happy 的 `sessionProtocol.ts` 自身标记为 under review，不建议直接复制其 wire protocol。我们只参考事件建模和 UI 映射思路。

### 1.3 对本项目的直接影响

- Codex 的 app-server 是主协议。
- 移动 App 应该渲染 app-server 的结构化 item/event，而不是渲染 ANSI 终端。
- 移动端断线不能杀掉服务器上的 Codex，因此生产模式必须有服务端常驻层；Linux/Windows 都由 `sadcoder-agent service` 持有 Codex app-server 子进程。
- Happy 的“移动端 session state + event mapper + approval handler”值得借鉴，但通信路径要改成 SSH 直连。

## 2. 第一性原理

1. Codex 真正的工作发生在服务器上，状态也应保留在服务器的 `CODEX_HOME` 与项目工作区中。
2. 手机只是控制面，不应该持有项目代码、不应该替服务器做模型请求、不应该复制 Codex 状态。
3. SSH 是认证、加密、穿透内网与命令启动机制，不是业务协议。
4. Codex app-server 是业务协议，所有可结构化表达的功能都应先尝试走 app-server。
5. 对长期任务，连接与任务生命周期必须解耦：手机断网可以丢失订阅，但不应终止服务器上的 turn。
6. 对安全敏感操作，审批必须结构化显示：命令、cwd、diff、MCP tool、原因、权限范围都要可读。
7. MVP 仍然少造业务协议轮子：Codex 语义直接复用官方 app-server；自研部分只做跨平台生命周期、代理、保活和恢复。

### 2.1 任务生命周期硬约束

SadCoder 必须遵守一个最重要的不变量：手机连接状态不能决定 Codex 任务是否继续执行。

- 手机断网、App 退后台、SSH channel 断开、agent proxy 断开，都不能触发 `turn/interrupt`。
- 手机断开时，`sadcoder-agent` 必须继续持有或恢复 Codex app-server backend，保持当前 thread/turn 在服务器侧运行。
- 只有用户在 App 中明确点击“中断/停止本轮”，并由 App 发出 `turn/interrupt` 或等价 agent RPC 时，SadCoder 才主动中止 Codex 当前 turn。
- 如果 Codex 自身因为模型错误、命令错误、权限错误、服务器崩溃、进程退出等原因失败，那是 Codex/backend 故障，不属于手机断线导致的中止。
- 如果任务运行到审批点而手机不在线，默认行为是保持审批 pending，让任务等待用户重连后决策；不能因为手机断开自动拒绝、自动取消或自动 interrupt。
- agent 可以记录“任务等待手机审批”的状态并发出本地通知/下次打开 App 提示，但不应擅自替用户作出终止性决策。

## 3. 技术栈选择

### 3.1 推荐客户端技术栈

App 端推荐：

- Flutter
- Material 3
- Dart `json_serializable` / `freezed`
- `drift` 或 `sqlite3` 做本地缓存
- `flutter_secure_storage` / Keychain / Android Keystore 做敏感信息存储
- `dartssh2` 作为 SSH 库候选

理由：

- 需要同时兼顾 Android 和 iOS，Flutter 的跨平台移动端成熟度、构建链、Material 3、深色模式、i18n、列表性能和包生态更直接。
- iOS 不是首要商店发布目标，用户自行编译安装即可；Flutter 对这种模式足够简单。
- React Native/Expo 可以参考 Happy 的产品形态，但 SSH 长连接和原生后台限制会更依赖 native module。
- Tauri mobile 可作为长期备选，但 MVP 会更容易陷入 Rust/WebView/移动端插件三套边界。

可选后续：

- 如果 Dart 侧 SSH、agent stream codec、加密存储或后台连接复杂度过高，把通信核心抽成 Rust crate，通过 `flutter_rust_bridge` 暴露给 Flutter。
- 若未来要桌面端，可以复用同一个 Rust 通信核心，再另做桌面 UI。

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
- 提供 `agent/health`、`agent/logs`、`agent/restartBackend`、`agent/stopBackend` 等额外 RPC；`agent/logs` 返回 service/app-server 日志的有界尾部内容，App 设置诊断页可读取展示，`agent/installCodex` 留作后续安装自动化。

## 5. 协议设计

### 5.1 Agent 与 app-server 初始化

通过 SSH 执行 `sadcoder-agent proxy` 后，App 可以先发送 `agent/hello` 或在 proxy 前通过 `sadcoder-agent status --json` 完成健康检查。agent ready 后，进入 Codex app-server 初始化。app-server 初始化消息固定为：

```json
{
  "method": "initialize",
  "id": 1,
  "params": {
    "clientInfo": {
      "name": "sadcoder_mobile",
      "title": "SadCoder Mobile",
      "version": "0.1.0"
    },
    "capabilities": {
      "experimentalApi": true,
      "mcpServerOpenaiFormElicitation": true
    }
  }
}
```

随后发送：

```json
{ "method": "initialized" }
```

客户端必须支持三类入站消息：

1. Response：带 `id`，对应 App 发出的 request。
2. Notification：无 `id`，例如 `thread/started`、`turn/started`、`item/*`。
3. Server request：带 `id` 和 `method`，例如审批请求、MCP form elicitation、current time request。客户端必须回复，否则 app-server 可能等待。

### 5.2 JSON-RPC dispatcher

客户端内部需要一个通用 dispatcher：

- `sendRequest(method, params): Deferred<Result>`
- `sendNotification(method, params)`
- `respond(id, result)`
- `onNotification(method, params)`
- `onServerRequest(id, method, params)`

所有 Codex 方法都通过通用 dispatcher 支持，避免客户端版本落后时无法调用新方法。UI 层可以先实现常用功能，开发者/高级界面保留“原始 RPC 调用”能力。

- 已在 `CodexAppServerClient` 暴露低层 `requestRaw`，允许传入非空 method 与 object params 直通同一 JSON-RPC request path；协议测试覆盖未知 app-server 方法转发和空 method 拒绝。该能力已通过 `CodexSessionStateController.requestRaw` 接到 Chat 高级折叠区的 Raw RPC 面板：默认不出现在主对话面，展开后仍需用户勾选确认，params 只接受 JSON object，不走 SSH command fallback。
- 已接入 `currentTime/read` server request 的自动响应：`CodexAppSession` 组装独立的 `ServerRequestAutoResponder`，返回 `currentTimeAt` Unix 秒；该方法不会进入 approval state，也不会在重连 snapshot 回填时显示为未知审批。
- 已对当前移动端明确不支持的已知 app-server server request 返回显式 JSON-RPC error，而不是长期挂成未知审批：`item/tool/call`、`account/chatgptAuthTokens/refresh`、`attestation/generate`、legacy `applyPatchApproval` 和 legacy `execCommandApproval` 由 `ServerRequestAutoResponder` 统一拒绝，approval coordinator 和 reconnect snapshot 过滤共用同一方法清单；未知未来 request 仍按通用只读审批显示。

### 5.3 事件映射

不要直接把 app-server 原始 JSON 塞给 UI。需要映射为 UI 状态：

- `ThreadState`
- `TurnState`
- `ItemState`
- `ApprovalRequestState`
- `TokenUsageState`
- `ConnectionState`
- `AgentState`

但原始 JSON 要保留在本地日志中，用于兼容未知 item 类型和调试。

关键事件：

- `thread/started`
- `thread/status/changed`
- `thread/closed`
- `turn/started`
- `turn/completed`
- `thread/tokenUsage/updated`
- `item/started`
- `item/agentMessage/delta`
- `item/reasoning/delta`
- `item/commandExecution/outputDelta`
- `item/completed`
- `serverRequest/resolved`
- `account/updated`
- `account/rateLimits/updated`
- `mcpServer/startupStatus/updated`

当前实现状态：

- 已落地移动端 `CodexEvent` typed mapper：thread/turn/item/chat delta、reasoning、file change、MCP progress、auto-review、`thread/tokenUsage/updated`、`account/updated`、`account/rateLimits/updated` 和 `mcpServer/startupStatus/updated` 均映射为明确 `CodexEventKind`；状态类通知保留结构化 `payload` 和原始 raw JSON，默认不进入 Chat timeline。`AccountSnapshotController` 已支持 `account/updated` 稀疏 payload 的非破坏性合并，AppShell 已订阅 active session event stream 并把 auth mode / plan type 更新接入 account snapshot state；`AccountUsageSnapshotController` 已支持 `account/rateLimits/updated` 稀疏 payload 的非破坏性合并，AppShell 已把 rate-limit 更新接入 account usage state；`McpServerStatusController` 已支持 `mcpServer/startupStatus/updated` 单 server startup 状态合并并在 `/mcp` 摘要展示；`ThreadTokenUsageController` 已接入 `thread/tokenUsage/updated`，并在 `/status` 与 `/usage` 摘要展示当前/最近会话 token 用量，不进入 Chat timeline。

### 5.4 审批请求

必须支持：

- `item/commandExecution/requestApproval`
- `item/fileChange/requestApproval`
- `mcpServer/elicitation/request`
- 后续 app-server 新增的 server request 类型以通用方式显示。

审批 UI 要展示：

- 类型：命令、文件修改、MCP、表单。
- command / cwd / reason。
- diff 或 fileChanges。
- MCP server、tool name、input。
- 决策：允许一次、允许本 session、拒绝、取消 turn。

决策映射：

- approve once -> `accept`
- approve session -> `acceptForSession`
- deny -> `decline`
- cancel/abort -> `cancel`

断线期间的审批语义：

- agent 收到 app-server 发起的 server request 后，如果手机在线，就转发给 App。
- 如果手机离线，agent 保持该 server request pending，并把审批请求持久化到本地状态。
- App 重连后先拉取 pending approvals，再由用户选择允许、拒绝或取消 turn。
- agent 不允许因为 App 离线、SSH 断开、App 后台、代理连接超时而自动返回 `decline` 或 `cancel`。
- 只有用户明确选择“取消本轮/中断任务”时，才映射为 `cancel` 或 `turn/interrupt`。

当前实现状态：

- 已支持未知 app-server server request 的保守通用表示：`ApprovalCoordinator` 将未知 method 映射为 `PendingApprovalKind.unknown` 并保留 raw params；Approvals 页面展示 request id、thread、method、reason 和非标准参数 key 摘要，但不直接渲染未知 payload 值、不提供批准/拒绝按钮，避免客户端版本落后时丢失 pending request 或误发错误响应。
- 已补强 Approvals 页面权限范围展示：command approval 的 `additionalPermissions` 与 permissions approval 的 `permissions` 会显示顶层/次级权限 scope 摘要（例如 `fileSystem.write, network.enabled`），不直接渲染深层未知 payload 值。

### 5.5 能力探测与版本兼容

每次连接后执行：

1. `sadcoder-agent status --json`
2. 从 `AgentStatus` 读取 `codexPath`、`codexAvailable`、`codexVersion`、`backend`，Codex 版本检测不由 App 另跑一套 `codex --version`。
3. agent backend 探测：SadCoder service / direct stdio fallback / 平台本地监听状态。
4. `initialize`
5. `model/list`
6. `config/read`
7. `account/read`
8. 可选：通过 `sadcoder-agent schema --json` 或 `agent/schema` 生成/读取服务器 app-server JSON Schema cache；App 设置诊断页展示缓存模式、Codex 版本、digest、bundle/cache 路径和文件摘要，且不直接依赖交互式 shell 环境，也不自行执行 `codex`。

客户端内置一个“最低支持 Codex 版本”，低于该版本只允许 stdio 调试或提示升级。

对 app-server 的 experimental API：

- 默认初始化时开启 `experimentalApi: true`。
- UI 对 experimental 功能加标识。
- 对未知 method/item 不崩溃，保留 raw event。
- 模型选择与覆盖必须从 `model/list` 读取服务器实际 catalog，不能在 App 内硬编码 GPT-5.x 名称；解析层同时兼容 app-server v2 的 camelCase 字段与 Codex 远程 catalog/cache 的 snake_case 字段，例如 GPT-5.6 Sol/Terra/Luna 的 `default_reasoning_level`、`supported_reasoning_levels`、`service_tiers` 和 `availability_nux`。
- 已补强移动端 model catalog 解析：`supportedReasoningEfforts` / `supported_reasoning_levels` 和 `serviceTiers` / `service_tiers` 同时支持对象数组与紧凑字符串数组，避免不同 Codex 版本或缓存来源把 reasoning/service tier 能力信息丢失。
- 已将 model catalog 能力摘要接入 Settings 模型列表：每个可见模型除 label/default/provider 外，可显示 reasoning levels（含默认值）、service tiers（含默认值）和 availability announcement，避免 `model/list` 返回的能力信息只停留在解析层。
- 已将同一 model catalog 能力摘要接入 Chat `/model` 选择器：下拉菜单展开时显示 reasoning/service tier/announcement，选中态仍保持单行模型 label，避免影响输入区密度。
- 已将 model catalog 能力摘要中的默认值片段资源化，英文显示 `default: ...`，中文显示 `默认：...`，避免 UI helper 内硬编码可见文案。

### 5.6 Codex 配置策略

默认原则：服务器上的 Codex 配置是权威默认值。SadCoder 不复制、不重建、不默认覆盖服务器 `CODEX_HOME/config.toml`、项目级配置、profile、MCP、插件、技能、权限 profile、模型 provider 或登录状态。

配置读取：

- 连接后通过 `config/read` 读取服务器当前有效配置，用于展示和诊断。
- 通过 `model/list`、`permissionProfile/list`、`mcpServerStatus/list` 等接口读取服务器实际可用能力。
- App 本地只缓存“展示快照”和“用户显式覆盖偏好”，不能把本地缓存当作服务器真实配置。

覆盖层级从低到高：

1. 服务器 Codex 配置：默认来源，包括 `config.toml`、profile、项目配置、环境变量、MCP、插件、登录凭据等。
2. SadCoder App 默认覆盖：用户在 App 设置中选择的默认 model、effort、approval policy、sandbox/permission profile、cwd 等；只在 SadCoder 发起 thread/turn 时作为参数传入。
3. 当前会话覆盖：用户在某个 thread/session 中设置的覆盖，后续 turns 默认继承，直到用户清除或切换。
4. 本次对话/本次 turn 覆盖：发送消息时临时选择的 model、effort、approval policy、sandbox/permission profile、cwd、developer instructions 等，只影响这一次 `turn/start`。

覆盖规则：

- 未显式设置的字段必须省略或传 `null`，让 app-server 使用服务器配置解析结果。
- 显式覆盖应尽量通过 `thread/start`、`thread/resume`、`turn/start`、`thread/settings/update` 等请求参数表达，而不是直接改写服务器配置文件。
- App 设置里的覆盖默认不落盘到服务器 Codex 配置；只保存在手机本地或 SadCoder 自己的 profile 中。
- 只有用户进入“服务器 Codex 配置编辑”并明确确认时，才允许调用 `config/value/write` 或 `config/batchWrite` 修改服务器配置。
- 修改服务器配置前必须展示 diff/摘要，并提示这会影响服务器上所有 Codex 客户端，而不只是 SadCoder。
- App 必须提供“清除本次覆盖”“清除会话覆盖”“恢复服务器默认配置”的入口。
- `thread/settings/update` 的清理语义必须按字段处理：当前上游只有 `serviceTier` 这种 double-option 字段能用显式 `null` 清除；普通 `Option<T>` 字段的 `null` 与省略等价，不能被 App 当作“恢复服务器默认”。对这些字段，App 需要发送已知 baseline 值、保留为本地覆盖语义，或等待上游提供显式清除能力。

典型覆盖项：

- model / model provider
- reasoning effort / reasoning summary
- approval policy
- sandbox policy 或 permission profile
- cwd / runtime workspace roots
- personality / collaboration mode
- web search、MCP、plugin、skill 相关选择
- developer instructions / append instructions

不建议由 App 默认覆盖：

- OpenAI/ChatGPT 登录凭据
- MCP server 全局配置
- plugin marketplace 全局配置
- managed requirements / 企业管控策略
- `CODEX_HOME` 路径
- 服务器环境变量与 shell profile

UI 必须清楚标识每个生效值来自哪里：`服务器默认`、`App 默认覆盖`、`本会话覆盖`、`本次覆盖`。

### 5.7 斜杠命令覆盖策略

新增硬要求：Codex TUI 的所有斜杠命令功能都必须在 SadCoder 中被涵盖实现。

这不意味着所有命令都在 MVP 一次性做成完整图形界面；但每个命令必须有明确状态：已结构化支持、UI-only 支持、agent/SSH fallback 支持、暂不适用但可解释、或因 Codex 版本/平台不可用而隐藏。不能出现用户输入 `/xxx` 后被静默当作普通 prompt 发给模型的情况。

设计原则：

- 斜杠命令是命令，不是普通聊天文本。输入框以 `/` 开头时进入命令解析流程，除非用户明确选择“作为普通文本发送”。
- App 内置 `SlashCommandRegistry`，字段包括：command、aliases、description、supportsInlineArgs、availableDuringTask、availableInSideConversation、platformVisibility、featureFlag、mappingType、mappingTarget、phase、riskLevel。
- `sadcoder-agent` 暴露 `agent/slashCommands/list`，返回当前 Codex 版本对应的 manifest。MVP 可以先由 SadCoder 根据 Codex 源码版本维护 manifest；后续若 Codex app-server 暴露官方 slash manifest，则切到官方来源。
- App 启动时比较 `AgentStatus.codexVersion`、app-server schema 和本地 manifest 版本。发现未知斜杠命令时，在高级面板显示“当前 App 未识别”，允许 raw RPC/SSH fallback，但不静默吞掉。
- inline args 命令必须提供参数解析或表单：`/review`、`/rename`、`/plan`、`/goal`、`/ide`、`/keymap`、`/mcp`、`/raw`、`/usage`、`/pets`、`/side`、`/btw`、`/resume`、`/sandbox-add-read-dir`。
- 命令可用性必须跟随 active turn 状态。Codex 标记为 active task 不可用的命令，App 禁用或提示原因，不能通过隐式 interrupt 绕过。
- 断线生命周期约束同样适用于斜杠命令：`/quit`、`/exit` 只关闭 App/当前代理连接，不停止服务器任务；`/stop` 只对应后台 terminal/process 停止语义，不等价于 `turn/interrupt`；只有用户明确点击“中断/停止本轮”才发送 `turn/interrupt`。
- 平台差异要显式展示：例如 `/sandbox-add-read-dir` 是 Windows sandbox 辅助能力，`/app` 在移动端通常只能显示“不适用/打开 Codex Desktop 不可用”，debug-only 命令只在开发构建出现。

执行映射分四类：

1. app-server 原生映射：优先走官方 JSON-RPC，例如 thread、turn、review、goal、account、model、config、MCP、plugin、skill、usage、feedback、background terminal/process 等接口。
2. SadCoder UI-only：移动端本地体验，例如复制、raw view、主题、状态栏、标题、keymap、vim 输入模式、退出当前界面等。
3. agent/SSH fallback：app-server 暂无结构化接口时，由 `sadcoder-agent` 执行等价 CLI 或服务器脚本，并把结果结构化返回。
4. 会话拓扑扩展：`/side`、`/btw`、`/agent`、`/subagents` 需要在 UI 中表示 fork、临时侧聊、多 agent thread 或子 agent 关系。MVP 只做命令面板和明确禁用/实验提示；第二阶段优先实现 `/side`、`/btw` 的临时侧聊；第三阶段实现 `/agent`、`/subagents` 的多 agent thread 浏览与切换。

会话拓扑分期判断：

- `/side`、`/btw` 难度为中等。Codex app-server 已有 `thread/fork` 的 `ephemeral: true` 支持，TUI 也是基于 ephemeral fork 加隐藏 boundary prompt 实现。SadCoder 的主要工作是移动端状态机：主线和侧聊并存、side 不污染 main、审批归属、返回主线、断线后合理降级。
- `/side`、`/btw` 的第二阶段目标是“最小可用”：创建 ephemeral fork，注入 side boundary prompt，进入 side UI，允许返回 main thread；side 中禁用不适合的斜杠命令；side 不能因为切换或断线触发 main thread 的 `turn/interrupt`。
- `/side`、`/btw` 的限制需要明确：ephemeral side thread 不承诺像普通持久 thread 一样长期保留；断线重连后能恢复则恢复，不能恢复时要提示用户该 side 已丢失，但不能影响 main thread。
- `/agent`、`/subagents` 难度为高。它们不是“新建 agent”的按钮，而是对 Codex multi-agent/subagent thread 树的浏览、状态归因和切换。需要处理 `parentThreadId`、`ancestorThreadId`、`agentNickname`、`agentRole`、`CollabAgentToolCall`、`SubAgentActivity`、running/closed/error 状态，以及多 thread 的事件回填。
- `/agent`、`/subagents` 不进入 MVP，也不和 `/side` 同期强做完整控制。第三阶段先做只读拓扑和切换查看，再评估是否支持 send/wait/close/resume 等主动控制能力。

当前 Codex 斜杠命令覆盖矩阵：

| 命令 | 覆盖方式 | 阶段/备注 |
| --- | --- | --- |
| `/model` | `model/list` + thread/session/turn 覆盖 | MVP |
| `/permissions` | `permissionProfile/list` + approval/sandbox 覆盖 | MVP |
| `/personality` | 配置读取 + thread/session/turn 覆盖 | MVP |
| `/status` | `thread/read`、`config/read`、account/model/permission 状态聚合 | MVP |
| `/rename` | `thread/name/set` 或等价 app-server method | MVP |
| `/new` | `thread/start` | MVP |
| `/clear` | 清空当前移动端会话视图并启动新 thread；active turn 中禁用 | MVP |
| `/resume` | `thread/list` + `thread/resume` | MVP |
| `/archive` | `thread/archive` | MVP |
| `/delete` | `thread/delete`，必须二次确认 | MVP |
| `/copy` | App 本地复制最后回复/选中 item markdown | MVP |
| `/raw` | App 本地 raw event/raw transcript 视图 | MVP |
| `/quit`、`/exit` | 关闭当前移动端会话/代理连接；不 interrupt 服务器 turn | MVP |
| `/review` | `review/start` | 第二阶段 |
| `/fork` | `thread/fork` | 第二阶段 |
| `/compact` | `thread/compact/start` | 第二阶段 |
| `/goal` | `thread/goal/*` 或当前 app-server 等价接口 | 第二阶段 |
| `/diff` | 优先 app-server diff/file change；必要时 `command/exec git diff --stat && git diff` | 第二阶段 |
| `/mention` | 文件选择器 + prompt attachment/context 注入 | 第二阶段 |
| `/usage` | `account/usage/read`、rate limits、token usage 聚合 | 第二阶段 |
| `/mcp` | `mcpServerStatus/list`、OAuth、reload、verbose 详情 | 第二阶段 |
| `/plugins` | `plugin/*` + `marketplace/*` | 第二阶段 |
| `/skills` | `skills/list` + skill detail/enable 状态 | 第二阶段 |
| `/apps` | `apps` 相关 app-server 能力；无结构化接口时 agent fallback | 第二阶段 |
| `/hooks` | hooks list/read/update；无接口时 agent fallback | 第二阶段 |
| `/logout` | `account/logout`，必须确认影响服务器 Codex 登录态 | 第二阶段 |
| `/ps` | background terminals/process list | 第二阶段 |
| `/stop`、`/clean` | 停止后台 terminals/process；不等价于中断当前 turn | 第二阶段 |
| `/ide` | 移动端文件/选择区上下文替代 IDE context；桌面 IDE 直连不作为首版目标 | 第三阶段 |
| `/keymap` | App 本地快捷键/外接键盘设置 | 第三阶段 |
| `/vim` | App 本地输入模式设置 | 第三阶段 |
| `/setup-default-sandbox` | agent/SSH fallback 调用 Codex sandbox setup；高风险确认 | 第三阶段 |
| `/sandbox-add-read-dir` | Windows sandbox read dir 配置；agent fallback；要求绝对路径校验 | 第三阶段 |
| `/experimental` | `config/read` + experimental feature toggles；写配置需确认 | 第三阶段 |
| `/approve` | auto-review retry approval 语义；优先 app-server，缺失时 agent fallback | 第三阶段 |
| `/memories` | memory 配置读取/编辑；写服务器配置需确认 | 第三阶段 |
| `/import` | Claude Code import 流程；agent/SSH fallback | 第三阶段 |
| `/app` | 移动端通常显示“不适用”；若服务器支持 Codex Desktop handoff，再接入 | 第三阶段/可选 |
| `/init` | app-server 若无接口则 agent/SSH fallback 生成 AGENTS.md；需 diff 审批 | 第三阶段 |
| `/plan` | collaboration mode 切换/本次 turn 覆盖 | 第三阶段 |
| `/side`、`/btw` | `thread/fork ephemeral=true` + boundary prompt + side UI；断线后可降级 | 第二阶段/实验 |
| `/agent` | 多 agent thread picker；先只读和切换查看，再评估控制能力 | 第三阶段 |
| `/subagents` | 子 agent thread 树、状态归因和管理 UI；先只读拓扑 | 第三阶段 |
| `/debug-config` | config layers/debug source 展示 | 第三阶段 |
| `/title` | App 本地/远端 title 显示设置 | 第三阶段 |
| `/statusline` | App 本地状态栏显示设置 | 第三阶段 |
| `/theme` | App 本地主题设置 | 第三阶段 |
| `/pets`、`/pet` | App 可显示为“终端 TUI 专属/可关闭”；不影响 Codex 语义 | 第三阶段/可选 |
| `/feedback` | `feedback/upload` 或 agent fallback | 第三阶段 |
| `/rollout` | debug/诊断信息；开发构建可见 | 高级/调试 |
| `/test-approval` | 开发构建审批链路测试 | 高级/调试 |
| `/debug-m-drop`、`/debug-m-update` | memory debug 命令；开发构建或高级诊断入口 | 高级/调试 |

验收标准：

- registry 必须覆盖当前 `slash_command.rs` 中的全部命令和别名：`/clean -> /stop`、`/pet -> /pets`、`/approve -> AutoReview`、`/subagents -> MultiAgents`。
- 每次 Codex 版本升级时，CI 对比本地 manifest 与 `slash_command.rs` 或官方 manifest，新增命令必须显式定级。
- App 的命令面板需要显示命令说明、参数要求、当前是否可用、来源类型（app-server/UI/agent fallback/debug）、以及不可用原因。
- 任何斜杠命令执行失败都应返回结构化错误，并保留 raw detail 供诊断。

## 6. 功能范围

### 6.1 MVP 必须支持

连接与服务器：

- SSH profile 列表。
- 新建/编辑 SSH profile：host、port、user、auth method、private key、password/passphrase、known_hosts。
- 手动测试连接。
- 自动启动或连接 `sadcoder-agent`。
- 显示 Codex CLI version、app-server backend version、agent status。
- 手动重启 agent/backend。
- 连接断开后自动重连。

会话：

- `thread/list`
- `thread/start`
- `thread/resume`
- `thread/read`
- `thread/archive`
- `thread/unarchive`
- `thread/delete`
- 当前 thread 状态显示。

对话：

- 发送文本 turn：`turn/start`
- 斜杠命令面板 MVP：`/model`、`/permissions`、`/personality`、`/status`、`/rename`、`/new`、`/clear`、`/resume`、`/archive`、`/delete`、`/copy`、`/raw`、`/quit`、`/exit`。
- 流式显示 assistant message。
- 显示 reasoning summary/delta。
- 显示 command execution、output delta、exit status。
- 显示 file changes/diff。
- 显示 MCP tool call。
- `turn/interrupt`
- `turn/steer`
- 完成/失败/中断状态。

审批：

- command approval。
- file change approval。
- MCP elicitation/request。

配置：

- `account/read`
- `model/list`
- `config/read`
- 显示服务器 Codex 当前有效配置摘要。
- model、reasoning effort、approval policy、sandbox/permission profile 基础选择。
- 支持本次 turn 覆盖和当前会话覆盖。
- 支持 App 默认覆盖，但默认不写入服务器 Codex 配置。
- 支持一键清除覆盖并恢复服务器默认。

体验：

- 深色模式。
- zh-CN / en-US 基础 i18n。
- 移动端保活：Android active turn 使用 foreground service；iOS 尽量利用短后台窗口和本地通知，不能承诺长期后台 SSH。
- 本地日志导出。

### 6.2 第二阶段支持

Codex 高级会话：

- `thread/fork`
- `thread/compact/start`
- `thread/goal/set/get/clear`
- `thread/turns/list`
- `thread/items/list`
- rewind/duplicate UI。
- token usage / goal budget UI。

文件与命令：

- `workspace/directoryList`
- `workspace/fileStat`
- `workspace/fileRead`
- `fs/writeFile` / `fs/watch` 留作后续受控编辑与监听设计，不进入只读文件浏览 MVP。
- `fuzzyFileSearch/*`
- `thread/shellCommand`
- `command/exec` PTY streaming。
- 轻量文件浏览器和 diff viewer。

认证：

- `account/login/start`：API key、ChatGPT browser/device code。
- `account/login/cancel`
- `account/logout`
- `account/rateLimits/read`
- `account/usage/read`

MCP/插件/技能：

- `mcpServerStatus/list`
- `mcpServer/oauth/login`
- `config/mcpServer/reload`
- `skills/list`
- `plugin/list`
- `plugin/read`
- `plugin/install`
- `plugin/uninstall`
- `marketplace/add/remove/upgrade`
- 斜杠命令第二阶段：`/review`、`/fork`、`/compact`、`/goal`、`/diff`、`/mention`、`/usage`、`/mcp`、`/plugins`、`/skills`、`/apps`、`/hooks`、`/logout`、`/ps`、`/stop`。
- 临时侧聊实验支持：`/side`、`/btw`，基于 `thread/fork ephemeral=true`，注入 side boundary prompt，支持返回主线；不承诺 ephemeral side thread 长期断线恢复。

### 6.3 第三阶段支持

- Review：`review/start`。
- Remote environment：`environment/add/info`。
- Realtime text/audio：`thread/realtime/*`，需要单独评估移动端音频与 WebRTC。
- `process/spawn` 高级进程管理。
- `externalAgentConfig/*`。
- `feedback/upload`。
- hooks 管理。
- Codex Cloud 相关 CLI 能力，若 app-server 不覆盖则走 SSH command fallback。
- 斜杠命令第三阶段和高级诊断：`/ide`、`/keymap`、`/vim`、`/setup-default-sandbox`、`/sandbox-add-read-dir`、`/experimental`、`/approve`、`/memories`、`/import`、`/app`、`/init`、`/plan`、`/agent`、`/subagents`、`/debug-config`、`/title`、`/statusline`、`/theme`、`/pets`、`/feedback`、`/rollout`、`/test-approval`、`/debug-m-drop`、`/debug-m-update`。
- 多 agent 拓扑：`/agent`、`/subagents` 先支持只读树和切换查看，再评估主动控制能力。

### 6.4 CLI 功能覆盖策略

Codex CLI 子命令与 App 覆盖方式：

| Codex CLI 能力 | App 覆盖方式 |
| --- | --- |
| 默认交互 TUI | app-server `thread/*` + `turn/*` |
| TUI 斜杠命令 | `SlashCommandRegistry` + app-server/UI/agent fallback 映射；禁止默认当普通 prompt 发送 |
| `exec` | 优先 `thread/start + turn/start` 或 `command/exec`；需要非交互语义时保留 SSH command fallback |
| `review` | `review/start` |
| `login/logout` | `account/*`，必要时 SSH fallback |
| `resume/fork/archive/delete/unarchive` | `thread/*` |
| `mcp` | `mcpServer*` + `config/*`，必要时 SSH fallback |
| `plugin` | `plugin/*` + `marketplace/*` |
| `app-server daemon` | 不作为生产依赖；SadCoder 使用 `sadcoder-agent service/proxy`，必要时 direct stdio fallback |
| `doctor` | `sadcoder-agent doctor --json` 结构化诊断；Settings Diagnostics 卡片显示 Codex/backend/reconnect cache 摘要 |
| `app-server generate-json-schema` | `sadcoder-agent schema --json` / `agent/schema` 统一生成和缓存 schema 摘要；Settings Diagnostics 展示缓存状态、digest 和文件摘要，供 App 做版本/能力适配 |
| `configure` | `sadcoder-agent configure --json` 结构化持久化 Codex program / args / PATH prepend；Settings Diagnostics 卡片提供保存入口 |
| `update` | SSH command fallback 或 agent-managed update policy |
| `sandbox` | 主要通过 permission profile/sandboxPolicy；调试命令走 SSH fallback |
| `apply` | 优先用 app-server 文件变更事件；必要时 SSH fallback |
| `cloud` | app-server 若无覆盖则第三阶段处理 |

“所有功能”的实际定义：凡 app-server 暴露的功能，客户端通过通用 JSON-RPC 支持；凡只存在 CLI/TUI 的功能，通过 SlashCommandRegistry、UI-only 行为或 SSH command fallback 支持，UI 再逐步结构化。新增 Codex CLI 子命令或斜杠命令必须先进入能力清单，再决定 MVP/第二阶段/第三阶段，不允许遗漏。

## 7. SSH 配置设计

### 7.1 Profile 字段

基础字段：

- profile name
- host
- port
- username
- authentication type：password / private key
- private key content 或移动端文件引用
- passphrase
- known host fingerprint
- default remote cwd
- codex path：默认 `codex`
- CODEX_HOME：可选
- connection mode：agent service proxy / direct stdio debug fallback

高级字段：

- ProxyJump
- connect timeout
- keepalive interval
- environment variables
- remote shell prefix
- custom agent/backend start command
- custom proxy command

### 7.2 OpenSSH config 兼容

首版 UI 支持常用字段，不承诺完整 OpenSSH parser：

- `Host`
- `HostName`
- `User`
- `Port`
- `IdentityFile`
- `ProxyJump`
- `IdentitiesOnly`

高级用户可以手动编辑 SadCoder 自己的 config 文件：

```toml
[[hosts]]
name = "prod"
host = "10.0.0.12"
port = 22
user = "ubuntu"
identity_file = "..."
codex_bin = "codex"
default_cwd = "/home/ubuntu/project"
mode = "agent-proxy"
```

App 内部存储使用加密数据库；导入/导出时明确提示敏感信息处理。

### 7.3 Host key 策略

- 默认启用 TOFU：首次连接展示 fingerprint，用户确认后保存。
- 后续 fingerprint 改变必须阻断连接并要求用户明确处理。
- 不提供“永久忽略 host key”作为普通选项。
- 支持 SHA256 fingerprint 展示。

当前实现状态：

- 已落地 Hosts 页面 changed host key 专用阻断弹窗：当已保存 endpoint 的 key type 或 SHA256 fingerprint 与当前收到值不一致时，App 会展示已保存/当前收到的 key type 与 fingerprint，只提供关闭动作，不提供信任继续或自动重试；手动 probe 与连接按钮路径均覆盖。

## 8. 保活、重连与连通性验证

### 8.1 自动保活

分三层：

1. SSH 层：启用 SSH keepalive 或定期 global request。
2. Agent proxy 层：定期 ping/pong 或 `agent/ping`。
3. App-server 层：空闲时低频发送轻量 RPC，例如 `thread/loaded/list`；活跃 turn 期间主要依赖事件流。

建议参数：

- SSH keepalive：15-30 秒。
- Agent proxy ping：15-30 秒。
- App RPC heartbeat：60 秒，仅前台或 active turn。
- 重连 backoff：1s、2s、5s、10s、30s，上限 60s，带 jitter。

### 8.2 移动端后台策略

- 没有 active turn：App 进入后台后可以断开长连接，只保留本地状态。
- Android 有 active turn：启动 foreground service，通知栏显示当前 host/thread，保持连接接收审批和完成状态。
- iOS 有 active turn：尽量在前台保持实时连接；进入后台后利用有限后台时间完成短任务，长任务依赖 agent 继续运行并在下次打开 App 时回填状态。自编译安装不改变 iOS 后台限制。
- 用户可关闭“后台保持连接”，关闭后只做断线恢复，不保证实时审批通知。
- Android WorkManager 只做低频健康检查，不承诺实时性。
- 无论哪种后台策略，App 断线都只是停止实时观察；服务器上的 active turn 必须继续执行或继续等待审批，不能被 App 生命周期自动中断。

### 8.3 重连流程

1. SSH 断开或 agent proxy 心跳失败。
2. App 标记 UI 为 reconnecting，但不向 agent 或 app-server 发送中断。
3. agent 继续持有 backend app-server 连接；如果 backend 崩溃，agent 按 backend 恢复策略处理，但不能因手机断开而主动终止 turn。
4. App 重新 SSH 连接。
5. 执行 `sadcoder-agent status --json`，必要时 `sadcoder-agent start`。
6. 重新打开 `sadcoder-agent proxy`。
7. 重新 `initialize`。
8. 对当前 thread 执行 `thread/resume` 或 `thread/read`。
9. 使用 `thread/turns/list` / `thread/items/list` 回填丢失事件。
10. 优先通过 proxy 内的 `agent/snapshot` 拉取 agent 缓存的 pending approvals 和最近事件；旧版本或兼容路径才回落到独立 `sadcoder-agent snapshot --json`。
11. 如果仍有 active turn，继续订阅事件；否则标记 idle。

### 8.4 手动连通性验证

“测试连接”按钮输出分阶段诊断：

1. TCP connect。
2. SSH handshake。
3. Host key 校验。
4. Auth 成功。
5. 远端 shell 可执行。
6. `sadcoder-agent status --json` 可执行，并返回 Codex path/availability/version/backend。
7. 必要时 `sadcoder-agent start` 可启动 service 或明确返回失败原因；direct stdio 只在显式 debug/compat backend 下单独诊断。
8. `sadcoder-agent proxy` 可连接。
9. JSON-RPC `initialize` 成功。
10. `account/read`。
11. `model/list`。
12. `thread/list limit=1`。

`sadcoder-agent doctor --json` 是非破坏性组合诊断入口，应同时返回 Codex 命令解析/版本/失败原因、agent status、backend readiness 和 reconnect cache 状态。App 通过 SSH 读取该 JSON，并在 Settings -> Diagnostics 中用结构化卡片展示，不直接在 App 侧重新执行 Codex 探测。

每一阶段都要给出明确错误和建议，例如：

- Codex 未安装。
- Codex 版本过低。
- agent 未安装或未运行。
- Windows service/计划任务未启动。
- SadCoder service 不可用或启动失败。
- ChatGPT/API key 未登录。
- 权限不足或 cwd 不存在。

## 9. UI 设计

### 9.1 信息架构

主导航：

- Hosts：服务器列表与连接状态。
- Threads：当前服务器的 Codex 会话列表。
- Chat：当前会话详情。
- Approvals：待审批请求。
- Files：轻量文件浏览器。
- Settings：模型、权限、SSH、语言、主题、日志。

MVP 可以简化为底部导航：

- Sessions
- Chat
- Approvals
- Settings

### 9.2 Chat 页面

核心元素：

- 顶部：host、cwd、model、effort、approval/sandbox 状态、连接状态。
- 中部：按 turn 分组的消息流。
- item 渲染：
  - 用户消息。
  - assistant message。
  - reasoning 折叠块。
  - command execution 卡片：命令、cwd、实时输出、exit code。
  - file change 卡片：文件名、状态、diff。
  - MCP tool 卡片：server、tool、args/result。
  - web search item。
  - error/status item。
- 底部输入：
  - 文本输入。
  - 输入 `/` 打开斜杠命令面板。
  - send。
  - interrupt。
  - steer when active。
  - model/effort/permission quick controls，默认显示“服务器默认”，只有用户选择后才显示覆盖标记。

当前实现状态：

- 已收敛 Chat 顶部为左侧三横线会话侧栏按钮、中部 TUI 式状态词（idle/running/working/failed）+ 当前工作详情和右侧 host selector；活动条会从当前非终态 timeline item 提取命令/工具/文件变更详情，不暴露 thread/turn 内部 id。主区域优先显示 thread timeline 的用户/Codex 文本、工具调用、命令输出和 diff；用户/Codex 消息采用开放消息流，命令/工具/diff 采用执行块，推理等低频内容默认折叠，会话列表不再展示 cwd/status 详情，timeline item metadata 不进入默认主对话流。
- 本轮 UI pass 已补强 Chat 主画布权重和 TUI 状态 marker/status chip，侧栏开关固定为左上三横线且默认收起会话侧栏，timeline turn 作为主内容渲染并有 widget 测试覆盖；会话侧栏已改为工具侧栏式列表 surface，点选会话只切换/加载 timeline，不展示 Thread detail/cwd/turn id 详情；顶栏状态和主机选择器支持窄屏 flex 收缩，斜杠命令预览仍保留为输入附近的轻提示，不再抢占默认对话信息架构。
- Chat 高级折叠区已按能力拆分：配置覆盖控件只在有 `CodexConfigOverrideController` 时出现，Raw RPC 面板可显示禁用态，但发送只依赖已注入的 session controller，避免 session-only 页面展开高级区时因覆盖 controller 缺失而崩溃；默认对话面仍不显示这些调试控件。
- 最新 UI pass 已把 active turn 的 raw `Status: inProgress` 从主 timeline 移除，running/working/failed 详情只由顶部 TUI 状态槽承担；高级调试入口改为图标折叠按钮，斜杠命令输入预览改为轻量 inline surface，避免底部输入区继续占用对话主体。
- 最新 UI contract 已将斜杠命令输入预览固定到 composer chrome：预览仍作为输入框上方的轻提示展示，但不再作为 `chat-main-conversation` 主滚动区的子节点，避免命令解析提示混入用户/Codex 文本、工具调用和命令输出 transcript。
- 本轮 UI pass 将 Chat 高级调试入口从 inline 展开区迁到可滚动 bottom sheet：默认对话页不再把 Raw RPC、会话覆盖、本次回合覆盖插入输入框上方；用户点调试图标才进入独立高级工具面板，关闭后回到以 timeline 文本、工具调用和 composer 为主体的对话界面。
- 本轮 UI pass 继续强化对话主体权重：顶部 activity strip 增加 TUI 式语义色轨，running/working/failed 详情仍只放在顶部状态槽；会话侧栏行改为紧凑工具行和选中 rail，仅展示会话标题，不回退显示 cwd、status、thread/turn id 等详情。
- 本轮 UI polish 将会话侧栏的 active / archived 模式切换从横向 segmented control 改为竖向紧凑工具按钮，保留 tooltip、选中 rail 和图标语义，避免窄侧栏横向挤压对话主体。
- 侧聊提示面板也已去掉 side/main thread id，仅保留侧聊标题、触发命令和返回主线按钮；默认对话画布不再显示内部会话详情。
- 本轮 Chat 可见 UI 里程碑已将 user / Codex 文本改为左右气泡式阅读流，并默认复用 Files Markdown 预览的 MarkdownBody、代码高亮和图片占位策略；command/file/tool/reasoning 仍保持中性 timeline block，超长文本回退 selectable raw，长 command output 默认折叠并提供行数/字节数、尾部摘要和展开动作。Composer 已压缩为多行自动换行输入，移除输入模式/发送快捷键/terminal pet helper 文案，高级控制入口迁入左上三横线侧栏，timeline 增加跳到最新行为：同一 thread 新事件尊重用户历史位置，切换 thread/session 默认滚到最新。
- 后续 Chat 输入框修复已将 composer 改为受最大高度约束的真正多行输入区：移动端键盘动作保留换行，长文本软换行后输入框增高到上限再内部滚动；硬件 Enter / Ctrl+Enter 发送仍按 keymap 执行，widget 测试覆盖长中文输入不再把布局向右撑开。
- 本轮 Chat UI / timeline 性能里程碑已修正消息方向契约：user 消息固定右侧、Codex/assistant 消息固定左侧，文本气泡使用约 92% 可用 timeline 宽度且保留左右方向感；command/file/tool/reasoning 仍为中性 timeline block。Chat timeline 新增可拖动的浮层“跳到最新”按钮，位置限制在对话内容区域内，不占 composer 或 timeline layout 空间；左上三横线会话侧栏使用 210ms ease-out slide/fade 过渡，打开/关闭不再跳变。全局正文、中文、英文、代码块和 terminal/diff/raw 输出统一到随包发布的 LXGW WenKai Mono 字体，并在 `assets/fonts` 保留 OFL 授权文本。
- 本轮 Chat timeline 已改为有界窗口与按需分页：普通 thread 选择先读取 metadata，再通过 `thread/items/list(sortDirection=desc, limit=80)` 拉最新窗口，向上滚动接近顶部后按 cursor 继续加载更早 item page；即使 detail reader 意外带回 full turns，只要 item reader 可用，Chat 首屏仍优先使用 bounded items page，full turns 只作为无 reader 或读取失败 fallback；controller 对 item id 去重，失败时保留当前 timeline 并显示 retry 状态，live event / reconnect recovery 的 turn backfill 路径仍保留且同样受窗口上限保护。后续仍需根据真实 app-server cursor 语义做端到端设备验证，确认 `nextCursor` 在各 Codex 版本上均表示更早历史页。
- 本轮结构整理将 Chat timeline viewport、滚动监听、向上加载触发和可拖动“跳到最新”浮层从 `ChatPage` 拆到 `features/chat/chat_timeline_view.dart`；`ChatPage` 只负责页面编排、侧聊 header 和 timeline renderer 组合。后续若继续降低 `ChatPage` 体量，可再把 timeline item renderer、thread sidebar 与 slash command sheets 分别拆成独立文件。
- 本轮结构整理继续将 Chat 会话侧栏 surface、workspace 摘要 header、active/archived thread list 与 thread tile 从 `ChatPage` 拆到 `features/chat/chat_thread_sidebar.dart`；高级控制 bottom sheet 仍保留在页面层，避免 sidebar 模块依赖配置覆盖/Raw RPC 调试能力。后续 `ChatPage` 仍可继续拆 timeline item renderer 与 slash command sheets。
- 本轮结构整理将 Chat timeline renderer、消息气泡、reasoning 折叠块、command/file/tool 执行块、Markdown raw fallback、terminal output 折叠和 diff 渲染从 `ChatPage` 拆到 `features/chat/chat_timeline_renderer.dart`；`ChatPage` 不再直接依赖 Markdown preview / diff block / terminal renderer 细节。后续 `ChatPage` 主要剩余解耦点是 slash command dispatcher callbacks 和各类 command sheets。
- 本轮结构整理将 composer 上方的 slash command preview 从 `ChatPage` 拆到 `features/chat/chat_slash_command_preview.dart`，保留 known/unknown/empty slash 的轻提示与“作为文本发送”入口；`ChatPage` 只传入解析结果和回调。后续可继续把 slash command dispatcher callbacks 与 command sheets 从页面层拆出。
- 本轮结构整理将 Chat 顶部 activity strip / TUI 状态线从 `ChatPage` 拆到 `features/chat/chat_activity_strip.dart`，保留 sidebar toggle、running/working 状态 rail、状态行 chips 和当前 active timeline work 摘要；`ChatPage` 只传入状态 controllers、status line parts 和连接控件。后续 `ChatPage` 仍主要剩余 slash command dispatcher callbacks、command sheets 和高级控制 sheet 可继续拆分。
- 本轮结构整理将 Chat 右上连接/主机选择控件从 `ChatPage` 拆到 `features/chat/chat_connection_controls.dart`，保留已保存主机别名显示、popup profile 选择、per-host 状态 chip 和连接忙碌态；`ChatPage` 只提供 profiles/session summaries 与选择回调。后续主机管理和多 host 同时连接仍按 9.7.1 的 HostSessionManager 路线推进。
- 本轮结构整理将 Chat 高级控制 bottom sheet 从 `ChatPage` 拆到 `features/chat/chat_advanced_controls_sheet.dart`，由独立组件组合 Session/Turn override controls 与 Raw RPC panel；`ChatPage` 只负责打开 sheet、传入 override controller、Raw RPC sender 和 session override 应用回调。后续 `ChatPage` 主要剩余 slash command dispatcher callbacks 与各类 command sheets 可继续拆分。
- 本轮结构整理将 `/theme` command sheet 从 `ChatPage` 拆到 `features/chat/chat_theme_sheet.dart`，公开 `ChatThemeSheet` / `ChatThemeSheetResult` 并保留主题模式、真实 candy palette 选择和 apply 返回契约；`ChatPage` 只负责展示 sheet 并把结果应用到 appearance controller。
- 本轮结构整理将 `/feedback` command sheet 从 `ChatPage` 拆到 `features/chat/chat_feedback_sheet.dart`，公开 `ChatFeedbackSheet` / `ChatFeedbackFormResult` 并保留 category、note、include logs 确认弹窗和 `feedback/upload` 参数映射契约；`ChatPage` 只负责打开 sheet 并提交结果。
- 本轮结构整理将 `/model` command sheet 从 `ChatPage` 拆到 `features/chat/chat_model_override_sheet.dart`，公开 `ChatModelOverrideSheet` / `ChatModelOverrideResult` 并保留 turn/session scope、model/list picker、model/effort 字段和 apply 返回契约；同时新增 `features/chat/chat_override_scope.dart` 承载通用 scope selector 与 overrides 读取 helper。
- 本轮结构整理将 `/personality` command sheet 从 `ChatPage` 拆到 `features/chat/chat_personality_override_sheet.dart`，公开 `ChatPersonalityOverrideSheet` / `ChatPersonalityOverrideResult` 并复用 `chat_override_scope.dart`，保留 turn/session scope、personality 字段和 apply 返回契约；`ChatPage` 只负责打开 sheet 并写入 override controller。
- 本轮结构整理将 `/permissions` command sheet 从 `ChatPage` 拆到 `features/chat/chat_permissions_override_sheet.dart`，公开 `ChatPermissionsOverrideSheet` / `ChatPermissionsOverrideResult` 并复用 `chat_override_scope.dart`，保留 approval policy、sandbox/network、permission profile selector、risk warning 和 apply 返回契约；result 自带 `isHighRisk` 判定，`ChatPage` 只负责二次确认和写入 override controller。
- 本轮结构整理将 `/agent` / `/subagents` topology bottom sheet 从 `ChatPage` 拆到 `features/chat/chat_agent_topology_sheet.dart`，公开 `ChatAgentTopologySheet` 并保留 active thread 标记、agent role/path/status/parent/ancestor 详情、subagent-only title 和点击返回 `ThreadSummary` 的契约；`ChatPage` 只负责刷新 thread/topology 数据和切换 active thread。
- 本轮结构整理将 side conversation inline banner 从 `ChatPage` 拆到 `features/chat/chat_side_conversation_panel.dart`，公开 `ChatSideConversation` / `ChatSideConversationPanel` 并保留 compact 状态、`/side`/`/btw` 命令提示、不显示 parent/side thread id、返回主线按钮启停契约；`ChatPage` 只保留侧聊生命周期和 thread 切换逻辑。
- 本轮结构整理将 `/goal` inline argument parser 从 `ChatPage` 拆到 `features/chat/chat_goal_command.dart`，公开 `ChatGoalCommand` 及 get/clear/set 子类型和 `parseChatGoalCommand`，覆盖 get/show/clear/status/budget/set/default objective 与无效参数边界；`ChatPage` 只保留 thread goal runner 调用和本地化 summary 生成。
- 本轮结构整理将 composer file mention 的 range 跟踪、重叠清理、剪枝和 `TurnTextElement` byte-range 转换从 `ChatPage` 拆到 `features/chat/chat_composer_mention.dart`，公开 `ChatComposerMention` 与 helper；`ChatPage` 只负责选择文件、计算插入区间和更新输入框文本。
- 本轮结构整理将 `/rollout` 只读诊断的 raw thread path 解析从 `ChatPage` 拆到 `features/chat/chat_rollout_diagnostics.dart`，公开 `rolloutPathFromThreadRaw` 并覆盖 camel/snake key、嵌套 `rollout.path`、空值跳过和稳定优先级；`ChatPage` 只负责命令参数校验和本地化提示。
- 本轮结构整理将 Chat thread sidebar 的宽度规则和 overlay breakpoint 从 `ChatPage` 拆到 `features/chat/chat_layout_metrics.dart`，公开 `chatThreadSidebarWidthFor` / `chatThreadSidebarOverlayBreakpoint` 并覆盖窄屏、overlay 和宽屏 docked 三档布局边界；`ChatPage` 只消费布局常量和计算结果。
- 本轮结构整理将 `/plugins` inline argument parser 从 `ChatPage` 拆到 `features/chat/chat_plugins_command.dart`，公开 list/read/install/uninstall 结构化 command 与 `parseChatPluginsCommand`，覆盖 marketplace kind filter、`read`/`show`/`detail`、`install`、`uninstall`/`remove` 和非法参数边界；`ChatPage` 只负责调用 plugin reader/mutation runner 并生成 summary。
- 本轮结构整理继续将 `/mcp` inline argument parser 从 `ChatPage` 拆到 `features/chat/chat_mcp_command.dart`，公开 summary/reload/login 结构化 command 与 `parseChatMcpCommand`，覆盖 `verbose`、`reload`/`refresh`、`login`/`oauth`/`auth` 和非法参数边界；`ChatPage` 只负责调用 MCP status/OAuth/config runner 并生成 summary。
- 本轮结构整理将 `/skills`、`/hooks`、`/apps` 的只读 catalog summary 命令加载、reader 不可用处理和加载失败摘要从 `ChatPage` 拆到 `features/chat/chat_catalog_summary_commands.dart`；`ChatPage` 只传入当前 cwd/thread context，summary 模块负责参数边界、reader 调用和本地化错误摘要。
- 本轮结构整理将 `/debug-config`、`/experimental`、`/memories` 的只读配置 summary 命令 refresh、cwd 选择和参数边界从 `ChatPage` 拆到 `features/chat/chat_config_summary_commands.dart`；`ChatPage` 只传入 config snapshot controller、当前 workspace cwds 和 thread raw memory context。
- 本轮结构整理将 `/raw` transcript view 的 `toggle`/`on`/`off` 参数解析从 `ChatPage` 的 `setState` 分支拆到 `features/chat/chat_raw_transcript_command.dart`；`ChatPage` 只根据纯函数返回的下一状态更新本地 raw timeline 显示。
- 本轮结构整理将 `/ps` 背景终端列表和 `/stop`/`/clean` 后台终端清理的参数边界、thread/runner 可用性检查与 runner 调用从 `ChatPage` 拆到 `features/chat/chat_background_terminal_commands.dart`；`ChatPage` 只传入当前 thread id 和 session runner。
- 本轮结构整理将 `/diff` 的空参数校验、当前 workspace cwd 选择、`GitDiffReader` 调用和加载失败摘要从 `ChatPage` 拆到 `features/chat/chat_diff_command.dart`；`ChatPage` 只传入当前 cwds 和 session diff reader。
- 本轮结构整理将 `/test-approval` 的空参数校验、本地 file-change 测试审批 payload 构造和 `ApprovalStateController.upsert` 调用从 `ChatPage` 拆到 `features/chat/chat_test_approval_command.dart`；`ChatPage` 只传入当前 thread/turn context 和时间。
- 已补齐 active turn 文本追加路径：`CodexAppServerClient`、`CodexTurnRunner`、`TurnController` 和 Chat composer 已支持 `turn/steer`，active turn 中发送普通文本会带 `expectedTurnId` steer 当前回合，而不是启动新 turn 或禁用输入；本次 turn overrides 仍只随 `turn/start` 消耗，不会被 steer 清掉。

### 9.3 Approvals 页面

审批优先级最高，需要可从通知直接进入。

每个审批请求展示：

- 请求类型。
- Codex 给出的 reason。
- 风险提示。
- 命令或 diff。
- 影响路径。
- 选项：
  - Allow once
  - Allow for session
  - Deny
  - Cancel turn

中文 UI 对应：

- 允许一次
- 本会话允许
- 拒绝
- 取消本轮

### 9.4 配置覆盖 UI

设置和对话页都需要避免让用户误以为 App 会接管服务器 Codex 配置。

显示规则：

- 每个可配置项旁边显示来源标签：`服务器默认`、`App 默认覆盖`、`本会话覆盖`、`本次覆盖`。
- 默认状态显示服务器解析出来的值，但控件处于“未覆盖”状态。
- 用户改变控件时，必须选择覆盖范围：本次发送、本会话、App 默认。
- 高风险覆盖，例如 `danger-full-access`、`approvalPolicy=never`、自定义 permission profile，必须有明显风险提示。
- 提供“恢复服务器默认”按钮，清除 App 默认/会话/本次覆盖。
- 服务器配置编辑入口单独放在高级设置中，不和普通覆盖控件混在一起。

服务器配置编辑规则：

- 默认只读展示 `config/read` 摘要。
- 需要修改服务器配置时，展示变更摘要和影响范围。
- 调用 `config/value/write` 或 `config/batchWrite` 前必须二次确认。
- 写入后调用必要的 reload 接口，例如 `config/mcpServer/reload`，并刷新 `config/read`。

### 9.5 斜杠命令面板

斜杠命令面板是移动端覆盖 Codex TUI 能力的主要入口。

交互规则：

- 输入框首字符为 `/` 时弹出命令面板。
- 支持搜索 command、alias、中文/英文说明。
- 每条命令展示：命令名、简短说明、参数提示、当前阶段、来源标签（app-server、UI、本地、agent fallback、debug）、当前是否可用。
- active turn 中不可用的命令置灰，并显示原因，例如“当前任务运行中，不能 archive/delete/fork”。
- 支持 inline args 的命令提供参数表单或补全，例如 `/rename <name>`、`/mcp verbose`、`/sandbox-add-read-dir <absolute_path>`。
- 高风险命令需要确认：`/delete`、`/logout`、`/setup-default-sandbox`、`/sandbox-add-read-dir`、写服务器配置类命令。
- `/quit` 和 `/exit` 的按钮文案必须表达为“关闭本 App 会话/断开连接”，不能让用户误解为停止服务器任务。
- 用户确实想把 `/xxx` 当作普通 prompt 时，需要在面板中选择“作为文本发送”，并在发送内容中保留原文。

视觉要求：

- 命令面板使用移动端常见 command palette/bottom sheet，不模拟终端弹窗。
- 命令按照常用、会话、配置、文件/命令、MCP/插件、调试分组。
- 对当前平台不可用的命令默认隐藏；高级设置可显示“不可用命令”用于诊断。
- i18n 中保留原始 command 名，不翻译 `/model` 等命令本身，只翻译说明和错误。

当前实现状态：

- 已落地 `SlashCommandRegistry`、命令解析、unknown slash 不默认作为普通 prompt 发送、移动端 `/quit`/`/exit` 仅断开 App/proxy 语义、以及命令面板高级可见性开关。
- 已落地与 `refs/codex/codex-rs/tui/src/slash_command.rs` 的防漂移测试：自动校验命令名、展示顺序、alias、inline args、side conversation 可用性和 active turn 可用性；SadCoder 自有扩展 `/duplicate`、`/rewind`、`/plugins` 的差异需要显式白名单。
- 已接入 `agent/slashCommands/list` 远端 manifest 的 reconnect cache：`SlashCommandRegistryController` 按 host/profile 加载远端 manifest，成功后写入本地 cache；远端加载失败时优先回退同 profile/cache 的 manifest，再回退内置 registry。
- 已将 `/rollout` 接成只读 UI 诊断命令：有参数时不可用；无线程 raw path 时按 Codex TUI 语义显示 `Rollout path is not available yet.`，如果 thread raw 后续暴露 rollout path，则显示当前路径。
- 已将 `/test-approval` 接成移动端本地 debug-only 审批链路测试：注入一条 file-change `PendingApproval` 到当前 session 的 `ApprovalStateController`，不调用 app-server、不修改服务器状态。
- 已将 `/experimental` 接成只读配置摘要：刷新当前 cwd 的 `config/read` snapshot，显示 app-server experimental API 已启用，并列出 config 中 experimental/feature 相关键；写服务器配置和 toggle 仍留待后续确认流程。
- 已将 `/memories` 接成只读配置摘要：刷新当前 cwd 的 `config/read` snapshot，展示 `[memories]` / memory feature 相关配置和当前 thread memory mode；`thread/memoryMode/set`、`memory/reset` 等写操作仍留待后续带确认流程实现。
- 已将 `/app` 接成移动端 UI-only 诊断：无参数时明确提示 Codex Desktop handoff 在移动端不可用，不调用 app-server、不发送 prompt；带参数时返回 unavailable。后续只有在服务器明确暴露 Desktop handoff 能力时再改成结构化接入。
- 已将 `/import` 接成移动端 UI-only 诊断：无参数时明确提示 Claude Code import 仍需要受保护的 agent fallback，不调用 app-server、不扫描远端文件、不发送 prompt；带参数时返回 unavailable。后续实现必须先设计确认、可预览迁移摘要和回滚/跳过策略。
- 已将 `/init` 接成移动端 UI-only 诊断：无参数时明确提示 AGENTS.md 初始化需要先生成 diff 预览并审批，不调用 app-server、不写文件、不发送 prompt；带参数时返回 unavailable。后续实现必须复用受控编辑/审批链路，不能直接通过 SSH 命令写入工作区。
- 已将 `/setup-default-sandbox` 和 `/sandbox-add-read-dir` 接成移动端高风险诊断：前者无参数时提示需要受保护的 agent fallback 和高风险确认；后者先做 Windows 绝对路径/UNC 路径校验，合法路径只显示受保护 fallback 诊断，不调用 app-server、不执行 agent 命令、不修改沙箱配置；无效路径或不支持参数返回 unavailable。后续真正执行 fallback 前仍必须接入可审计变更摘要。
- 已为 `/setup-default-sandbox` 与合法 Windows `/sandbox-add-read-dir <absolute_path>` 接入高风险确认门：用户确认后仍只显示 guarded fallback 诊断，不执行 agent 命令、不修改服务器设置；取消时返回 command cancelled，且非法路径不会触发确认。
- 斜杠命令面板已使用左侧竖向分组 rail，而不是横向 tab；widget 回归测试会校验 common/session/configuration 分组按钮按同一 x 坐标纵向排列，避免窄屏重新出现横向标签挤压或底部 overflow。

### 9.6 工作区文件浏览与只读查看

工作区文件浏览是 `/mention`、`/ide`、代码审查、diff 查看和后续受控编辑能力的基础能力。它不应该继续塞进 `ChatPage` 内部，而应该作为独立的 `features/files` 模块建设。

目标：

- 基于当前 workspace cwd、thread cwd 或显式 cwd override 浏览工作区目录树。
- 支持展开目录、刷新目录、搜索/过滤文件、复制文件路径。
- 支持打开文本文件进行只读查看。
- 支持代码文件语法高亮。
- 支持 Markdown 文件在渲染视图和 raw 源码视图之间切换。
- 支持大文件分段读取，不强制一次性读取完整文件。
- MVP 明确不支持编辑、删除、重命名、新建文件或新建目录；后续编辑能力必须单独设计写入确认、diff 审批和冲突检测。
- Files 页面保持只读浏览边界，不提供 terminal、shell command、写文件或其他可修改工作区的快捷入口；这些能力属于独立 Terminal/Commands 页面或受控编辑流程。

结构要求：

- 新增 `WorkspaceDirectoryReader`，负责目录列表读取、分页、隐藏文件策略和错误归一化。
- 新增 `WorkspaceFileReader`，负责文件元信息和内容读取。
- 优先使用结构化 app-server/agent file API；如果暂时只能通过 `command/exec` fallback 实现，fallback 必须封装在 reader 内，不允许 UI 直接拼命令。
- 目录树、文件查看器、Markdown/raw 切换、代码高亮都放在 `features/files` 下，聊天页只负责入口或上下文联动。
- 所有路径必须限制在 workspace root 内，禁止 `..`、绝对路径替换、符号链接逃逸等路径穿越。
- 文件 API 必须返回结构化错误：未连接、无 cwd、路径不存在、权限不足、路径越界、二进制不可预览、文件过大、读取失败。

建议协议：

- `workspace/directoryList`
  - 参数：`root`、`path`、`limit`、`cursor`、`includeHidden`。
  - 返回：目录项列表、分页 cursor、文件/目录类型、大小、修改时间、是否隐藏。
- `workspace/fileStat`
  - 参数：`root`、`path`。
  - 返回：文件类型、大小、mtime、是否二进制、mime/language、内容版本或 hash。
- `workspace/fileRead`
  - 参数：`root`、`path`、`offset`、`limitBytes`、`encoding`。
  - 返回：`sizeBytes`、`offset`、`bytesRead`、`nextOffset`、`hasMore`、`encoding`、`isBinary`、`content`、`contentHash` 或 `version`。

大文件策略：

- 小文件可以一次性读取并完整渲染。
- 大文件默认使用 range read：`offset + limitBytes`，UI 显示已加载大小/总大小，并提供“加载更多”。
- range read 必须避免切坏 UTF-8 字符；服务端应在安全边界返回文本 chunk。
- range read 的后续 chunk 加载失败时，UI 必须保留已加载内容并允许用户按同一 offset 重试，不能把整个预览重置为空状态。
- Markdown 大文件默认 raw 分段查看；只有文件大小低于阈值或用户明确触发时才完整渲染。
- 代码高亮只保证对当前已加载内容生效，不要求跨 chunk 完整语义高亮。
- 二进制文件默认不预览文本，显示文件大小、类型、路径和不可预览状态。

验收标准：

- 未连接、无 cwd、空目录、权限不足、路径不存在、路径越界、大文件、二进制文件都有明确 UI 状态。
- 可以从当前 workspace root 浏览目录树并打开 `.dart`、`.rs`、`.md`、`.txt` 等文本文件。
- Markdown 文件默认可渲染，并可切换 raw；大 Markdown 受大小阈值保护。
- 代码文件有语法高亮；大文件模式不会阻塞 UI。
- 文件读取支持分段加载，测试覆盖 `nextOffset`、`hasMore`、编码边界和错误状态。
- 不出现任何写文件入口；只读查看不会触发 server turn、不会修改工作区。
- Files toolbar 不暴露 terminal/shell command 入口，避免把只读浏览和命令执行混在同一模块里。

当前实现状态：

- 已落地 `features/files` 独立模块，包含目录树、文件预览、Markdown render/raw 切换、代码高亮、远端文件搜索入口和只读 toolbar。
- 已落地 `workspace/directoryList`、`workspace/fileStat`、`workspace/fileRead` 的 agent RPC，并保留旧 `fs/*` 只读方法作为客户端兼容 fallback。
- 已调整 Files 页面为左侧工作区文件侧栏和主区域 status page / 文件预览；文件过滤、隐藏文件、远端搜索和刷新入口已收敛为紧凑工具行，搜索栏高度已压缩，显式 workspace root 与默认 root 选择保持折叠入口。
- 本轮 UI pass 已继续压缩 Files 顶部和工具栏密度，文件搜索栏限制为 20px 高、88px 宽上限（测试契约不超过 96px），文件树行改为工具侧栏式密集行；主区域保留 status page / opened file 的单一主体语义，预览面板只保留清晰边界，不再用投影制造卡片感；窄屏默认收起文件树侧栏，左上三横线负责展开，避免文件树覆盖主状态页。
- 本轮 UI pass 为文件树行增加轻量语义色轨和固定尺寸图标容器，保留只读文件浏览边界；工作区 root 选择继续折叠，搜索栏保持紧凑，主界面仍只承担 status page 或已打开文件预览。
- 本轮 UI polish 将文件树行进一步收成单行导航项，默认只显示图标、文件名、展开/复制动作和选中 rail；绝对路径、大小、修改时间仍按 locale 格式化但移入 tooltip，避免侧栏元数据抢占主预览区域。
- 本轮 UI polish 将工作区 root 折叠入口补充为当前 root 路径摘要：默认仍不显示输入框和保存默认 root 动作，用户展开后才可手动指定 root、恢复默认 root 或保存默认 workspace；顶部仍保留 `Root: ...` 状态文本，侧栏折叠标题只显示路径，避免主区域和侧栏重复抢占空间。
- 本轮可见 UI 里程碑已补文件页 widget 契约：`workspace-files-root-selector`、紧凑 `workspace-files-filter` 和文件树入口均属于左侧 `workspace-files-sidebar`，主区域仍由 `workspace-files-main` 承担 status page 或打开文件预览，避免工作区选择/搜索控件回流到主内容区。
- 本轮 Chat 可见 UI 里程碑已在 Chat 左侧会话侧栏顶部显示当前 workspace/cwd 摘要，并把高级控制入口收归侧栏；cwd/session/turn override 等调试信息不回流到主对话流。Files 页面继续负责完整 root selector、默认工作区保存、搜索和文件树，Chat 只展示当前上下文摘要与入口。
- 本轮 Chat UI / timeline 性能里程碑没有改变 Files 只读边界；9.6 仍以 Files 页面作为完整工作区选择、默认 workspace、搜索和文件树入口。Chat 侧栏只保留当前 workspace/cwd 摘要与切换入口，避免把 cwd/session/turn override 调试信息重新塞回主对话流。
- 已覆盖路径归一化、目录响应 path/name 校验、目录分页 `nextCursor`/`cursor`、拒绝 `..` / 绝对 child path、符号链接祖先拒绝、二进制文件拒绝、UTF-8 range 边界、后续 chunk 失败重试和大 Markdown raw 保护。
- 已补充文件页 widget 覆盖：可手动指定工作区 root，目录读取使用该 root；可保存 App 默认工作区 root 到 cwd 覆盖，并可从临时 root 恢复默认 root。
- 已补充文件页只读边界 widget 覆盖：打开文件预览后仍不出现 terminal、新建文件/文件夹、重命名、删除、编辑、保存或写文件入口，确保后续 UI polish 不会把受控编辑能力混入只读 Files 页面。
- 仍待后续单独设计：受控编辑、写文件、目录监听、diff 审批和冲突检测；这些能力不得混入只读 Files 页面。

### 9.7 深色模式

- 使用 Material 3 dynamic color 可选，但默认提供稳定主题。
- 支持 system / light / dark。
- 代码块、diff、terminal output 要有专门配色，不能只用普通文本颜色。
- 配色方案可影响代码关键字、终端 accent 和标题区等语义 accent，但 diff added/removed、风险状态等角色必须保持可识别，不能随主题被简单染成同一种主色。
- 已落地 system/light/dark、五档字号（极小/小/中/大/极大）和多配色方案；Candy palette 已从单一 Material seed 调整为参考 cotton-candy / bubblegum / mint / sky / lemon 调色板的明确 hex 色板（`#FFB3E6`、`#FFD1F3`、`#B8F2E6`、`#A0C4FF`、`#FFF1B6`），并保留浅色模式深色主按钮/正文对比；新增 `pastel-candy` 粉彩糖果方案，参考 pastel candy 的粉、浅蓝、浅金、清绿、淡紫组合（`#F4BCC7`、`#9EDEF2`、`#F2E1B1`、`#C6F2AF`、`#D5CAF9`），新增 `candy-tones` 柔和糖果色方案（`#D3F8E2`、`#E4C1F9`、`#F694C1`、`#EDE7B1`、`#A9DEF9`），Candy Pop 高饱和糖果配色参考 Coolors `9b5de5-f15bb5-fee440-00bbf9-00f5d4` 的紫、粉、黄、青、薄荷 hex 调色板；`sugar-rush` 已按网上 bubblegum/candy 参考改为粉红、淡黄、泡泡蓝、糖果绿、紫色组合（`#F56C78`、`#ECE482`、`#7CD6E4`、`#AAE48F`、`#C25DE9`），同时保留代码、diff、terminal 的语义色边界。
- 本轮 UI polish 已为 Chat 顶部活动条、三横线侧栏入口和 timeline execution block 增加轻量层次；running/working/failure 详情固定在顶部 TUI 式状态槽中，不把会话详情或内部 thread/turn id 放回主对话流。command/file/tool 块使用左侧语义色轨区分命令、文件变更和工具调用，Files 主区未连接/无 cwd/未打开文件状态保持带边界和图标容器的 status page。会话和文件树仍放在左侧栏，左上三横线作为入口，低频 workspace root 和高级外观/诊断设置保持折叠。
- 本轮 Chat UI 收口将 side conversation 提示从大 Card 改为单行 inline banner：只显示侧聊状态和 `/side`/`/btw` 入口命令，返回主线使用图标按钮；不显示 parent/side thread id，也不再显示 “Command:” 调试标签，避免侧聊状态抢占 Codex 对话和工具调用主体。
- 本轮外观 polish 将配色选择器从默认 Material ChoiceChip 改为自定义 swatch tile：每个 palette 直接展示多色糖果/主题色条、选中勾选和轻量边界层次；字号仍保留极小/小/中/大/极大五档。
- 已将字号五档从默认 ChoiceChip 调整为带示例字形、语义色轨、选中勾选和固定宽度约束的自定义 tile；配色 swatch tile 在极窄宽度下按容器收缩，避免设置侧栏或小屏布局出现横向溢出。
- 本轮可见 UI 里程碑已补 Appearance 测试契约：设置页必须渲染 `candy`、`pastel-candy`、`candy-tones`、`candy-pop`、`sugar-rush` 五套糖果色板入口，控制器必须暴露五套各 5 个互异 swatch 的真实糖果配色；字号入口必须完整渲染并按 `extra-small`、`small`、`medium`、`large`、`extra-large` 五档有序提供。

### 9.7.1 主机、设置与主题后续改造

用户体验后续要求：

- SSH 主机管理支持多台主机：本地保存多 profile，按 host 分组折叠展示；后续升级为多 host 同时连接和 per-host session/thread 列表。
- SSH 主机管理补文件导入和密钥管理：支持从文件导入 OpenSSH config 与私钥；支持 App 内生成 RSA / ED25519 密钥对并导出/复制 public key；导入或生成的私钥必须进入 durable credential store（Android Keystore / iOS Keychain），不得归入可被“清缓存”删除的普通 cache。
- Chat 顶栏右上角提供当前连接主机选择器：主机选择切换当前 session 上下文；连接/断开操作保留在 Hosts 页面或 `/quit` 等明确命令入口，且不直接中断 active turn。
- Settings 页面改为多级菜单，最多二级：一级为 Account、Models、Permissions、Appearance、SSH、Diagnostics 等分组；二级进入具体设置页，避免单页继续膨胀。
- Appearance 增加更多配色方案：保留系统/light/dark，新增 candy 等高辨识度 palette；代码块、diff、terminal output 仍使用语义色而不是简单整体换色。
- 多连接架构需要独立设计 `HostSessionManager` 或等价控制器：每个 host 维护独立 `CodexSessionStateController`、thread cache、approval 归属和后台保活策略。

当前实现状态：

- 已落地本地多 SSH profile 保存、按 host 分组折叠、保存项删除、OpenSSH config 导入、私钥文件导入、RSA / ED25519 密钥生成和 public key 复制/导出；私钥走 secure profile store 持久化，不放普通 cache。
- 本轮加固了生产 SSH profile store wiring：默认 App 入口统一使用 `defaultSshProfileStore`，其组合固定为 SharedPreferences metadata + FlutterSecureStorage secrets；新增测试直接断言默认组合，并验证导入私钥、密码、passphrase 不会写入 SharedPreferences metadata，重新加载时由 durable credential store 回填。
- 已统一主机显示原则：保存主机和会话状态优先显示用户别名；无别名时显示 host/IP，不把 `user@host:port` 当作默认标题。
- 已对齐手动保存与 OpenSSH config 导入的 profile id 规则：用户填写别名时，同一 `user@host:port` 下的不同别名会保存为不同 profile，并在同一 host 分组下折叠展示；无别名时仍回退到 endpoint id，避免普通单主机配置产生重复项。
- 已加固 OpenSSH config 导入的条件段边界：`Match` 条件块不会被当作普通 Host 配置继续套用到前一个主机或全局默认；当前移动端导入只解析明确的 `Host` 段，条件配置留待后续显式能力设计。
- 已落地 Chat 顶栏主机选择器、Settings 二级菜单、candy/lagoon/ember palette 和斜杠命令高级可见性开关。
- Settings 菜单已明确收敛为最多二级：一级分组为 Codex、Interface、Connection、System，二级才进入 Permissions、Account、Models、Appearance、SSH、Diagnostics；Diagnostics 默认折叠在 System 下，避免低频诊断项和常用设置平铺混杂，窄屏仍保持“菜单页 -> 具体设置页”的单详情导航。
- 本轮 Chat 可见 UI 里程碑已压低 AppShell 底部 `NavigationBar` 高度到 58px，先减少主对话页被全局导航占用的垂直空间。后续二级 Chat detail 路由方案记录为：主页 -> 对话 -> 选择已连接服务器/session 或新建 session -> 对话详情；对话详情页隐藏 bottom nav，由详情页自己的左上返回/侧栏入口承担导航。
- 本轮 Chat UI / timeline 性能里程碑保持 9.7.1 的二级 Chat detail 路由为后续设计，不在本轮重做导航架构；当前只增强 Chat 页面内侧栏动效、气泡阅读宽度、字体一致性和 timeline 按需加载。
- 已落地配置覆盖三层恢复入口：Settings 可一键清除 App 默认覆盖、会话覆盖和本次覆盖并回到服务器默认来源；本地恢复动作不伪造 `thread/settings/update` 普通字段显式清理语义。
- 已落地 per-host pending approval 聚合与动作路由：Approvals 页面展示所有已连接 host 的待审批项，审批响应回到所属 host 的 `ApprovalStateController`。
- 已落地 per-host thread summary/detail cache 持久化/恢复：每个 host 的最近线程列表、选中 threadId 和当前 thread detail 通过 `ThreadCacheStore` 独立保存，重建 host UI state 时优先恢复缓存，再由远端权威 thread/detail 读取刷新。
- 已落地 per-host thread item cache reader、timeline 恢复和 reconnect fallback：`ThreadItemCacheStore` 按 profile/thread 隔离保存 item summaries 和分页游标，`local_data` schema 已补 `item_cache.profile_id` 与 profile/thread 索引；`CodexSessionStateController.threadItemListReader` 已通过缓存 decorator 保存/回退 canonical thread item 读取，host UI state 恢复选中 thread 时会从 item cache 回填 timeline；重连时 `thread/turns/list(itemsView: full)` 会有界分页回填当前 thread，若 turn list 不可用或失败，会尝试 `thread/items/list` 有界分页回填 timeline；turn/item 分页边界按 id 去重，优先保留新页数据。
- 已落地删除 SSH profile 时清理 per-host 普通重连缓存：`ThreadCacheStore`、`ThreadItemCacheStore` 与 `ThreadTimelineCursorStore` 的 SharedPreferences 实现支持按 profile 删除本地 thread summary、item cache 和 delivered cursor/timeline cursor；Hosts 页面删除主机配置时会 best-effort 清理这些非敏感缓存，避免已删除主机的会话状态残留。
- 已落地 timeline 本地 event cursor 快照基础：`ChatTimelineController.cursor` 可从当前 selected thread 的 turns/items 派生已见 turnId/itemId、lastTurnId 和 lastItemId，供后续持久化 cursor、断线增量回填和 agent delivered cursor 对接。
- 已落地 per-host timeline cursor 持久化基础：`ThreadTimelineCursorStore` 按 profile/thread 保存已见 turnId/itemId、lastTurnId/lastItemId，并由 `AppHostSessionUiState` 监听 timeline 变化进行 best-effort 写入；后续 reconnect 可基于该持久化 cursor 对接 agent delivered cursor 和增量回填。
- 已落地 cursor-aware reconnect backfill 基础：`AppSessionRecoveryCoordinator` 可读取 host/thread 持久化 timeline cursor，turn 分页回填遇到 lastTurnId 会保留边界 turn 后停止继续翻旧页；item fallback 遇到 lastItemId 后从边界 item 开始恢复并继续读取后续页，边界缺失时回退为旧的 bounded page 行为。
- 已落地 agent delivered cursor wire 基础：`sadcoder-agent` reconnect cache 会为 recent event 分配递增 cursor 并在 snapshot 上记录 `deliveredCursor`；Rust protocol 与移动端 `AgentSnapshot` 均已支持 camel/snake case cursor 字段解析，为后续按 delivered cursor 请求增量事件做准备。
- 已落地 agent thread snapshot 基础：`agent/snapshot` 可额外返回从 app-server 事件和 pending request 中提取的 threadId、lastTurnId、lastItemId 与 lastEventCursor，移动端已解析该可选 `threads` 字段并用于 per-thread delivered cursor/gap 合并和 last turn/item 边界持久化，为后续更完整的 thread reconciliation 提供结构化事实来源。
- 已落地移动端 agent delivered cursor 本地合并：`CodexSessionStateController` 会发布已确认的 agent snapshot stream，`AppHostSessionUiState` 监听后按 snapshot recent event 的 threadId 将 `deliveredCursor` 合并写入对应 profile/thread 的 `ThreadTimelineCursorStore`，且 timeline cursor 持久化会保留已有 delivered cursor。
- 已落地 agent snapshot 增量读取基础：`agent/snapshot` 支持 `sinceCursor`/`since_cursor` 参数并只返回 cursor 之后的 retained recent events，pending approvals 仍全量返回；移动端 `AgentSnapshotReader` / `CodexAppServerClient.agentSnapshot` 已支持透传 `sinceCursor`，`CodexSessionStateController` 可通过注入的 cursor provider 在 backfill snapshot 时使用该 cursor。
- 已落地 pending approval snapshot 权威同步：移动端回填 `agent/snapshot` 时会把 snapshot 前已存在但不在远端全量 pending approvals 中的本地审批清理掉，同时保留 snapshot 读取期间新到的实时 server request，避免重连后陈旧审批残留或误删竞态。
- 已落地移动端 snapshot cursor 接线：`AppAgentSnapshotCursorProvider` 会优先读取 active turn thread 的内存/持久化 delivered cursor，其次使用当前选中 thread，必要时回落到 thread cache 的上次选中 thread 和 `ThreadTimelineCursorStore`；如果 active thread 没有 cursor，则保守返回空 cursor 触发完整 snapshot，避免用无关 thread 的 cursor 跳过正在运行任务的事件；没有任何候选 thread 时会清空本次 resolved thread，避免后续 cursor gap fallback 误用旧线程；默认 `AppShell` 创建的单 host 与 `HostSessionManager` session controller 都会把该 provider 接入 `CodexSessionStateController.snapshotCursorProvider`。
- 已落地 snapshot CLI cursor fallback：`sadcoder-agent snapshot --since-cursor ... --json` 与 proxy `agent/snapshot` 共享 retained event 过滤语义；移动端 `AgentRemoteService.readSnapshot` 会把 `sinceCursor` 传给独立 SSH fallback 命令，避免旧兼容路径退回全量 snapshot。
- 已落地 reconnect cache cursor/thread 诊断：`AgentReconnectCacheStatus` / `agent status` / `doctor` 会暴露最新 `deliveredCursor`、pending approval 数、recent event 数和 thread snapshot 数，移动端 agent status 解析与 Hosts/Settings 诊断页会展示这些值，便于确认重连增量 snapshot 使用的事实来源。
- 已落地 Hosts / Settings Diagnostics 的 agent version 展示：主机探测结果与 Settings agent doctor 卡片会显示 `AgentStatus.agentVersion`，便于排查 App 与 sadcoder-agent 版本不匹配。
- 已落地 Settings Diagnostics 的 App version 展示：Diagnostics 顶部会显示移动端包版本 `sadcoderMobileAppVersion`，并与 agent version、Codex version 放在同一只读诊断入口；app-server initialize 仍使用独立的 `sadcoderMobileClientVersion`，避免把发布包版本和协议 client version 混用；测试会对齐 `sadcoderMobileAppVersion` 与 `pubspec.yaml` 的 `version`，防止发布版本漂移。
- 已落地 Hosts / Settings Diagnostics 的 Codex failure 展示：`sadcoder-agent doctor --json` 中 command diagnostic failure 与 `AgentStatus.codexFailure` 会作为独立结构化行展示，避免 Node/NVM 运行时错误、非零退出、路径缺失等被压缩成模糊的“Codex 不可用”摘要。
- 已落地 Hosts 探测结果的 backend readiness 展示：agent status 摘要会显示 backend kind 与 state，例如 SadCoder service / ready 或 stdio fallback / unavailable，避免只看到后端类型而不知道可用性。
- 已落地 Hosts 页面 `agent/stopBackend` UI 入口：已连接状态下可在主机表单中停止当前 host 的 SadCoder backend，操作前必须二次确认；确认后调用现有 `CodexSessionStateController.stopBackend()` 并停留 idle，不自动重连，失败时使用本地化摘要并保留底层错误详情。
- 已落地 agent snapshot 缓存窗口诊断：`AgentStateSnapshot` 会暴露 `retainedCursorFloor` 与 `cursorGap`，当客户端 `sinceCursor` 早于 agent retained recent event 窗口或无法在窗口中确认时标记 gap，为后续触发更保守的 thread/read、turn/item 分页 reconciliation 做准备。
- 已落地 cursor gap 驱动的移动端保守恢复：`AppHostSessionUiState` 会把 agent snapshot 的 `cursorGap` 映射到对应 thread 的一次性 recovery hint；`AppSessionRecoveryCoordinator` 在 gap 存在时不再用本地 lastTurnId/lastItemId 提前截断 turn/item 有界回填，并会在 snapshot 晚于 connected 状态到达时主动对当前 thread 再触发一次恢复。
- 已落地 cursor gap 的延迟 thread 切换恢复：如果 agent snapshot gap 属于非当前 thread，App 不会立刻切换 UI；用户之后打开该 thread 时，`AppHostSessionUiState` 会消费对应 gap hint 并触发一次保守 turn/item 回填，避免断线期间非当前 thread 的事件缺口长期停留。
- 已落地未知归属 cursor gap 的保守恢复：当 agent snapshot 只报告 `cursorGap=true` 但没有 recent event/thread id 可归因时，App 会保留一个 unknown gap 信号；用户之后打开任一尚未消费该 gap 的 thread 时，会按保守策略有界回填，避免因为缺少 thread id 而误用旧 cursor 提前截断。
- 已落地明确归属 cursor gap 的即时恢复路由修正：当 snapshot gap 明确属于当前可见 thread，而另一个 thread 有 active turn 时，恢复目标会绑定到该 gap thread，不再通过 active-thread-first 的 `recoverCurrentThread()` 误切到无关 active thread；测试覆盖 pending snapshot 到达时的 selected-gap + unrelated-active-turn 场景。
- 已落地 active turn snapshot gap 恢复：当 `agent/snapshot` 先标记 cursor gap、随后才回放 `turn/started` recent event 时，`AppHostSessionUiState` 会在 active turn 建立后再次检查该 thread 的 gap hint，并触发现有保守 turn/item 回填；无需用户先打开会话详情，也不会把恢复目标错误绑定到当前 UI 选中 thread。
- 已落地显式 thread cursor-gap 恢复入口：当 UI 已知缺口归属的 threadId 时会直接调用 `recoverThread(threadId)`，不再通过 active-thread-first 的 `recoverCurrentThread()` 路由，避免用户打开非 active 缺口会话时被正在运行的 active turn 抢走恢复目标。
- 已补强 agent snapshot per-thread cursor 合并：当 `threads[].lastEventCursor` 已经比 retained `recentEvents[].cursor` 更新时，移动端持久化 delivered cursor 不会被旧 recent event 回退；可比较的数字 cursor 与带数字后缀的 legacy/test cursor 都按只前进策略合并，避免下一次 `sinceCursor` 重复拉取旧事件。
- 已落地 agent `--backend auto` 的 service-only 生产语义：auto 会启动并连接 SadCoder service，service 启动或 proxy 连接失败时返回错误，不再静默降级到 direct stdio；direct stdio 仅保留给显式 `--backend stdio` 或兼容 `--backend daemon` 路径。
- 已落地后台 active-turn retention 的上下文刷新：App 后台且 active turn 仍需保活时，如果 host/thread/turn context 变化，会释放旧 foreground retention 并用新 context 重新 retain，避免 Android 通知和保活上下文停留在旧 turn。
- 已落地后台 active-turn retention 连接丢失后的前台恢复：如果 App 后台期间保留的 active-turn 观察连接自行断开，lifecycle coordinator 会释放 retention 并标记 foreground resume，回到前台后重新恢复观察连接。
- 已落地服务端 turn/started 事件驱动的 active turn 跟踪：`ChatTimelineController` 会把 `turn/started` 通知传给 host UI state，`TurnController` 可据此跟踪非本机提交但正在运行的 turn；AppShell 后台保活 context 会优先当前 host，必要时扫描已连接 host UI states，确保切到其他 host 后仍能为已有 active turn 建立 foreground retention。
- 已落地多 host 后台 active-turn 监听扩展：AppShell 的 lifecycle coordinator 会监听已创建 host UI states 的 `TurnController`，managed host 切到后台后仍保持各自 event subscription；如果 App 已在后台时 inactive host 后续收到 `turn/started`，也会触发 foreground retention context 刷新。
- 已落地 host UI state 自主观察 session status：每个 `AppHostSessionUiState` 会监听自己的 `CodexSessionStateController`，连接成功后自行恢复缓存、触发 reconnect recovery 并刷新 slash command manifest；AppShell 不再只把 active session status 转发给当前页面，避免 inactive host 切换前漏掉线程刷新和重连恢复。
- 已落地同一 host 的并发连接请求合并：`HostSessionManager` 会按 profileId 复用在途 connect Future，避免重复点击或快速切换时对同一个 `CodexSessionStateController` 发起重入连接；显式 disconnect/close 会释放该在途记录，失败后可重试。
- 后续仍需完整多 host 同时连接架构：`HostSessionManager` 已作为基础控制器引入，但完整后台保活策略、断线期间事件 cursor/分页增量回填和更完整的 reconnect turn/item reconciliation 还需要继续拆分完善。

### 9.8 i18n

首版语言：

- `zh-CN`
- `en-US`

规则：

- 所有可见文本必须进资源文件。
- 错误消息可以保留底层英文 raw detail，但必须有中文摘要。
- 时间、数字、文件大小按系统 locale 格式化。

当前实现状态：

- 已覆盖 `en-US` / `zh-CN` 基础资源完整性、数字/日期/文件大小格式化和斜杠命令说明本地化；Chat 中 `/rollout`、`/test-approval`、`/debug-config` 未知来源/未知 layer 标签和 `/plugins` 本地版本标签等可见诊断/摘要文本已移入资源文件，避免 debug/diagnostic/summary 路径继续硬编码英文 UI。
- 已新增通用 `messageWithDetail` 资源化 formatter，并在 Host/Settings/Files/Chat 的用户可见失败详情和 Chat 摘要模块中使用；Chat 的 debug config、experimental、memories、MCP、usage、status、skills/plugins/hooks/apps/diff 与 permission profile 加载失败会保留 raw detail，但摘要与详情之间的分隔符按当前 locale 渲染（英文 `: `，中文 `：`），不影响 raw JSON、路径、配置 key 或协议 enum 的原样展示。
- 已将 Hosts 页面 SSH config 空导入、私钥导入未包含 PEM private key block 这类 App 自己生成的失败详情移入资源文件：中文界面不再显示英文 `FormatException`、`No importable SSH Host entries found.` 或 `No PEM private key block found.`，同时继续保留真实底层 raw error detail 的原样展示策略。
- 已将 Terminal 缺少 command exec runner 的 App 生成失败改为 typed `TerminalSessionException`，UI 按 failure code 映射到本地化详情：中文界面不再显示英文 `No active command exec session` 或 Dart `Bad state` 包装；未知底层错误仍保留 raw detail。
- 已将 Hosts 页面常见用户操作失败增加本地化摘要：已保存 profile 加载/保存失败、连接失败、断开连接失败和 backend 重启失败都通过 `messageWithDetail` 显示当前 locale 摘要并保留底层 raw detail；连接状态卡优先显示用户刚触发的 action error，避免 controller raw error 遮住本地化摘要。
- 已将 Hosts 手动 SSH/M0 probe 失败和 Chat 高级 Raw RPC 发送失败增加本地化摘要；高级诊断面板仍显示底层 raw exception detail，但中文界面不再只有英文/Dart 异常文本。
- 已将 Hosts 手动 SSH/M0 probe 的 agent status 摘要格式移入资源文件：平台、架构、Codex 版本或结构化失败详情作为占位符填充，中文界面显示本地化摘要，同时继续保留 `runtime-not-found`、stderr 等底层 raw detail 供诊断。
- 已将 TurnController 自己生成的常见失败改为 typed `TurnControllerException`：无 active Codex session、已有 active turn、缺失 thread id、无可中断 turn 和 turn transition 冲突都会在 Chat 顶部状态槽与 `/status` 摘要中按当前 locale 显示；runner/app-server 传回的真实异常仍保留 raw detail，不做字符串匹配翻译。
- 已将 Settings 页面 account/model/server config/agent doctor/agent Codex configure/schema/logs 的加载或保存失败统一为本地化摘要 + raw detail：中文界面不再只显示 `Bad state: ...`，同时保留底层异常、远端 stderr 或诊断细节。

## 10. 本地数据模型

建议本地数据库表：

- `ssh_profiles`
- `known_hosts`
- `connection_history`
- `thread_cache`
- `item_cache`
- `pending_approvals`
- `app_settings`
- `codex_config_snapshots`
- `codex_override_profiles`
- `slash_command_manifest_cache`
- `slash_command_usage_history`
- `raw_rpc_logs`

缓存原则：

- 服务器 Codex 状态是权威来源。
- 本地缓存只用于离线浏览、快速恢复 UI、诊断。
- Codex override profile 只记录 SadCoder 显式覆盖，不代表服务器真实配置。
- 不在手机上长期保存敏感项目文件内容，除非用户明确打开并缓存。

## 11. 安全设计

### 11.1 凭据

- SSH 私钥和密码/passphrase 使用 Android Keystore 与 iOS Keychain 加密。
- 支持生物识别解锁 profile。
- 不把 OpenAI API key 存到手机，除非用户明确选择“从手机写入服务器 Codex 登录”。推荐让 Codex 凭据留在服务器 `CODEX_HOME`。
- 登录流程优先通过 app-server `account/login/start` 的 device code/browser URL，让服务器端 Codex 自己持久化 token。
- App 默认不写服务器 Codex 配置；任何 `config/value/write` 或 `config/batchWrite` 都必须由用户从高级配置入口显式触发。

### 11.2 权限与审批

- 默认权限模式不应是 `danger-full-access`。
- UI 明确显示当前 approval policy 和 sandbox/permission profile。
- 对 `danger-full-access`、`approvalPolicy=never` 组合显示高风险标记。
- 审批操作需要防误触：高风险命令或大 diff 可要求二次确认。

当前实现状态：

- Settings/Chat status 会显示当前 approval policy、sandbox/permission profile，并对 `approvalPolicy=never`、`dangerFullAccess`/`:danger-full-access` 这类高风险状态显示明确 warning。
- `/permissions` 在应用 turn/session 权限覆盖前会重新判定高风险状态；命中 `approvalPolicy=never`、`dangerFullAccess` sandbox 或 `:danger-full-access` permission profile 时，必须通过二次确认才写入本地 override，取消不会启动 turn，也不会修改已有覆盖。
- 审批页已对高风险命令和大 diff 加二次确认；移动端 `/setup-default-sandbox`、`/sandbox-add-read-dir` 这类高风险斜杠命令在真正落地 fallback 前也需要确认。

### 11.3 日志脱敏

日志默认脱敏：

- passwords
- private keys
- API keys
- access tokens
- Authorization headers
- cookie-like values

导出日志前再次提示用户可能包含路径、命令、项目名。

当前实现状态：

- JSON-RPC diagnostic log buffer 默认通过 `LogRedactor` 保存 redacted payload，并在复制/导出前再次弹出确认，提示可能包含路径、命令和项目名。
- agent/app-server service logs 在进入移动端模型与 Settings UI controller 前都会再次通过 `LogRedactor` 脱敏；`content` 与 `error` 会清理 password、private key、API key、access token、Authorization header 和 cookie-like values，日志 path、大小、tail/truncated 等诊断元数据保留。

## 12. 测试计划

### 12.1 单元测试

- SSH config parser。
- JSON-RPC dispatcher。
- agent proxy stream codec。
- app-server event mapper。
- approval decision mapper。
- Codex config source/override precedence resolver。
- SlashCommandRegistry：命令、别名、inline args、active turn 可用性、平台可见性。
- slash command mapper：确保命令不会默认落入普通 prompt。
- reconnect state machine。
- i18n resource completeness。

### 12.2 集成测试

使用本地或 CI Linux 容器，以及一台 Windows 测试机/Runner：

- 安装 Codex CLI。
- 安装或启动 `sadcoder-agent`。
- Linux backend 覆盖 `sadcoder-agent service/proxy` 与 direct stdio fallback。
- Windows backend 覆盖 `sadcoder-agent service/proxy` 与 direct stdio fallback。
- 通过 `sadcoder-agent proxy` 完成 initialize。
- 执行 thread start/resume/list。
- 模拟 item streaming。
- 模拟审批请求。
- 模拟 SSH/channel 断开和重连。
- 验证 SSH/channel 断开不会触发 `turn/interrupt`，不会杀掉 agent-managed app-server。
- 验证断线期间审批请求保持 pending，重连后仍可由用户决策。
- 验证只有 App 明确发送 interrupt/cancel 指令时，agent 才转发中断。
  - 已补充移动端 session 层快速覆盖：`connection.done` 模拟 SSH/channel 断开后进入 reconnect，不清 pending approval，不经过 disconnecting 状态，且 fake connection method log 明确断言自动重连不会出现 `turn/interrupt`；同一测试再显式调用 `TurnRunner.interruptTurn`，验证只有明确中断路径会记录 `turn/interrupt`。
- 验证未设置覆盖时，`thread/start` / `turn/start` 不发送覆盖字段，沿用服务器 Codex 配置。
  - 已补充协议层覆盖：`startThread` 只发送空 `thread/start` params，默认 `startTurn` 只发送 `threadId` 和 `input`，并显式断言不包含 model/effort/cwd/personality/serviceTier 等覆盖字段。
- 验证本次 turn、本会话、App 默认覆盖的优先级正确。
  - 已补充 turn controller 覆盖：提交文本前会先解析覆盖层，App 默认保留未被覆盖字段，会话覆盖 App 默认，本次 turn 覆盖会话/App 默认后再传给 `turn/start` runner。
- 验证普通覆盖不会调用 `config/value/write` 或 `config/batchWrite`。
  - 已补充移动端协议层快速覆盖：普通 one-turn override 只发 `turn/start`，普通 thread/session override 只发 `thread/settings/update`，method log 明确不包含 `config/value/write` 或 `config/batchWrite`。
- 验证清除会话覆盖时只对上游支持显式清除的字段发送 `null`，例如 `serviceTier`；普通 `Option<T>` 字段不得用 `null` 伪装成恢复服务器默认。
  - 已补充协议层覆盖：`updateThreadSettings` 在清理空字段时只发送 `serviceTier: null`，普通空白 `model` / `effort` / `cwd` / `personality` 字段不会出现在 `thread/settings/update` 参数中。
- 验证当前 Codex 斜杠命令 manifest 覆盖 `/model`、`/ide`、`/permissions`、`/keymap`、`/vim`、`/setup-default-sandbox`、`/sandbox-add-read-dir`、`/experimental`、`/approve`、`/memories`、`/skills`、`/import`、`/hooks`、`/review`、`/rename`、`/new`、`/archive`、`/delete`、`/resume`、`/fork`、`/app`、`/init`、`/compact`、`/plan`、`/goal`、`/agent`、`/side`、`/btw`、`/copy`、`/raw`、`/diff`、`/mention`、`/status`、`/usage`、`/debug-config`、`/title`、`/statusline`、`/theme`、`/pets`、`/mcp`、`/apps`、`/plugins`、`/logout`、`/quit`、`/exit`、`/feedback`、`/rollout`、`/ps`、`/stop`、`/clear`、`/personality`、`/test-approval`、`/subagents`、`/debug-m-drop`、`/debug-m-update`。
- 验证别名 `/clean -> /stop`、`/pet -> /pets`、`/approve -> AutoReview`、`/subagents -> MultiAgents`。
  - 已补充 registry 层覆盖：别名/重命名变体不仅解析到 canonical command，还断言 `/clean` 的 background-terminal 语义、`/pet` 的 TUI-only not-applicable 语义、`/approve` 的 auto-review 语义和 `/subagents` 的 topology/subagent-tree 语义。
- 验证 active turn 中不可用的斜杠命令被禁用，不会触发隐式 `turn/interrupt`。
  - 已补充 Chat widget 层覆盖：active turn 时命令面板将不可用命令（例如 `/delete`）置灰并显示不可用原因，同时 fake turn runner 未记录任何 `turn/interrupt`。
- 验证 `/quit`、`/exit` 只断开 App/proxy，不停止服务器上的 active turn。
  - 已补充 Chat widget 层覆盖：`/quit` 和 `/exit` 都通过真实 composer 提交流程断开 mobile proxy，session 回到 idle，且 fake turn runner 未记录任何 `turn/interrupt`。
- 验证 `/stop` 只作用于后台 terminal/process，不等价于 `turn/interrupt`。
  - 已补充 Chat widget 层覆盖：active turn 中 `/stop` 只调用当前 thread 的 background terminal clean，未启动新 turn，且 fake turn runner 未记录任何 `turn/interrupt`。
- 验证 unknown slash command 被显示为未支持或需要 raw fallback，不会静默作为普通 prompt 发送。
  - 已补充 Chat widget 层覆盖：unknown slash 会显示 `Send as text` 显式入口，默认发送按钮不可用，fake turn runner 未记录新 turn 或 `turn/interrupt`；只有用户显式选择发送为文本后才会启动 turn。
- 验证 `/side`、`/btw` 创建 ephemeral fork 时不会 interrupt main thread，side 返回/丢弃不会影响 main thread active turn。
- 验证 side thread 注入 boundary prompt，side 内不允许再次 `/side`，不允许 rename/review 等不适合 side 的命令。
  - 已补充 runner 层覆盖：`startSideConversation` 使用 `thread/fork ephemeral=true` + developer instructions，并通过 `thread/inject_items` 注入 side boundary prompt，注入失败时 best-effort 删除 side thread。
  - 已补充 dispatcher 层覆盖：side conversation 模式下 `/fork`、嵌套 `/side`、`/rename`、`/review` 均返回 unavailable 且不调用对应 handler；`/status` 等允许命令仍可执行。
- 验证 `/agent`、`/subagents` 的只读拓扑可以从 `parentThreadId`、`ancestorThreadId`、`CollabAgentToolCall`、`SubAgentActivity` 回填，并正确区分 running、closed、errored 状态。
  - 已补充 Chat widget 层覆盖：`/agent` 拓扑弹层同时展示 running/closed/errored agent runtime status，且状态色用于区分运行、关闭和错误的子 agent 条目。
  - 已补充 Chat widget 层覆盖：`/subagents` 弹层只展示子 agent 条目，并验证显式 parent/ancestor 子线程和当前 thread 中 `CollabAgentToolCall` / `SubAgentActivity` 回填的子 agent 会同时展示 status、role、agent path、parent 和 ancestor 信息，切换子 agent thread 不启动新 turn。

### 12.3 移动端 QA

- Android/iOS 真机深色/浅色模式。
- 网络切换：Wi-Fi -> 4G/5G -> Wi-Fi。
- App 前后台切换。
- Android active turn 时 foreground service 保活。
- iOS 后台限制下的断线恢复和状态回填。
- 长输出 command rendering。
- diff 大文件渲染性能。
- host key 变化阻断。

### 12.4 兼容性矩阵

服务器：

- Ubuntu LTS x86_64。
- Debian x86_64。
- Windows 10/11 x86_64，启用 OpenSSH Server。
- Windows Server 2022+ x86_64，启用 OpenSSH Server。
- macOS arm64 作为可选自测目标，不作为首版承诺。

移动端：

- Android 10+ 作为最低目标候选。
- Android 13+ 通知权限专项测试。
- iOS 16+ 作为自编译安装目标候选。
- iOS 后台长连接不作为首版承诺。

## 13. 里程碑

### M0：协议探针

目标：证明移动端协议栈可以通过 SSH 连接 Linux/Windows 上的 Codex app-server。

交付：

- Dart/Flutter 命令行或最小 App 原型。
- SSH 连接 Linux 与 Windows 远端。
- `sadcoder-agent status/start/proxy`。
- Linux backend 覆盖 SadCoder service 后端和 direct stdio fallback。
- Windows backend 覆盖 SadCoder service 后端和 direct stdio fallback。
- `initialize`、`thread/list`、`model/list`。

### M1：移动端 MVP

目标：Android 可连接 Linux/Windows 服务器并完成基础 Codex 对话；iOS 工程可自行编译安装并跑通主流程。

交付：

- SSH profile UI。
- 测试连接。
- Session list。
- Chat 页面。
- `thread/start/resume`。
- `turn/start` 流式输出。
- `turn/interrupt`。
- command/file/MCP item 基础渲染。
- command/file approval。
- 深色模式。
- zh-CN/en-US。
- MVP 斜杠命令面板和核心命令映射。

### M2：可用性完善

目标：弱网和移动场景可用。

交付：

- Android foreground service。
- iOS 断线恢复与打开 App 后状态回填。
- 自动 keepalive。
- 自动重连。
- 回填丢失 turns/items。
- 通知入口。
- 本地日志与导出。
- account/model/config 基础设置。

### M3：Codex 功能扩展

目标：覆盖大部分 Codex CLI/app-server 能力。

交付：

- fork/duplicate/rewind。
- goal/compact。
- workspace file browser：目录树浏览、只读文件查看、range read 大文件加载、代码高亮、Markdown render/raw 切换。
- shell command / command exec。
- MCP server status/oauth。
- plugin/skill marketplace。
- review。
- rate limits/usage。
- 第二阶段斜杠命令完整映射：review/fork/compact/goal/diff/mention/usage/MCP/plugin/skill/hooks/logout/background terminals。
- `/side`、`/btw` 实验支持：ephemeral fork、side boundary prompt、side/main 切换、审批归属、断线降级。

### M4：高级能力

目标：接近完整 Codex 控制台。

交付：

- realtime。
- process/spawn。
- remote environments。
- hooks。
- external agent config import。
- doctor/update/apply/cloud 的结构化或 SSH fallback UI。
- 第三阶段斜杠命令、调试命令和平台专属命令覆盖。
- `/agent`、`/subagents` 多 agent 拓扑：只读树、agent picker、thread 切换、状态回填；主动控制能力另行评估。

## 14. 风险与对策

### 14.1 sadcoder-agent 增加维护面

风险：

- 为了 Windows/Linux 一致保活，需要维护 agent 安装、服务、proxy、日志和升级。

对策：

- agent 功能保持薄层：只做生命周期与代理，不重写 Codex 业务语义。
- 所有 Codex 能力仍走 app-server JSON-RPC。
- agent RPC 限定在 `agent/*` 命名空间。
- 做 Linux/Windows CI 和集成测试。

### 14.2 Codex app-server daemon 只作为兼容背景

风险：

- 官方 daemon/proxy 协议可能变化，但 SadCoder 生产路径不依赖它。

对策：

- 做版本探测。
- 保留 direct stdio debug fallback。
- agent 支持 service/proxy 与 direct stdio fallback，避免把官方 daemon 作为唯一依赖。
- 客户端 JSON-RPC 通用化，不把所有 method 写死。
- 建立 Codex 版本兼容矩阵。

### 14.3 Agent proxy 与 app-server 连接恢复复杂

风险：

- agent 需要在移动端断开后继续持有 app-server，并在重连后恢复 thread 状态、事件缓存和 pending approval。
- app-server 发起审批 request 时，如果手机在线程断开，agent 不能响应取消，也不能让 request 因代理生命周期被清理。

对策：

- M0 先实现单连接、单 active thread。
- M1 再实现事件缓存和 request id 重写。
- pending approval 采用明确策略：默认等待重连和用户决策，不自动拒绝、不自动取消、不自动 interrupt。
- agent 的上游 app-server 连接和下游手机 proxy 连接分离；下游断开只移除订阅，不关闭上游 active turn。
- 保留 direct stdio debug 模式定位问题。

### 14.4 手机后台限制

风险：

- Android 和 iOS 都会限制后台长连接，iOS 更严格。

对策：

- Android active turn 用 foreground service。
- iOS 不承诺长期后台实时连接，依赖 agent 继续执行和重连回填。
- 非 active turn 不承诺实时连接。
- reconnect + backfill 保证最终一致。

### 14.5 长任务与断线恢复

风险：

- 断线期间丢失事件。
- 断线期间用户可能误以为任务已停止，实际任务仍在服务器继续运行或等待审批。

对策：

- agent-managed service/app-server 保持服务端进程。
- 重连后用 `thread/read`、`thread/turns/list`、`thread/items/list` 回填。
- 本地 event cursor 记录最后已见 turn/item。
- UI 明确区分“手机已断开/未实时观察”和“服务器任务已中断/已完成”。
- 只有 App 发出用户明确触发的 `turn/interrupt`，agent 才转发中断；断线、后台、重连失败都不能隐式中断。

### 14.6 “所有 CLI/斜杠功能”范围过大

风险：

- Codex CLI 有些子命令不是 app-server API。
- Codex TUI 斜杠命令会随版本变化，且部分命令只在特定平台、debug build 或 feature flag 下可见。
- 如果 App 把 `/xxx` 当作普通 prompt 发送，用户会误以为执行了 Codex 命令，实际可能只是让模型看到一段文本。
- `/side`、`/btw`、`/agent`、`/subagents` 涉及多 thread 拓扑，容易把 main thread、side thread、subagent thread 的事件、审批和中断语义混在一起。

对策：

- 定义覆盖策略：app-server 优先，CLI-only 功能走 SSH command fallback。
- 斜杠命令进入 `SlashCommandRegistry`，每条命令必须有映射类型、阶段、可用性和 fallback 状态。
- CI 对比当前 Codex slash manifest，新增/删除/改名命令必须显式处理。
- 输入框斜杠解析默认走命令面板，只有用户显式选择时才按普通文本发送。
- 会话拓扑功能分期实现：`/side`、`/btw` 先做 ephemeral fork 最小可用；`/agent`、`/subagents` 先做只读拓扑和切换查看，主动控制能力单独评估。
- 所有拓扑切换都必须携带明确 threadId，审批、事件回填和 interrupt/cancel 必须绑定到具体 thread/turn，不能使用“当前 UI 所在页面”做隐式目标。
- UI 分阶段结构化。
- 提供高级 Raw RPC/Command 面板用于临时覆盖新能力。
  - Raw RPC 已先接入 Chat 高级折叠区并带确认；Raw Command/SSH fallback 仍需后续单独设计审计、确认和敏感信息处理。

## 15. 需要定夺的问题

1. 首版服务器是否同时支持 Linux 和 Windows？
   - 推荐：是。为此把 `sadcoder-agent` 提升为生产路径；SadCoder service 统一承接 Linux/Windows。

2. 是否接受服务器除官方 `codex` 外再安装一个 `sadcoder-agent`？
   - 推荐：接受。否则 Windows 上很难可靠保活；`sadcoder-agent` 保持薄层，不 fork Codex。

3. MVP 是否必须支持手机后台长时间实时收审批？
   - 推荐：Android active turn 用 foreground service 支持；iOS 不承诺长期后台实时收审批，依赖重连回填。

4. Codex 登录凭据放哪里？
   - 推荐：放服务器 `CODEX_HOME`，手机只触发/展示登录流程，不长期保存 OpenAI 凭据。

5. 是否要做 Flutter 跨端？
   - 推荐：是。Android 主发布，iOS 工程保持可自行编译安装。

6. 是否要 fork Codex 或魔改 Codex？
   - 推荐：MVP 不 fork。只有官方 app-server 加 `sadcoder-agent` 仍无法满足核心目标时再评估。

## 16. 当前推荐决策

首版采用：

- App：Flutter + Material 3，Android 主发布，iOS 可自行编译安装。
- 通信：SSH + `sadcoder-agent proxy`。
- 协议：Codex app-server JSON-RPC。
- 服务端：Windows/Linux 安装官方 `codex` + `sadcoder-agent`。
- 模式：生产默认 agent-proxy；SadCoder service 作为长期 backend；调试 fallback 为 direct stdio。
- 功能优先级：任务不断线执行、连接可靠性、线程/turn、流式 item、审批、重连、基础配置。

暂不采用：

- Happy Server 云中转。
- TUI/ANSI 屏幕抓取。
- `codex exec` 作为主通信方式。
- fork Codex。
