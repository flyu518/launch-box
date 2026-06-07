# 启动台实现计划

> 给自动化开发代理的说明：按任务逐步执行本计划。任务使用复选框格式，便于跟踪进度。

## 目标

在 `launch-box` 仓库中构建一个 SwiftUI macOS 启动台应用，用户可见名称为 `启动台`。

## 架构原则

把可测试的启动台状态和组织逻辑放在 `LaunchBoxCore` 中；把 AppKit、SwiftUI、菜单栏、窗口和系统集成放在可执行目标中。项目使用 Swift 包管理器，并提供仓库内脚本生成最小 `.app` 包。

## 技术栈

- Swift 包管理器
- SwiftUI
- AppKit
- Carbon 全局快捷键
- XCTest

## 任务 1：核心模型和测试

涉及文件：

- 创建：`Package.swift`
- 创建：`Sources/LaunchBoxCore/Models.swift`
- 创建：`Sources/LaunchBoxCore/AppSearch.swift`
- 创建：`Sources/LaunchBoxCore/LibraryOrganizer.swift`
- 创建：`Sources/LaunchBoxCore/LibraryPersistence.swift`
- 创建：`Tests/LaunchBoxCoreTests/LaunchBoxCoreTests.swift`

执行步骤：

- [ ] 编写搜索、分类成员关系、文件夹、最近使用和持久化测试。
- [ ] 运行 `swift test`，确认测试因实现缺失而失败。
- [ ] 实现核心文件。
- [ ] 运行 `swift test`，确认所有核心测试通过。

## 任务 2：macOS 应用集成

涉及文件：

- 创建：`Sources/LaunchBox/LaunchBoxApp.swift`
- 创建：`Sources/LaunchBox/LaunchStore.swift`
- 创建：`Sources/LaunchBox/AppScanner.swift`
- 创建：`Sources/LaunchBox/AppLauncher.swift`
- 创建：`Sources/LaunchBox/OverlayWindowController.swift`
- 创建：`Sources/LaunchBox/HotKeyManager.swift`
- 创建：`Sources/LaunchBox/Views/LauncherOverlayView.swift`
- 创建：`Sources/LaunchBox/Views/LauncherSidebarView.swift`
- 创建：`Sources/LaunchBox/Views/AppGridView.swift`
- 创建：`Sources/LaunchBox/Views/PreferencesView.swift`
- 创建：`Sources/LaunchBox/Support/IconCache.swift`

执行步骤：

- [ ] 接入菜单栏应用入口和设置界面。
- [ ] 实现全屏覆盖窗口，并用 SwiftUI 渲染内容。
- [ ] 通过 `NSWorkspace` 实现应用扫描和启动。
- [ ] 实现分类条、搜索、应用网格、右键菜单、拖拽排序、分类编辑、收藏、最近使用和文件夹。
- [ ] 实现 `Option + Space` 全局快捷键。
- [ ] 运行 `swift build`。

## 任务 3：运行脚本和验证

涉及文件：

- 创建：`script/build_and_run.sh`
- 创建：`.codex/environments/environment.toml`
- 创建：`.gitignore`
- 创建：`README.md`

执行步骤：

- [ ] 添加仓库内构建/运行脚本，用于生成 `dist/启动台.app`。
- [ ] 添加 Codex 运行按钮环境配置。
- [ ] 运行 `swift test`。
- [ ] 运行 `swift build`。
- [ ] 在允许本机图形界面启动时，运行 `./script/build_and_run.sh --verify`。
