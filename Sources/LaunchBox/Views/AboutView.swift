import SwiftUI

struct AboutView: View {
    @ObservedObject var updateCheck: UpdateCheckModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: AppIconFactory.dockIcon())
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(AppMetadata.displayName)
                        .font(.title2.weight(.semibold))

                    Text("版本 \(AppMetadata.versionDisplay)")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("启动台是一个 macOS 启动台替代工具，支持搜索、收藏、分类、文件夹和配置导入导出。")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await updateCheck.check()
                        }
                    } label: {
                        if updateCheck.isChecking {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("检查更新")
                        }
                    }
                    .disabled(updateCheck.isChecking)

                    Link("GitHub", destination: AppMetadata.repositoryURL)
                    Link("Release", destination: AppMetadata.releasesURL)
                }

                if let message = updateCheck.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(updateCheck.messageIsError ? .red : .secondary)
                        .textSelection(.enabled)
                }

                if let availableUpdate = updateCheck.availableUpdate {
                    Link("下载 \(availableUpdate.version)", destination: availableUpdate.pageURL)
                        .font(.caption)
                }
            }

            Divider()

            HStack {
                Text("开源协议")
                    .foregroundStyle(.secondary)

                Text("MIT")
                    .textSelection(.enabled)
            }
            .font(.callout)
        }
        .padding(24)
        .frame(width: 420, alignment: .leading)
    }
}
