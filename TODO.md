# SadCoder TODO

本文件是 SadCoder 未完成工作、待验证事项和条件性 Future Features 的唯一清单。当前架构与已实现行为见 [docs/README.md](docs/README.md)。

优先级定义：

- `P0`：发布、数据安全、任务连续性或核心兼容性阻塞项。
- `P1`：明确需要补齐的产品能力、架构改进或自动化覆盖。
- `P2`：依赖上游能力或需要产品验证后再做的增强。
- `Future`：当前不进入主线里程碑，满足重新立项条件后再评估。

## P0 发布与平台验证

- [ ] 配置独立 Android release keystore 和安全的 CI/本地注入方式，移除 `release` build 对 debug signing config 的依赖；验证 split-ABI APK/AAB 的 v2/v3 签名、升级安装和密钥备份流程。
- [ ] 在 Ubuntu LTS、Debian、Windows 10/11 和 Windows Server 2022+ 上完成 `sadcoder-agent service/proxy` 与显式 direct stdio fallback 的真实集成矩阵；覆盖 Codex 安装、initialize、thread/turn、审批、断线和 backend 恢复。
- [ ] 在真实 Codex app-server 版本上验证 `thread/items/list(sortDirection=desc)` 的 `nextCursor` 确实指向更早历史页，并覆盖 live delta、分页、reconnect backfill 和 cursor gap 交错。
- [ ] 完成 Android 10+、Android 13+ 通知权限和 iOS 16+ 自编译安装验证；确认当前最低系统版本后将“候选”升级为发布契约。
- [ ] 完成真机网络与生命周期 QA：Wi-Fi/蜂窝网络切换、前后台切换、Android active-turn foreground service、iOS 后台后重连回填、长 command 摘要、超大 diff 性能和 changed host key 阻断。

## P1 协议与后端

- [ ] 为 `sadcoder-agent installCodex` 设计受控安装自动化：固定来源、版本校验、变更摘要、权限边界、失败回滚和 Linux/Windows 差异必须可审计。
- [ ] 为 Raw Command/SSH fallback 设计独立的安全模型；至少覆盖命令白名单或结构化参数、目标 host/cwd、二次确认、敏感信息脱敏和执行结果归属。现有 Raw RPC 不得自动升级为任意 shell。
- [ ] 当官方 app-server 暴露 slash command manifest 时，从本地/agent 维护的 manifest 切换到官方来源，并保留版本差异与新增命令的 CI 审计。
- [ ] 评估并实现 OpenSSH `Match` 条件段的显式导入语义；在此之前继续只导入明确的 `Host` 段，不能把条件配置错误套用到全局或前一个 host。
- [ ] 为 `/setup-default-sandbox` 和 `/sandbox-add-read-dir` 的真实 agent fallback 增加结构化变更摘要、平台校验、高风险确认和审计记录；当前只保留安全诊断，不执行修改。
- [ ] 审计任意 MCP tool call 的确认、权限、参数展示、结果归属和重连语义；完成前仅支持稳定的 MCP status/OAuth/resource read 路径。
- [ ] 改进 Files 写入一致性：优先采用上游 CAS/expected-version 和原子 rename；上游不可用时继续明确标注 best-effort 乐观冲突检查与 copy-then-remove partial failure。
- [ ] 补齐 `/side`、`/btw` 的集成测试：创建/返回/丢弃 side thread 不得 interrupt main thread，审批、事件和中断必须始终绑定显式 thread/turn。

## P1 移动端结构与交互

- [ ] 评估并实现二级 Chat detail 路由：主页进入会话选择，再进入隐藏 bottom navigation 的对话详情；明确返回、侧栏、active turn 和多 host 切换行为。
- [ ] 继续降低 `ChatPage` 体量：优先拆分 slash command dispatcher callbacks 与仍由页面持有的 command sheets，同时保持现有 controller ownership 和 widget key 契约。
- [ ] 评估 `/agent`、`/subagents` 的主动 send/wait/close/resume 控制；在 thread/approval/interrupt 归属可以严格证明前，只保留只读拓扑和 thread 切换。
- [ ] 将 API key、ChatGPT browser/device-code 登录保留为非主路径兼容能力；实现前必须明确凭据只由服务器 Codex 持久化，移动端不长期保存 OpenAI 凭据。
- [ ] 服务器明确提供 Codex Desktop handoff/rollout 结构化能力后，再替换当前 `/app` 不适用提示和 `/rollout` 只读诊断；不得通过猜测路径或任意 shell 模拟。

## P1 测试与兼容性维护

- [ ] 建立 Linux/Windows CI 的 Codex 版本兼容矩阵，持续验证 capability probe、schema digest、slash manifest、server request auto-response 和 service/direct-stdio backend。
- [ ] 将仍停留在测试策略中的端到端路径落到可重复环境：pending approval 跨断线、仅显式 interrupt/cancel 才中断、side conversation 边界、agent/subagent 状态回填和 host 切换恢复。
- [ ] 增加 macOS arm64 可选自测，确认 agent 构建、SSH proxy 和 app-server 基础能力；该平台暂不作为首版承诺。

## P2 条件性增强

- [ ] 只有现有 Flutter/Dart SSH、stream codec、secure storage 或后台连接复杂度形成可测量瓶颈时，才评估抽取 Rust 通信核心并通过 `flutter_rust_bridge` 复用。
- [ ] 需要桌面端产品后，再基于共享通信核心单独设计桌面 UI；当前移动端主线不为桌面形态提前增加抽象。
- [ ] 完整 OpenSSH parser、复杂条件配置和更广泛的代理组合仅在真实用户配置无法由当前字段集表达时扩展。

## Future Features

- [ ] `07863db` 的 WebSocket PCM 音频采集/播放实验保持隔离，不作为当前必做项。只有手机系统语音转文字无法满足明确需求时，才重新立项端到端 realtime audio。
- [ ] 重新立项 realtime audio 时，必须单独验证 WebRTC/传输协议、音频质量、回声消除、权限、前后台行为、跨设备兼容性以及与普通 `turn/start` 会话恢复的关系。
