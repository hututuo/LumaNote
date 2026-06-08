# Glass Markdown Note Project Index

| 路径 | 创建时间 | 最近修改 | 类型 | 用途 | 是否可删除 | 关联任务 | 备注 |
|---|---|---|---|---|---|---|---|
| `CONTEXT.md` | 2026-06-07 10:01 | 2026-06-07 10:01 | 项目上下文 | 记录极简玻璃 Markdown 便签的产品方向、核心行为和入口 | 不建议删除 | 构建玻璃 Markdown 便签 | 后续先读 |
| `PROJECT_INDEX.md` | 2026-06-07 10:01 | 2026-06-07 10:01 | 项目索引 | 记录项目内方案、设计稿、源码、运行验证和归档状态 | 不建议删除 | 构建玻璃 Markdown 便签 | 持续维护 |
| `.gitignore` | 2026-06-08 09:53 | 2026-06-08 09:53 | Git 忽略规则 | 排除 `.DS_Store`、Swift 构建产物、生成的 `QuietNote.app`、run/scratch/backups 和临时日志，避免可重建/临时材料进入功能 commit | 不建议删除 | Glass Markdown Note Git 初始化 v01 | 项目根目录已按独立 Git 仓库管理；首个提交为 `项目初始归档` |
| `design/quiet-rail-note_reference_20260607-100100.png` | 2026-06-07 10:01 | 2026-06-07 10:01 | 视觉参考 | 融合 Bottom Rail Note 与 Slim Strip Note 的主视觉靶子 | 不建议删除 | Product Design 视觉方向 | 作为 SwiftUI 实现参考 |
| `app/QuietNote/` | 2026-06-07 10:05 | 2026-06-07 10:16 | SwiftUI 应用源码 | 原生 macOS 玻璃 Markdown 便签应用 | 不建议删除 | 构建玻璃 Markdown 便签 | 已可 `swift build`，可打开 `build/QuietNote.app` |
| `app/QuietNote/scripts/build-app.sh` | 2026-06-07 10:18 | 2026-06-07 10:18 | 构建脚本 | 编译并生成 `build/QuietNote.app` | 不建议删除 | 构建玻璃 Markdown 便签 | 用于本地重建调试版 app 包 |
| `app/QuietNote/support/Info.plist` | 2026-06-07 10:19 | 2026-06-07 10:35 | app 配置模板 | `QuietNote.app` 的 bundle metadata 模板 | 不建议删除 | 构建玻璃 Markdown 便签 | `LSUIElement=false`，使 app 出现在 Dock/任务栏 |
| `app/QuietNote/build/QuietNote.app` | 2026-06-07 10:09 | 2026-06-07 10:16 | macOS app 包 | 可双击运行的本地调试版 QuietNote | 可重建 | 构建玻璃 Markdown 便签 | 由 `.build/debug/QuietNote` 打包生成 |
| `app/QuietNote/Sources/MarkdownRenderingEditor.swift` | 2026-06-07 10:20 | 2026-06-08 21:40 | 实时渲染编辑器 | 用原生 `NSTextView` 在编辑时实时渲染 Markdown 样式 | 不建议删除 | 编辑器细滚动条 | task 布局已归一化：解析时按缩进宽度 + 固定 checkbox 槽位动态计算 hidden marker kern；checkbox x 使用 lineFragment 左缘 + textContainer padding + task 缩进；空 task 行按 Return 只删除 marker、不新增换行；关闭 NSTextView 自动补全/文本检查，避免系统根据上一行 `-` 自动补横杠；编辑器滚动容器使用 macOS overlay 小滚动条和 5pt 自定义 mini scroller，右侧细线式显示并自动隐藏 |
| `app/QuietNote/Sources/MarkdownPreviewView.swift` | 2026-06-07 10:07 | 2026-06-07 10:24 | 已删除旧组件 | 旧的单独预览模式组件，已被实时渲染编辑器替代 | 已删除 | 去除编辑/预览模式 | 防止后续误回到编辑/预览切换 |
| `app/QuietNote/Sources/AppText.swift` | 2026-06-07 17:30 | 2026-06-08 21:20 | 应用文案 | App 内中文/English 文案表 | 不建议删除 | 最近文件切换 | 设置文案区分“便签透明度”和“磨砂强度/玻璃质感”，用于设置页、更多菜单、剪切板库和动作菜单；新增切换便签文件、打开新文件、最近打开和空状态文案 |
| `app/QuietNote/Sources/AppSettings.swift` | 2026-06-07 10:05 | 2026-06-08 00:50 | 应用设置 | 保存透明度、玻璃强度、置顶、剪切板偏好和语言 | 不建议删除 | 默认外观参数调整 | 新增 `language`，默认中文；新用户默认开启本地剪切板监听；`noteOpacity` 最低值为 1%，新默认透明度 60%，新默认磨砂强度 10% |
| `app/QuietNote/Sources/SettingsView.swift` | 2026-06-07 10:05 | 2026-06-08 00:50 | 设置窗口 | app 设置表单 | 不建议删除 | 默认外观参数调整 | 新增中文/English 分段选择；快捷键拆成快捷呼出、快捷关闭、打开剪切板库；透明度和磨砂强度下方有简短说明 |
| `app/QuietNote/Sources/NoteWindowView.swift` | 2026-06-07 10:05 | 2026-06-08 21:48 | 主窗口视图 | 顶部拖动提示、底部控制栏、透明度控制和弹出层入口 | 不建议删除 | 最近文件切换高度调整 | 三条杠封装为 `islandDragGrip` 独立拖动热区；顶岛透明度只作用于玻璃壳层，标题和图标固定可读；设置/More 菜单改为窗口内玻璃浮层，锚定底部设置按钮并按便签边界自动避让；顶岛移除局部高光线，避免右下角出现细线线头；底栏文件按钮改为左右箭头切换入口，弹出锚定按钮的窗口内玻璃浮层，首行打开新文件并与最近文件列表分隔，另存为按钮保留；文件切换浮层降低透明感以盖住正文、增强可读性，并按最多 7 条最近文件给更高面板；正文区域右侧 padding 收窄，让编辑器滚动条更贴近右边缘 |
| `app/QuietNote/Sources/NoteStore.swift` | 2026-06-07 10:05 | 2026-06-08 21:20 | 便签数据层 | 本地 Markdown 保存、当前文件路径、最近文件和标题提取 | 不建议删除 | 最近文件切换 | `displayTitle` 优先使用正文第一个 Markdown 标题，否则显示实际保存文件名；支持打开文件后将实时保存切到该文件，另存为后切到新文件，并记住当前路径；新增最多 8 个最近文件路径，打开/另存为会推到列表顶部 |
| `app/QuietNote/Sources/WindowDragView.swift` | 2026-06-07 10:05 | 2026-06-07 14:56 | 拖动热区 | 透明 AppKit 拖动层，用于顶部区域和顶岛本体拖拽窗口 | 不建议删除 | 失焦后三指拖动 | `WindowDragView` 负责整条顶栏拖动，`WindowClickDragView` 负责顶岛点击/拖动共存，两者都 `acceptsFirstMouse` |
| `app/QuietNote/Sources/ClipboardStore.swift` | 2026-06-07 10:05 | 2026-06-07 12:02 | 剪切板数据层 | 本地剪切板监听、保存、识别、复制、粘贴和打开动作 | 不建议删除 | 底部剪切板提取提示条 | 新增最近含提取项记录；URL/邮箱/电话/地址可打开为 Safari/mailto/tel/Apple Maps |
| `app/QuietNote/Sources/ClipboardDetector.swift` | 2026-06-07 10:05 | 2026-06-07 16:25 | 剪切板识别器 | 从剪切板文本中提取 URL、邮箱、电话、地址和带标签编号 | 不建议删除 | 每条记录下方提取信息 | 不再提取普通数字；Number 仅识别验证码/订单号/快递单号等带标签编号；电话限制为 10-15 位并排除日期格式 |
| `app/QuietNote/Sources/ClipboardLibraryView.swift` | 2026-06-07 10:05 | 2026-06-07 17:32 | 剪切板库 UI | 搜索、每条记录下方提取信息、复制/粘贴/删除/打开操作 | 不建议删除 | 中英文切换 | 提取项固定显示在所属剪切板记录下方的小框里，支持 Copy/Paste/Open；库内标题、搜索、空状态和动作文案支持中英文 |
| `app/QuietNote/Sources/MoreMenuView.swift` | 2026-06-07 10:05 | 2026-06-08 00:50 | 紧凑设置菜单 | 便签内更多菜单和快捷键设置 sheet | 不建议删除 | 默认外观参数调整 | 菜单内容保持紧凑，背景由主窗口内玻璃浮层容器提供；顶部显示“玻璃质感”和模糊/泛白/质感说明，小窗口内可滚动；快捷键拆成呼出/关闭/剪切板库 |
| `app/QuietNote/Sources/NotePanelController.swift` | 2026-06-07 10:05 | 2026-06-07 10:35 | 窗口控制 | 设置 `hidesOnDeactivate=false`，防止切到其他应用时便签面板消失 | 不建议删除 | 失焦后保持悬浮 | 与 always-on-top 配合，便签可叠在其他窗口上 |
| `app/QuietNote/Sources/QuietNoteApp.swift` | 2026-06-07 10:05 | 2026-06-07 10:35 | 应用入口 | 使用 `.regular` 应用模式并保留 reopen 显示窗口行为 | 不建议删除 | Dock 显示与重新打开应用显示窗口 | 修复进程存在但窗口不见、以及不在 Dock/任务栏显示的问题 |
| `app/QuietNote/Sources/HotKeyCenter.swift` | 2026-06-07 10:05 | 2026-06-07 17:30 | 全局快捷键 | 注册 QuietNote 全局快捷键 | 不建议删除 | 快捷键拆分 | 新增 `showQuietNote` 和 `hideQuietNote`，默认呼出 `Option+Space`，默认关闭 `Option+Esc`；旧 toggle 名仅用于迁移现有快捷键 |
| `app/QuietNote/runs/20260607-100950_launch-check/` | 2026-06-07 10:09 | 2026-06-07 10:09 | 运行截图 | 首次启动截图，窗口显示不明显 | 可删除 | 启动验证 | 被 v2/v3 验证覆盖 |
| `app/QuietNote/runs/20260607-101300_launch-check-v2/` | 2026-06-07 10:10 | 2026-06-07 10:10 | 运行截图 | 修正窗口样式后确认 QuietNote 可见 | 可删除 | 启动验证 | 发现文字随窗口透明度一起变淡 |
| `app/QuietNote/runs/20260607-101650_opacity-readability/` | 2026-06-07 10:11 | 2026-06-07 10:11 | 运行截图 | 改成玻璃层透明、文字保持清晰后的验证截图 | 可删除 | 透明度可读性验证 | 当前视觉基线 |
| `app/QuietNote/runs/20260607-102025_live-render-editor/` | 2026-06-07 10:20 | 2026-06-07 10:20 | 运行截图 | 去除编辑/预览切换后验证实时渲染编辑器 | 可删除 | 实时 Markdown 渲染验证 | 当前编辑体验基线 |
| `app/QuietNote/runs/20260607-102516_three-drag-bars-display/` | 2026-06-07 10:25 | 2026-06-07 10:25 | 运行截图 | 首次三条拖动提示截图 | 可删除 | 顶部拖动提示验证 | 发现浅色背景上仍偏淡 |
| `app/QuietNote/runs/20260607-102630_visible-drag-bars-display/` | 2026-06-07 10:26 | 2026-06-07 10:26 | 运行截图 | 调深顶部三条拖动提示后验证应用已显示 | 可删除 | 顶部拖动提示验证 | 当前顶部拖动提示基线 |
| `app/QuietNote/runs/20260607-103101_reopen-visible-check/` | 2026-06-07 10:31 | 2026-06-07 10:31 | 运行截图 | 用户反馈窗口不见后重新打开并截图确认 | 可删除 | 重新打开应用验证 | 进程存在但窗口未显示，激活应用后窗口恢复 |
| `app/QuietNote/runs/20260607-103255_reopen-hook-build-check/` | 2026-06-07 10:32 | 2026-06-07 10:32 | 运行截图 | 增加 reopen 钩子后重新打包、启动、重复打开并截图确认 | 可删除 | 重新打开应用显示窗口 | `swift build` 和 app 包 plist 校验通过，重复 `open` 后窗口数量保持 1 |
| `app/QuietNote/runs/20260607-103534_dock-and-deactivate-sticky-check/` | 2026-06-07 10:35 | 2026-06-07 10:35 | 运行截图 | 改为普通 app 并验证失焦后窗口仍存在 | 可删除 | Dock/任务栏与失焦验证 | 打包后 `LSUIElement=false`，系统报告 `visible=true, windows=1` |
| `app/QuietNote/runs/20260607-103556_finder-deactivate-sticky-check/` | 2026-06-07 10:35 | 2026-06-07 10:35 | 运行截图 | 切到 Finder 后验证便签仍叠在其他窗口上 | 可删除 | 失焦后保持悬浮验证 | 菜单栏已为 Finder，QuietNote 仍可见且窗口数量为 1 |
| `app/QuietNote/runs/20260607-104119_zero-opacity-task-checkbox-check/` | 2026-06-07 10:41 | 2026-06-07 10:41 | 运行截图 | 验证 0% 透明度和待办 checkbox 实时渲染 | 可删除 | 透明度与 Markdown 待办语法 | `swift build` 与 app 打包通过，截图中玻璃底归零且 `- [ ]` 显示为 checkbox |
| `app/QuietNote/runs/20260607-104552_transparent-body-visible-controls-check/` | 2026-06-07 10:45 | 2026-06-07 10:45 | 运行截图 | 验证主体透明时底部控制条仍有最低可见度 | 可删除 | 透明时控件找回验证 | `swift build` 与 app 打包通过，0% 状态下滑块和更多按钮仍可见 |
| `app/QuietNote/runs/20260607-104918_minimum-one-percent-glass-check/` | 2026-06-07 10:49 | 2026-06-07 10:49 | 运行截图 | 验证最低 1% 透明度状态下仍保留玻璃便签轮廓 | 可删除 | 透明度最低值视觉验证 | `swift build` 与 app 打包通过，滑杆左端为 1，当前值为 1% |
| `app/QuietNote/runs/20260607-105817_small-drag-handle-first-mouse-check/` | 2026-06-07 10:58 | 2026-06-07 10:58 | 运行截图 | 验证顶部拖动横条缩小后的视觉比例 | 可删除 | 顶部拖动提示与失焦拖动 | `swift build` 与 app 打包通过；物理三指拖动需用户实机确认 |
| `app/QuietNote/runs/20260607-110524_wide-hidden-drag-hit-area-check/` | 2026-06-07 11:05 | 2026-06-07 11:05 | 运行截图 | 验证可见横条不变大，同时隐形拖动热区扩大 | 可删除 | 顶部拖动热区覆盖横条 | `swift build` 与 app 打包通过；拖动热区明确设置为顶部整条区域 |
| `app/QuietNote/runs/20260607-111511_clipboard-settings-v2-build-check/` | 2026-06-07 11:15 | 2026-06-07 11:15 | 运行截图 | 剪切板库和设置第二版后重新打包并确认 app 可见 | 可删除 | 剪切板/设置第二版验证 | `swift build` 与 app 打包通过；本地剪切板库当前为空，未写入假历史 |
| `app/QuietNote/runs/20260607-112331_clipboard-auto-monitor-fix-check/` | 2026-06-07 11:23 | 2026-06-07 11:23 | 运行截图 | 修复剪切板自动监听后确认 app 运行和剪切板库有记录 | 可删除 | 剪切板自动监听修复 | 实测测试文本被抓取并识别 URL/Email/Phone/Number；清理测试项后重启，当前剪切板被自动读入 |
| `app/QuietNote/runs/20260607-113323_per-item-extraction-ui-check/` | 2026-06-07 11:33 | 2026-06-07 11:33 | 运行截图 | 调整为每条剪切板记录下方显示提取信息后重新打包验证 | 可删除 | 每条记录下方提取信息 | `swift build` 与 app 打包通过；实测同一条文本下提取 URL/Email/Phone/Number/Address |
| `app/QuietNote/runs/20260607-113536_per-item-extraction-final-check/` | 2026-06-07 11:35 | 2026-06-07 11:35 | 运行截图 | 每条记录提取逻辑修正后的当前屏幕截图 | 可删除 | 每条记录下方提取信息 | AppleScript 未能自动点开剪切板弹窗，数据层验证已通过 |
| `app/QuietNote/runs/20260607-114620_reopen-after-missing-check/` | 2026-06-07 11:46 | 2026-06-07 11:46 | 运行截图 | 用户反馈应用不见后用 `open -n` 重新打开并截图确认 | 可删除 | 重新打开应用验证 | 系统报告 `visible=true, windows=1`；当前透明度为 1%，窗口较淡但可见 |
| `app/QuietNote/runs/20260607-115932_bottom-extraction-action-chip-check/` | 2026-06-07 11:59 | 2026-06-07 11:59 | 运行截图 | 增加底部剪切板提取提示条后的初次验证 | 可删除 | 底部剪切板提取提示条 | 发现 URL 会吃入中文逗号后的文字，已被后续修复 |
| `app/QuietNote/runs/20260607-120216_bottom-chip-open-actions-final-check/` | 2026-06-07 12:02 | 2026-06-07 12:02 | 运行截图 | 底部剪切板提取提示条与打开动作最终验证 | 可删除 | 底部剪切板提取提示条 | `swift build` 与 app 打包通过；实测 URL/Email/Phone/Number/Address 提取正确 |
| `app/QuietNote/runs/20260607-125942_lower-liquid-extraction-chip-check/` | 2026-06-07 12:59 | 2026-06-07 12:59 | 运行截图 | 底部剪切板提取小标签下移并加入 Liquid Glass 小圆后的验证 | 可删除 | 底部剪切板提取提示条视觉 | `swift build` 与 app 打包通过；圆圈仍偏淡，被 13:01 版本加强 |
| `app/QuietNote/runs/20260607-130144_lower-stronger-liquid-chip-check/` | 2026-06-07 13:01 | 2026-06-07 13:01 | 运行截图 | 加强 Liquid Glass 小圆并进一步下移后的验证 | 可删除 | 底部剪切板提取提示条视觉 | 当前底部提示条视觉基线 |
| `app/QuietNote/runs/20260607-141429_native-glass-prominent-chip-check/` | 2026-06-07 14:14 | 2026-06-07 14:14 | 运行截图 | 尝试用系统 `.glassProminent` 实现提示入口 | 可删除 | 底部剪切板提取提示条视觉 | 嵌入 Menu label 后仍像胶囊，不够圆，被 14:37 版本替代 |
| `app/QuietNote/runs/20260607-141850_real-glass-menu-circle-check/` | 2026-06-07 14:18 | 2026-06-07 14:18 | 运行截图 | 把 Menu 直接套系统 glass button 后的验证 | 可删除 | 底部剪切板提取提示条视觉 | 仍带下拉箭头，视觉不是纯小圆，被 14:37 版本替代 |
| `app/QuietNote/runs/20260607-143756_real-glass-circle-popover-check/` | 2026-06-07 14:37 | 2026-06-07 14:37 | 运行截图 | 使用真正圆形 `.glassProminent` Button + popover 的验证 | 可删除 | 底部剪切板提取提示条视觉 | 当前 Liquid Glass 小圆基线 |
| `app/QuietNote/runs/20260607-152000_top-island-bar-check/` | 2026-06-07 14:46 | 2026-06-07 14:46 | 运行截图 | 顶部灵动岛与拖动横条同排后的展开/收起验证 | 可删除 | 顶部剪切板灵动岛 | `screen.png` 为识别后展开胶囊，`screen_plain.png` 为无提取内容时收回玻璃小球；当前顶栏交互基线 |
| `app/QuietNote/runs/20260607-150200_unified-top-island-check/` | 2026-06-07 14:50 | 2026-06-07 14:50 | 运行截图 | 把横条并入顶部岛后的首次验证 | 可删除 | 顶部剪切板灵动岛 | 统一为一个控件，但系统蓝 `.glassProminent` 过重，被 14:52 中性玻璃版本替代 |
| `app/QuietNote/runs/20260607-150800_neutral-glass-top-island-check/` | 2026-06-07 14:52 | 2026-06-07 14:52 | 运行截图 | 中性自绘玻璃顶岛展开/收起验证 | 可删除 | 顶部剪切板灵动岛 | `expanded.png` 为识别后展开态，`collapsed.png` 为普通小玻璃珠；当前视觉基线 |
| `app/QuietNote/runs/20260607-151900_click-drag-top-island-check/` | 2026-06-07 14:56 | 2026-06-07 14:56 | 运行截图 | 恢复顶岛本体点击/拖动共存后的验证 | 可删除 | 顶部剪切板灵动岛 | `swift build` 与打包通过；三指拖动需用户实机确认，代码已移除拦截拖动的 Button |
| `app/QuietNote/runs/20260607-153600_title-island-auto-reset-check/` | 2026-06-07 15:02 | 2026-06-07 15:04 | 运行截图 | 顶岛默认标题、检测替换、60 秒自动回标题验证 | 可删除 | 顶部标题胶囊 | `title.png` 默认显示 Today，`detected.png` 显示提取内容，`after_60s.png` 确认自动回到 Today |
| `app/QuietNote/runs/20260607-151300_center-title-clipboard-icon-check/` | 2026-06-07 15:18 | 2026-06-07 15:18 | 运行截图 | 标题居中并把剪切板入口限制到右侧图标后的验证 | 可删除 | 顶部标题胶囊 | `title.png` 标题居中显示 Today，`detected.png` 检测态右侧也保留剪切板图标 |
| `app/QuietNote/runs/20260607-152700_island-opacity-sync-check/` | 2026-06-07 15:25 | 2026-06-07 15:26 | 运行截图 | 顶岛透明度同步便签透明度并保留最低可见度后的验证 | 可删除 | 顶部标题胶囊 | `current.png` 为修改后常规状态，`minimum.png` 为 noteOpacity=1% 时顶岛仍以约 5% 最低可见度显示 |
| `app/QuietNote/runs/20260607-153900_island-hit-zones-width-check/` | 2026-06-07 15:39 | 2026-06-07 15:39 | 运行截图 | 检测态命中区分区和宽度收短后的验证 | 可删除 | 顶部剪切板灵动岛 | `detected.png` 显示检测态宽度收短；左侧三条杠已从动作点击层移出 |
| `app/QuietNote/runs/20260607-154700_clipboard-inline-overlay-check/` | 2026-06-07 15:47 | 2026-06-07 15:47 | 运行截图 | 替换系统 popover 前后的手动点击验证截图 | 可删除 | 剪切板库浮层 | AppleScript 坐标点击受当前前台窗口限制，截图仅作窗口状态参考；最终代码已编译打包通过 |
| `app/QuietNote/runs/20260607-160500_island-shell-only-opacity-check/` | 2026-06-07 16:16 | 2026-06-07 16:17 | 运行截图 | 顶岛仅玻璃壳层跟随透明度、标题和图标保持固定可读后的验证 | 可删除 | 顶部剪切板灵动岛 | `current.png` 为常规状态，`minimum.png` 为 noteOpacity=1% 时壳层变淡但标题/图标仍可读 |
| `app/QuietNote/runs/20260607-161900_grip-drag-hit-area-restored-check/` | 2026-06-07 16:19 | 2026-06-07 16:19 | 运行截图 | 三条杠独立拖动热区恢复后的构建和可见性验证 | 可删除 | 顶部剪切板灵动岛 | `swift build` 与打包通过；物理三指拖动需用户实机确认 |
| `app/QuietNote/runs/20260607-162800_language-and-shortcuts-settings-check/` | 2026-06-07 17:34 | 2026-06-07 17:34 | 运行截图 | 设置页新增中英文切换和独立呼出/关闭快捷键后的验证 | 可删除 | 中英文切换与快捷键拆分 | `settings.png` 显示语言分段选择、快捷呼出便签、快捷关闭便签和打开剪切板库 |
| `app/QuietNote/runs/20260607-164900_task-markdown-continuation-fix-check/` | 2026-06-07 22:51 | 2026-06-07 22:51 | 运行截图 | Markdown task checkbox 空白和回车续行修复后的可见性验证 | 可删除 | Markdown task 输入修复 | `swift build` 与打包通过；用户需实机确认敲回车续成新 checkbox |
| `app/QuietNote/runs/20260607-165800_task-caret-height-fix-check/` | 2026-06-07 22:58 | 2026-06-07 22:58 | 运行截图 | Markdown task 光标高度修复后的构建和可见性验证 | 可删除 | Markdown task 输入修复 | 隐藏 task marker 不再使用超小字体；`swift build` 与打包通过 |
| `app/QuietNote/runs/20260607-232000_task-checkbox-gap-follow-marker-check/` | 2026-06-07 23:13 | 2026-06-07 23:13 | 运行截图 | Markdown task checkbox 与正文间距修复后的可见性验证 | 可删除 | Markdown task 输入修复 | `swift build` 与打包通过；checkbox 由隐藏 marker 末端反推位置，避免框后再次出现明显空白 |
| `app/QuietNote/runs/20260607-231610_task-checkbox-slot-width-check/` | 2026-06-07 23:17 | 2026-06-07 23:17 | 运行截图 | Markdown task checkbox 槽位宽度修复后的可见性验证 | 可删除 | Markdown task 输入修复 | `swift build` 与打包通过；隐藏 marker 宽度约为 checkbox 加小间距，避免 task 文字和框重叠 |
| `app/QuietNote/runs/20260607-232100_task-checkbox-left-nudge-check/` | 2026-06-07 23:22 | 2026-06-07 23:22 | 运行截图 | Markdown task checkbox 左移微调后的可见性验证 | 可删除 | Markdown task 输入修复 | `swift build` 与打包通过；只左移 checkbox 绘制位置，不改变正文起点和 Markdown 存储 |
| `app/QuietNote/runs/20260607-232600_task-checkbox-left-edge-align-check/` | 2026-06-07 23:27 | 2026-06-07 23:27 | 运行截图 | Markdown task checkbox 左边缘对齐普通正文后的可见性验证 | 可删除 | Markdown task 输入修复 | `swift build` 与打包通过；checkbox 左边缘使用行首 x，正文仍靠隐藏 marker 槽位排到框右侧 |
| `app/QuietNote/runs/20260607-233118_task-layout-normalized-check/` | 2026-06-07 23:34 | 2026-06-07 23:40 | 运行截图 | Markdown task 布局归一化后的可见性验证 | 可删除 | Markdown task 输入修复 | `swift build` 与打包通过；`screen.png`/`final.png` 验证当前 app 可见，Swift 计算验证不同 marker 空格数归一到同一 checkbox 槽位 |
| `app/QuietNote/runs/20260607-234400_task-checkbox-text-padding-align-check/` | 2026-06-07 23:58 | 2026-06-07 23:58 | 运行截图 | Markdown task checkbox 按普通文字 padding 对齐后的可见性验证 | 可删除 | Markdown task 输入修复 | `swift build` 与打包通过；checkbox 左缘加入 `textContainer.lineFragmentPadding`，与普通正文真实左缘一致 |
| `app/QuietNote/runs/20260608-000224_empty-task-enter-exit-check/` | 2026-06-08 00:04 | 2026-06-08 00:04 | 运行截图 | 空 Markdown task 行按 Return 退出 task list 后的可见性验证 | 可删除 | Markdown task 输入修复 | `swift build` 与打包通过；代码改为删除当前行内容 range，不再把空 task 行替换成额外 `\n` |
| `app/QuietNote/runs/20260608-001000_disable-system-text-autocomplete-check/` | 2026-06-08 00:11 | 2026-06-08 00:11 | 运行截图 | 禁用系统文本自动补全后防止空 task 退出补横杠的可见性验证 | 可删除 | Markdown task 输入修复 | `swift build` 与打包通过；关闭 `isAutomaticTextCompletionEnabled`、text checking 和 smart insert/delete 等系统自动机制 |

## Current Status

- `active`: 原生 SwiftUI 应用已可编译和启动，已改为单一实时渲染 Markdown 编辑器，正在继续打磨功能与视觉。

## Decisions

- 采用“一个便签 + 底部细工具条 + 0-100% 透明度拉条”的主界面。
- 剪切板库默认作为弹出层或设置项，不常驻占用正文空间。
- 快捷键需要可修改。
- 快捷键拆成“快捷呼出便签”和“快捷关闭便签”，另保留“打开剪切板库”快捷键；旧 Show/Hide toggle 不再作为设置项展示。
- 设置页提供中文/English 应用内语言切换；正文 Markdown 内容不随语言切换改动。
- 透明度控制作用于玻璃便签本体，文字和控件保持清晰，避免长期使用时可读性下降。
- 不采用“编辑/预览”模式切换；正文区域直接实时渲染 Markdown 样式并保持可编辑。
- 顶部空白区域使用三个半透明横条提示可拖动；每次打包后应直接打开 `build/QuietNote.app` 方便试用。
- 顶部拖动层使用 `acceptsFirstMouse`，让失焦时第一下鼠标/触控板输入可直接触发拖动。
- 应用采用普通 `.regular` 模式并设置 `LSUIElement=false`，应显示在 Dock/任务栏；便签面板设置 `hidesOnDeactivate=false`，切到其他窗口时不应自动消失。
- 不再允许完全无框透明状态；透明度滑杆最低值为 1%，最低状态保留轻玻璃轮廓、细边框和可找回的底部控制条。
- `- [ ]` 与 `- [x]` 使用实时 checkbox 渲染，不再只做普通文本着色。
- Markdown task 行回车应自动续成新的空 checkbox；不要退回只补普通 `-` 的行为。
- 剪切板库不做顶部分类聚合；每条复制记录下方显示从该条文本中提取的 URL、邮箱、电话、地址和带标签编号小框，保留上下文关系；不要因普通数字触发提取。
- 顶部剪切板识别提示采用单一自绘玻璃岛；默认居中显示便签标题，右侧剪切板图标才打开剪切板库，胶囊本体短按不打开库；剪切板库使用顶岛下方居中的应用内玻璃浮层，不再用系统 popover；胶囊玻璃壳层透明度跟随便签透明度但最低保留约 5% 可见度，标题和图标不随透明度变化；检测到可提取内容时同一个控件临时替换为类似灵动岛的小胶囊，左侧三条杠由 `islandDragGrip` 提供独立拖动热区且不弹窗，中间检测内容区域才可打开复制/粘贴/URL/邮箱/电话/地址动作，右侧剪切板图标只打开剪切板库；1 分钟后自动恢复标题。
- 剪切板监听新用户默认开启；开启监听时会立即抓取当前剪切板，而不是等下一次变化。
