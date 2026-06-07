import AppKit

@MainActor
final class KeyboardCommandRouter {
    static let shared = KeyboardCommandRouter()

    var handler: ((NSEvent) -> Bool)?

    func handle(_ event: NSEvent) -> Bool {
        handler?(event) == true
    }
}
