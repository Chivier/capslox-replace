import ApplicationServices
import CapsloxCore
import CoreGraphics
import Foundation
import IOKit
import IOKit.hid
import IOKit.hidsystem

private let generatedEventMarker: Int64 = 0x6361_7073_6c6f_78
private let defaultCapsLockTapThresholdMilliseconds: UInt64 = 250

final class CapsloxRuntime {
    let capsLockTapThresholdMilliseconds: UInt64
    private var eventTap: CapsloxEventTap?
    private var eventTapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventTapRefcon: UnsafeMutableRawPointer?
    private(set) var startErrorMessage: String?

    init(capsLockTapThresholdMilliseconds: UInt64 = configuredCapsLockTapThresholdMilliseconds()) {
        self.capsLockTapThresholdMilliseconds = capsLockTapThresholdMilliseconds
    }

    var isRunning: Bool {
        eventTap != nil && startErrorMessage == nil
    }

    var isEnabled: Bool {
        eventTap?.isEnabled ?? false
    }

    func start() -> Bool {
        requestAccessibilityIfNeeded()

        let eventTap = CapsloxEventTap(capsLockTapThresholdMilliseconds: capsLockTapThresholdMilliseconds)
        guard eventTap.start() else {
            startErrorMessage = """
            Failed to open the IOHID keyboard monitor or HIDSystem lock-state controller.
            Confirm Input Monitoring permission for CapsMov, then restart CapsMov.
            """
            return false
        }

        let refcon = Unmanaged.passRetained(eventTap).toOpaque()
        let mask = eventMask([.keyDown, .keyUp, .flagsChanged])

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            Unmanaged<CapsloxEventTap>.fromOpaque(refcon).release()
            startErrorMessage = """
            Failed to create keyboard event tap.
            Confirm Accessibility and Input Monitoring permission for CapsMov, then restart CapsMov.
            """
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = eventTap
        eventTapPort = tap
        self.runLoopSource = runLoopSource
        eventTapRefcon = refcon
        startErrorMessage = nil
        return true
    }

    func setEnabled(_ enabled: Bool) {
        eventTap?.setEnabled(enabled)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let eventTapPort {
            CFMachPortInvalidate(eventTapPort)
        }
        if let eventTapRefcon {
            Unmanaged<CapsloxEventTap>.fromOpaque(eventTapRefcon).release()
        }
        runLoopSource = nil
        eventTapPort = nil
        eventTapRefcon = nil
        eventTap = nil
    }

    deinit {
        stop()
    }
}

private final class CapsloxEventTap {
    private let engine: CapsloxEngine
    private let engineLock = NSLock()
    private let lockStateController = CapsLockLockStateController()
    private var enabled = true
    private lazy var capsLockMonitor = CapsLockPhysicalMonitor { [weak self] phase in
        self?.handleCapsLockTransition(phase)
    }

    init(capsLockTapThresholdMilliseconds: UInt64) {
        engine = CapsloxEngine(capsLockTapThresholdMilliseconds: capsLockTapThresholdMilliseconds)
    }

    var isEnabled: Bool {
        engineLock.lock()
        defer { engineLock.unlock() }
        return enabled
    }

    func start() -> Bool {
        lockStateController.start() && capsLockMonitor.start()
    }

    func setEnabled(_ enabled: Bool) {
        let cancellation: EventDecision?

        engineLock.lock()
        if self.enabled == enabled {
            engineLock.unlock()
            return
        }
        self.enabled = enabled
        cancellation = enabled ? nil : engine.cancelActiveGesture()
        engineLock.unlock()

        if let cancellation {
            perform(cancellation)
        }
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if isGeneratedByCapslox(event) {
            return Unmanaged.passUnretained(event)
        }

        guard isEnabled else {
            return Unmanaged.passUnretained(event)
        }

        if isCapsLockFlagsChanged(type: type, event: event) {
            return nil
        }

        guard let input = inputEvent(type: type, event: event) else {
            return Unmanaged.passUnretained(event)
        }

        switch handle(input) {
        case .passthrough(let actions):
            actions.forEach(perform)
            return Unmanaged.passUnretained(event)
        case .consumed(let output, let actions):
            actions.forEach(perform)
            output.forEach(post)
            return nil
        }
    }

    private func handleCapsLockTransition(_ phase: KeyPhase) {
        guard isEnabled else {
            return
        }

        if phase == .down {
            lockStateController.beginCapsLockGesture()
        }
        let input = InputEvent.capsLock(
            isDown: phase == .down,
            device: nil,
            timeMilliseconds: currentTimeMilliseconds()
        )
        guard case .consumed(let output, let actions) = handle(input) else {
            return
        }
        actions.forEach(perform)
        output.forEach(post)
    }

    private func handle(_ input: InputEvent) -> EventDecision {
        engineLock.lock()
        defer { engineLock.unlock() }
        return engine.handle(input)
    }

    private func perform(_ decision: EventDecision) {
        switch decision {
        case .passthrough(let actions):
            actions.forEach(perform)
        case .consumed(let output, let actions):
            actions.forEach(perform)
            output.forEach(post)
        }
    }

    private func perform(_ action: SystemAction) {
        switch action {
        case .clearCapsLock:
            lockStateController.clearCapsLock()
        case .toggleCapsLock:
            lockStateController.toggleCapsLockFromGesture()
        }
    }

    private func inputEvent(type: CGEventType, event: CGEvent) -> InputEvent? {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        switch type {
        case .keyDown:
            return .key(
                key(from: keyCode),
                phase: .down,
                modifiers: modifiers(from: event.flags),
                device: nil,
                timeMilliseconds: currentTimeMilliseconds()
            )
        case .keyUp:
            return .key(
                key(from: keyCode),
                phase: .up,
                modifiers: modifiers(from: event.flags),
                device: nil,
                timeMilliseconds: currentTimeMilliseconds()
            )
        default:
            return nil
        }
    }

    private func post(_ output: OutputEvent) {
        guard let keyCode = keyCode(for: output.key) else {
            return
        }
        let keyDown = output.phase == .down
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: keyDown) else {
            return
        }
        event.flags = flags(from: output.modifiers)
        event.setIntegerValueField(.eventSourceUserData, value: generatedEventMarker)
        event.post(tap: .cghidEventTap)
    }
}

private final class CapsLockLockStateController {
    private var connection = io_connect_t()
    private var capsLockStateAtGestureStart: Bool?

    func start() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else {
            return false
        }
        defer { IOObjectRelease(service) }

        return IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection) == KERN_SUCCESS
    }

    func beginCapsLockGesture() {
        capsLockStateAtGestureStart = capsLockEnabled()
    }

    func clearCapsLock() {
        setCapsLock(false)
        capsLockStateAtGestureStart = nil
    }

    func toggleCapsLockFromGesture() {
        guard let initialState = capsLockStateAtGestureStart else {
            toggleCapsLock()
            return
        }
        setCapsLock(!initialState)
        capsLockStateAtGestureStart = nil
    }

    private func toggleCapsLock() {
        guard let enabled = capsLockEnabled() else {
            return
        }
        setCapsLock(!enabled)
    }

    private func capsLockEnabled() -> Bool? {
        guard connection != 0 else {
            return nil
        }

        var enabled = false
        let result = IOHIDGetModifierLockState(connection, Int32(kIOHIDCapsLockState), &enabled)
        guard result == KERN_SUCCESS else {
            return nil
        }
        return enabled
    }

    private func setCapsLock(_ enabled: Bool) {
        guard connection != 0 else {
            return
        }
        IOHIDSetModifierLockState(connection, Int32(kIOHIDCapsLockState), enabled)
    }

    deinit {
        guard connection != 0 else {
            return
        }
        IOServiceClose(connection)
    }
}

private final class CapsLockPhysicalMonitor {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    private let stateLock = NSLock()
    private var state = CapsLockPhysicalState()
    private let onTransition: (KeyPhase) -> Void

    init(onTransition: @escaping (KeyPhase) -> Void) {
        self.onTransition = onTransition
    }

    func start() -> Bool {
        let keyboards: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
            ],
            [
                kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey: kHIDUsage_GD_Keypad,
            ],
        ]

        IOHIDManagerSetDeviceMatchingMultiple(manager, keyboards as CFArray)
        IOHIDManagerRegisterInputValueCallback(manager, capsLockInputValueCallback, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        return IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess
    }

    deinit {
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    fileprivate func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == kHIDPage_KeyboardOrKeypad,
              IOHIDElementGetUsage(element) == kHIDUsage_KeyboardCapsLock
        else {
            return
        }

        let sourceID = UInt64(UInt(bitPattern: Unmanaged.passUnretained(element).toOpaque()))
        let isPressed = IOHIDValueGetIntegerValue(value) != 0

        stateLock.lock()
        let transition = state.update(sourceID: sourceID, isPressed: isPressed)
        stateLock.unlock()

        guard let transition else {
            return
        }
        onTransition(transition)
    }
}

private func capsLockInputValueCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue?
) {
    guard result == kIOReturnSuccess, let context, let value else {
        return
    }
    let monitor = Unmanaged<CapsLockPhysicalMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.handle(value)
}

private enum KeyCode {
    static let a = 0
    static let s = 1
    static let d = 2
    static let f = 3
    static let e = 14
    static let i = 34
    static let l = 37
    static let j = 38
    static let k = 40
    static let command = 55
    static let capsLock = 57
    static let pageUp = 116
    static let pageDown = 121
    static let leftArrow = 123
    static let rightArrow = 124
    static let downArrow = 125
    static let upArrow = 126
}

private func key(from keyCode: Int) -> Key {
    switch keyCode {
    case KeyCode.a:
        return .a
    case KeyCode.e:
        return .e
    case KeyCode.d:
        return .d
    case KeyCode.s:
        return .s
    case KeyCode.f:
        return .f
    case KeyCode.i:
        return .i
    case KeyCode.k:
        return .k
    case KeyCode.j:
        return .j
    case KeyCode.l:
        return .l
    case KeyCode.capsLock:
        return .capsLock
    case KeyCode.upArrow:
        return .upArrow
    case KeyCode.downArrow:
        return .downArrow
    case KeyCode.leftArrow:
        return .leftArrow
    case KeyCode.rightArrow:
        return .rightArrow
    case KeyCode.pageUp:
        return .pageUp
    case KeyCode.pageDown:
        return .pageDown
    default:
        return .other(keyCode)
    }
}

private func keyCode(for key: Key) -> Int? {
    switch key {
    case .a:
        return KeyCode.a
    case .e:
        return KeyCode.e
    case .d:
        return KeyCode.d
    case .s:
        return KeyCode.s
    case .f:
        return KeyCode.f
    case .i:
        return KeyCode.i
    case .k:
        return KeyCode.k
    case .j:
        return KeyCode.j
    case .l:
        return KeyCode.l
    case .capsLock:
        return KeyCode.capsLock
    case .upArrow:
        return KeyCode.upArrow
    case .downArrow:
        return KeyCode.downArrow
    case .leftArrow:
        return KeyCode.leftArrow
    case .rightArrow:
        return KeyCode.rightArrow
    case .pageUp:
        return KeyCode.pageUp
    case .pageDown:
        return KeyCode.pageDown
    case .other:
        return nil
    }
}

private func modifiers(from flags: CGEventFlags) -> Set<KeyModifier> {
    var modifiers = Set<KeyModifier>()
    if flags.contains(.maskCommand) {
        modifiers.insert(.command)
    }
    if flags.contains(.maskShift) {
        modifiers.insert(.shift)
    }
    if flags.contains(.maskAlternate) {
        modifiers.insert(.option)
    }
    if flags.contains(.maskControl) {
        modifiers.insert(.control)
    }
    return modifiers
}

private func flags(from modifiers: Set<KeyModifier>) -> CGEventFlags {
    var flags = CGEventFlags()
    if modifiers.contains(.command) {
        flags.insert(.maskCommand)
    }
    if modifiers.contains(.shift) {
        flags.insert(.maskShift)
    }
    if modifiers.contains(.option) {
        flags.insert(.maskAlternate)
    }
    if modifiers.contains(.control) {
        flags.insert(.maskControl)
    }
    return flags
}

private func isGeneratedByCapslox(_ event: CGEvent) -> Bool {
    event.getIntegerValueField(.eventSourceUserData) == generatedEventMarker
}

private func isCapsLockFlagsChanged(type: CGEventType, event: CGEvent) -> Bool {
    guard type == .flagsChanged else {
        return false
    }
    return Int(event.getIntegerValueField(.keyboardEventKeycode)) == KeyCode.capsLock
}

private func eventMask(_ types: [CGEventType]) -> CGEventMask {
    types.reduce(CGEventMask(0)) { mask, type in
        mask | (CGEventMask(1) << CGEventMask(type.rawValue))
    }
}

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let tap = Unmanaged<CapsloxEventTap>.fromOpaque(refcon).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}

private func currentTimeMilliseconds() -> UInt64 {
    DispatchTime.now().uptimeNanoseconds / 1_000_000
}

func configuredCapsLockTapThresholdMilliseconds() -> UInt64 {
    guard let rawValue = ProcessInfo.processInfo.environment["CAPSLOX_TAP_THRESHOLD_MS"],
          let threshold = UInt64(rawValue),
          threshold > 0
    else {
        return defaultCapsLockTapThresholdMilliseconds
    }
    return threshold
}

private func requestAccessibilityIfNeeded() {
    let promptKey = "AXTrustedCheckOptionPrompt"
    let options = [promptKey: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
}
