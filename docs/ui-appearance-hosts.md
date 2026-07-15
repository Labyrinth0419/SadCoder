# 主题、主机、设置与 i18n

## 9.7 深色模式

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

### 9.7.1 主机、设置与主题演进

用户体验要求：

- SSH 主机管理支持多台主机：本地保存多 profile，按 host 分组折叠展示；多 host 同时连接和 per-host session/thread 列表已落地。
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
- OpenSSH config 导入会隔离 `Match` 条件段，不把它继续套用到前一个主机或全局默认；当前移动端只导入明确的 `Host` 段，条件段扩展见 [TODO](../TODO.md#p1-协议与后端)。
- 已落地 Chat 顶栏主机选择器、Settings 二级菜单、candy/lagoon/ember palette 和斜杠命令高级可见性开关。
- 已落地 Chat 侧栏 per-host 会话可见化：`HostSessionSummary` 携带当前选中 thread id/title 及该 host 当前缓存/远端列表，`AppShell` 从每个 host 的 UI state 汇总；Chat 左侧栏显示所有 managed host 的状态、endpoint、当前 thread 和可展开的完整线程列表，点击线程会先切换 host 再读取对应 thread。后台 active-turn、cursor gap、分页回填和 reconnect reconciliation 均按 host 隔离；active host 断开或失败时会自动选择仍可用的 host，没有候选时清空 active profile。
- Settings 菜单已明确收敛为最多二级：一级分组为 Codex、Interface、Connection、System，二级才进入 Permissions、Account、Models、Appearance、SSH、Diagnostics；Diagnostics 默认折叠在 System 下，避免低频诊断项和常用设置平铺混杂，窄屏仍保持“菜单页 -> 具体设置页”的单详情导航。
- AppShell 底部 `NavigationBar` 高度为 58px，以减少主对话页被全局导航占用的垂直空间。二级 Chat detail 路由属于开放设计，见 [TODO](../TODO.md#p1-移动端结构与交互)。
- 本轮 Chat 侧栏可用性里程碑已在左上三横线打开的会话面板顶部加入带图标和明确文字的全宽“新建对话”入口，避免入口藏在会话列表标题行或多主机列表下方；按钮复用 `/new` 的 `startNewThread` 生命周期，成功后清理旧 timeline、刷新会话列表并在窄屏 overlay 侧栏中自动收起，活动 turn 时自动禁用。
- 已修复三横线侧栏重复展示会话面板：`ChatThreadListPanel` 作为唯一线程/归档/恢复入口始终保留；存在 `hostSessions` 多主机汇总时，主机卡只显示连接状态与当前线程上下文，关闭其内部 per-host 线程展开，避免同一当前主机线程被渲染两次；没有当前线程列表 controller 时仍保留 host panel 的 per-host fallback。
- 已落地配置覆盖三层恢复入口：Settings 可一键清除 App 默认覆盖、会话覆盖和本次覆盖并回到服务器默认来源；本地恢复动作不伪造 `thread/settings/update` 普通字段显式清理语义。
- 已落地 per-host pending approval 聚合与动作路由：Approvals 页面展示所有已连接 host 的待审批项，审批响应回到所属 host 的 `ApprovalStateController`。
- 已落地 per-host thread summary/detail cache 持久化/恢复：每个 host 的最近线程列表、选中 threadId 和当前 thread detail 通过 `ThreadCacheStore` 独立保存，重建 host UI state 时优先恢复缓存，再由远端权威 thread/detail 读取刷新。
- 已落地 per-host thread item cache reader、timeline 恢复和 reconnect fallback：`ThreadItemCacheStore` 按 profile/thread 隔离保存 item summaries 和分页游标，`local_data` schema 已补 `item_cache.profile_id` 与 profile/thread 索引；`CodexSessionStateController.threadItemListReader` 已通过缓存 decorator 保存/回退 canonical thread item 读取，host UI state 恢复选中 thread 时会从 item cache 回填 timeline；重连时 `thread/turns/list(itemsView: full)` 会有界分页回填当前 thread，若 turn list 不可用或失败，会尝试 `thread/items/list` 有界分页回填 timeline；turn/item 分页边界按 id 去重，优先保留新页数据。
- 已落地删除 SSH profile 时清理 per-host 普通重连缓存：`ThreadCacheStore`、`ThreadItemCacheStore` 与 `ThreadTimelineCursorStore` 的 SharedPreferences 实现支持按 profile 删除本地 thread summary、item cache 和 delivered cursor/timeline cursor；Hosts 页面删除主机配置时会 best-effort 清理这些非敏感缓存，避免已删除主机的会话状态残留。
- `ChatTimelineController.cursor` 可从当前 selected thread 的 turns/items 派生已见 turnId/itemId、lastTurnId 和 lastItemId，并用于持久化 cursor、断线增量回填和 agent delivered cursor 对接。
- `ThreadTimelineCursorStore` 按 profile/thread 保存已见 turnId/itemId、lastTurnId/lastItemId，并由 `AppHostSessionUiState` 监听 timeline 变化进行 best-effort 写入；reconnect 使用该持久化 cursor 对接 agent delivered cursor 和增量回填。
- 已落地 cursor-aware reconnect backfill 基础：`AppSessionRecoveryCoordinator` 可读取 host/thread 持久化 timeline cursor，turn 分页回填遇到 lastTurnId 会保留边界 turn 后停止继续翻旧页；item fallback 遇到 lastItemId 后从边界 item 开始恢复并继续读取后续页，边界缺失时回退为旧的 bounded page 行为。
- `sadcoder-agent` reconnect cache 为 recent event 分配递增 cursor 并在 snapshot 上记录 `deliveredCursor`；Rust protocol 与移动端 `AgentSnapshot` 均支持 camel/snake case cursor 字段解析和按 delivered cursor 请求增量事件。
- `agent/snapshot` 可额外返回从 app-server 事件和 pending request 中提取的 threadId、lastTurnId、lastItemId 与 lastEventCursor，移动端解析该可选 `threads` 字段并用于 per-thread delivered cursor/gap 合并和 last turn/item 边界持久化。
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
- `AgentStateSnapshot` 暴露 `retainedCursorFloor` 与 `cursorGap`，当客户端 `sinceCursor` 早于 agent retained recent event 窗口或无法在窗口中确认时标记 gap，并触发更保守的 thread/read、turn/item 分页 reconciliation。
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
- `CodexAppServerClient` / `CodexRealtimeRunner` 具备 `thread/realtime/*` 的类型化协议和通知映射。主线仍以普通文本 `turn/start` 为权威会话路径；语音输入优先使用手机系统语音转文字后发送普通 turn。提交 `07863db` 的 WebSocket 音频设备链路保持隔离，重新立项条件见 [TODO](../TODO.md#future-features)。
- Chat composer 隐藏实验性 realtime/语音按钮，不把隔离的音频链路伪装成主流程入口；需要语音输入时使用系统语音转文字后发送普通 `turn/start`。
- App 对外品牌已正式收敛为 `Sad`：Flutter title、Android label/后台任务通知、iOS display/bundle name 和 App 内可见产品名统一更新，Android/iOS launcher icon 全部由 `assets/branding/sad-icon.svg` 生成；Dart package、Android applicationId、MethodChannel、数据目录与 `sadcoder-agent` 协议标识保持兼容，不随展示名重命名。
- 已落地受控 Files 文本编辑：连接层暴露独立 `WorkspaceFileMutationRunner`，`fs/writeFile` 仅在 workspace path/符号链接校验、完整文本加载、版本或旧内容冲突检查通过后调用；Files 编辑 sheet 保存前展示逐行 diff 并要求二次确认，写入后刷新 preview stat/content。`fs/watch` / `fs/unwatch` 与 `fs/changed` 也已类型化，当前预览文件发生外部变化时会提示用户重新审阅。由于上游 `fs/writeFile` 没有 expected-version 参数，冲突检查仍是非原子的乐观保护。
- 已落地结构化 Codex maintenance / Cloud runner：`sadcoder-agent codex` 只暴露固定的 `doctor`、`update`、legacy `apply`、`cloud list/status/diff/apply` 操作，task/env/cursor/attempt/cwd 均由 Rust `Command::arg` 传递，不提供任意 shell 参数。Settings Diagnostics 提供只读诊断/查询、更新确认、apply 前 diff 预览和 backend 重启入口；Cloud 明确依赖服务器已有 ChatGPT auth，手机不保存认证或 API key，API-first 主流程不变。
- 已落地多 host 同时连接生命周期：`HostSessionManager` 为每个 host 保留独立 session、approval、thread/item/timeline state；并发连接请求合并，后台保活与断线 cursor/分页回填按 host 隔离，active host disconnect/failure/close 后优先切换到 connected/connecting/reconnecting host，没有可用候选时清空 active profile。对应 manager、AppShell 和 Chat host selector 回归测试已覆盖。

## 9.8 i18n

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
