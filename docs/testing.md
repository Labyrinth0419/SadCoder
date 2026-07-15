# 测试策略与兼容性矩阵

本文件定义自动化、集成测试和设备 QA 契约。尚未在真实平台矩阵完成的执行项集中跟踪在 [TODO](../TODO.md#p0-发布与平台验证)，这里保留长期验证范围。

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

- Android 10+ 为当前最低目标，发布前仍需完成真实设备确认。
- Android 13+ 通知权限专项测试。
- iOS 16+ 为当前自编译安装目标，发布前仍需完成真实设备确认。
- iOS 后台长连接不作为首版承诺。
