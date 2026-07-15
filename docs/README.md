# SadCoder 文档

本目录描述 SadCoder 当前采用的产品原则、系统边界、协议、能力、界面、安全策略和验证契约。开放工作不写回主题文档，统一由根目录的 [TODO.md](../TODO.md) 跟踪。

## 文档索引

- [产品目标与原则](product-principles.md)：目标、参考项目结论、第一性原理和已采用的总体决策。
- [技术栈与系统架构](architecture.md)：Flutter 客户端、Rust agent、生产 service/proxy 路径和 direct stdio 调试路径。
- [协议、配置与兼容性](protocol.md)：app-server 初始化、JSON-RPC、事件/审批、配置覆盖和斜杠命令映射。
- [功能与 CLI 覆盖](capabilities.md)：当前能力分组及 CLI/app-server 覆盖策略。
- [SSH、保活与重连](ssh-connectivity.md)：profile、host key、后台策略、重连和连通性诊断。
- [Chat 信息架构与对话交互](ui-chat.md)：会话导航、timeline、composer、reasoning、queue/interrupt 和完成的稳定性里程碑。
- [审批、配置覆盖与斜杠命令 UI](ui-approvals-settings.md)：Approvals、配置来源/覆盖范围和命令面板行为。
- [工作区文件浏览与受控编辑](ui-files.md)：目录树、range read、预览、diff、文件变更和 workspace 安全边界。
- [主题、主机、设置与 i18n](ui-appearance-hosts.md)：主题、SSH profile、多 host、后台恢复、设置导航和本地化。
- [本地数据与安全](data-security.md)：本地模型、凭据、审批边界和日志脱敏。
- [测试策略与兼容性矩阵](testing.md)：自动化测试契约、集成测试范围、设备 QA 和目标平台矩阵。
- [里程碑范围记录](milestones.md)：原始 M0-M4 范围，用于解释功能演进，不作为开放任务清单。
- [风险与决策](risks-decisions.md)：长期风险、约束和已经采用的决策。

## 维护规则

1. 已实现行为、稳定接口和长期约束写入对应主题文档。
2. 未实现、待验证、依赖上游或需要进一步改进的事项只写入 [TODO.md](../TODO.md)。
3. 完成 TODO 时，先更新相关主题文档，再从 TODO 删除或移入完成记录；不要在两个位置保留相互冲突的状态。
4. 版本相关能力以运行时 capability probe 和当前 Codex app-server schema 为准，文档不替代协议探测。
