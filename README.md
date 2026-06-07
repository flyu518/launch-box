# 启动台（launch-box）

`launch-box` 是一个 macOS 启动台应用，用户可见名称为 **启动台**。

项目目标是保留旧版 macOS 启动台的直接、快速和可拖拽整理体验，同时补上更实用的搜索、收藏、分类、文件夹、隐藏应用、导入导出和菜单栏入口。

> 当前项目仍处于本地可用阶段。公开发布前建议补齐正式签名、公证和版本发布流程。

## 功能

- 菜单栏应用，左键打开启动台，右键打开菜单和设置
- 全屏半透明 SwiftUI 启动台界面
- 默认全局快捷键：`Option + Space`
- 扫描 `/Applications`、`/System/Applications` 和 `~/Applications`
- 支持应用名称、包标识符、路径、中文拼音和常见别名搜索
- 内置分区：全部、收藏、最近、未分类、隐藏
- 自定义分类，支持重命名、删除和手动排序
- 分类内支持文件夹，支持拖拽创建、拖入、拖出和自动整理
- 支持应用排序、收藏排序、分类排序
- 支持隐藏应用，隐藏后只在“隐藏”分区显示
- 支持配置导入、导出和导入前备份
- JSON 持久化配置，便于备份和排查问题

## 系统要求

- macOS 14.0 或更高版本
- Xcode 15 或更高版本，或匹配的 Swift 5.9+ 工具链
- Swift 包管理器

本项目使用 Swift 包管理器组织，没有依赖第三方包。

## 快速开始

```bash
git clone https://github.com/flyu518/launch-box.git
cd launch-box
swift test
./script/build_and_run.sh --verify
```

构建脚本会生成并启动：

```text
dist/启动台.app
```

该开发包使用本地临时签名，只适合本机开发和测试。面向用户分发时，应使用 Apple Developer ID 签名并完成公证。

## 常用命令

运行测试：

```bash
swift test
```

只运行核心测试：

```bash
swift test --filter LaunchBoxCoreTests
```

编译 Swift 包可执行文件：

```bash
swift build
```

构建 `.app` 并启动：

```bash
./script/build_and_run.sh
```

构建、启动并校验进程：

```bash
./script/build_and_run.sh --verify
```

启动并查看应用日志：

```bash
./script/build_and_run.sh --logs
```

启动并查看遥测日志：

```bash
./script/build_and_run.sh --telemetry
```

使用 LLDB 调试器启动：

```bash
./script/build_and_run.sh --debug
```

## 项目结构

```text
Package.swift
Sources/
  LaunchBox/              macOS 应用入口、SwiftUI 界面、菜单栏、快捷键、扫描和启动逻辑
  LaunchBoxCore/          可测试的核心模型、搜索、持久化、分类/文件夹整理逻辑
Tests/
  LaunchBoxCoreTests/     核心逻辑测试
script/
  build_and_run.sh        构建 .app、生成图标、签名、启动、日志和调试入口
  generate_app_icon.swift 生成开发用 AppIcon.icns
docs/
  superpowers/            中文设计和实现过程文档
```

## 配置和数据

应用配置默认保存到：

```text
~/Library/Application Support/launch-box/LaunchLibrary.json
```

配置中包含：

- 应用排序
- 收藏列表
- 最近打开记录
- 分类和文件夹结构
- 隐藏应用列表
- 快捷键设置

设置页支持导入和导出配置。导入前会尝试备份当前配置，备份文件也放在同一目录。

## 权限和隐私

`启动台` 只扫描本机应用目录并在本机保存配置，不需要网络服务。

可能触发的系统提示：

- 首次打开或控制其他应用时，macOS 可能弹出安全确认
- 开启“登录时启动”时，会使用系统登录项接口注册应用
- 使用“在 Finder 中显示”会调用 Finder 打开应用所在位置

如果应用无法启动、无法打开其他应用，先检查 macOS 的“隐私与安全性”提示和系统设置。

## 开发说明

核心业务逻辑应优先放在 `Sources/LaunchBoxCore`，并配套测试。SwiftUI 和 AppKit 相关的窗口、菜单栏、快捷键和界面逻辑放在 `Sources/LaunchBox`。

提交前建议至少运行：

```bash
swift test
./script/build_and_run.sh --verify
```

如果只改了 UI，也建议运行 `--verify`，避免本地 app bundle 没有刷新导致误判。

## 故障排查

如果 `swift test` 或 `swift build` 在包清单阶段失败，通常是命令行工具或 Xcode 工具链不匹配。建议安装完整 Xcode，并确认：

```bash
xcode-select -p
swift --version
```

如果 `./script/build_and_run.sh --verify` 构建成功但校验失败，先确认系统是否允许查询进程列表。脚本会优先使用 `pgrep`，不可用时会退回到 macOS 系统事件查询。

如果配置损坏，应用会把损坏文件移动为类似下面的备份文件，并使用空配置启动：

```text
LaunchLibrary.json.corrupt-<timestamp>
```

## 贡献

欢迎通过议题或拉取请求参与改进。建议拉取请求包含：

- 清晰的问题描述或功能说明
- 对应的测试或手动验证步骤
- 影响用户数据、权限或启动流程时的兼容说明

请尽量保持改动聚焦，避免把 UI 调整、数据迁移和无关重构混在同一个 PR 中。

## 发布前清单

公开发布 GitHub 仓库或版本前，建议补齐：

- `CHANGELOG.md`
- 正式包标识符
- Apple Developer ID 签名和公证
- 版本发布构建脚本
- 截图或录屏

## 许可证

本项目使用 MIT 许可证。详见 [LICENSE](LICENSE)。

MIT 许可证允许他人使用、复制、修改、合并、发布、分发和再授权本项目代码，但需要保留原始版权声明和许可证文本。软件按“原样”提供，不提供担保。
