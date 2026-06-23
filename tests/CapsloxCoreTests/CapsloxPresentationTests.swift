import Testing
@testable import CapsloxCore

@Test func presentationUsesDistinctMenuBarIdentity() {
    #expect(CapsloxPresentation.appDisplayName == "CapsMov")
    #expect(CapsloxPresentation.bundleName == "CapsMov")
    #expect(CapsloxPresentation.statusBarTooltip == "CapsMov Navigation Layer")
}

@Test func presentationListsCoreNavigationMappings() {
    let mappings = CapsloxPresentation.navigationMappings

    #expect(mappings.count == 8)
    #expect(mappings.contains(.init(input: "Caps + E", output: "Up")))
    #expect(mappings.contains(.init(input: "Caps + D", output: "Down")))
    #expect(mappings.contains(.init(input: "Caps + S", output: "Left")))
    #expect(mappings.contains(.init(input: "Caps + F", output: "Right")))
    #expect(mappings.contains(.init(input: "Caps + I", output: "Page Up")))
    #expect(mappings.contains(.init(input: "Caps + K", output: "Page Down")))
    #expect(mappings.contains(.init(input: "Caps + J", output: "Line Start")))
    #expect(mappings.contains(.init(input: "Caps + L", output: "Line End")))
}

@Test func presentationSplitsDirectionAndUtilityMappingsForCompactPopover() {
    #expect(CapsloxPresentation.directionMappings == [
        .init(input: "E", output: "Up"),
        .init(input: "S", output: "Left"),
        .init(input: "D", output: "Down"),
        .init(input: "F", output: "Right"),
    ])
    #expect(CapsloxPresentation.utilityMappings == [
        .init(input: "I", output: "Page Up"),
        .init(input: "K", output: "Page Down"),
        .init(input: "J", output: "Line Start"),
        .init(input: "L", output: "Line End"),
    ])
}

@Test func presentationProvidesPermissionConfigSteps() {
    #expect(CapsloxPresentation.permissionConfigTitle == "Permission Config")
    #expect(CapsloxPresentation.permissionConfigSteps == [
        .init(input: "Accessibility", output: "Allow CapsMov to modify keyboard events"),
        .init(input: "Input Monitoring", output: "Allow CapsMov to read physical Caps Lock state"),
    ])
}
