# 产品目标与原则

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
