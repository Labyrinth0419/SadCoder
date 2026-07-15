# Chat 信息架构与对话交互

## 信息架构

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

## Chat 页面

核心元素：

- 顶部：host、cwd、model、effort、approval/sandbox 状态、连接状态。
- 中部：按 turn 分组的消息流。
- item 渲染：
  - 用户消息。
  - assistant message。
  - active reasoning：Markdown 渲染并浮动在输入框上方，不折叠、不混入历史消息流。
  - command execution 卡片：命令与永久受限的头尾输出摘要，不提供完整输出入口。
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

- 已收敛 Chat 顶部为左侧三横线会话侧栏按钮、中部 TUI 式状态词（idle/running/working/failed）+ 当前工作详情和右侧 host selector；活动条会从当前非终态 timeline item 提取命令/工具/文件变更详情，不暴露 thread/turn 内部 id。主区域优先显示 thread timeline 的用户/Codex 文本、工具调用、命令输出和 diff；用户/Codex 消息采用开放消息流，命令/工具/diff 采用执行块，当前活动 turn 的 reasoning 以不折叠 Markdown 浮层固定在 composer 上方且不混入历史消息流，会话列表不再展示 cwd/status 详情，timeline item metadata 不进入默认主对话流。
- 本轮 UI pass 已补强 Chat 主画布权重和 TUI 状态 marker/status chip，侧栏开关固定为左上三横线且默认收起会话侧栏，timeline turn 作为主内容渲染并有 widget 测试覆盖；会话侧栏已改为工具侧栏式列表 surface，点选会话只切换/加载 timeline，不展示 Thread detail/cwd/turn id 详情；顶栏状态和主机选择器支持窄屏 flex 收缩，斜杠命令预览仍保留为输入附近的轻提示，不再抢占默认对话信息架构。
- Chat 高级折叠区已按能力拆分：配置覆盖控件只在有 `CodexConfigOverrideController` 时出现，Raw RPC 面板可显示禁用态，但发送只依赖已注入的 session controller，避免 session-only 页面展开高级区时因覆盖 controller 缺失而崩溃；默认对话面仍不显示这些调试控件。
- 最新 UI pass 已把 active turn 的 raw `Status: inProgress` 从主 timeline 移除，running/working/failed 详情只由顶部 TUI 状态槽承担；高级调试入口改为图标折叠按钮，斜杠命令输入预览改为轻量 inline surface，避免底部输入区继续占用对话主体。
- 最新 UI contract 已将斜杠命令输入预览固定到 composer chrome：预览仍作为输入框上方的轻提示展示，但不再作为 `chat-main-conversation` 主滚动区的子节点，避免命令解析提示混入用户/Codex 文本、工具调用和命令输出 transcript。
- 本轮 UI pass 将 Chat 高级调试入口从 inline 展开区迁到可滚动 bottom sheet：默认对话页不再把 Raw RPC、会话覆盖、本次回合覆盖插入输入框上方；用户点调试图标才进入独立高级工具面板，关闭后回到以 timeline 文本、工具调用和 composer 为主体的对话界面。
- 本轮 UI pass 继续强化对话主体权重：顶部 activity strip 增加 TUI 式语义色轨，running/working/failed 详情仍只放在顶部状态槽；会话侧栏行改为紧凑工具行和选中 rail，仅展示会话标题，不回退显示 cwd、status、thread/turn id 等详情。
- 本轮 UI polish 将会话侧栏的 active / archived 模式切换从横向 segmented control 改为竖向紧凑工具按钮，保留 tooltip、选中 rail 和图标语义，避免窄侧栏横向挤压对话主体。
- 侧聊提示面板也已去掉 side/main thread id，仅保留侧聊标题、触发命令和返回主线按钮；默认对话画布不再显示内部会话详情。
- 本轮 Chat 可见 UI 里程碑已将 user / Codex 文本改为左右气泡式阅读流，并默认复用 Files Markdown 预览的 MarkdownBody、代码高亮和图片占位策略；command/file/tool 保持中性 timeline block，active reasoning 改为 composer 上方的不折叠 Markdown 浮层，超长文本回退 selectable raw。command output 永久只显示行数/字节数与头尾摘要，中段始终省略，短输出也至少隐藏一个字符，不再存在展开或完整输出动作。Composer 已压缩为多行自动换行输入，移除输入模式/发送快捷键/terminal pet helper 文案，高级控制入口迁入左上三横线侧栏，timeline 增加跳到最新行为：同一 thread 新事件尊重用户历史位置，切换 thread/session 默认滚到最新。
- Chat composer 是受最大高度约束的多行输入区：移动端键盘动作保留换行，长文本软换行后输入框增高到上限再内部滚动；硬件 Enter / Ctrl+Enter 发送仍按 keymap 执行，widget 测试覆盖长中文输入不再把布局向右撑开。
- 本轮 Chat UI / timeline 性能里程碑已修正消息方向契约：user 消息固定右侧、Codex/assistant 消息固定左侧，文本气泡使用约 92% 可用 timeline 宽度且保留左右方向感；command/file/tool 仍为中性 timeline block，active reasoning 使用独立的 composer 上方 Markdown 浮层。Chat timeline 新增可拖动的浮层“跳到最新”按钮，位置限制在对话内容区域内，不占 composer 或 timeline layout 空间；左上三横线会话侧栏使用 210ms ease-out slide/fade 过渡，打开/关闭不再跳变。全局正文、中文、英文、代码块和 terminal/diff/raw 输出统一到随包发布的 LXGW WenKai Mono 字体，并在 `assets/fonts` 保留 OFL 授权文本。
- Chat timeline 使用有界窗口与按需分页：普通 thread 选择先读取 metadata，再通过 `thread/items/list(sortDirection=desc, limit=80)` 拉最新窗口，向上滚动接近顶部后按 cursor 继续加载更早 item page；即使 detail reader 意外带回 full turns，只要 item reader 可用，Chat 首屏仍优先使用 bounded items page，full turns 只作为无 reader 或读取失败 fallback；controller 对 item id 去重，失败时保留当前 timeline 并显示 retry 状态，live event / reconnect recovery 的 turn backfill 路径仍保留且同样受窗口上限保护。真实 app-server cursor 矩阵验证见 [TODO](../TODO.md#p0-发布与平台验证)。
- Chat timeline viewport、滚动监听、向上加载触发和可拖动“跳到最新”浮层位于 `features/chat/chat_timeline_view.dart`；`ChatPage` 只负责页面编排、侧聊 header 和 timeline renderer 组合。
- 本轮结构整理将 Chat timeline 首屏有界窗口、向上分页、older-history retry 和 active turn -> timeline 同步从 `ChatPage` 拆到 `features/chat/chat_timeline_window_coordinator.dart`；分页 generation、最近加载 thread id 和 reader fallback 都由 coordinator 持有，`ChatPage` 只在 thread/turn listener 中触发 coordinator，避免页面继续承载 timeline 按需加载状态机。
- Chat 会话侧栏 surface、workspace 摘要 header、active/archived thread list 与 thread tile 位于 `features/chat/chat_thread_sidebar.dart`；高级控制 bottom sheet 保留在页面层，避免 sidebar 模块依赖配置覆盖/Raw RPC 调试能力。
- Chat timeline renderer、消息气泡、command/file/tool 执行块、Markdown raw fallback、terminal output 头尾摘要和 diff 渲染位于 `features/chat/chat_timeline_renderer.dart`；active reasoning 浮层由 `features/chat/chat_reasoning_overlay.dart` 独立承载。`ChatPage` 不直接依赖 Markdown preview / diff block / terminal renderer 细节，剩余页面解耦工作见 [TODO](../TODO.md#p1-移动端结构与交互)。
- composer 上方的 slash command preview 位于 `features/chat/chat_slash_command_preview.dart`，保留 known/unknown/empty slash 的轻提示与“作为文本发送”入口；`ChatPage` 只传入解析结果和回调。
- Chat 顶部 activity strip / TUI 状态线位于 `features/chat/chat_activity_strip.dart`，保留 sidebar toggle、running/working 状态 rail、状态行 chips 和当前 active timeline work 摘要；`ChatPage` 只传入状态 controllers、status line parts 和连接控件。
- 本轮结构整理将 Chat 右上连接/主机选择控件从 `ChatPage` 拆到 `features/chat/chat_connection_controls.dart`，保留已保存主机别名显示、popup profile 选择、per-host 状态 chip 和连接忙碌态；`ChatPage` 只提供 profiles/session summaries 与选择回调。多 host active host 生命周期由 `HostSessionManager` 统一协调。
- Chat 高级控制 bottom sheet 位于 `features/chat/chat_advanced_controls_sheet.dart`，由独立组件组合 Session/Turn override controls 与 Raw RPC panel；`ChatPage` 只负责打开 sheet、传入 override controller、Raw RPC sender 和 session override 应用回调。
- 本轮结构整理将 thread lifecycle / mutation slash callbacks 从 `ChatPage` 拆到 `features/chat/chat_thread_command_handler.dart`：`/new`、`/resume`、`/rename`、`/fork`、`/duplicate`、`/rewind`、`/compact`、`/archive`、`/delete` 和 archived-thread restore 的业务调用、确认弹窗、timeline/thread refresh 归入独立 handler；`ChatPage` 只传入 controllers 与少量页面级回调。`/side`、`/btw` 与 `/agent` 仍留在页面层，因为它们直接管理 side conversation 状态或 topology sheet。
- 本轮结构整理将 appearance/input preference slash callbacks 从 `ChatPage` 拆到 `features/chat/chat_appearance_command_handler.dart`：`/theme`、`/title`、`/statusline`、`/vim`、`/keymap`、`/pets` 的 sheet 打开、inline 参数解析和 `AppAppearanceController` 写入集中到独立 handler；`ChatPage` 只创建 handler 并继续负责 composer 当前 UI 状态。
- 本轮结构整理将 override slash callbacks 从 `ChatPage` 拆到 `features/chat/chat_override_command_handler.dart`：`/model`、`/permissions`、`/personality` 和 `/plan` 的 sheet 打开、high-risk permissions 确认、override controller 写入和 Plan-mode inline prompt 提交归入独立 handler；`ChatPage` 只保留当前 model 解析和 active turn timeline 同步回调，避免 handler 反向依赖页面内部状态。
- 本轮结构整理将 account/feedback slash callbacks 从 `ChatPage` 拆到 `features/chat/chat_account_command_handler.dart`：`/feedback` 的反馈 sheet、日志同意后上传参数映射，以及 `/logout` 的确认弹窗、account/logout 调用和 account/usage snapshot 刷新归入独立 handler；`ChatPage` 只提供当前 thread/turn id provider。
- 本轮结构整理将 Chat 只读 summary 与 utility slash callbacks 从 `ChatPage` 拆到 `features/chat/chat_summary_command_handler.dart`：`/status`、`/usage`、`/mcp`、`/skills`、`/plugins`、`/hooks`、`/apps`、`/debug-config`、`/experimental`、`/memories`、`/rollout`、`/diff`、`/goal`、`/review`、`/ps`、`/stop`、`/test-approval`、`/approve` 和 `/copy` 的 runner/reader 调用、summary 构造与刷新编排归入独立 handler；`ChatPage` 只保留 raw transcript 可见性、composer mention/IDE context 和真正拥有页面状态的侧聊/拓扑入口。
- 本轮结构整理将 `/mention` 与 `/ide` 的文件搜索 bottom sheet、workspace root 可用性检查和选择结果分发从 `ChatPage` 拆到 `features/chat/chat_file_context_command_handler.dart`；`ChatPage` 继续只拥有 composer 文本、mention range 和 `TurnTextElement` 转换，避免文件搜索 UI 反向操作输入框内部状态。
- 本轮结构整理将 `/side`、`/btw`、`/agent`、`/subagents` 和侧聊返回主线的 runner/read/sheet 编排从 `ChatPage` 拆到 `features/chat/chat_conversation_command_handler.dart`；`ChatPage` 仍只持有 `_sideConversation`、断线清理和 turn 状态联动，handler 通过 provider/setter callback 操作页面状态，避免侧聊 lifecycle 与 topology sheet 继续堆在主页面文件。
- 本轮结构整理将 Chat 顶部 host/profile 加载、saved/host-session/connected profile 合并、默认选中 profile 计算和连接失败提示从 `ChatPage` 拆到 `features/chat/chat_profile_selection_handler.dart`；`ChatPage` 只保留 `_savedProfiles`、`_selectedProfileId`、`_profileLoadError` 三个 UI 状态并把它们传给 `ChatConnectionControls` / sidebar host panel。
- 本轮结构整理将 composer submit 判定、普通 prompt 提交、active turn steer、bang shell command、slash-as-text 分支、turn override 清理和 shell failure snackbar 从 `ChatPage` 拆到 `features/chat/chat_composer_submit_handler.dart`；`ChatPage` 继续只拥有 `TextEditingController`、slash text prompt 和 mention range，并通过 callback 生成 `TurnTextElement` 与清空输入。
- 本轮结构整理将 Chat 高级控制 sheet 打开、Raw RPC sender 注入和 session override apply / thread settings refresh 从 `ChatPage` 拆到 `features/chat/chat_advanced_controls_handler.dart`；`ChatPage` 只负责 sidebar header 的高级入口可见性和提供 current thread / refresh callbacks。
- 本轮结构整理将 `/theme` command sheet 从 `ChatPage` 拆到 `features/chat/chat_theme_sheet.dart`，公开 `ChatThemeSheet` / `ChatThemeSheetResult` 并保留主题模式、真实 candy palette 选择和 apply 返回契约；`ChatPage` 只负责展示 sheet 并把结果应用到 appearance controller。
- 本轮结构整理将 `/feedback` command sheet 从 `ChatPage` 拆到 `features/chat/chat_feedback_sheet.dart`，公开 `ChatFeedbackSheet` / `ChatFeedbackFormResult` 并保留 category、note、include logs 确认弹窗和 `feedback/upload` 参数映射契约；`ChatPage` 只负责打开 sheet 并提交结果。
- 本轮结构整理将 `/model` command sheet 从 `ChatPage` 拆到 `features/chat/chat_model_override_sheet.dart`，公开 `ChatModelOverrideSheet` / `ChatModelOverrideResult` 并保留 turn/session scope、model/list picker、model/effort 字段和 apply 返回契约；同时新增 `features/chat/chat_override_scope.dart` 承载通用 scope selector 与 overrides 读取 helper。
- 本轮结构整理将 `/personality` command sheet 从 `ChatPage` 拆到 `features/chat/chat_personality_override_sheet.dart`，公开 `ChatPersonalityOverrideSheet` / `ChatPersonalityOverrideResult` 并复用 `chat_override_scope.dart`，保留 turn/session scope、personality 字段和 apply 返回契约；`ChatPage` 只负责打开 sheet 并写入 override controller。
- 本轮结构整理将 `/permissions` command sheet 从 `ChatPage` 拆到 `features/chat/chat_permissions_override_sheet.dart`，公开 `ChatPermissionsOverrideSheet` / `ChatPermissionsOverrideResult` 并复用 `chat_override_scope.dart`，保留 approval policy、sandbox/network、permission profile selector、risk warning 和 apply 返回契约；result 自带 `isHighRisk` 判定，`ChatPage` 只负责二次确认和写入 override controller。
- 本轮结构整理将 `/agent` / `/subagents` topology bottom sheet 从 `ChatPage` 拆到 `features/chat/chat_agent_topology_sheet.dart`，公开 `ChatAgentTopologySheet` 并保留 active thread 标记、agent role/path/status/parent/ancestor 详情、subagent-only title 和点击返回 `ThreadSummary` 的契约；`ChatPage` 只负责刷新 thread/topology 数据和切换 active thread。
- 本轮结构整理将 side conversation inline banner 从 `ChatPage` 拆到 `features/chat/chat_side_conversation_panel.dart`，公开 `ChatSideConversation` / `ChatSideConversationPanel` 并保留 compact 状态、`/side`/`/btw` 命令提示、不显示 parent/side thread id、返回主线按钮启停契约；`ChatPage` 只保留侧聊生命周期和 thread 切换逻辑。
- 本轮结构整理将 `/goal` inline argument parser 从 `ChatPage` 拆到 `features/chat/chat_goal_command.dart`，公开 `ChatGoalCommand` 及 get/clear/set 子类型和 `parseChatGoalCommand`，覆盖 get/show/clear/status/budget/set/default objective 与无效参数边界；`ChatPage` 只保留 thread goal runner 调用和本地化 summary 生成。
- 本轮结构整理继续将 `/goal` 的 thread goal runner 调用和本地化 summary 生成从 `ChatPage` 拆入 `features/chat/chat_goal_command.dart`；`ChatPage` 只传入当前 thread id、runner 和本地化资源。
- 本轮结构整理将 composer file mention 的 range 跟踪、重叠清理、剪枝和 `TurnTextElement` byte-range 转换从 `ChatPage` 拆到 `features/chat/chat_composer_mention.dart`，公开 `ChatComposerMention` 与 helper；`ChatPage` 只负责选择文件、计算插入区间和更新输入框文本。
- 本轮结构整理将 `/rollout` 只读诊断的 raw thread path 解析从 `ChatPage` 拆到 `features/chat/chat_rollout_diagnostics.dart`，公开 `rolloutPathFromThreadRaw` 并覆盖 camel/snake key、嵌套 `rollout.path`、空值跳过和稳定优先级；`ChatPage` 只负责命令参数校验和本地化提示。
- 本轮结构整理将 Chat thread sidebar 的宽度规则和 overlay breakpoint 从 `ChatPage` 拆到 `features/chat/chat_layout_metrics.dart`，公开 `chatThreadSidebarWidthFor` / `chatThreadSidebarOverlayBreakpoint` 并覆盖窄屏、overlay 和宽屏 docked 三档布局边界；`ChatPage` 只消费布局常量和计算结果。
- 本轮结构整理将 `/plugins` inline argument parser 从 `ChatPage` 拆到 `features/chat/chat_plugins_command.dart`，公开 list/read/install/uninstall 与 marketplace add/remove/upgrade 结构化 command 和 `parseChatPluginsCommand`，覆盖 marketplace kind filter、`read`/`show`/`detail`、`install`、`uninstall`/`remove`、add 的 `--ref`/重复 `--sparse` 参数以及非法参数边界；plugin 与 marketplace mutation 都要求用户确认其选中服务器和其他 Codex 客户端影响，取消时不发送 RPC，成功后刷新 `plugin/list`。连接层通过类型化 `MarketplaceMutationRunner` 严格调用 `marketplace/add`、`marketplace/remove`、`marketplace/upgrade`，兼容 camelCase/snake_case 结果并展示 upgrade 部分失败。
- 已将 `/plugins read` 与 `/plugins install` 对齐当前稳定 app-server 契约：操作前先从 `plugin/list` 权威 catalog 解析唯一目标，本地 marketplace 发送 `marketplacePath + pluginName`，远端 catalog 发送 `remoteMarketplaceName + remotePluginId`，同名插件冲突时要求使用列表中显示的唯一 plugin id，不猜测 marketplace；`plugin/read` 同时解析稳定的 `plugin.summary` detail 结构并兼容旧响应，`plugin/uninstall` 只发送协议允许的 `pluginId`。
- 已接入稳定的远端插件技能正文读取：`/plugins read <plugin>` 会展示 `plugin/read` detail 中的技能名、说明和启用状态，`/plugins skill <plugin> <skill>` 先通过同一 `plugin/list` catalog 解析唯一远端目标，再调用 `plugin/skill/read { remoteMarketplaceName, remotePluginId, skillName }` 并原样展示服务端返回的正文；本地 marketplace 不会错误调用远端 skill API，仍使用已有本地 plugin/skills/workspace 路径查看。
- 本轮结构整理继续将 `/mcp` inline argument parser、MCP status/OAuth/config runner 调用和本地化 summary 生成从 `ChatPage` 拆到 `features/chat/chat_mcp_command.dart`，公开 summary/reload/login 结构化 command、`parseChatMcpCommand` 与 `buildMcpSummaryFromCommand`，覆盖 `verbose`、`reload`/`refresh`、`login`/`oauth`/`auth`、runner 不可用和非法参数边界；`ChatPage` 只传入当前 thread/context controllers。
- 已接入稳定的只读 MCP resource API：`/mcp resource <server> <uri>`（兼容 `/mcp read-resource`）通过类型化 `mcpServer/resource/read` 读取内容，存在当前 thread 时携带 `threadId` 复用该线程的 MCP runtime/environment，没有当前 thread 时允许 threadless 读取；文本正文原样展示，二进制内容只显示 MIME 与 base64 字符数，不在对话区展开完整 payload。任意 MCP tool call 不在当前安全边界内，审计工作见 [TODO](../TODO.md#p1-协议与后端)。
- 本轮结构整理将 `/skills`、`/hooks`、`/apps` 的 catalog summary 命令加载、reader 不可用处理和加载失败摘要从 `ChatPage` 拆到 `features/chat/chat_catalog_summary_commands.dart`；`ChatPage` 只传入当前 cwd/thread context，summary 模块负责参数边界、reader 调用和本地化错误摘要。
- `/hooks` 已从只读 snackbar 摘要升级为可管理 bottom sheet：`hooks/list` 显示 cwd、event、handler、source、matcher、enabled 和 trust 状态；用户管理的 hook 可在二次确认后通过 `config/batchWrite` 的 `hooks.state` 启用/禁用或写入当前 `trusted_hash`，每次修改后重新读取列表；受管 hook 保持只读，旧连接没有 mutation runner 时回退原摘要路径。
- 本轮结构整理将 `/debug-config`、`/experimental`、`/memories` 的只读配置 summary 命令 refresh、cwd 选择和参数边界从 `ChatPage` 拆到 `features/chat/chat_config_summary_commands.dart`；`ChatPage` 只传入 config snapshot controller、当前 workspace cwds 和 thread raw memory context。
- 本轮结构整理将 `/raw` transcript view 的 `toggle`/`on`/`off` 参数解析从 `ChatPage` 的 `setState` 分支拆到 `features/chat/chat_raw_transcript_command.dart`；`ChatPage` 只根据纯函数返回的下一状态更新本地 raw timeline 显示。
- 本轮结构整理将 `/ps` 背景终端列表和 `/stop`/`/clean` 后台终端清理的参数边界、thread/runner 可用性检查与 runner 调用从 `ChatPage` 拆到 `features/chat/chat_background_terminal_commands.dart`；`ChatPage` 只传入当前 thread id 和 session runner。
- 本轮结构整理将 `/diff` 的空参数校验、当前 workspace cwd 选择、`GitDiffReader` 调用和加载失败摘要从 `ChatPage` 拆到 `features/chat/chat_diff_command.dart`；`ChatPage` 只传入当前 cwds 和 session diff reader。
- 本轮结构整理将 `/test-approval` 的空参数校验、本地 file-change 测试审批 payload 构造和 `ApprovalStateController.upsert` 调用从 `ChatPage` 拆到 `features/chat/chat_test_approval_command.dart`；`ChatPage` 只传入当前 thread/turn context 和时间。
- 本轮结构整理将 `/review` 的参数解析、`ThreadReviewRunner.startReview` 调用、返回 turn 跟踪、timeline 插入和 thread detail 刷新从 `ChatPage` 拆到 `features/chat/chat_review_command.dart`；`ChatPage` 只传入当前 thread/context controllers 和列表刷新回调。
- 已补齐 active turn 文本追加路径：`CodexAppServerClient`、`CodexTurnRunner`、`TurnController` 和 Chat composer 已支持 `turn/steer`，active turn 中发送普通文本会带 `expectedTurnId` steer 当前回合，而不是启动新 turn 或禁用输入；本次 turn overrides 仍只随 `turn/start` 消耗，不会被 steer 清掉。

### Goal / 重连稳定性修复（完成于 2026-07-15 11:50:14 +08:00）

- [x] **`/goal <objective>` 已对齐 TUI 的状态编辑语义。** 设置 objective 前先读取当前权威 goal：首次创建继续让服务端默认 `active`，已有 `complete` / `budgetLimited` goal 显式恢复 `active`，`paused` / `blocked` / `usageLimited` 保持上游状态；显式 `/goal status ...` 不做额外读取。`thread/goal/set` 返回后只提示“目标已更新，将在就绪后继续执行”，不再把正常的 `0 token` 初始快照表达成执行完成。已覆盖首次 goal、两个终态、paused/blocked/usageLimited 和显式状态更新测试。提交：`ff47af3`。
- [x] **权威 `thread/goal/updated` 已进入 live/replay timeline。** `CodexEvent` 解析完整 `ThreadGoal`，timeline 使用独立的 `threadGoalUpdate` 结构化类型，不伪造 `userMessage` 或 `turn/start`；界面显示等价的 `/goal <objective>`、权威状态、token 与时间用量。以服务端 `threadId + createdAt` 标识同一 goal 实例，后续状态更新与 reconnect snapshot 更新同一条记录，避免重复。提交：`7f592ed`。
- [x] **session recovery 已按 profile、connection generation、request generation 和 threadId 隔离。** `CodexSessionStateController` 为每个实际连接发布 generation；恢复请求在每次 await 后校验完整 ownership token，离开 connected 时立即使旧请求失效并清理 detail/turn/timeline 内存状态，同 profile 新连接仅恢复挂起 thread，切换 profile/host 不继承旧 thread。timeline 的 detail/turn/window hydration 已收敛到 `ChatPage -> ChatTimelineWindowCoordinator`，空 item 页可回退到稳定 `thread/read` turns；窗口 reset 会拒绝旧 host 的迟到页，snapshot 与 live delta 按服务端顺序合并并按 item ID 去重。提交：`bdc3c2b`。
- [x] **回归验证已完成。** 覆盖“旧请求在途 -> 断开 -> 连接另一 profile -> 旧结果迟到”、同 session reconnect、host switch、live delta 与初始/分页窗口交错、goal live/replay 去重、完整 detail fallback 和原有 host timeline/后台通知流程；`flutter analyze` 无问题，完整 `flutter test` 共 `1230` 项全部通过。

以上三项已完成，`/goal` 与 reconnect timeline 可按当前稳定 app-server 能力标记为端到端稳定。

### TUI 展示与通知可读性（完成于 2026-07-15 12:43:43 +08:00）

- [x] **命令执行输出已改为永久受限的头尾摘要。** command block 只显示总行数/字节数、头部、已本地化的中段省略标记和尾部；无论长短都至少隐藏一行或一个字符，完整输出永远不会进入 widget tree，展开/收起按钮及对应文案已删除。长输出、短单行输出、亮色/暗色 terminal 语义色和 ChatPage 结构化命令测试均按此安全契约更新。提交：`a1b6048`。
- [x] **Android 后台通知已完成原生 i18n 与别名优先级。** `SshProfile.notificationLabel` 优先使用用户填写的非空别名，没有别名时回退 `username@host:port`；展示身份通过 `BackgroundConnectionContext -> MethodChannel -> MainActivity -> BackgroundConnectionService` 传递，route matching 仍使用 profile/endpoint，不把展示名称混入连接身份。通知 channel、标题、活动任务、会话、回合和未知主机文案均移入 English / `values-zh-rCN` 资源，长 thread/turn ID 会压缩。提交：`884aca8`。
- [x] **active reasoning 已按 Codex TUI 方向浮动在 composer 上方。** timeline history 不再渲染 reasoning item；当前活动 turn 的多个 reasoning section 组合为 Markdown，通过 `WorkspaceMarkdownPreview` 直接展示，无折叠控件，并以有界滚动区域防止长推理与输入框重叠；turn 结束后浮层消失。提交：`37f6595`。
- [x] **queued steer 与 interrupt 已使用专用控制条目。** 普通新 turn 首条输入仍是 user message；活动 turn 中通过 `turn/steer` 提交的文本生成带唯一序号的 `queuedInstruction`，成功 `turn/interrupt` 生成 `interruptInstruction`，两者使用独立图标、颜色、key 和中英文标签，不再伪装成普通用户气泡。app-server 的持久化 `UserMessage` 不携带 queue/interrupt delivery metadata，因此该分类只在当前客户端会话内成立；首次到达且文本匹配的权威 user item 会逐条确认本地 queue，重复 replay/item-completed 不会误消费后来同文本的指令，重连历史不伪造服务端未提供的语义。提交：`8020264`。
- [x] **全量与设备验证已完成。** `flutter analyze` 无问题，完整 `flutter test` 共 `1241` 项全部通过，`flutter build apk --debug` 成功生成 `apps/sadcoder_mobile/build/app/outputs/flutter-apk/app-debug.apk`（构建产物继续由 Git 忽略）。Android 36 x86_64 emulator 已完成安装和冷启动：Sad 品牌名/icon 与 Hosts 首屏正常渲染；英文通知标题实际为 `Sad - Lab-Workstation` 且未显示 endpoint，简体中文通知实际显示“任务正在执行 / 会话 / 回合”，无别名时实际回退 `Sad - tester@10.0.2.2:22`；长 ID 在通知栏中压缩且无重叠，app 专属 logcat 与 crash buffer 均无 fatal。

以上四项已完成。通知展示身份与连接 route 保持分离；queued/interrupt 的特殊样式遵守当前 app-server 能力边界，不宣称可以从重连历史恢复未持久化的 delivery 语义。
