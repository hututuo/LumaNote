# LumaNote v0.1.5

Release date: 2026-06-20

## 更新详情

- 修复拖动窗口边角缩放时 Markdown 编辑区卡顿的问题，减少缩放过程中滚动高度精算带来的额外开销。
- 保留拖动时的实时 Markdown 重排，正文宽度会继续跟随窗口变化，不再为了性能冻结编辑区的视觉反馈。
- 补充窗口缩放相关回归测试，避免后续优化再次牺牲实时重排体验。

## 安装提示

这个版本仍然采用 ad-hoc 签名，暂未经过 Apple 公证。首次打开时，macOS 可能提示“未知开发者”。请只从官方 GitHub Release 下载，并在打开前核对 SHA256。

如果 macOS 阻止首次打开，请进入 `系统设置` -> `隐私与安全`，找到 LumaNote 的提示，点击 `仍要打开`，再确认 `打开`。

---

## English

LumaNote v0.1.5 is a small maintenance release focused on smoother window resizing without sacrificing live Markdown reflow.

## Update Details

- Fixed stuttering while dragging the window corners by reducing extra scroll-height measurement work during live resize.
- Preserved live Markdown reflow while resizing, so the editor content continues to follow the window width instead of freezing for performance.
- Added regression coverage for window resizing so future optimizations keep the live reflow experience intact.

## Install Notes

This build is ad-hoc signed and is not Apple notarized. macOS may show an "unidentified developer" warning on first launch. Download only from the official GitHub Release and verify the SHA256 checksum before opening.

If macOS blocks the first launch, open `System Settings` -> `Privacy & Security`, find the LumaNote warning, click `Open Anyway`, then confirm `Open`.
