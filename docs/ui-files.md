# 工作区文件浏览与受控编辑

## 9.6 工作区文件浏览与只读查看

工作区文件浏览是 `/mention`、`/ide`、代码审查、diff 查看和受控编辑的基础能力，作为独立的 `features/files` 模块维护，不放入 `ChatPage`。

目标：

- 基于当前 workspace cwd、thread cwd 或显式 cwd override 浏览工作区目录树。
- 支持展开目录、刷新目录、搜索/过滤文件、复制文件路径。
- 支持打开文本文件进行只读查看。
- 支持代码文件语法高亮。
- 支持 Markdown 文件在渲染视图和 raw 源码视图之间切换。
- 支持大文件分段读取，不强制一次性读取完整文件。
- Files 页面默认保持内容浏览边界；需要 mutation runner 时才显示受控的新建、复制、移动/重命名、删除和文本编辑入口。所有变更都经过 workspace path guard、符号链接防护和二次确认，不复用只读 reader 直接写入。
- 顶栏允许进入独立 Terminal 页面，终端命令仍遵循独立的 sandbox/host-process 确认流程；文件生命周期操作使用结构化 filesystem RPC，不把任意 shell 写文件能力混入文件预览流程。

结构要求：

- 新增 `WorkspaceDirectoryReader`，负责目录列表读取、分页、隐藏文件策略和错误归一化。
- 新增 `WorkspaceFileReader`，负责文件元信息和内容读取。
- 优先使用结构化 app-server/agent file API；如果暂时只能通过 `command/exec` fallback 实现，fallback 必须封装在 reader 内，不允许 UI 直接拼命令。
- 目录树、文件查看器、Markdown/raw 切换、代码高亮都放在 `features/files` 下，聊天页只负责入口或上下文联动。
- 所有路径必须限制在 workspace root 内，禁止 `..`、绝对路径替换、符号链接逃逸等路径穿越。
- 文件 API 必须返回结构化错误：未连接、无 cwd、路径不存在、权限不足、路径越界、二进制不可预览、文件过大、读取失败。

建议协议：

- `workspace/directoryList`
  - 参数：`root`、`path`、`limit`、`cursor`、`includeHidden`。
  - 返回：目录项列表、分页 cursor、文件/目录类型、大小、修改时间、是否隐藏。
- `workspace/fileStat`
  - 参数：`root`、`path`。
  - 返回：文件类型、大小、mtime、是否二进制、mime/language、内容版本或 hash。
- `workspace/fileRead`
  - 参数：`root`、`path`、`offset`、`limitBytes`、`encoding`。
  - 返回：`sizeBytes`、`offset`、`bytesRead`、`nextOffset`、`hasMore`、`encoding`、`isBinary`、`content`、`contentHash` 或 `version`。

大文件策略：

- 小文件可以一次性读取并完整渲染。
- 大文件默认使用 range read：`offset + limitBytes`，UI 显示已加载大小/总大小，并提供“加载更多”。
- range read 必须避免切坏 UTF-8 字符；服务端应在安全边界返回文本 chunk。
- range read 的后续 chunk 加载失败时，UI 必须保留已加载内容并允许用户按同一 offset 重试，不能把整个预览重置为空状态。
- Markdown 大文件默认 raw 分段查看；只有文件大小低于阈值或用户明确触发时才完整渲染。
- 代码高亮只保证对当前已加载内容生效，不要求跨 chunk 完整语义高亮。
- 二进制文件默认不预览文本，显示文件大小、类型、路径和不可预览状态。

验收标准：

- 未连接、无 cwd、空目录、权限不足、路径不存在、路径越界、大文件、二进制文件都有明确 UI 状态。
- 可以从当前 workspace root 浏览目录树并打开 `.dart`、`.rs`、`.md`、`.txt` 等文本文件。
- Markdown 文件默认可渲染，并可切换 raw；大 Markdown 受大小阈值保护。
- 代码文件有语法高亮；大文件模式不会阻塞 UI。
- 文件读取支持分段加载，测试覆盖 `nextOffset`、`hasMore`、编码边界和错误状态。
- 没有 mutation runner 时不出现写文件入口；只读查看不会触发 server turn、不会修改工作区。启用 mutation runner 后，受控变更入口必须经过明确确认并在完成后刷新工作区。
- Files toolbar 不暴露 terminal/shell command 入口，避免把只读浏览和命令执行混在同一模块里。

当前实现状态：

- 已落地 `features/files` 独立模块，包含目录树、文件预览、Markdown render/raw 切换、代码高亮、远端文件搜索入口和只读 toolbar。
- 已落地 `workspace/directoryList`、`workspace/fileStat`、`workspace/fileRead` 的 agent RPC，并保留旧 `fs/*` 只读方法作为客户端兼容 fallback。
- 已调整 Files 页面为左侧工作区文件侧栏和主区域 status page / 文件预览；文件过滤、隐藏文件、远端搜索和刷新入口已收敛为紧凑工具行，搜索栏高度已压缩，显式 workspace root 与默认 root 选择保持折叠入口。
- 本轮 UI pass 已继续压缩 Files 顶部和工具栏密度，文件搜索栏限制为 20px 高、88px 宽上限（测试契约不超过 96px），文件树行改为工具侧栏式密集行；主区域保留 status page / opened file 的单一主体语义，预览面板只保留清晰边界，不再用投影制造卡片感；窄屏默认收起文件树侧栏，左上三横线负责展开，避免文件树覆盖主状态页。
- 本轮 UI pass 为文件树行增加轻量语义色轨和固定尺寸图标容器，保留只读文件浏览边界；工作区 root 选择继续折叠，搜索栏保持紧凑，主界面仍只承担 status page 或已打开文件预览。
- 本轮 UI polish 将文件树行进一步收成单行导航项，默认只显示图标、文件名、展开/复制动作和选中 rail；绝对路径、大小、修改时间仍按 locale 格式化但移入 tooltip，避免侧栏元数据抢占主预览区域。
- 本轮 UI polish 将工作区 root 折叠入口补充为当前 root 路径摘要：默认仍不显示输入框和保存默认 root 动作，用户展开后才可手动指定 root、恢复默认 root 或保存默认 workspace；顶部仍保留 `Root: ...` 状态文本，侧栏折叠标题只显示路径，避免主区域和侧栏重复抢占空间。
- 本轮可见 UI 里程碑已补文件页 widget 契约：`workspace-files-root-selector`、紧凑 `workspace-files-filter` 和文件树入口均属于左侧 `workspace-files-sidebar`，主区域仍由 `workspace-files-main` 承担 status page 或打开文件预览，避免工作区选择/搜索控件回流到主内容区。
- 本轮 Chat 可见 UI 里程碑已在 Chat 左侧会话侧栏顶部显示当前 workspace/cwd 摘要，并把高级控制入口收归侧栏；cwd/session/turn override 等调试信息不回流到主对话流。Files 页面继续负责完整 root selector、默认工作区保存、搜索和文件树，Chat 只展示当前上下文摘要与入口。
- 本轮 Chat UI / timeline 性能里程碑没有改变 Files 只读边界；9.6 仍以 Files 页面作为完整工作区选择、默认 workspace、搜索和文件树入口。Chat 侧栏只保留当前 workspace/cwd 摘要与切换入口，避免把 cwd/session/turn override 调试信息重新塞回主对话流。
- 已覆盖路径归一化、目录响应 path/name 校验、目录分页 `nextCursor`/`cursor`、拒绝 `..` / 绝对 child path、符号链接祖先拒绝、二进制文件拒绝、UTF-8 range 边界、后续 chunk 失败重试和大 Markdown raw 保护。
- 已补充文件页 widget 覆盖：可手动指定工作区 root，目录读取使用该 root；可保存 App 默认工作区 root 到 cwd 覆盖，并可从临时 root 恢复默认 root。
- 已补充文件页 widget 覆盖：无 mutation runner 的只读预览不出现新建文件/文件夹、重命名、删除、编辑、保存或写文件入口；启用 mutation runner 时覆盖新建、复制、移动/重命名、删除、二次确认和失败提示；独立的“打开终端”入口不把终端命令混入文件预览流程。
- 已完成现有文本文件的受控编辑、`fs/writeFile`、`fs/watch`、diff 审批和乐观冲突检测，并保持独立 mutation runner；服务器端 CAS、原子 rename 和更强一致冲突控制仍待上游协议支持。
- 新建文件/目录、复制、删除和移动/重命名使用上游结构化 `fs/createDirectory`、`fs/copy`、`fs/remove` 与既有 `fs/writeFile`，所有目标路径限制在 workspace root 内并拒绝符号链接逃逸。上游没有 rename RPC，因此移动明确实现为 copy 后 remove；copy 成功但 remove 失败时向 UI 报告 partial failure，不伪装成原子成功。更强一致性工作见 [TODO](../TODO.md#p1-协议与后端)。
