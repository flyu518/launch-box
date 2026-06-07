import Carbon.HIToolbox
import Foundation
import LaunchBoxCore

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func register(settings: HotKeySettings) {
        unregister()

        guard settings.isEnabled else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return noErr
                }

                let manager = Unmanaged<HotKeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                DispatchQueue.main.async {
                    manager.action()
                }

                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: FourCharCode("LBOX"), id: 1)
        RegisterEventHotKey(
            settings.keyCode,
            settings.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}

private func FourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, byte in
        (result << 8) + OSType(byte)
    }
}
