import Combine
import Foundation

@MainActor
final class UpdateCheckModel: ObservableObject {
    @Published private(set) var isChecking = false
    @Published private(set) var message: String?
    @Published private(set) var messageIsError = false
    @Published private(set) var availableUpdate: AppUpdate?

    func check() async {
        guard !isChecking else {
            return
        }

        isChecking = true
        message = nil
        messageIsError = false
        availableUpdate = nil

        do {
            let result = try await UpdateChecker.check(currentVersion: AppMetadata.version)
            switch result {
            case .upToDate:
                message = "当前已是最新版本。"
            case .available(let update):
                message = "发现新版本 \(update.version)。"
                availableUpdate = update
            }
            messageIsError = false
        } catch {
            message = "检查更新失败：\(error.localizedDescription)"
            messageIsError = true
        }

        isChecking = false
    }
}
