# 本地数据与安全

## 10. 本地数据模型

建议本地数据库表：

- `ssh_profiles`
- `known_hosts`
- `connection_history`
- `thread_cache`
- `item_cache`
- `pending_approvals`
- `app_settings`
- `codex_config_snapshots`
- `codex_override_profiles`
- `slash_command_manifest_cache`
- `slash_command_usage_history`
- `raw_rpc_logs`

缓存原则：

- 服务器 Codex 状态是权威来源。
- 本地缓存只用于离线浏览、快速恢复 UI、诊断。
- Codex override profile 只记录 SadCoder 显式覆盖，不代表服务器真实配置。
- 不在手机上长期保存敏感项目文件内容，除非用户明确打开并缓存。

## 11. 安全设计

### 11.1 凭据

- SSH 私钥和密码/passphrase 使用 Android Keystore 与 iOS Keychain 加密。
- 支持生物识别解锁 profile。
- 不把 OpenAI API key 存到手机，除非用户明确选择“从手机写入服务器 Codex 登录”。推荐让 Codex 凭据留在服务器 `CODEX_HOME`。
- 主路径依赖服务器侧已配置的 API key；App 只读取/展示账号状态，不把交互式登录作为主要功能。服务器侧 Codex 始终负责持久化凭据，非主路径登录兼容工作见 [TODO](../TODO.md#p1-移动端结构与交互)。
- App 默认不写服务器 Codex 配置；任何 `config/value/write` 或 `config/batchWrite` 都必须由用户从高级配置入口显式触发。

### 11.2 权限与审批

- 默认权限模式不应是 `danger-full-access`。
- UI 明确显示当前 approval policy 和 sandbox/permission profile。
- 对 `danger-full-access`、`approvalPolicy=never` 组合显示高风险标记。
- 审批操作需要防误触：高风险命令或大 diff 可要求二次确认。

当前实现状态：

- Settings/Chat status 会显示当前 approval policy、sandbox/permission profile，并对 `approvalPolicy=never`、`dangerFullAccess`/`:danger-full-access` 这类高风险状态显示明确 warning。
- `/permissions` 在应用 turn/session 权限覆盖前会重新判定高风险状态；命中 `approvalPolicy=never`、`dangerFullAccess` sandbox 或 `:danger-full-access` permission profile 时，必须通过二次确认才写入本地 override，取消不会启动 turn，也不会修改已有覆盖。
- 审批页已对高风险命令和大 diff 加二次确认；移动端 `/setup-default-sandbox`、`/sandbox-add-read-dir` 这类高风险斜杠命令在真正落地 fallback 前也需要确认。

### 11.3 日志脱敏

日志默认脱敏：

- passwords
- private keys
- API keys
- access tokens
- Authorization headers
- cookie-like values

导出日志前再次提示用户可能包含路径、命令、项目名。

当前实现状态：

- JSON-RPC diagnostic log buffer 默认通过 `LogRedactor` 保存 redacted payload，并在复制/导出前再次弹出确认，提示可能包含路径、命令和项目名。
- agent/app-server service logs 在进入移动端模型与 Settings UI controller 前都会再次通过 `LogRedactor` 脱敏；`content` 与 `error` 会清理 password、private key、API key、access token、Authorization header 和 cookie-like values，日志 path、大小、tail/truncated 等诊断元数据保留。
