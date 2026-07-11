# SadCoder 跨平台移动 App 设计计划

## 0. 目标摘要

SadCoder 的目标不是在手机上“模拟一个终端”，而是让移动 App 通过 SSH 直连服务器，并以结构化协议监管服务器上的 Codex：能查看会话、发送消息、接收流式事件、处理审批、管理线程、执行命令、调整配置，并尽量覆盖 Codex CLI 暴露的能力。

推荐方向：

1. App 端兼顾 Android 和 iOS；Android 是主要发布目标，iOS 用户可以自行编译安装。
2. 服务端兼顾 Linux 和 Windows；为跨平台保活与生命周期管理，引入 `sadcoder-agent` 作为轻量 Rust 常驻层。
3. Codex 业务协议仍以官方 `app-server` JSON-RPC 为核心；`sadcoder-agent` 负责启动、持有、代理和恢复 app-server 连接。
4. Linux/Windows 统一由 `sadcoder-agent service` 管理长期 app-server；调试或 service 启动失败时才使用 direct stdio fallback，不依赖官方 standalone daemon。
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

- Linux：`sadcoder-agent service` 独立于 SSH channel 启动并长期持有 `codex app-server --listen unix://...`；`proxy` 只连接 service socket，direct stdio 仅作为调试/降级 fallback。
- Windows：`sadcoder-agent service` 使用用户级后台进程/计划任务等方式管理 `codex app-server` 子进程，并通过 named pipe 或 localhost control channel 给 `proxy` 连接。

这比完全依赖官方 daemon 多一个 SadCoder 二进制，但换来 Windows/Linux 一致的保活、诊断、重连和能力探测。Codex 本体仍然不 fork，仍然安装官方 `codex`，但 Codex 路径、Node/PATH 运行时和版本检测都由 agent 统一解析。

## 4. 推荐架构

### 4.1 生产模式：sadcoder-agent over SSH

启动流程：

1. App 读取用户配置的 SSH profile。
2. 建立 SSH 连接并完成 host key 校验。
3. 检查远端 shell 可以执行非交互命令。
4. 执行 `sadcoder-agent status --json`，从 agent status 获取 Codex path、availability、version、backend 状态。
5. 如 service 未运行，执行 `sadcoder-agent start`；若 start 失败且是调试/降级场景，agent 可返回 direct stdio fallback。
6. 新开一个 SSH exec channel，执行 `sadcoder-agent proxy`。
7. App 在该 channel 上发送 app-server JSON-RPC；agent 连接本地 service socket 或 fallback app-server，并做 id 重写、转发、事件缓存和恢复。
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

direct stdio fallback 只用于调试或 service 启动失败后的临时降级：

```sh
codex app-server --listen stdio://
```

fallback 不满足“手机断线不影响任务继续执行”的生产硬约束，UI 必须明确标识风险。官方 `codex app-server daemon/proxy` 不作为 SadCoder 生产依赖，避免 npm/NVM CLI 与 standalone daemon 路径要求不一致。

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
- 提供 `agent/health`、`agent/logs`、`agent/restartBackend` 等额外 RPC；`agent/logs` 返回 service/app-server 日志的有界尾部内容，App 设置诊断页可读取展示，`agent/installCodex` 留作后续安装自动化。

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
7. 必要时 `sadcoder-agent start` 可启动 service 或明确返回 fallback/失败原因。
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
- SadCoder service 不可用，agent fallback 失败。
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
- 已覆盖路径归一化、目录响应 path/name 校验、拒绝 `..` / 绝对 child path、符号链接祖先拒绝、二进制文件拒绝、UTF-8 range 边界、后续 chunk 失败重试和大 Markdown raw 保护。
- 仍待后续单独设计：受控编辑、写文件、目录监听、diff 审批和冲突检测；这些能力不得混入只读 Files 页面。

### 9.7 深色模式

- 使用 Material 3 dynamic color 可选，但默认提供稳定主题。
- 支持 system / light / dark。
- 代码块、diff、terminal output 要有专门配色，不能只用普通文本颜色。
- 配色方案可影响代码关键字、终端 accent 和标题区等语义 accent，但 diff added/removed、风险状态等角色必须保持可识别，不能随主题被简单染成同一种主色。

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
- 已统一主机显示原则：保存主机和会话状态优先显示用户别名；无别名时显示 host/IP，不把 `user@host:port` 当作默认标题。
- 已落地 Chat 顶栏主机选择器、Settings 二级菜单、candy/lagoon/ember palette 和斜杠命令高级可见性开关。
- 已落地 per-host pending approval 聚合与动作路由：Approvals 页面展示所有已连接 host 的待审批项，审批响应回到所属 host 的 `ApprovalStateController`。
- 已落地 per-host thread summary/detail cache 持久化/恢复：每个 host 的最近线程列表、选中 threadId 和当前 thread detail 通过 `ThreadCacheStore` 独立保存，重建 host UI state 时优先恢复缓存，再由远端权威 thread/detail 读取刷新。
- 已落地 per-host thread item cache reader、timeline 恢复和 reconnect item fallback：`ThreadItemCacheStore` 按 profile/thread 隔离保存 item summaries 和分页游标，`local_data` schema 已补 `item_cache.profile_id` 与 profile/thread 索引；`CodexSessionStateController.threadItemListReader` 已通过缓存 decorator 保存/回退 canonical thread item 读取，host UI state 恢复选中 thread 时会从 item cache 回填 timeline；重连时若 `thread/turns/list` 不可用或失败，会尝试 `thread/items/list` 回填当前 thread timeline。
- 后续仍需完整多 host 同时连接架构：`HostSessionManager` 已作为基础控制器引入，但后台保活策略、断线期间事件 cursor/分页增量回填和更完整的 reconnect turn/item reconciliation 还需要继续拆分完善。

### 9.8 i18n

首版语言：

- `zh-CN`
- `en-US`

规则：

- 所有可见文本必须进资源文件。
- 错误消息可以保留底层英文 raw detail，但必须有中文摘要。
- 时间、数字、文件大小按系统 locale 格式化。

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

### 11.3 日志脱敏

日志默认脱敏：

- passwords
- private keys
- API keys
- access tokens
- Authorization headers
- cookie-like values

导出日志前再次提示用户可能包含路径、命令、项目名。

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
- 验证未设置覆盖时，`thread/start` / `turn/start` 不发送覆盖字段，沿用服务器 Codex 配置。
- 验证本次 turn、本会话、App 默认覆盖的优先级正确。
- 验证普通覆盖不会调用 `config/value/write` 或 `config/batchWrite`。
- 验证清除会话覆盖时只对上游支持显式清除的字段发送 `null`，例如 `serviceTier`；普通 `Option<T>` 字段不得用 `null` 伪装成恢复服务器默认。
- 验证当前 Codex 斜杠命令 manifest 覆盖 `/model`、`/ide`、`/permissions`、`/keymap`、`/vim`、`/setup-default-sandbox`、`/sandbox-add-read-dir`、`/experimental`、`/approve`、`/memories`、`/skills`、`/import`、`/hooks`、`/review`、`/rename`、`/new`、`/archive`、`/delete`、`/resume`、`/fork`、`/app`、`/init`、`/compact`、`/plan`、`/goal`、`/agent`、`/side`、`/btw`、`/copy`、`/raw`、`/diff`、`/mention`、`/status`、`/usage`、`/debug-config`、`/title`、`/statusline`、`/theme`、`/pets`、`/mcp`、`/apps`、`/plugins`、`/logout`、`/quit`、`/exit`、`/feedback`、`/rollout`、`/ps`、`/stop`、`/clear`、`/personality`、`/test-approval`、`/subagents`、`/debug-m-drop`、`/debug-m-update`。
- 验证别名 `/clean -> /stop`、`/pet -> /pets`、`/approve -> AutoReview`、`/subagents -> MultiAgents`。
- 验证 active turn 中不可用的斜杠命令被禁用，不会触发隐式 `turn/interrupt`。
- 验证 `/quit`、`/exit` 只断开 App/proxy，不停止服务器上的 active turn。
- 验证 `/stop` 只作用于后台 terminal/process，不等价于 `turn/interrupt`。
- 验证 unknown slash command 被显示为未支持或需要 raw fallback，不会静默作为普通 prompt 发送。
- 验证 `/side`、`/btw` 创建 ephemeral fork 时不会 interrupt main thread，side 返回/丢弃不会影响 main thread active turn。
- 验证 side thread 注入 boundary prompt，side 内不允许再次 `/side`，不允许 rename/review 等不适合 side 的命令。
- 验证 `/agent`、`/subagents` 的只读拓扑可以从 `parentThreadId`、`ancestorThreadId`、`CollabAgentToolCall`、`SubAgentActivity` 回填，并正确区分 running、closed、errored 状态。

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
