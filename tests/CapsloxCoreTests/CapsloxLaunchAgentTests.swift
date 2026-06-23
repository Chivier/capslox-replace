import Testing
@testable import CapsloxCore

@Test func launchAgentPlistStartsCurrentAppAtLoginWithoutKeepAlive() {
    let plist = CapsloxLaunchAgent.plist(
        executablePath: "/Users/example/Applications/CapsMov.app/Contents/MacOS/CapsMov",
        logDirectory: "/Users/example/Library/Logs",
        tapThresholdMilliseconds: nil
    )

    #expect(plist.contains("<string>com.capsmov.app</string>"))
    #expect(plist.contains("<string>/Users/example/Applications/CapsMov.app/Contents/MacOS/CapsMov</string>"))
    #expect(plist.contains("<key>RunAtLoad</key>"))
    #expect(plist.contains("<true/>"))
    #expect(plist.contains("<string>/Users/example/Library/Logs/CapsMov.log</string>"))
    #expect(!plist.contains("<key>KeepAlive</key>"))
}

@Test func launchAgentPlistCanPersistCustomTapThreshold() {
    let plist = CapsloxLaunchAgent.plist(
        executablePath: "/Users/example/Apps/Capslox",
        logDirectory: "/Users/example/Library/Logs",
        tapThresholdMilliseconds: 300
    )

    #expect(plist.contains("<key>EnvironmentVariables</key>"))
    #expect(plist.contains("<key>CAPSLOX_TAP_THRESHOLD_MS</key>"))
    #expect(plist.contains("<string>300</string>"))
}
