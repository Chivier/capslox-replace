public struct CapsLockPhysicalState {
    private var pressedSources = Set<UInt64>()

    public init() {}

    public var isDown: Bool {
        !pressedSources.isEmpty
    }

    public mutating func update(sourceID: UInt64, isPressed: Bool) -> KeyPhase? {
        let wasDown = isDown

        if isPressed {
            pressedSources.insert(sourceID)
        } else {
            pressedSources.remove(sourceID)
        }

        guard wasDown != isDown else {
            return nil
        }

        return isDown ? .down : .up
    }
}
