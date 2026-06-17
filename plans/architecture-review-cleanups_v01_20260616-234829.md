# LumaNote 代码审查修复方案 v01

状态：accepted
创建时间：2026-06-16 23:48:29
分支：`refactor/review-cleanups`
基线：`5dc81c8 修复中文输入法组合输入`
完成时间：2026-06-17

## 完成结论

这轮代码审查清理已经完成，并且实际覆盖范围超过最初的低风险清单。最初列出的 `AppText` 重复、剪切板颜色重复、工作区预览缓存、剪切板搜索索引容量、视图直接读取 `NSApp.delegate` 等项都已处理；原本暂不处理的 `@Observable` 迁移、`ClipboardStore.configure(settings:)` 构造注入、`NoteStore` 启动读文件延后，以及 `NoteWindowView` / `MarkdownRenderingEditor` 大文件拆分也已在后续 checkpoint 中分段完成。

后续不应把这份 v01 当成仍待执行的 active 计划。若继续做维护，建议另起新方案，重点放在更细的 `NoteWindowView` 状态拆分、Onboarding 体积控制、以及视觉回归核查，而不是重复这轮已经完成的清理。

## 目标

这轮目标不是大改产品形态，而是把审查中已经确认的代码味道和低风险问题先收一轮，降低后续维护成本，同时不破坏 LumaNote 已经反复调过的视觉、拖动、Markdown 和剪切板交互。

## 本轮修复范围

优先修这些低风险且可验证的点：

1. `AppText(language:)` 在 `NoteWindowView` 多处重复实例化。
   - 做法：给 `NoteWindowView` 增加统一的 `copy` 计算属性，主视图内部直接复用。
   - 收益：减少噪音，后续调文案时更清楚。

2. `ClipboardLibraryView` 中 `inkColor` / `softInkColor` 等颜色在多个子视图重复定义。
   - 做法：抽一个轻量 `ClipboardPalette`，由 `colorScheme + themeColor` 生成墨色、弱墨色、搜索描边和强调色。
   - 收益：剪切板库颜色逻辑集中，后续继续调玻璃可读性时不用到处找。

3. `workspacePreviewCache` 删除工作区文件后不清理。
   - 做法：移除工作区文件、打开/保存/新建当前文档时同步清理对应路径的预览缓存；可选加一个小上限，避免预览缓存无限长。
   - 收益：避免已移除或被覆盖的文档预览长期留在内存。

4. `itemSearchIndex` 在大量删除/裁剪后可能保留过大容量。
   - 做法：`clear()`、`trim()`、重建缓存时不保留旧容量；单条删除继续只清当前 id。
   - 收益：剪切板库长时间使用后更容易释放内存。

5. `NSApp.delegate` 在视图里直接取 `AppDelegate`。
   - 做法：先从 `OnboardingView` 开始改为闭包注入更新控制，`UpdateCheckButtonView` 后续可同一方向继续收。
   - 收益：引导页不直接认识 AppDelegate，测试和维护更干净。

6. 项目结构扁平、`NoteWindowView` / `MarkdownRenderingEditor` 过大。
   - 本轮只做方案沉淀和局部无风险清理，不做大文件搬家。
   - 后续建议单开 `refactor/note-window-components` 和 `refactor/markdown-editor-modules`，一次只拆一个区域。

## 原计划暂不处理项，后续实际状态

1. `ObservableObject` 迁移 `@Observable`。
   - 后续实际已完成：`AppSettings`、`NoteStore`、`ClipboardStore` 已迁移到 Swift Observation，内部任务/缓存用 ignored 标记隔离。

2. `NoteStore.init()` 主线程同步 I/O 全量异步化。
   - 后续实际已完成：真实 App 使用 deferred initial load，已有 Markdown 内容延后读入，测试保留同步模式。

3. `ClipboardStore.configure(settings:)` 改成构造注入。
   - 后续实际已完成：`ClipboardStore(settings:)` 初始化注入设置依赖，移除外部 configure 调用。

4. `NoteWindowView` / `MarkdownRenderingEditor` 大拆分。
   - 后续实际已分段完成：编辑器的滚动容器、绘制层、范围 helper、task 前缀、行内/块级样式，以及主窗口的底栏、顶岛、收起把手、正文区、文件面板、滑动状态机等都已拆出。继续拆可以作为新的维护任务，不属于本 v01 未完成项。

## 提交计划

1. `docs: 记录代码审查修复方案`
   - 包含本方案和项目索引记录。

2. `整理剪切板和文案轻量依赖`
   - `NoteWindowView` 统一 `AppText`。
   - `ClipboardLibraryView` 抽 `ClipboardPalette`。
   - `OnboardingView` 更新控制改为闭包注入。

3. `清理工作区预览和剪切板搜索缓存`
   - 修 `workspacePreviewCache` 清理。
   - 修 `itemSearchIndex` 容量释放。
   - 补针对缓存清理的测试。

## 验证计划

每个正式提交前至少运行：

- `git diff --check`
- `swift test`

代码完成后运行：

- `./scripts/build-app.sh`
- 关闭并重新打开 `build/LumaNote.app`
- 采样进程 CPU/RSS，确认没有明显异常

## 回滚策略

- 回滚整轮：切回原分支或 `git revert` 本分支的修复提交。
- 回滚单项：每个修复按功能拆 commit，可以逐个 revert。
