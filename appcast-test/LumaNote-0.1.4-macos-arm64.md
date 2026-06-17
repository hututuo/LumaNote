# LumaNote v0.1.4

Release date: 2026-06-17

## 更新详情

- 进一步优化 Markdown 实时编辑：标题、代码块、任务列表、链接和滚动区域的样式刷新更稳定，中文输入法候选词组合时不再被实时渲染打断。
- 优化剪切板库和剪切板识别：减少滚动时的额外绘制成本，提取结果去重更轻，路径、电话、邮箱、网址、地址和带标签编号的识别仍保持在原复制记录下方。
- 优化顶部胶囊和底部工具栏：保留剪切板识别时的流动高光，同时减少长期静置时的持续开销。
- 优化工作区和文件切换：首次文档加载、最近文件预览和删除后的缓存清理更稳，降低冷启动和切换时的卡顿风险。
- 整理内部结构并补充测试：将窗口、Markdown、剪切板、设置和引导拆成更清楚的模块，方便后续继续迭代而不影响现有手感。

## 安装提示

这个版本仍然采用 ad-hoc 签名，暂未经过 Apple 公证。首次打开时，macOS 可能提示“未知开发者”。请只从官方 GitHub Release 下载，并在打开前核对 SHA256。

如果 macOS 阻止首次打开，请进入 `系统设置` -> `隐私与安全`，找到 LumaNote 的提示，点击 `仍要打开`，再确认 `打开`。

---

## English

LumaNote v0.1.4 is a maintenance release focused on smoother editing, lighter clipboard handling, and a cleaner internal structure for future updates.

## Update Details

- Improved live Markdown editing: heading, code block, task list, link, and scroll styling refresh more consistently, and Chinese IME composition is no longer interrupted by live rendering.
- Improved clipboard library and detection performance: scrolling does less extra drawing, detected values are deduplicated with less overhead, and paths, phone numbers, emails, URLs, addresses, and labeled codes still stay attached to the original clipboard record.
- Improved the top capsule and bottom toolbar: the flowing clipboard-detection highlight remains, while idle overhead is reduced.
- Improved workspaces and file switching: first document loading, recent-file previews, and cache cleanup after deletion are more robust, reducing the risk of cold-start or switching stalls.
- Cleaned up internal structure and expanded tests: window, Markdown, clipboard, settings, and onboarding logic are split into clearer modules so future changes are safer.

## Install Notes

This build is ad-hoc signed and is not Apple notarized. macOS may show an "unidentified developer" warning on first launch. Download only from the official GitHub Release and verify the SHA256 checksum before opening.

If macOS blocks the first launch, open `System Settings` -> `Privacy & Security`, find the LumaNote warning, click `Open Anyway`, then confirm `Open`.
