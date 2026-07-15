# 审批、配置覆盖与斜杠命令 UI

## 9.3 Approvals 页面

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

## 9.4 配置覆盖 UI

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

## 9.5 斜杠命令面板

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
- `/rollout` 是只读 UI 诊断命令：有参数时不可用；无线程 raw path 时按 Codex TUI 语义显示 `Rollout path is not available yet.`，thread raw 提供 rollout path 时显示当前路径。
- 已将稳定的 `configRequirements/read` 合并进服务器配置快照和 `/debug-config`：新 app-server 会展示受管 approval/sandbox/model/feature 等约束，明确区别于普通 `config/read` 生效值和 layers；旧版本 method-not-found 时仍保留普通配置摘要并显示 requirements 不可用，其他读取错误不会被静默吞掉。
- 已将 `/test-approval` 接成移动端本地 debug-only 审批链路测试：注入一条 file-change `PendingApproval` 到当前 session 的 `ApprovalStateController`，不调用 app-server、不修改服务器状态。
- 已将 `/plan` 从本地硬编码 Plan preset 升级为优先读取官方 `collaborationMode/list`：服务端返回的 mode、model 和 `reasoning_effort` 作为权威 mask，preset 未指定 model 时才继承当前有效 model，并继续发送 `developer_instructions: null` 让 app-server 使用内置模式指令；仅旧服务端返回 method-not-found 或连接未暴露该 reader 时回退原有 Plan/medium 兼容值，其他 catalog 错误不会被静默隐藏。
- `/experimental` 保留 `config/read` 只读摘要作为不支持 `experimentalFeature/list` 的旧服务端回退路径。
- 已将 `/experimental` 升级为按 `experimentalFeature/list` 自动读取服务端 Beta feature catalog 的可操作 bottom sheet；开关修改前展示旧值/新值与全局服务器影响并二次确认，确认后通过 `config/batchWrite` 写入 `features.<name>`、热重载用户配置，再刷新能力状态；旧服务端不支持该接口时回退到原有只读配置摘要。当前稳定 app-server 另有 `experimentalFeature/enablement/set`，但它只提供低于 `config.toml` 的进程内运行时覆盖、不会持久化，并会静默忽略不在服务端白名单中的 feature key，因此不等价于 Codex TUI `/experimental`，不能替换这里的持久化配置路径。
- `/memories` 保留 `config/read` 摘要作为旧服务端或没有 thread memory metadata 时的回退路径。
- 已将 `/memories` 升级为当前线程记忆模式与全局记忆清空 bottom sheet：线程模式通过 `thread/memoryMode/set` 修改并单独确认；`memory/reset` 会明确提示其会清空服务器记忆文件和数据库记录，使用独立高风险确认；操作完成后刷新当前 thread。
- 已将 `/skills` 从只读 `skills/list` 摘要升级为对齐 Codex TUI 的技能管理 bottom sheet：无参数时按当前 workspace/cwd 列出并搜索技能，开关变更前明确确认会修改服务器 `CODEX_HOME` 并影响其他 Codex 客户端，确认后通过稳定的 `skills/config/write` 按 path（缺失时按 name）写入启用状态，再强制刷新服务端 catalog；`/skills reload` 继续保留只读强制扫描摘要，缺少 mutation capability 的旧连接也保持原有只读回退。
- `/app` 是移动端 UI-only 诊断：无参数时明确提示 Codex Desktop handoff 在移动端不可用，不调用 app-server、不发送 prompt；带参数时返回 unavailable。结构化 handoff 依赖上游能力，见 [TODO](../TODO.md#p1-移动端结构与交互)。
- 已将 `/import` 接成官方 `externalAgentConfig/*` 结构化流程：同时检测用户级和当前工作区 Claude Code 数据，按迁移组展示类型、作用域、服务端描述和明细数量，允许多选/全选并在写入服务器 Codex 配置或工作区文件前二次确认；提交时原样回传 detect payload，未知未来类型/字段不会被移动端丢弃。`externalAgentConfig/import/progress` 与 `externalAgentConfig/import/completed` 已映射为 typed event，并由独立 controller 处理响应/通知相邻到达竞态、进度去重累积和 completed 权威结果替换；确认后 UI 会显示可随时关闭的进度页、逐项成功/失败与最终计数，关闭不会取消服务端导入。`externalAgentConfig/import/readHistories` 已在下一次打开 `/import` 时展示最近结果，使断线后仍可核对完成状态；回滚仍由上游能力决定，移动端不会伪造本地回滚语义。
- 已按 Codex TUI 当前语义接入 `/init`：移动端提交与 `refs/codex/codex-rs/tui/prompt_for_init_command.md` 同步的固定 prompt 启动普通 turn，要求先检查当前 cwd 是否已有 `AGENTS.md` 且不得覆盖；实际文件变更继续经过 app-server file-change diff/approval 链路，不通过 SSH 命令直接写文件。
- `/setup-default-sandbox` 和 `/sandbox-add-read-dir` 当前是移动端高风险诊断：前者无参数时提示需要受保护的 agent fallback 和高风险确认；后者先做 Windows 绝对路径/UNC 路径校验，合法路径只显示受保护 fallback 诊断，不调用 app-server、不执行 agent 命令、不修改沙箱配置；无效路径或不支持参数返回 unavailable。真实 fallback 的安全工作见 [TODO](../TODO.md#p1-协议与后端)。
- 已为 `/setup-default-sandbox` 与合法 Windows `/sandbox-add-read-dir <absolute_path>` 接入高风险确认门：用户确认后仍只显示 guarded fallback 诊断，不执行 agent 命令、不修改服务器设置；取消时返回 command cancelled，且非法路径不会触发确认。
- 本轮已将 `/setup-default-sandbox` 从上述诊断态升级为官方 app-server 执行路径：移动端在专用高风险确认中明确提示所选 Windows 主机会触发管理员授权并持久化沙箱配置，确认后调用 `windowsSandbox/setupStart { mode: elevated, cwd }`，解析 `windowsSandbox/setupCompleted` 异步通知并展示成功、失败或超时结果，成功后刷新服务器配置快照；连接层暴露类型化 Windows sandbox runner，manifest 映射改为 `appServer` / `windowsOnly`。`/sandbox-add-read-dir` 仍保持受保护诊断，因为当前 app-server 只提供 readiness/setup RPC，上游读取目录授权仍是 TUI 进程内 `grant_read_root_non_elevated`，没有可供远程 App 审计调用的结构化协议；在上游新增对应 RPC 或 agent 复用官方原生实现前，不以任意 shell 命令替代。
- 已对齐当前上游 `/debug-m-drop`、`/debug-m-update` 语义：Codex TUI 对二者只显示 app-server memory maintenance stub，不执行内存变更；移动端开发命令现在返回同语义的本地化诊断，不再误报“未实现”，带参数或 active turn 场景仍按 manifest 可用性拒绝。
- 斜杠命令面板已使用左侧竖向分组 rail，而不是横向 tab；widget 回归测试会校验 common/session/configuration 分组按钮按同一 x 坐标纵向排列，避免窄屏重新出现横向标签挤压或底部 overflow。
