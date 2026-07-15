# SSH、保活与重连

## 7. SSH 配置设计

### 7.1 Profile 字段

基础字段：

- profile name
- host
- port
- username
- authentication type：password / private key
- private key content 或移动端文件引用
- passphrase
- known host fingerprint
- default remote cwd
- codex path：默认 `codex`
- CODEX_HOME：可选
- connection mode：agent service proxy / direct stdio debug fallback

高级字段：

- ProxyJump
- connect timeout
- keepalive interval
- environment variables
- remote shell prefix
- custom agent/backend start command
- custom proxy command

### 7.2 OpenSSH config 兼容

首版 UI 支持常用字段，不承诺完整 OpenSSH parser：

- `Host`
- `HostName`
- `User`
- `Port`
- `IdentityFile`
- `ProxyJump`
- `IdentitiesOnly`

高级用户可以手动编辑 SadCoder 自己的 config 文件：

```toml
[[hosts]]
name = "prod"
host = "10.0.0.12"
port = 22
user = "ubuntu"
identity_file = "..."
codex_bin = "codex"
default_cwd = "/home/ubuntu/project"
mode = "agent-proxy"
```

App 内部存储使用加密数据库；导入/导出时明确提示敏感信息处理。

### 7.3 Host key 策略

- 默认启用 TOFU：首次连接展示 fingerprint，用户确认后保存。
- fingerprint 改变时必须阻断连接并要求用户明确处理。
- 不提供“永久忽略 host key”作为普通选项。
- 支持 SHA256 fingerprint 展示。

当前实现状态：

- 已落地 Hosts 页面 changed host key 专用阻断弹窗：当已保存 endpoint 的 key type 或 SHA256 fingerprint 与当前收到值不一致时，App 会展示已保存/当前收到的 key type 与 fingerprint，只提供关闭动作，不提供信任继续或自动重试；手动 probe 与连接按钮路径均覆盖。

## 8. 保活、重连与连通性验证

### 8.1 自动保活

分三层：

1. SSH 层：启用 SSH keepalive 或定期 global request。
2. Agent proxy 层：定期 ping/pong 或 `agent/ping`。
3. App-server 层：空闲时低频发送轻量 RPC，例如 `thread/loaded/list`；活跃 turn 期间主要依赖事件流。

建议参数：

- SSH keepalive：15-30 秒。
- Agent proxy ping：15-30 秒。
- App RPC heartbeat：60 秒，仅前台或 active turn。
- 重连 backoff：1s、2s、5s、10s、30s，上限 60s，带 jitter。

### 8.2 移动端后台策略

- 没有 active turn：App 进入后台后可以断开长连接，只保留本地状态。
- Android 有 active turn：启动 foreground service，通知栏显示当前 host/thread，保持连接接收审批和完成状态。
- iOS 有 active turn：尽量在前台保持实时连接；进入后台后利用有限后台时间完成短任务，长任务依赖 agent 继续运行并在下次打开 App 时回填状态。自编译安装不改变 iOS 后台限制。
- 用户可关闭“后台保持连接”，关闭后只做断线恢复，不保证实时审批通知。
- Android WorkManager 只做低频健康检查，不承诺实时性。
- 无论哪种后台策略，App 断线都只是停止实时观察；服务器上的 active turn 必须继续执行或继续等待审批，不能被 App 生命周期自动中断。

### 8.3 重连流程

1. SSH 断开或 agent proxy 心跳失败。
2. App 标记 UI 为 reconnecting，但不向 agent 或 app-server 发送中断。
3. agent 继续持有 backend app-server 连接；如果 backend 崩溃，agent 按 backend 恢复策略处理，但不能因手机断开而主动终止 turn。
4. App 重新 SSH 连接。
5. 执行 `sadcoder-agent status --json`，必要时 `sadcoder-agent start`。
6. 重新打开 `sadcoder-agent proxy`。
7. 重新 `initialize`。
8. 对当前 thread 执行 `thread/resume` 或 `thread/read`。
9. 使用 `thread/turns/list` / `thread/items/list` 回填丢失事件。
10. 优先通过 proxy 内的 `agent/snapshot` 拉取 agent 缓存的 pending approvals 和最近事件；旧版本或兼容路径才回落到独立 `sadcoder-agent snapshot --json`。
11. 如果仍有 active turn，继续订阅事件；否则标记 idle。

### 8.4 手动连通性验证

“测试连接”按钮输出分阶段诊断：

1. TCP connect。
2. SSH handshake。
3. Host key 校验。
4. Auth 成功。
5. 远端 shell 可执行。
6. `sadcoder-agent status --json` 可执行，并返回 Codex path/availability/version/backend。
7. 必要时 `sadcoder-agent start` 可启动 service 或明确返回失败原因；direct stdio 只在显式 debug/compat backend 下单独诊断。
8. `sadcoder-agent proxy` 可连接。
9. JSON-RPC `initialize` 成功。
10. `account/read`。
11. `model/list`。
12. `thread/list limit=1`。

`sadcoder-agent doctor --json` 是非破坏性组合诊断入口，应同时返回 Codex 命令解析/版本/失败原因、agent status、backend readiness 和 reconnect cache 状态。App 通过 SSH 读取该 JSON，并在 Settings -> Diagnostics 中用结构化卡片展示，不直接在 App 侧重新执行 Codex 探测。

每一阶段都要给出明确错误和建议，例如：

- Codex 未安装。
- Codex 版本过低。
- agent 未安装或未运行。
- Windows service/计划任务未启动。
- SadCoder service 不可用或启动失败。
- ChatGPT/API key 未登录。
- 权限不足或 cwd 不存在。
