# 风险与决策

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
- 会话拓扑保持明确边界：`/side`、`/btw` 使用 ephemeral fork；`/agent`、`/subagents` 当前只读并允许切换查看，主动控制单独审计。
- 所有拓扑切换都必须携带明确 threadId，审批、事件回填和 interrupt/cancel 必须绑定到具体 thread/turn，不能使用“当前 UI 所在页面”做隐式目标。
- UI 分阶段结构化。
- 提供高级 Raw RPC 面板用于临时覆盖新能力，并保持显式确认。Raw Command/SSH fallback 不属于当前安全边界，开放工作见 [TODO](../TODO.md#p1-协议与后端)。

## 15. 已采用的决策

1. 首版服务器是否同时支持 Linux 和 Windows？
   - 决策：是。为此把 `sadcoder-agent` 提升为生产路径；SadCoder service 统一承接 Linux/Windows。

2. 是否接受服务器除官方 `codex` 外再安装一个 `sadcoder-agent`？
   - 决策：接受。否则 Windows 上很难可靠保活；`sadcoder-agent` 保持薄层，不 fork Codex。

3. MVP 是否必须支持手机后台长时间实时收审批？
   - 决策：Android active turn 用 foreground service 支持；iOS 不承诺长期后台实时收审批，依赖重连回填。

4. Codex 登录凭据放哪里？
   - 决策：放服务器 `CODEX_HOME`，手机只触发/展示登录流程，不长期保存 OpenAI 凭据。

5. 是否要做 Flutter 跨端？
   - 决策：是。Android 主发布，iOS 工程保持可自行编译安装。

6. 是否要 fork Codex 或魔改 Codex？
   - 决策：不 fork。只有官方 app-server 加 `sadcoder-agent` 仍无法满足核心目标时才重新评估。
