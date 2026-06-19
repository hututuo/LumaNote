# LumaNote

简体中文 | [English](#english)

<table align="center">
  <tr>
    <td align="center" width="180">
      <img src="assets/lumanote-icon.png" width="112" alt="LumaNote app icon"><br>
      <strong>LumaNote</strong>
    </td>
    <td align="center" width="280">
      <img src="assets/wechat-group-qr.jpeg" width="220" alt="HTT 的仓库交流群二维码"><br>
      欢迎扫码加入群聊，讨论使用问题、交流想法，也会发布产品更新通知。
    </td>
  </tr>
</table>

LumaNote 是一个本地优先的 macOS SwiftUI 玻璃便签。它把实时 Markdown、透明小窗、本地剪切板库、智能提取和全局快捷键放进一个可以长期贴在屏幕边缘的小便签里。

<p align="center">
  <img src="design/quiet-rail-note_reference_20260607-100100.png" alt="LumaNote 玻璃便签预览" width="720">
</p>

## 亮点

- 一个小而漂亮的玻璃 Markdown 便签，可以调透明度、磨砂感、主题色和字体大小。
- 实时 Markdown 样式：标题、粗体、斜体、链接、列表、待办框、引用、代码块、高亮等常用语法会在编辑时直接显示。
- 不做编辑/预览两套模式：你始终在原始 Markdown 文件里写字，光标靠近已渲染内容时会自动露出原始语法，方便继续修改。
- 顶部胶囊和底部工具栏可以自动收起，小窗口里也尽量把空间留给正文。
- 本地剪切板库：复制过的文本会保存在本机，可搜索、复制、删除，也可限制保留数量。
- 剪切板智能提取：自动识别网址、邮箱、电话、地址、文件路径、验证码、订单号和冒号后的可复制文本，并保留在原剪切板记录下面。
- 顶部剪切板胶囊：识别到电话、地址、网址等内容时可以主动展开，支持一键复制或打开对应动作。
- 最近文件和工作区切换：底部切换按钮可以快速切换最近打开的 Markdown 文档，也可以新建或打开新文件。
- 全局快捷键：可自定义呼出/隐藏便签、打开剪切板库，并带冲突提示和恢复默认。
- Sparkle 更新检查、开机自启、中英文界面、跟随系统/亮色/暗色模式。

## 为什么

很多笔记软件最后都会变成资料库、数据库或者工作台。LumaNote 不想抢走你的屏幕，它更像一张长期贴在屏幕边上的透明便签：写一段草稿、放一条待办、临时记一个链接、复制一个地址或验证码，伸手就能用，没事时又不会太显眼。

## 特色：实时 Markdown 便签

LumaNote 保存的是普通 `.md` 文本，不会把你的内容锁进私有格式。编辑器会把常用 Markdown 语法做成轻量实时样式，但语法符号仍然留在文件里。

光标进入标题、链接、加粗、行内代码或代码块附近时，隐藏的 Markdown 标记会临时显示出来，方便你继续改 `#`、`**`、链接地址或代码围栏。完整兼容性见 [Markdown Compatibility](docs/markdown-compatibility.md)。

## 特色：剪切板库和智能提取

开启本地剪切板监听后，LumaNote 会把复制过的文本保存在本机，并在每条记录下面显示从这条内容里提取出的信息。比如一段文字里有手机号、邮箱、地址或网址，它会分别变成可点击的小气泡。

提取结果不会被按类型混在一起，而是保留在原始剪切板记录下面，这样你能清楚知道“这个电话号码是从哪条复制内容里来的”。网址可以打开，邮箱可以发邮件，电话可以拨号，地址可以交给地图搜索。

## 安装

推荐从 [GitHub Releases](https://github.com/hututuo/LumaNote/releases/latest) 下载最新 `.dmg`：

1. 下载 `LumaNote-0.1.5-macos-arm64.dmg` 和 `SHA256SUMS-v0.1.5.txt`。
2. 可选校验：

```bash
shasum -a 256 LumaNote-0.1.5-macos-arm64.dmg
cat SHA256SUMS-v0.1.5.txt
```

3. 打开 DMG，把 `LumaNote.app` 拖到 Applications。

这个构建是 ad-hoc 签名，尚未 Apple notarize。首次打开如果提示“未知开发者”：系统设置 -> 隐私与安全 -> 找到 `LumaNote` -> 点“仍要打开” -> 确认“打开”。

备用源码一行安装方式：

```bash
curl -fsSL https://raw.githubusercontent.com/hututuo/LumaNote/main/install.sh | bash
```

这个脚本会克隆或更新源码到 `~/.lumanote/source`，在本机用 Swift 构建并 ad-hoc 签名，然后安装到 `~/Applications/LumaNote.app` 并打开应用。它需要 macOS 14+ 和 Swift / Xcode Command Line Tools。

## 更新

App 内置 Sparkle 更新检查。首次引导、设置页或底部 More 菜单里可以开启“自动检查更新”；开启后，App 会定期读取 GitHub 上的 `appcast.xml`，发现新版本后弹窗提示，由你确认后再安装，不会静默替换应用。

也可以在 App 菜单或设置里手动点“检查更新”。

如果你是通过源码一行安装，也可以重新运行安装命令，它会拉取最新源码并重新构建本地 App。

## 本地数据与隐私

LumaNote 的数据保存在本机：

```text
~/Library/Application Support/QuietNote/
```

剪切板库也只保存在本机。DMG 和 zip 构建会打包 Swift app 与 Sparkle framework；普通用户不需要 Homebrew、Node.js、Python、本地服务、MCP server、daemon 或 sidecar 进程。

可选系统能力：

- 登录项：只有启用“开机自启”时才使用。
- 剪切板：只有启用本地剪切板监听时才读取文本剪切板。
- 网络：只用于检查 GitHub Release / Sparkle 更新。

## 从源码运行

```bash
git clone https://github.com/hututuo/LumaNote.git
cd LumaNote/app/QuietNote
swift run QuietNote
```

如果只想生成本地 `.app`：

```bash
cd app/QuietNote
./scripts/build-app.sh
open build/LumaNote.app
```

## 本地打包

生成本地 DMG：

```bash
cd app/QuietNote
./scripts/build-app.sh
./scripts/build-dmg.sh
```

准备完整 release 产物：

```bash
cd app/QuietNote
SPARKLE_PRIVATE_KEY_FILE="$HOME/.config/lumanote/sparkle-ed25519-private.key" \
  ./scripts/prepare-release.sh
```

发布脚本会生成 `.app`、DMG、Sparkle zip、兼容安装 zip、`SHA256SUMS` 和 `appcast.xml`。Sparkle 私钥不要提交到 Git；也可以把私钥放在登录钥匙串的 `com.hututuo.lumanote` account 下。

## 仓库结构

```text
LumaNote/
  app/QuietNote/                 # SwiftUI macOS app 源码
    Sources/
      App/                       # 应用入口、设置、快捷键、更新
      Clipboard/                 # 剪切板监听、识别和剪切板库 UI
      Markdown/                  # 实时 Markdown 编辑器和样式
      NoteWindow/                # 主便签外壳、顶部胶囊、底部工具栏和浮层
      Notes/                     # Markdown 文件、最近文件和工作区
      Onboarding/                # 首次启动引导
      Settings/                  # 完整设置和紧凑 More 菜单
      Window/                    # AppKit 窗口、拖动和浮层辅助
    scripts/                     # 构建、DMG、release 脚本
    support/                     # Info.plist、图标、DMG 背景
  assets/                        # README 图标和微信群二维码
  docs/                          # Markdown 兼容性和发布说明
  install.sh                     # 源码一行安装脚本
```

## License

MIT

---

## English

LumaNote is a local-first macOS SwiftUI glass sticky note. It combines live Markdown, a translucent note window, a local clipboard library, smart extraction, and global shortcuts in one small note that can stay at the edge of your screen.

<p align="center">
  <img src="design/quiet-rail-note_reference_20260607-100100.png" alt="LumaNote glass sticky note preview" width="720">
</p>

## Highlights

- A small glass Markdown sticky note with adjustable opacity, glass texture, accent color, and editor font size.
- Live Markdown styling for headings, bold, italic, links, lists, task checkboxes, quotes, code blocks, highlights, and other everyday syntax.
- No separate edit and preview modes: you always edit the plain Markdown file, and hidden source markers reappear when the cursor moves near styled content.
- The top capsule and bottom toolbar can auto-hide so compact notes keep more room for writing.
- Local clipboard library with search, copy, delete, and retention controls.
- Smart clipboard extraction for URLs, emails, phone numbers, addresses, file paths, verification codes, order numbers, and copyable text after labels.
- Top clipboard capsule that can expand when useful values are detected, with quick copy or open actions.
- Recent-file and workspace switching from the compact bottom switcher, plus new/open file flows.
- Configurable global shortcuts for showing/hiding the note and opening the clipboard library, with conflict hints and reset-to-default.
- Sparkle update checks, Launch at Login, Chinese/English UI, and follow-system/light/dark appearance.

## Why

Many note apps grow into libraries, databases, or dashboards. LumaNote is intentionally smaller: a translucent note that can stay beside your work, hold a draft, checklist, link, address, or verification code, and stay quiet when you do not need it.

## Feature: Live Markdown Notes

LumaNote saves ordinary `.md` text and does not lock your notes into a private format. The editor applies lightweight live styling to common Markdown syntax while keeping the original source in the file.

When the cursor enters or moves near a styled heading, link, emphasis span, inline code, or fenced code block, the hidden Markdown markers temporarily reappear so you can edit `#`, `**`, link destinations, or code fences in place. See [Markdown Compatibility](docs/markdown-compatibility.md) for the full table.

## Feature: Clipboard Library And Smart Extraction

When local clipboard monitoring is enabled, LumaNote stores copied text locally and shows extracted values under the original clipboard item. A phone number, email, address, or URL inside a copied paragraph becomes a small actionable value.

Detected values stay attached to the copied item they came from instead of being mixed into global type buckets. URLs can open in the browser, emails can open Mail, phone numbers can open a call action, and addresses can open Maps search.

## Installation

Download the latest `.dmg` from [GitHub Releases](https://github.com/hututuo/LumaNote/releases/latest):

1. Download `LumaNote-0.1.5-macos-arm64.dmg` and `SHA256SUMS-v0.1.5.txt`.
2. Optionally verify:

```bash
shasum -a 256 LumaNote-0.1.5-macos-arm64.dmg
cat SHA256SUMS-v0.1.5.txt
```

3. Open the DMG and drag `LumaNote.app` to Applications.

This build is ad-hoc signed and is not Apple notarized. macOS may show an "unidentified developer" warning on first launch. Open System Settings -> Privacy & Security -> find `LumaNote` -> click Open Anyway -> confirm Open.

Backup source install:

```bash
curl -fsSL https://raw.githubusercontent.com/hututuo/LumaNote/main/install.sh | bash
```

This script clones or updates the source under `~/.lumanote/source`, builds and ad-hoc signs the app locally with Swift, installs it to `~/Applications/LumaNote.app`, and opens it. It requires macOS 14+ and Swift / Xcode Command Line Tools.

## Update

The app includes Sparkle update checking. You can enable automatic update checks from the first-run guide, Settings, or the compact More panel. When enabled, the app periodically reads the GitHub `appcast.xml`; if a newer version is available, it asks before installing and does not silently replace the app.

You can also click Check for Updates from the app menu or Settings.

If you installed from source with the one-line installer, re-run the command to pull the latest source and rebuild the local app.

## Local Data And Privacy

LumaNote stores data locally:

```text
~/Library/Application Support/QuietNote/
```

The clipboard library is local as well. DMG and zip builds bundle the Swift app and Sparkle framework; users do not need Homebrew, Node.js, Python, a local server, an MCP server, a daemon, or a sidecar process.

Optional system capabilities:

- Login Items: used only if you enable Launch at Login.
- Clipboard: reads text clipboard only when local clipboard monitoring is enabled.
- Network: used for GitHub Release / Sparkle update checks.

## Run From Source

```bash
git clone https://github.com/hututuo/LumaNote.git
cd LumaNote/app/QuietNote
swift run QuietNote
```

Build a local `.app`:

```bash
cd app/QuietNote
./scripts/build-app.sh
open build/LumaNote.app
```

## Package Locally

Build a local DMG:

```bash
cd app/QuietNote
./scripts/build-app.sh
./scripts/build-dmg.sh
```

Prepare full release assets:

```bash
cd app/QuietNote
SPARKLE_PRIVATE_KEY_FILE="$HOME/.config/lumanote/sparkle-ed25519-private.key" \
  ./scripts/prepare-release.sh
```

The release script produces the app bundle, DMG, Sparkle zip, compatibility zip, `SHA256SUMS`, and `appcast.xml`. Never commit the Sparkle private key. Release operators can also keep the key in the login Keychain under account `com.hututuo.lumanote`.

## Repository Layout

```text
LumaNote/
  app/QuietNote/                 # SwiftUI macOS app source
    Sources/
      App/                       # App entry, settings, shortcuts, updates
      Clipboard/                 # Clipboard monitoring, detection, library UI
      Markdown/                  # Live Markdown editor and styling
      NoteWindow/                # Main shell, top capsule, bottom toolbar, panels
      Notes/                     # Markdown files, recent files, workspaces
      Onboarding/                # First-run guide
      Settings/                  # Full settings and compact More menu
      Window/                    # AppKit window, drag, overlay helpers
    scripts/                     # Build, DMG, release scripts
    support/                     # Info.plist, icon, DMG background
  assets/                        # README icon and WeChat QR image
  docs/                          # Markdown compatibility and release notes
  install.sh                     # One-line source installer
```

## License

MIT
