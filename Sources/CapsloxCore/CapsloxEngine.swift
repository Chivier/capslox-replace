public enum KeyboardTransport: CaseIterable, Equatable {
    case builtIn
    case bluetooth
    case usb
    case unknown
}

public struct KeyboardDevice: Equatable {
    public var transport: KeyboardTransport
    public var vendorID: Int?
    public var productID: Int?

    public init(transport: KeyboardTransport, vendorID: Int? = nil, productID: Int? = nil) {
        self.transport = transport
        self.vendorID = vendorID
        self.productID = productID
    }
}

public enum Key: Hashable {
    case capsLock
    case a
    case e
    case d
    case s
    case f
    case i
    case k
    case j
    case l
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow
    case pageUp
    case pageDown
    case other(Int)
}

public enum KeyPhase: Hashable {
    case down
    case up
}

public enum KeyModifier: Comparable, Hashable {
    case command
    case shift
    case option
    case control
}

public struct InputEvent: Equatable {
    public var key: Key
    public var phase: KeyPhase
    public var modifiers: Set<KeyModifier>
    public var device: KeyboardDevice?
    public var timeMilliseconds: UInt64

    public static func capsLock(isDown: Bool, device: KeyboardDevice?, timeMilliseconds: UInt64 = 0) -> InputEvent {
        InputEvent(
            key: .capsLock,
            phase: isDown ? .down : .up,
            modifiers: [],
            device: device,
            timeMilliseconds: timeMilliseconds
        )
    }

    public static func key(
        _ key: Key,
        phase: KeyPhase,
        modifiers: Set<KeyModifier>,
        device: KeyboardDevice?,
        timeMilliseconds: UInt64 = 0
    ) -> InputEvent {
        InputEvent(
            key: key,
            phase: phase,
            modifiers: modifiers,
            device: device,
            timeMilliseconds: timeMilliseconds
        )
    }
}

public struct OutputEvent: Equatable {
    public var key: Key
    public var phase: KeyPhase
    public var modifiers: Set<KeyModifier>

    public static func key(_ key: Key, phase: KeyPhase, modifiers: Set<KeyModifier>) -> OutputEvent {
        OutputEvent(key: key, phase: phase, modifiers: modifiers)
    }
}

public enum SystemAction: Equatable {
    case clearCapsLock
    case toggleCapsLock
}

public enum EventDecision: Equatable {
    case passthrough(actions: [SystemAction])
    case consumed([OutputEvent], actions: [SystemAction])

    public static var passThrough: EventDecision {
        .passthrough(actions: [])
    }

    public static func passThroughWithActions(_ actions: [SystemAction]) -> EventDecision {
        .passthrough(actions: actions)
    }

    public static func consume(_ output: [OutputEvent] = [], actions: [SystemAction] = []) -> EventDecision {
        .consumed(output, actions: actions)
    }
}

public final class CapsloxEngine {
    private let capsLockTapThresholdMilliseconds: UInt64
    private var isCapsLockDown = false
    private var capsLockDownAtMilliseconds: UInt64?
    private var capsLockWasUsedAsModifier = false
    private var activeRemaps: [Key: OutputKey] = [:]
    private var activeRemapOrder: [Key] = []
    private var suppressedPhysicalKeys = Set<Key>()

    public init(capsLockTapThresholdMilliseconds: UInt64 = 250) {
        self.capsLockTapThresholdMilliseconds = capsLockTapThresholdMilliseconds
    }

    public func cancelActiveGesture() -> EventDecision {
        let releaseEvents = releaseActiveRemaps()
        suppressedPhysicalKeys.removeAll()
        isCapsLockDown = false
        capsLockDownAtMilliseconds = nil
        capsLockWasUsedAsModifier = false

        if releaseEvents.isEmpty {
            return .passThrough
        }
        return .consume(releaseEvents, actions: [.clearCapsLock])
    }

    public func handle(_ event: InputEvent) -> EventDecision {
        if event.key == .capsLock {
            return handleCapsLock(phase: event.phase, timeMilliseconds: event.timeMilliseconds)
        }

        if event.phase == .up, suppressedPhysicalKeys.contains(event.key) {
            suppressedPhysicalKeys.remove(event.key)
            guard let existing = activeRemaps.removeValue(forKey: event.key) else {
                return .consume()
            }
            activeRemapOrder.removeAll { $0 == event.key }
            return .consume([
                .key(existing.key, phase: .up, modifiers: existing.modifiers)
            ])
        }

        guard isCapsLockDown else {
            return .passThrough
        }

        let activationActions = event.phase == .down ? markCapsLockUsedAsModifier() : []

        if let existing = activeRemaps[event.key] {
            if event.phase == .up {
                activeRemaps.removeValue(forKey: event.key)
                activeRemapOrder.removeAll { $0 == event.key }
                suppressedPhysicalKeys.remove(event.key)
            }
            return .consume([
                .key(existing.key, phase: event.phase, modifiers: existing.modifiers)
            ], actions: activationActions)
        }

        guard event.phase == .down else {
            return .passThrough
        }

        guard let remap = remap(for: event.key, modifiers: event.modifiers) else {
            return activationActions.isEmpty ? .passThrough : .passThroughWithActions(activationActions)
        }

        activeRemaps[event.key] = remap
        activeRemapOrder.append(event.key)
        suppressedPhysicalKeys.insert(event.key)
        return .consume([
            .key(remap.key, phase: event.phase, modifiers: remap.modifiers)
        ], actions: activationActions)
    }

    private func handleCapsLock(phase: KeyPhase, timeMilliseconds: UInt64) -> EventDecision {
        switch phase {
        case .down:
            guard !isCapsLockDown else {
                return capsLockWasUsedAsModifier ? .consume(actions: [.clearCapsLock]) : .consume()
            }
            isCapsLockDown = true
            capsLockDownAtMilliseconds = timeMilliseconds
            capsLockWasUsedAsModifier = false
            clearActiveRemaps()
            return .consume()
        case .up:
            guard isCapsLockDown else {
                return .consume()
            }
            let releaseEvents = releaseActiveRemaps()
            let shouldToggleCapsLock = !capsLockWasUsedAsModifier && isWithinTapThreshold(upAt: timeMilliseconds)
            isCapsLockDown = false
            capsLockDownAtMilliseconds = nil
            capsLockWasUsedAsModifier = false
            return .consume(
                releaseEvents,
                actions: shouldToggleCapsLock ? [.toggleCapsLock] : [.clearCapsLock]
            )
        }
    }

    private func markCapsLockUsedAsModifier() -> [SystemAction] {
        guard !capsLockWasUsedAsModifier else {
            return []
        }
        capsLockWasUsedAsModifier = true
        return [.clearCapsLock]
    }

    private func isWithinTapThreshold(upAt timeMilliseconds: UInt64) -> Bool {
        guard let downAt = capsLockDownAtMilliseconds else {
            return false
        }
        guard timeMilliseconds >= downAt else {
            return false
        }
        return timeMilliseconds - downAt <= capsLockTapThresholdMilliseconds
    }

    private func clearActiveRemaps() {
        activeRemaps.removeAll()
        activeRemapOrder.removeAll()
    }

    private func releaseActiveRemaps() -> [OutputEvent] {
        let output = activeRemapOrder.reversed().compactMap { key -> OutputEvent? in
            guard let remap = activeRemaps[key] else {
                return nil
            }
            return .key(remap.key, phase: .up, modifiers: remap.modifiers)
        }
        clearActiveRemaps()
        return output
    }

    private func remap(for key: Key, modifiers: Set<KeyModifier>) -> OutputKey? {
        switch key {
        case .e:
            return OutputKey(key: .upArrow, modifiers: modifiers)
        case .d:
            return OutputKey(key: .downArrow, modifiers: modifiers)
        case .s:
            return OutputKey(key: .leftArrow, modifiers: modifiers)
        case .f:
            return OutputKey(key: .rightArrow, modifiers: modifiers)
        case .i:
            return OutputKey(key: .pageUp, modifiers: modifiers)
        case .k:
            return OutputKey(key: .pageDown, modifiers: modifiers)
        case .j:
            return OutputKey(key: .leftArrow, modifiers: modifiers.union([.command]))
        case .l:
            return OutputKey(key: .rightArrow, modifiers: modifiers.union([.command]))
        case .capsLock, .a, .upArrow, .downArrow, .leftArrow, .rightArrow, .pageUp, .pageDown, .other:
            return nil
        }
    }
}

private struct OutputKey {
    var key: Key
    var modifiers: Set<KeyModifier>
}
