import AppKit
import Carbon.HIToolbox
import LaunchBoxCore
import SwiftUI

struct HotKeyRecorderView: View {
    @Binding var settings: HotKeySettings
    let onCommit: () -> Void

    @State private var isRecording = false
    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("当前快捷键")
                    .foregroundStyle(.secondary)

                Text(HotKeyDisplayFormatter.displayText(for: settings))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .frame(minWidth: 110, alignment: .leading)

                Button(isRecording ? "请按新的快捷键" : "修改快捷键") {
                    isRecording = true
                    message = "等待按键，Esc 取消。"
                    messageIsError = false
                }

                Button("恢复默认") {
                    settings = HotKeySettings(isEnabled: settings.isEnabled)
                    message = "已恢复为 Option + Space。"
                    messageIsError = false
                    onCommit()
                }
            }

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(messageIsError ? .red : .secondary)
            }
        }
        .background {
            HotKeyCaptureView(isActive: isRecording) { event in
                handleKeyDown(event)
            }
            .frame(width: 0, height: 0)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 {
            isRecording = false
            message = nil
            return
        }

        let modifiers = HotKeyDisplayFormatter.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            message = "需要同时按下 Command、Option、Control 或 Shift。"
            messageIsError = true
            return
        }

        let newSettings = HotKeySettings(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            isEnabled: settings.isEnabled
        )
        settings = newSettings
        isRecording = false
        message = "已设置为 \(HotKeyDisplayFormatter.displayText(for: newSettings))。"
        messageIsError = false
        onCommit()
    }
}

private struct HotKeyCaptureView: NSViewRepresentable {
    let isActive: Bool
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onKeyDown = onKeyDown
        view.isActive = isActive
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onKeyDown = onKeyDown
        nsView.isActive = isActive

        guard isActive else {
            return
        }

        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class CaptureView: NSView {
        var isActive = false
        var onKeyDown: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool {
            true
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if isActive {
                window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            onKeyDown?(event)
        }
    }
}

enum HotKeyDisplayFormatter {
    static func displayText(for settings: HotKeySettings) -> String {
        "\(modifierText(settings.modifiers))\(keyText(UInt16(settings.keyCode)))"
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0

        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        return modifiers
    }

    private static func modifierText(_ modifiers: UInt32) -> String {
        var parts: [String] = []

        if modifiers & UInt32(controlKey) != 0 {
            parts.append("^")
        }
        if modifiers & UInt32(optionKey) != 0 {
            parts.append("Option + ")
        }
        if modifiers & UInt32(shiftKey) != 0 {
            parts.append("Shift + ")
        }
        if modifiers & UInt32(cmdKey) != 0 {
            parts.append("Command + ")
        }

        return parts.joined()
    }

    private static func keyText(_ keyCode: UInt16) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }

    private static let keyNames: [UInt16: String] = [
        0: "A",
        1: "S",
        2: "D",
        3: "F",
        4: "H",
        5: "G",
        6: "Z",
        7: "X",
        8: "C",
        9: "V",
        11: "B",
        12: "Q",
        13: "W",
        14: "E",
        15: "R",
        16: "Y",
        17: "T",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        22: "6",
        23: "5",
        24: "=",
        25: "9",
        26: "7",
        27: "-",
        28: "8",
        29: "0",
        30: "]",
        31: "O",
        32: "U",
        33: "[",
        34: "I",
        35: "P",
        36: "Return",
        37: "L",
        38: "J",
        39: "'",
        40: "K",
        41: ";",
        42: "\\",
        43: ",",
        44: "/",
        45: "N",
        46: "M",
        47: ".",
        48: "Tab",
        49: "Space",
        50: "`",
        51: "Delete",
        53: "Esc",
        65: ".",
        67: "*",
        69: "+",
        71: "Clear",
        75: "/",
        76: "Enter",
        78: "-",
        81: "=",
        82: "0",
        83: "1",
        84: "2",
        85: "3",
        86: "4",
        87: "5",
        88: "6",
        89: "7",
        91: "8",
        92: "9",
        96: "F5",
        97: "F6",
        98: "F7",
        99: "F3",
        100: "F8",
        101: "F9",
        103: "F11",
        105: "F13",
        106: "F16",
        107: "F14",
        109: "F10",
        111: "F12",
        113: "F15",
        114: "Help",
        115: "Home",
        116: "Page Up",
        117: "Forward Delete",
        118: "F4",
        119: "End",
        120: "F2",
        121: "Page Down",
        122: "F1",
        123: "Left",
        124: "Right",
        125: "Down",
        126: "Up"
    ]
}
