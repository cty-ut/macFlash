# Flash 游戏库（macOS）

一个用 AppKit 编写的 macOS Flash 游戏启动器。它管理游戏网址和多个账号，并用各自独立的 Chromium 用户目录保存登录状态和游戏进度。默认收录《保卫羊村》，也可以添加其他游戏网址。

> **仓库内容：**这里提供启动器源码、图标和构建脚本。Chromium、Flash 插件和生成的 `.app` 不放入 Git 历史；可运行的应用包放在 [Releases](https://github.com/cty-ut/macFlash/releases)。克隆仓库后若要自行构建，需准备下述运行组件。

## 下载使用

从 [Releases](https://github.com/cty-ut/macFlash/releases) 下载 `FlashGameLibrary-macOS-v0.9.0.zip`，解压后打开 `Flash 游戏库.app`。当前应用主程序仅支持 Apple Silicon；内置 Chromium 和 Flash 为 Intel 版本，因此 Apple Silicon 电脑还需 Rosetta 2。Intel Mac 无法运行这一版应用。

目前仅在 Apple Silicon、macOS 15.6.1 的本机环境验证过《保卫羊村》。应用采用本地签名，没有 Apple 公证；首次打开时，macOS 可能要求你在 Finder 中右键应用并选择“打开”。游戏本身仍需连接原网站，能否进入也取决于网站和账号状态。

## 功能

- 添加、编辑、隐藏游戏；重新添加同一网址可恢复原有条目和数据。
- 为每款游戏创建多个账号，分别保存登录状态和进度；可重命名账号。
- 从界面打开游戏数据目录。

## 自行构建

需要 macOS、Xcode Command Line Tools，以及以下**不在仓库中**的运行组件：

1. Intel 版 Chromium 87.0.4280.0 的 `Chromium.app`。通过环境变量 `CHROMIUM_APP_SOURCE` 指向它；如果本地已经有完整的 `Flash 游戏库.app`，构建脚本也可从该包内读取 Chromium。
2. Mac PPAPI Flash 34.0.0.372 基准插件，放在 `runtime/flash-source.plugin/`，其中程序文件位于 `Contents/MacOS/PepperFlashPlayer`。脚本仅接受大小为 15,313,744 字节、SHA-256 为 `555d8be93c491db65a97ae1de86f921ddb850eeb3213d8cd9bac20245bdc5c3a` 的已测试文件。该插件的准确分发来源尚未核实。

在仓库根目录运行：

```sh
CHROMIUM_APP_SOURCE="/你的路径/Chromium.app" ./scripts/build-app.sh
```

脚本会核对基准插件的指纹，在 `.build/` 中制作运行副本，再编译启动器、组装 `Flash 游戏库.app` 并进行本地签名。它不会修改基准插件。脚本包含对 Flash 二进制的固定字节补丁；偏移量和预期字节记录在 `scripts/patch-clean-flash.py` 中。

构建完成后，双击 `Flash 游戏库.app`。选择游戏和账号，点击“开始游戏”。点击“新增账号”可继续创建账号，新账号首次进入需重新登录。

## 数据位置

应用数据保存在 `~/Library/Application Support/FlashGameLibrary/`：

| 路径 | 内容 |
| --- | --- |
| `games.json` | 游戏列表与账号名称 |
| `Profiles/<游戏 ID>/` | 原账号的浏览器数据与进度 |
| `Profiles/<游戏 ID>-account-<编号>/` | 后续账号的数据与进度 |

移出游戏库只隐藏条目，不删除账号数据。备份或迁移进度时，请先关闭对应的 Chromium 窗口，再复制这些目录。

## 使用范围

应用内的 Chromium 和 Flash 均为旧版组件。请仅在自己信任的游戏网站上使用，不要把它当作日常浏览器。此项目没有内置游戏 SWF，也不保证其他网站可用；其他 macOS 版本尚未验证。
