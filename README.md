# SadCoder

**中文** | [English](README-en.md)

SadCoder 是一个跨平台移动端 Codex 控制器，用于连接和管理远程服务器上运行的 Codex。移动 App 通过 SSH 连接服务器，启动或接入轻量的服务端 agent，再通过官方 app-server JSON-RPC 协议与 Codex 通信。

当前架构、协议、UI、安全和测试文档从 [docs/README.md](docs/README.md) 开始阅读。未完成工作和需要继续改进的事项只在 [TODO.md](TODO.md) 跟踪。

## 仓库结构

- `apps/sadcoder_mobile`：Flutter + Material 3 Android/iOS App。
- `crates/sadcoder-agent`：负责状态、生命周期和 app-server 代理命令的 Rust 服务端二进制。
- `crates/sadcoder-protocol`：agent 与测试共享的 Rust 协议 DTO。
- `resources`：移动端与 agent 共用的 manifest。
- `refs`：已忽略的 Codex 和 HappyCoder 本地参考项目。

## M0 本地协议探针

首个实现里程碑用于证明 app-server 协议边界，不重新实现 Codex 业务语义。

```powershell
cargo run -p sadcoder-agent -- status --json
cargo run -p sadcoder-agent -- doctor --json
cargo run -p sadcoder-agent -- probe --json
cargo run -p sadcoder-agent -- schema --json
cargo run -p sadcoder-agent -- slash-commands --json
```

`probe --json` 会启动 `codex app-server --listen stdio://`，发送 `initialize`，确认 `initialized`，然后调用 `model/list` 和 `thread/list`。

移动端提供 SSH command runner 抽象，并使用 `dartssh2` 实现远端 agent 命令调用。

交互式 Codex 会话会打开 SSH exec channel 并执行：

```powershell
sadcoder-agent proxy
```

需要时，`start` 会启动长期运行的 `sadcoder-agent service`。service 持有 `codex app-server --listen unix://...`；`proxy` 将 SSH channel 连接到本地 service socket，并在 App JSONL 消息与 app-server WebSocket text frame 之间桥接。service 运行在脱离 SSH channel 的 Unix session 或带 job breakaway 的 Windows process group 中，因此关闭移动端 SSH channel 只会停止 proxy 订阅，不会结束 service 持有的 app-server 进程。

backend 由 `--backend` 或 `SADCODER_BACKEND` 控制：

- `auto` 是生产 backend，始终连接 SadCoder service。service 无法启动或访问时，`start --json` 和 `proxy` 返回结构化错误，不会静默降级到 stdio。
- `auto` 只在已解析的 Codex command 通过 agent 版本/运行时 probe 后报告 ready。Codex 缺失、Node runtime 错误、权限失败或版本输出异常会报告 unavailable，不会把 stdio 错标成可用 backend。
- `stdio` 强制使用 direct stdio 调试路径；SSH 断开可能结束该 app-server 进程。
- `daemon` 仅为兼容保留并回退到 stdio，因为 npm/NVM Codex CLI 可能暴露 daemon 命令，但仍缺少官方 standalone installer layout。

`status` 不修改远端状态：在 `auto` 模式下报告 SadCoder service readiness；service 尚未运行时，会说明 `auto` 将启动并连接 SadCoder service。`start --json` 和 `proxy` 使用相同的 service-only 生产 backend；只有显式指定 `--backend stdio` 或兼容的 `--backend daemon` 时才使用 direct stdio。

`doctor --json` 将已解析 Codex command 的诊断与 `status --json` 使用的 agent status/backend/reconnect-cache 结构组合，调用方可以通过一个非破坏性命令排查 Codex runtime、service readiness 和待恢复状态。

`schema --json` 使用同一个已解析 Codex command 执行 `codex app-server generate-json-schema`，把生成的 JSON Schema bundle 缓存在 agent state 目录，并返回文件数量、总字节数、digest、bundle 路径和 Codex 版本。proxy 也通过 `agent/schema` 暴露同一摘要，并支持可选的 `refresh` 和 `experimental` 参数，因此移动 App 不需要自己定位或执行 `codex`。

## Codex 命令配置

移动 App 只需要定位 `sadcoder-agent`。Codex executable、runtime PATH 和版本诊断均以 agent 为权威来源。

agent 按以下顺序解析 Codex：

1. `--codex-path` / `--codex-program`
2. `SADCODER_CODEX_PATH`
3. 已持久化的 agent config
4. 继承的 `PATH`
5. 自动发现常见安装位置

自动发现只有在 agent 可以执行同一个 resolved command，并识别其 `codex --version` 输出后才会缓存候选项。无效 wrapper、错误 Node runtime 和与 Codex 无关的同名程序会被跳过，不会写入持久化配置。

持久化 Codex command：

```powershell
sadcoder-agent configure --codex /home/me/.nvm/versions/node/v24.14.1/bin/codex --path-prepend /home/me/.nvm/versions/node/v24.14.1/bin --json
```

使用重复的 `--codex-arg` 持久化 wrapper 参数：

```powershell
sadcoder-agent configure --codex /opt/codex-wrapper --codex-arg --profile --codex-arg mobile --path-prepend /opt/node/bin --json
```

生成的配置是结构化数据，例如：

```json
{
  "codex": {
    "program": "/home/me/.nvm/versions/node/v24.14.1/bin/codex",
    "args": [],
    "pathPrepend": ["/home/me/.nvm/versions/node/v24.14.1/bin"],
    "version": "codex-cli 0.143.0"
  }
}
```

配置文件位置：

- Linux/macOS：`~/.config/sadcoder/agent.json`
- Windows：`%LOCALAPPDATA%\SadCoder\agent.json`

`slash-commands --json` 输出 `resources/slash_commands_manifest.json` 中的共享斜杠命令 manifest。manifest 跟踪当前 Codex TUI 命令、别名、可用性规则、实现阶段和 SadCoder 映射策略，确保 `/...` 输入按命令处理，而不是静默作为普通 prompt 发给模型。

## 验证

```powershell
cargo fmt --all -- --check
cargo test --workspace
cd apps\sadcoder_mobile
dart format lib test
flutter analyze
flutter test
```
