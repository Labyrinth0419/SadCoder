# 协议、配置与兼容性

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
- 未知或新增的 app-server server request 类型以通用只读方式显示，不能静默丢弃或无限等待。

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
7. `configRequirements/read`；旧 app-server 返回 method-not-found 时保留普通配置快照并标记 requirements 不可用。
8. `modelProvider/capabilities/read`；读取当前模型提供方是否支持 namespace tools、image generation 和 web search，旧 app-server method-not-found 时只标记该能力摘要不可用。
9. `account/read`
10. 可选：通过 `sadcoder-agent schema --json` 或 `agent/schema` 生成/读取服务器 app-server JSON Schema cache；App 设置诊断页展示缓存模式、Codex 版本、digest、bundle/cache 路径和文件摘要，且不直接依赖交互式 shell 环境，也不自行执行 `codex`。

客户端内置一个“最低支持 Codex 版本”，低于该版本只允许 stdio 调试或提示升级。

对 app-server 的 experimental API：

- 默认初始化时开启 `experimentalApi: true`。
- UI 对 experimental 功能加标识。
- 对未知 method/item 不崩溃，保留 raw event。
- 模型选择与覆盖必须从 `model/list` 读取服务器实际 catalog，不能在 App 内硬编码 GPT-5.x 名称；解析层同时兼容 app-server v2 的 camelCase 字段与 Codex 远程 catalog/cache 的 snake_case 字段，例如 GPT-5.6 Sol/Terra/Luna 的 `default_reasoning_level`、`supported_reasoning_levels`、`service_tiers` 和 `availability_nux`。
- 已补强移动端 model catalog 解析：`supportedReasoningEfforts` / `supported_reasoning_levels` 和 `serviceTiers` / `service_tiers` 同时支持对象数组与紧凑字符串数组，避免不同 Codex 版本或缓存来源把 reasoning/service tier 能力信息丢失。
- 已将 model catalog 能力摘要接入 Settings 模型列表：每个可见模型除 label/default/provider 外，可显示 reasoning levels（含默认值）、service tiers（含默认值）和 availability announcement，避免 `model/list` 返回的能力信息只停留在解析层。
- 已将同一 model catalog 能力摘要接入 Chat `/model` 选择器：下拉菜单展开时显示 reasoning/service tier/announcement，选中态仍保持单行模型 label，避免影响输入区密度。
- 已将 `/model` 的推理强度改为按所选模型自动读取 `model/list` 的 `supportedReasoningEfforts` 与 `defaultReasoningEffort`：有能力元数据时提供服务器默认值和服务端声明的可选项，切换模型时清理不兼容覆盖；旧服务端、未知模型或自定义模型仍保留自由输入兼容路径。
- 已将 model catalog 能力摘要中的默认值片段资源化，英文显示 `default: ...`，中文显示 `默认：...`，避免 UI helper 内硬编码可见文案。
- 已将稳定的 `modelProvider/capabilities/read` 合并进服务器配置快照：Settings 只读配置卡和 `/debug-config` 会展示当前 provider 的 namespace tools、image generation、web search 能力；旧版本 method-not-found 时明确显示不可用，其他读取错误保留 raw detail 并使本次快照刷新失败，不把未知状态伪装成全部禁用。

### 5.6 Codex 配置策略

默认原则：服务器上的 Codex 配置是权威默认值。SadCoder 不复制、不重建、不默认覆盖服务器 `CODEX_HOME/config.toml`、项目级配置、profile、MCP、插件、技能、权限 profile、模型 provider 或登录状态。

配置读取：

- 连接后通过 `config/read` 读取服务器当前有效配置，用于展示和诊断。
- 通过 `configRequirements/read` 读取受管 approval、sandbox、permission profile、feature、network、model 等企业约束；该结果只读，不允许 App 绕过或改写。
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
- `sadcoder-agent` 暴露 `agent/slashCommands/list`，返回当前 Codex 版本对应的 manifest；当前由 SadCoder 根据 Codex 源码版本维护。官方 app-server manifest 的切换条件见 [TODO](../TODO.md#p1-协议与后端)。
- App 启动时比较 `AgentStatus.codexVersion`、app-server schema 和本地 manifest 版本。发现未知斜杠命令时，在高级面板显示“当前 App 未识别”，允许 raw RPC/SSH fallback，但不静默吞掉。
- inline args 命令必须提供参数解析或表单：`/review`、`/rename`、`/plan`、`/goal`、`/ide`、`/keymap`、`/mcp`、`/raw`、`/usage`、`/pets`、`/side`、`/btw`、`/resume`、`/sandbox-add-read-dir`。
- 命令可用性必须跟随 active turn 状态。Codex 标记为 active task 不可用的命令，App 禁用或提示原因，不能通过隐式 interrupt 绕过。
- 断线生命周期约束同样适用于斜杠命令：`/quit`、`/exit` 只关闭 App/当前代理连接，不停止服务器任务；`/stop` 只对应后台 terminal/process 停止语义，不等价于 `turn/interrupt`；只有用户明确点击“中断/停止本轮”才发送 `turn/interrupt`。
- 平台差异要显式展示：例如 `/sandbox-add-read-dir` 是 Windows sandbox 辅助能力，`/app` 在移动端通常只能显示“不适用/打开 Codex Desktop 不可用”，debug-only 命令只在开发构建出现。

执行映射分四类：

1. app-server 原生映射：优先走官方 JSON-RPC，例如 thread、turn、review、goal、account、model、config、MCP、plugin、skill、usage、feedback、background terminal/process 等接口。
2. SadCoder UI-only：移动端本地体验，例如复制、raw view、主题、状态栏、标题、keymap、vim 输入模式、退出当前界面等。
3. agent/SSH fallback：app-server 暂无结构化接口时，由 `sadcoder-agent` 执行等价 CLI 或服务器脚本，并把结果结构化返回。
4. 会话拓扑扩展：`/side`、`/btw`、`/agent`、`/subagents` 在 UI 中明确表示 fork、临时侧聊、多 agent thread 或子 agent 关系；当前已提供临时侧聊、只读多 agent 拓扑和 thread 切换。

会话拓扑分期判断：

- `/side`、`/btw` 难度为中等。Codex app-server 已有 `thread/fork` 的 `ephemeral: true` 支持，TUI 也是基于 ephemeral fork 加隐藏 boundary prompt 实现。SadCoder 的主要工作是移动端状态机：主线和侧聊并存、side 不污染 main、审批归属、返回主线、断线后合理降级。
- `/side`、`/btw` 创建 ephemeral fork，注入 side boundary prompt，进入 side UI 并允许返回 main thread；side 中禁用不适合的斜杠命令；side 不能因为切换或断线触发 main thread 的 `turn/interrupt`。
- `/side`、`/btw` 的限制需要明确：ephemeral side thread 不承诺像普通持久 thread 一样长期保留；断线重连后能恢复则恢复，不能恢复时要提示用户该 side 已丢失，但不能影响 main thread。
- `/agent`、`/subagents` 难度为高。它们不是“新建 agent”的按钮，而是对 Codex multi-agent/subagent thread 树的浏览、状态归因和切换。需要处理 `parentThreadId`、`ancestorThreadId`、`agentNickname`、`agentRole`、`CollabAgentToolCall`、`SubAgentActivity`、running/closed/error 状态，以及多 thread 的事件回填。
- `/agent`、`/subagents` 当前只提供只读拓扑和切换查看。send/wait/close/resume 等主动控制必须在归属语义审计后单独推进，见 [TODO](../TODO.md#p1-移动端结构与交互)。

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
| `/hooks` | `hooks/list` + `config/batchWrite hooks.state` 管理启用状态与 trusted hash | 第二阶段 |
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
| `/import` | `externalAgentConfig/detect` 预览 + `externalAgentConfig/import` 结构化导入 | 第三阶段 |
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
