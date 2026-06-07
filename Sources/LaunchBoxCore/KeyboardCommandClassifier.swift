import Foundation

public enum LauncherKeyboardCommand: Equatable, Sendable {
    case open
    case moveLeft
    case moveRight
    case moveDown
    case moveUp
}

public struct LauncherKeyboardInput: Equatable, Sendable {
    public var keyCode: UInt16
    public var hasCommand: Bool
    public var hasOption: Bool
    public var hasControl: Bool
    public var hasShift: Bool
    public var isModalActive: Bool
    public var isFolderOpen: Bool

    public init(
        keyCode: UInt16,
        hasCommand: Bool = false,
        hasOption: Bool = false,
        hasControl: Bool = false,
        hasShift: Bool = false,
        isModalActive: Bool = false,
        isFolderOpen: Bool = false
    ) {
        self.keyCode = keyCode
        self.hasCommand = hasCommand
        self.hasOption = hasOption
        self.hasControl = hasControl
        self.hasShift = hasShift
        self.isModalActive = isModalActive
        self.isFolderOpen = isFolderOpen
    }
}

public enum KeyboardCommandClassifier {
    public static func command(for input: LauncherKeyboardInput) -> LauncherKeyboardCommand? {
        guard !input.hasCommand,
              !input.hasOption,
              !input.hasControl,
              !input.hasShift,
              !input.isModalActive,
              !input.isFolderOpen else {
            return nil
        }

        switch input.keyCode {
        case 36:
            return .open
        case 123:
            return .moveLeft
        case 124:
            return .moveRight
        case 125:
            return .moveDown
        case 126:
            return .moveUp
        default:
            return nil
        }
    }
}
