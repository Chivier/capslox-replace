import Testing
@testable import CapsloxCore

private func consumeClearingCapsLock(_ output: [OutputEvent] = []) -> EventDecision {
    .consume(output, actions: [.clearCapsLock])
}

private func consumeTogglingCapsLock(_ output: [OutputEvent] = []) -> EventDecision {
    .consume(output, actions: [.toggleCapsLock])
}

private func passThroughClearingCapsLock() -> EventDecision {
    .passThroughWithActions([.clearCapsLock])
}

@Test func quickCapsLockTapTogglesOriginalCapsLock() {
    let engine = CapsloxEngine(capsLockTapThresholdMilliseconds: 200)

    #expect(engine.handle(.capsLock(isDown: true, device: nil, timeMilliseconds: 1_000)) == .consume())
    #expect(engine.handle(.capsLock(isDown: false, device: nil, timeMilliseconds: 1_120)) == consumeTogglingCapsLock())
}

@Test func longCapsLockHoldClearsInsteadOfTogglingCapsLock() {
    let engine = CapsloxEngine(capsLockTapThresholdMilliseconds: 200)

    #expect(engine.handle(.capsLock(isDown: true, device: nil, timeMilliseconds: 1_000)) == .consume())
    #expect(engine.handle(.capsLock(isDown: false, device: nil, timeMilliseconds: 1_250)) == consumeClearingCapsLock())
}

@Test func capsLockWithMappedShortcutClearsAndDoesNotToggleBeforeThreshold() {
    let engine = CapsloxEngine(capsLockTapThresholdMilliseconds: 200)

    #expect(engine.handle(.capsLock(isDown: true, device: nil, timeMilliseconds: 1_000)) == .consume())
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil, timeMilliseconds: 1_030)) == .consume([
        .key(.upArrow, phase: .down, modifiers: [])
    ], actions: [.clearCapsLock]))
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil, timeMilliseconds: 1_040)) == .consume([
        .key(.upArrow, phase: .up, modifiers: [])
    ]))
    #expect(engine.handle(.capsLock(isDown: false, device: nil, timeMilliseconds: 1_050)) == consumeClearingCapsLock())
}

@Test func capsLockWithUnmappedKeyClearsAndDoesNotToggle() {
    let engine = CapsloxEngine(capsLockTapThresholdMilliseconds: 200)

    #expect(engine.handle(.capsLock(isDown: true, device: nil, timeMilliseconds: 1_000)) == .consume())
    #expect(engine.handle(.key(.other(99), phase: .down, modifiers: [], device: nil, timeMilliseconds: 1_030)) == passThroughClearingCapsLock())
    #expect(engine.handle(.key(.other(99), phase: .up, modifiers: [], device: nil, timeMilliseconds: 1_040)) == .passThrough)
    #expect(engine.handle(.capsLock(isDown: false, device: nil, timeMilliseconds: 1_050)) == consumeClearingCapsLock())
}

@Test func capsLockEMapsToUpArrowAcrossKeyboardTransports() {
    for transport in KeyboardTransport.allCases {
        let engine = CapsloxEngine()
        let device = KeyboardDevice(transport: transport, vendorID: 100, productID: 200)

        #expect(engine.handle(.capsLock(isDown: true, device: device)) == .consume())
        #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: device)) == consumeClearingCapsLock([
            .key(.upArrow, phase: .down, modifiers: [])
        ]))
        #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: device)) == .consume([
            .key(.upArrow, phase: .up, modifiers: [])
        ]))
        #expect(engine.handle(.capsLock(isDown: false, device: device)) == consumeClearingCapsLock())
    }
}

@Test func capsLockTapIsConsumedWithoutTogglingCapsLock() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeTogglingCapsLock())
}

@Test func lineNavigationUsesMacCommandArrowSemantics() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.j, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
        .key(.leftArrow, phase: .down, modifiers: [.command])
    ]))
    #expect(engine.handle(.key(.j, phase: .up, modifiers: [], device: nil)) == .consume([
        .key(.leftArrow, phase: .up, modifiers: [.command])
    ]))
    #expect(engine.handle(.key(.l, phase: .down, modifiers: [.shift], device: nil)) == .consume([
        .key(.rightArrow, phase: .down, modifiers: [.command, .shift])
    ]))
}

@Test func everyCapsLockMappingUsesExpectedOutputKey() {
    let cases: [(Key, OutputEvent)] = [
        (.e, .key(.upArrow, phase: .down, modifiers: [])),
        (.d, .key(.downArrow, phase: .down, modifiers: [])),
        (.s, .key(.leftArrow, phase: .down, modifiers: [])),
        (.f, .key(.rightArrow, phase: .down, modifiers: [])),
        (.i, .key(.pageUp, phase: .down, modifiers: [])),
        (.k, .key(.pageDown, phase: .down, modifiers: [])),
        (.j, .key(.leftArrow, phase: .down, modifiers: [.command])),
        (.l, .key(.rightArrow, phase: .down, modifiers: [.command])),
    ]

    for (input, output) in cases {
        let engine = CapsloxEngine()

        #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
        #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([output]))
    }
}

@Test func mappedKeysPreserveShortcutModifiers() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [.shift], device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .down, modifiers: [.shift])
    ]))
    #expect(engine.handle(.key(.d, phase: .down, modifiers: [.command, .option], device: nil)) == .consume([
        .key(.downArrow, phase: .down, modifiers: [.command, .option])
    ]))
    #expect(engine.handle(.key(.j, phase: .down, modifiers: [.shift, .control], device: nil)) == .consume([
        .key(.leftArrow, phase: .down, modifiers: [.command, .shift, .control])
    ]))
}

@Test func unmappedKeysPassThroughWhileCapsLockIsHeld() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.other(99), phase: .down, modifiers: [], device: nil)) == passThroughClearingCapsLock())
    #expect(engine.handle(.key(.other(99), phase: .up, modifiers: [], device: nil)) == .passThrough)
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock())
}

@Test func mappedKeyUpWithoutPriorMappedKeyDownPassesThroughWhileCapsLockIsHeld() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .passThrough)
    #expect(engine.handle(.key(.j, phase: .up, modifiers: [.shift], device: nil)) == .passThrough)
}

@Test func releasingCapsLockBeforeMappedKeyReleasesSynthesizedKeyUp() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .up, modifiers: [])
    ]))
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .consume())
}

@Test func normalTypingAfterCapsLockSessionPassesThrough() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .up, modifiers: [])
    ]))
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .consume())

    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == .passThrough)
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .passThrough)
    #expect(engine.handle(.key(.a, phase: .down, modifiers: [.shift], device: nil)) == .passThrough)
    #expect(engine.handle(.key(.a, phase: .up, modifiers: [.shift], device: nil)) == .passThrough)
}

@Test func multipleMappedKeysHeldUntilCapsLockReleaseAreReleasedAndConsumed() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.handle(.key(.d, phase: .down, modifiers: [.shift], device: nil)) == .consume([
        .key(.downArrow, phase: .down, modifiers: [.shift])
    ]))
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
        .key(.downArrow, phase: .up, modifiers: [.shift]),
        .key(.upArrow, phase: .up, modifiers: []),
    ]))
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .consume())
    #expect(engine.handle(.key(.d, phase: .up, modifiers: [.shift], device: nil)) == .consume())

    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == .passThrough)
    #expect(engine.handle(.key(.d, phase: .down, modifiers: [.shift], device: nil)) == .passThrough)
}

@Test func multipleShortcutsWithinOneCapsLockHoldDoNotLeakState() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .consume([
        .key(.upArrow, phase: .up, modifiers: [])
    ]))
    #expect(engine.handle(.key(.f, phase: .down, modifiers: [], device: nil)) == .consume([
        .key(.rightArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.handle(.key(.f, phase: .up, modifiers: [], device: nil)) == .consume([
        .key(.rightArrow, phase: .up, modifiers: [])
    ]))
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock())
    #expect(engine.handle(.key(.f, phase: .down, modifiers: [], device: nil)) == .passThrough)
}

@Test func allShortcutsCanRunSequentiallyWithinOneCapsLockHold() {
    let engine = CapsloxEngine()
    let cases: [(input: Key, output: OutputEvent)] = [
        (.e, .key(.upArrow, phase: .down, modifiers: [])),
        (.d, .key(.downArrow, phase: .down, modifiers: [])),
        (.s, .key(.leftArrow, phase: .down, modifiers: [])),
        (.f, .key(.rightArrow, phase: .down, modifiers: [])),
        (.i, .key(.pageUp, phase: .down, modifiers: [])),
        (.k, .key(.pageDown, phase: .down, modifiers: [])),
        (.j, .key(.leftArrow, phase: .down, modifiers: [.command])),
        (.l, .key(.rightArrow, phase: .down, modifiers: [.command])),
    ]

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    for (index, entry) in cases.enumerated() {
        let (input, outputDown) = entry
        let outputUp = OutputEvent.key(outputDown.key, phase: .up, modifiers: outputDown.modifiers)
        let expectedDown = index == 0 ? consumeClearingCapsLock([outputDown]) : .consume([outputDown])

        #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == expectedDown)
        #expect(engine.handle(.key(input, phase: .up, modifiers: [], device: nil)) == .consume([outputUp]))
    }
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock())

    #expect(engine.handle(.key(.a, phase: .down, modifiers: [], device: nil)) == .passThrough)
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == .passThrough)
}

@Test func allMappedKeysReturnToNormalAfterEarlyCapsLockRelease() {
    let mappedKeys: [Key] = [.e, .d, .s, .f, .i, .k, .j, .l]

    for input in mappedKeys {
        let engine = CapsloxEngine()

        #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
        switch input {
        case .e:
            #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
                .key(.upArrow, phase: .down, modifiers: [])
            ]))
            #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
                .key(.upArrow, phase: .up, modifiers: [])
            ]))
        case .d:
            #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
                .key(.downArrow, phase: .down, modifiers: [])
            ]))
            #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
                .key(.downArrow, phase: .up, modifiers: [])
            ]))
        case .s:
            #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
                .key(.leftArrow, phase: .down, modifiers: [])
            ]))
            #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
                .key(.leftArrow, phase: .up, modifiers: [])
            ]))
        case .f:
            #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
                .key(.rightArrow, phase: .down, modifiers: [])
            ]))
            #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
                .key(.rightArrow, phase: .up, modifiers: [])
            ]))
        case .i:
            #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
                .key(.pageUp, phase: .down, modifiers: [])
            ]))
            #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
                .key(.pageUp, phase: .up, modifiers: [])
            ]))
        case .k:
            #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
                .key(.pageDown, phase: .down, modifiers: [])
            ]))
            #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
                .key(.pageDown, phase: .up, modifiers: [])
            ]))
        case .j:
            #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
                .key(.leftArrow, phase: .down, modifiers: [.command])
            ]))
            #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
                .key(.leftArrow, phase: .up, modifiers: [.command])
            ]))
        case .l:
            #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
                .key(.rightArrow, phase: .down, modifiers: [.command])
            ]))
            #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
                .key(.rightArrow, phase: .up, modifiers: [.command])
            ]))
        case .capsLock, .a, .upArrow, .downArrow, .leftArrow, .rightArrow, .pageUp, .pageDown, .other:
            Issue.record("Unexpected key in mapped-key coverage")
        }

        #expect(engine.handle(.key(input, phase: .up, modifiers: [], device: nil)) == .consume())
        #expect(engine.handle(.key(input, phase: .down, modifiers: [], device: nil)) == .passThrough)
        #expect(engine.handle(.key(input, phase: .up, modifiers: [], device: nil)) == .passThrough)
    }
}

@Test func repeatedMappedKeyDownProducesRepeatWithoutDuplicatingCleanup() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == .consume([
        .key(.upArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .up, modifiers: [])
    ]))
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .consume())
}

@Test func duplicateCapsLockDownDoesNotDropActiveShortcutState() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == consumeClearingCapsLock())
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .consume([
        .key(.upArrow, phase: .up, modifiers: [])
    ]))
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock())
}

@Test func repeatedCapsLockSessionsDoNotLeakMappedKeyState() {
    let engine = CapsloxEngine()

    for _ in 0..<2 {
        #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
        #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
            .key(.upArrow, phase: .down, modifiers: [])
        ]))
        #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock([
            .key(.upArrow, phase: .up, modifiers: [])
        ]))
        #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .consume())
    }
}

@Test func uppercaseMappedLettersWithoutCapsHoldPassThrough() {
    let engine = CapsloxEngine()

    for key in [Key.s, .e, .d, .f] {
        #expect(engine.handle(.key(key, phase: .down, modifiers: [.shift], device: nil)) == .passThrough)
        #expect(engine.handle(.key(key, phase: .up, modifiers: [.shift], device: nil)) == .passThrough)
    }
}

@Test func physicalCapsLockReleasePreventsLaterUppercaseRemaps() {
    var physicalState = CapsLockPhysicalState()
    let engine = CapsloxEngine()

    #expect(physicalState.update(sourceID: 1, isPressed: true) == .down)
    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.s, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
        .key(.leftArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.handle(.key(.s, phase: .up, modifiers: [], device: nil)) == .consume([
        .key(.leftArrow, phase: .up, modifiers: [])
    ]))

    #expect(physicalState.update(sourceID: 1, isPressed: false) == .up)
    #expect(engine.handle(.capsLock(isDown: false, device: nil)) == consumeClearingCapsLock())

    for key in [Key.s, .e, .d, .f] {
        #expect(engine.handle(.key(key, phase: .down, modifiers: [.shift], device: nil)) == .passThrough)
        #expect(engine.handle(.key(key, phase: .up, modifiers: [.shift], device: nil)) == .passThrough)
    }
}

@Test func capsLockPhysicalStateTracksMultipleKeyboardSources() {
    var physicalState = CapsLockPhysicalState()

    #expect(physicalState.update(sourceID: 1, isPressed: true) == .down)
    #expect(physicalState.isDown)
    #expect(physicalState.update(sourceID: 2, isPressed: true) == nil)
    #expect(physicalState.isDown)
    #expect(physicalState.update(sourceID: 1, isPressed: false) == nil)
    #expect(physicalState.isDown)
    #expect(physicalState.update(sourceID: 2, isPressed: false) == .up)
    #expect(!physicalState.isDown)
}

@Test func capsLockPhysicalStateIgnoresDuplicatePressAndReleaseValues() {
    var physicalState = CapsLockPhysicalState()

    #expect(physicalState.update(sourceID: 1, isPressed: true) == .down)
    #expect(physicalState.update(sourceID: 1, isPressed: true) == nil)
    #expect(physicalState.update(sourceID: 1, isPressed: false) == .up)
    #expect(physicalState.update(sourceID: 1, isPressed: false) == nil)
}

@Test func cancelActiveGestureReleasesMappedKeysForUiDisable() {
    let engine = CapsloxEngine()

    #expect(engine.handle(.capsLock(isDown: true, device: nil)) == .consume())
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == consumeClearingCapsLock([
        .key(.upArrow, phase: .down, modifiers: [])
    ]))
    #expect(engine.cancelActiveGesture() == consumeClearingCapsLock([
        .key(.upArrow, phase: .up, modifiers: [])
    ]))
    #expect(engine.handle(.key(.e, phase: .up, modifiers: [], device: nil)) == .passThrough)
    #expect(engine.handle(.key(.e, phase: .down, modifiers: [], device: nil)) == .passThrough)
}
