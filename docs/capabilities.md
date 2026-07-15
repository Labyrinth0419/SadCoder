# 功能与 CLI 覆盖

本文件保留 MVP、第二阶段和第三阶段的能力分组，用于说明接口覆盖层级；分组名称不是开放任务状态。明确未完成或待改进的工作统一记录在 [TODO](../TODO.md)。

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
- `configRequirements/read`
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
- `fs/writeFile` / `fs/watch` 已通过独立 `WorkspaceFileMutationRunner` 接入受控编辑：只对完整加载的现有文本文件显示编辑入口，保存前展示 diff 并二次确认，写入前按 `contentVersion` 或完整旧内容做乐观冲突检查，路径与符号链接继续走 workspace guard；`fs/watch` 为当前文件提供外部变更提示。服务端协议没有 compare-and-swap，因此检查与写入之间仍是 best-effort 乐观并发控制，不声称原子写入。
- `fuzzyFileSearch/*`
- `thread/shellCommand`
- `command/exec` PTY streaming。
- 轻量文件浏览器和 diff viewer。

认证：

- 主路径使用服务器侧已配置的 API key；App 读取账号状态但不把交互式登录作为主要功能。
- `account/login/start`（API key、ChatGPT browser/device code）与 `account/login/cancel` 只定义为非主路径兼容面；当前主线依赖服务器侧已配置的 API key，剩余兼容工作见 [TODO](../TODO.md#p1-移动端结构与交互)。
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
- 已接入 `environment/add`、`environment/info`、`environment/status`：Settings Diagnostics 提供环境 ID、exec-server WebSocket URL、可选连接超时的注册表单；注册或替换环境前要求二次确认，info/status 作为只读状态检查并兼容未知状态值。环境注册遵循 app-server 当前进程内存语义，不伪装成持久化 `CODEX_HOME` 配置。
- Realtime：主线只要求稳定 app-server 已明确支持的文本能力，现有 `thread/realtime/start`、`appendText`、`stop`、`listVoices` 保留为实验性文本入口，但不替代普通 `turn/start` 会话。语音输入优先调用手机系统语音转文字，再把文本作为普通 `turn/start` 发送，以复用既有会话、审批、断线恢复和 API-first 路径。提交 `07863db` 中的 WebSocket 音频设备实现保持隔离，重新立项条件见 [TODO](../TODO.md#future-features)。
- `process/spawn` 高级进程管理。
  - 已接入 `process/spawn`、`process/writeStdin`、`process/resizePty`、`process/kill` 以及 `process/outputDelta` / `process/exited` 通知；连接层提供类型化 `ProcessRunner`，Files 顶栏可进入实际 Terminal 页面。终端默认使用受 Codex sandbox 约束的 `command/exec`，只有用户显式切换到宿主机进程模式并逐次确认命令、cwd 与无沙箱风险后才调用 `process/spawn`，取消确认不发送 RPC。
- `externalAgentConfig/*`。
  - 已接入 `externalAgentConfig/detect`、`externalAgentConfig/import` 和 `externalAgentConfig/import/readHistories`；移动端保留检测项 raw JSON 以兼容未来字段，并把 progress/completed notification 映射为 typed event。
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
