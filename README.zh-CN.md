<div align="center">

<img src="assets/lumanote-icon.png" alt="LumaNote 图标" width="128">

# LumaNote

[English](README.md) | [中文](README.zh-CN.md)

**一款透明玻璃风格的 macOS Markdown 便签。**

**一条命令安装 · 实时 Markdown 样式 · 本地剪切板库**

</div>

> 英文 README 和中文 README 作为内容等价版本维护。任意一边更新时，另一边也需要在同一次提交中同步更新。

## Community

<p align="center">
  <img src="assets/wechat-group-qr.jpeg" alt="HTT 仓库微信群二维码" width="220">
</p>

<p align="center">
  扫码加入微信群，交流使用体验、产品发布和更新说明。
</p>

## 为什么做这个？

LumaNote 是为那些需要一直放在手边的小内容做的：一个想法、一条待办、一个链接、一个地址、一个验证码，或者一段正在写的 Markdown 草稿。

很多笔记软件最后都会变成资料库、数据库或者工作台。LumaNote 刻意保持很小：一个好看的玻璃便签、实时 Markdown 样式、快速切换文件、可调透明度，以及一个不会抢占屏幕的本地剪切板库。

## 快速安装

需要 macOS 14+，并已安装 Swift / Xcode Command Line Tools：

```bash
curl -fsSL https://raw.githubusercontent.com/hututuo/LumaNote/main/install.sh | bash
```

安装脚本会把仓库克隆或更新到 `~/.lumanote/source`，在本地构建并进行 ad-hoc 签名，安装到 `~/Applications/LumaNote.app`，并自动打开。

如果你把仓库发布在其他地址，可以覆盖 clone 来源：

```bash
LUMANOTE_REPO=https://github.com/your-name/LumaNote.git \
  curl -fsSL https://raw.githubusercontent.com/your-name/LumaNote/main/install.sh | bash
```

## 手动构建

```bash
git clone https://github.com/hututuo/LumaNote.git
cd LumaNote/app/QuietNote
./scripts/build-app.sh
open build/LumaNote.app
```

## 核心功能

| 功能 | 说明 |
|---|---|
| 玻璃便签 | 一个紧凑的毛玻璃便签，适合长期贴在屏幕边缘。 |
| 可调透明度 | 底部滑杆控制便签玻璃外壳可见度，同时保持文字和控件清晰。 |
| 实时 Markdown 样式 | 直接编辑原始 Markdown；标题、链接、列表、待办框、代码、高亮和常见行内样式会即时显示。 |
| 待办 checkbox | `- [ ]` 和 `- [x]` 会显示为可点击 checkbox，并支持 task list 回车续行/退出。 |
| 最近文件切换 | 底部切换按钮打开最近文件列表，第一行固定为打开新文件。 |
| 另存为 | 将当前便签另存为 Markdown/text 文件，并继续实时保存到该文件。 |
| 剪切板库 | 本地保存剪切板历史，支持搜索、保留数量、复制、粘贴和删除。 |
| 剪切板识别 | 从每条剪切板记录中识别 URL、邮箱、电话、地址类文本和带标签编号。 |
| 顶部灵动提示 | 可提取的剪切板内容会出现在顶部小胶囊里，可快速复制、粘贴、打开链接、发邮件、拨号或打开地图。 |
| 全局快捷键 | 可自定义呼出便签、隐藏便签、打开剪切板库的快捷键。 |
| 开机自启 | 可选 macOS 登录项集成，登录后自动打开 LumaNote。 |
| 中英文界面 | 内置中文 / English 界面切换。用户的 Markdown 内容不会被翻译或修改。 |

## Markdown 兼容性

LumaNote 保存的是原始 Markdown 文本。编辑器是轻量实时样式器，不是完整 CommonMark 或 GitHub-Flavored Markdown 渲染器。

完整表格见：

- [Markdown Compatibility](docs/markdown-compatibility.md)

## 本地数据

LumaNote 的 app 数据保存在本机：

```text
~/Library/Application Support/QuietNote/
```

剪切板监听只在本地工作，并且可以在便签菜单或设置中关闭。

## 仓库结构

```text
LumaNote/
  app/QuietNote/                 # SwiftUI macOS app 源码
    Sources/                     # App 代码
    scripts/build-app.sh         # 构建 build/LumaNote.app
    support/Info.plist           # Bundle 元数据
    support/AppIcon.icns         # macOS app 图标
  assets/                        # README 图标和微信群二维码
  docs/markdown-compatibility.md # Markdown 支持表格
  install.sh                     # 一条命令安装脚本
  README.md
  README.zh-CN.md
```

## 开发

```bash
cd app/QuietNote
swift build
./scripts/build-app.sh
open build/LumaNote.app
```

构建产物、`.build/`、`build/` 和本地 run 记录默认不进入 Git。

## 说明

LumaNote 目前是本地 macOS 构建版，不是 Developer ID 签名/公证的 App Store 发布版。如果首次启动遇到 macOS Gatekeeper 提示，可以从源码本地构建，或在系统设置中允许打开。
`./scripts/build-app.sh` 会对本地 app bundle 做 ad-hoc 签名，适合本地安装和后续一键更新流程，但它不等同于开发者证书签名或 notarization。
