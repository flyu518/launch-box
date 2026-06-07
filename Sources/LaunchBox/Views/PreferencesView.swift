import AppKit
import LaunchBoxCore
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @ObservedObject var store: LaunchStore
    let onHotKeyChange: () -> Void

    @State private var dataMessage: String?
    @State private var dataMessageIsError = false
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var isConfirmingReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            GroupBox("快捷键") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("启用全局快捷键", isOn: hotKeyEnabled)

                    HotKeyRecorderView(settings: hotKeySettings) {
                        store.save()
                        onHotKeyChange()
                    }

                    Text("默认是 Option + Space。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("行为") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("开机自动启动", isOn: launchAtLoginBinding)

                    Button("重置布局...") {
                        isConfirmingReset = true
                    }

                    Text("重置会清空收藏、分类、文件夹、最近和自定义排序，隐藏应用和快捷键会保留。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("数据") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Button("导出数据...") {
                            exportData()
                        }

                        Button("导入数据...") {
                            importData()
                        }

                        Button("重新扫描应用") {
                            store.rescan()
                            setDataMessage("已重新扫描应用。", isError: false)
                        }
                    }

                    if let dataMessage {
                        Text(dataMessage)
                            .font(.caption)
                            .foregroundStyle(dataMessageIsError ? .red : .secondary)
                            .textSelection(.enabled)
                    }

                    Text("分类、收藏、文件夹、排序和快捷键会保存在 Application Support/launch-box/LaunchLibrary.json。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
            }
        }
        .padding(24)
        .frame(minWidth: 560, idealWidth: 560, minHeight: 420)
        .onAppear {
            launchAtLogin = LoginItemManager.isEnabled
        }
        .confirmationDialog("重置布局？", isPresented: $isConfirmingReset) {
            Button("重置布局", role: .destructive) {
                store.resetLayout()
                setDataMessage("已重置布局。", isError: false)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("收藏、分类、文件夹、最近和自定义排序会被清空。")
        }
    }

    private var hotKeyEnabled: Binding<Bool> {
        Binding(
            get: { store.library.hotKey.isEnabled },
            set: { value in
                store.library.hotKey.isEnabled = value
                store.save()
                onHotKeyChange()
            }
        )
    }

    private var hotKeySettings: Binding<HotKeySettings> {
        Binding(
            get: { store.library.hotKey },
            set: { store.library.hotKey = $0 }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { value in
                do {
                    try LoginItemManager.setEnabled(value)
                    launchAtLogin = value
                    setDataMessage(value ? "已开启开机自动启动。" : "已关闭开机自动启动。", isError: false)
                } catch {
                    launchAtLogin = LoginItemManager.isEnabled
                    setDataMessage("更新开机启动失败：\(error.localizedDescription)", isError: true)
                }
            }
        )
    }

    private var defaultExportFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "启动台配置-\(formatter.string(from: Date())).json"
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultExportFileName
        panel.title = "导出启动台配置"
        panel.message = "导出分类、收藏、文件夹、排序和快捷键。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try store.exportLibrary(to: url)
            setDataMessage("已导出配置到 \(url.lastPathComponent)。", isError: false)
        } catch {
            setDataMessage("导出失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "导入启动台配置"
        panel.message = "导入前会自动备份当前配置。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let backupURL = try store.importLibrary(from: url)
            if let backupURL {
                setDataMessage("已导入配置，原配置已备份为 \(backupURL.lastPathComponent)。", isError: false)
            } else {
                setDataMessage("已导入配置。", isError: false)
            }
        } catch {
            setDataMessage("导入失败：文件格式不正确、版本不兼容或无法读取。\(error.localizedDescription)", isError: true)
        }
    }

    private func setDataMessage(_ message: String, isError: Bool) {
        dataMessage = message
        dataMessageIsError = isError
    }
}
