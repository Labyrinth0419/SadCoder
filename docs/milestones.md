# 里程碑范围记录

本文保留原始 M0-M4 的范围定义，用于解释功能演进和能力分组，不作为开放任务清单。未完成、待验证或需要继续改进的事项只在 [TODO](../TODO.md) 跟踪。

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
- MCP server status/oauth/resource read。
- plugin/skill marketplace。
- review。
- rate limits/usage。
- 第二阶段斜杠命令完整映射：review/fork/compact/goal/diff/mention/usage/MCP/plugin/skill/hooks/logout/background terminals。
- `/side`、`/btw` 实验支持：ephemeral fork、side boundary prompt、side/main 切换、审批归属、断线降级。

### M4：高级能力

目标：接近完整 Codex 控制台。

交付：

- realtime：实验性文本入口已接入；主线语音输入采用系统语音转文字后发送普通 `turn/start`，不要求自建实时音频/WebRTC 链路。
- process/spawn。
- remote environments。
- hooks。
- external agent config import。
- doctor/update/apply/cloud 的结构化 agent runner 与 Diagnostics UI；已落地固定 typed 操作、风险确认、apply 前 diff 预览和 update 后 backend 重启入口。
- 第三阶段斜杠命令、调试命令和平台专属命令覆盖。
- `/agent`、`/subagents` 多 agent 拓扑：只读树、agent picker、thread 切换、状态回填；主动控制不属于当前交付范围。

Future Features 及其重新立项条件见 [TODO](../TODO.md#future-features)。
