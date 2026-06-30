public struct CapsloxPresentationMapping: Equatable, Sendable {
    public var input: String
    public var output: String

    public init(input: String, output: String) {
        self.input = input
        self.output = output
    }
}

public enum CapsloxPresentation {
    public static let appDisplayName = "CapsMov"
    public static let bundleName = "CapsMov"
    public static let statusBarTooltip = "CapsMov Navigation Layer"
    public static let permissionConfigTitle = "Permission Config"

    public static let directionMappings: [CapsloxPresentationMapping] = [
        .init(input: "E", output: "Up"),
        .init(input: "S", output: "Left"),
        .init(input: "D", output: "Down"),
        .init(input: "F", output: "Right"),
    ]

    public static let utilityMappings: [CapsloxPresentationMapping] = [
        .init(input: "I", output: "Page Up"),
        .init(input: "K", output: "Page Down"),
        .init(input: "J", output: "Line Start"),
        .init(input: "L", output: "Line End"),
    ]

    public static let permissionConfigSteps: [CapsloxPresentationMapping] = [
        .init(input: "Accessibility", output: "Allow CapsMov to modify keyboard events"),
        .init(input: "Input Monitoring", output: "Allow CapsMov to read physical Caps Lock state"),
    ]

    public static let secureInputStatusTitle = "Secure Input"
    public static let secureInputReadyValue = "Clear"
    public static let secureInputBlockedValue = "Blocked"

    public static let navigationMappings: [CapsloxPresentationMapping] = [
        .init(input: "Caps + E", output: "Up"),
        .init(input: "Caps + D", output: "Down"),
        .init(input: "Caps + S", output: "Left"),
        .init(input: "Caps + F", output: "Right"),
        .init(input: "Caps + I", output: "Page Up"),
        .init(input: "Caps + K", output: "Page Down"),
        .init(input: "Caps + J", output: "Line Start"),
        .init(input: "Caps + L", output: "Line End"),
    ]

    public static func secureInputDetail(for status: SecureInputStatus) -> String {
        if let owner = status.owner {
            return "\(owner.name) is using macOS Secure Input, so CapsMov can't read keys for now. This is expected while a password field is focused—move focus out of it (or quit \(owner.name)) and CapsMov resumes on its own."
        }
        return "macOS still reports Secure Input from pid \(status.pid), which has already exited—a known macOS glitch. It usually clears by itself; if CapsMov still can't read keys, lock the screen or log out and back in to reset it."
    }

    public static func secureInputActionTitle(for status: SecureInputStatus) -> String {
        guard let owner = status.owner else {
            return "Refresh"
        }
        return "Quit \(owner.name)"
    }
}
