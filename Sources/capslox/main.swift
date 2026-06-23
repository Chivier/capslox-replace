import AppKit
import CapsloxCore
import Darwin
import SwiftUI

if CommandLine.arguments.contains("--smoke-test-ui") {
    print("\(CapsloxPresentation.appDisplayName) status bar UI ready")
    exit(0)
}

private func argumentValue(after flag: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: flag) else {
        return nil
    }
    let valueIndex = CommandLine.arguments.index(after: index)
    guard valueIndex < CommandLine.arguments.endIndex else {
        return nil
    }
    return CommandLine.arguments[valueIndex]
}

private let shouldShowPopoverForScreenshot = CommandLine.arguments.contains("--show-popover-for-screenshot")

@MainActor
private final class CapsloxAppDelegate: NSObject, NSApplicationDelegate {
    private var runtime: CapsloxRuntime?
    private var statusBarController: CapsloxStatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let runtime = CapsloxRuntime()
        _ = runtime.start()
        self.runtime = runtime
        statusBarController = CapsloxStatusBarController(
            runtime: runtime,
            showPopoverForScreenshot: shouldShowPopoverForScreenshot
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime?.stop()
    }
}

@MainActor
private final class CapsloxStatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let viewModel: CapsloxStatusViewModel

    init(runtime: CapsloxRuntime, showPopoverForScreenshot: Bool) {
        viewModel = CapsloxStatusViewModel(runtime: runtime)
        super.init()

        if let button = statusItem.button {
            button.image = CapsloxStatusIcon.makeImage()
            button.imagePosition = .imageOnly
            button.toolTip = CapsloxPresentation.statusBarTooltip
            button.target = self
            button.action = #selector(togglePopover(_:))
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 430)
        popover.contentViewController = NSHostingController(rootView: CapsloxPopoverView(viewModel: viewModel))

        if showPopoverForScreenshot {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPopover()
            }
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard statusItem.button != nil else {
            return
        }

        viewModel.refresh()
        if popover.isShown {
            popover.performClose(sender)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else {
            return
        }
        viewModel.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class CapsloxStatusViewModel: ObservableObject {
    @Published var isEnabled: Bool
    @Published var isRuntimeReady: Bool
    @Published var accessibilityTrusted: Bool
    @Published var launchAgentInstalled: Bool
    @Published var launchAgentError: String?
    @Published var startErrorMessage: String?

    private let runtime: CapsloxRuntime

    init(runtime: CapsloxRuntime) {
        self.runtime = runtime
        isEnabled = runtime.isEnabled
        isRuntimeReady = runtime.isRunning
        accessibilityTrusted = AXIsProcessTrusted()
        launchAgentInstalled = Self.defaultLaunchAgentPathExists()
        launchAgentError = nil
        startErrorMessage = runtime.startErrorMessage
    }

    var statusTitle: String {
        if !isRuntimeReady {
            return "Needs Permission"
        }
        return isEnabled ? "Running" : "Paused"
    }

    var statusDetail: String {
        if !isRuntimeReady {
            return "Enable Accessibility and Input Monitoring, then restart."
        }
        if isEnabled {
            return "Caps is active as a hold-to-navigate layer."
        }
        return "Keyboard input is passing through unchanged."
    }

    var thresholdText: String {
        "\(runtime.capsLockTapThresholdMilliseconds) ms tap threshold"
    }

    var shouldShowPermissionConfig: Bool {
        !accessibilityTrusted || !isRuntimeReady
    }

    func setEnabled(_ enabled: Bool) {
        runtime.setEnabled(enabled)
        refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try LaunchAgentManager.install(tapThresholdMilliseconds: runtime.capsLockTapThresholdMilliseconds)
            } else {
                try LaunchAgentManager.uninstall()
            }
            launchAgentError = nil
        } catch {
            launchAgentError = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        isEnabled = runtime.isEnabled
        isRuntimeReady = runtime.isRunning
        accessibilityTrusted = AXIsProcessTrusted()
        launchAgentInstalled = Self.defaultLaunchAgentPathExists()
        startErrorMessage = runtime.startErrorMessage
    }

    func openAccessibilitySettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func openSettingsPane(_ rawURL: String) {
        guard let url = URL(string: rawURL) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func defaultLaunchAgentPathExists() -> Bool {
        LaunchAgentManager.isInstalled
    }
}

private enum LaunchAgentManager {
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func install(tapThresholdMilliseconds: UInt64?) throws {
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try removeLegacyPlist()

        let executablePath = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let plist = CapsloxLaunchAgent.plist(
            executablePath: executablePath,
            logDirectory: logsURL.path,
            tapThresholdMilliseconds: tapThresholdMilliseconds
        )
        try plist.write(to: plistURL, atomically: true, encoding: .utf8)

        runLaunchctl(["disable", launchctlServiceName(for: CapsloxLaunchAgent.legacyLabel)])
        runLaunchctl(["bootout", launchctlDomain, legacyPlistURL.path])
        runLaunchctl(["bootstrap", launchctlDomain, plistURL.path])
        runLaunchctl(["enable", launchctlServiceName(for: CapsloxLaunchAgent.label)])
    }

    static func uninstall() throws {
        runLaunchctl(["disable", launchctlServiceName(for: CapsloxLaunchAgent.label)])
        runLaunchctl(["disable", launchctlServiceName(for: CapsloxLaunchAgent.legacyLabel)])
        try removePlistIfPresent(plistURL)
        try removeLegacyPlist()
    }

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(CapsloxLaunchAgent.label).plist")
    }

    private static var legacyPlistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(CapsloxLaunchAgent.legacyLabel).plist")
    }

    private static var logsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
    }

    private static var launchctlDomain: String {
        "gui/\(getuid())"
    }

    private static func launchctlServiceName(for label: String) -> String {
        "\(launchctlDomain)/\(label)"
    }

    private static func removeLegacyPlist() throws {
        try removePlistIfPresent(legacyPlistURL)
    }

    private static func removePlistIfPresent(_ url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func runLaunchctl(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}

private struct CapsloxPopoverView: View {
    @ObservedObject var viewModel: CapsloxStatusViewModel

    private let utilityColumns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
    ]

    var body: some View {
        Group {
            if viewModel.shouldShowPermissionConfig {
                permissionConfig
            } else {
                mainPanel
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            directionPad
            utilityGrid
            statusRows
            footer
        }
    }

    private var permissionConfig: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                iconPlate
                VStack(alignment: .leading, spacing: 2) {
                    Text(CapsloxPresentation.appDisplayName)
                        .font(.system(size: 17, weight: .semibold))
                    Text(CapsloxPresentation.permissionConfigTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusPill
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(CapsloxPresentation.permissionConfigSteps, id: \.input) { step in
                    PermissionConfigStep(
                        title: step.input,
                        detail: step.output,
                        isReady: step.input == "Accessibility" ? viewModel.accessibilityTrusted : viewModel.isRuntimeReady,
                        actionTitle: step.input == "Accessibility" ? "Open Accessibility" : "Open Input Monitoring",
                        action: step.input == "Accessibility"
                            ? viewModel.openAccessibilitySettings
                            : viewModel.openInputMonitoringSettings
                    )
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(viewModel.startErrorMessage ?? viewModel.statusDetail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            footer
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            iconPlate

            VStack(alignment: .leading, spacing: 2) {
                Text(CapsloxPresentation.appDisplayName)
                    .font(.system(size: 17, weight: .semibold))
                Text(viewModel.thresholdText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                statusPill
                Button {
                    viewModel.setEnabled(!viewModel.isEnabled)
                } label: {
                    SwitchPill(isOn: viewModel.isEnabled && viewModel.isRuntimeReady)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isRuntimeReady)
            }
        }
    }

    private var iconPlate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
            Image(nsImage: CapsloxStatusIcon.makeImage(size: 28))
                .frame(width: 28, height: 28)
        }
        .frame(width: 42, height: 42)
    }

    private var statusPill: some View {
        Label(viewModel.statusTitle, systemImage: statusSymbol)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.14))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var directionPad: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Caps Navigation")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("E S D F")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 7) {
                HStack(spacing: 7) {
                    Spacer(minLength: 0)
                    DirectionKey(mapping: .init(input: "E", output: "Up"), symbol: "arrow.up")
                    Spacer(minLength: 0)
                }
                HStack(spacing: 7) {
                    DirectionKey(mapping: .init(input: "S", output: "Left"), symbol: "arrow.left")
                    DirectionKey(mapping: .init(input: "D", output: "Down"), symbol: "arrow.down")
                    DirectionKey(mapping: .init(input: "F", output: "Right"), symbol: "arrow.right")
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var utilityGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("More Keys")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: utilityColumns, alignment: .leading, spacing: 7) {
                ForEach(CapsloxPresentation.utilityMappings, id: \.input) { mapping in
                    UtilityKey(mapping: mapping)
                }
            }
        }
    }

    private var statusRows: some View {
        VStack(spacing: 7) {
            StatusActionRow(
                title: "Accessibility",
                value: viewModel.accessibilityTrusted ? "Allowed" : "Required",
                symbol: viewModel.accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                isReady: viewModel.accessibilityTrusted,
                actionTitle: "Open",
                action: viewModel.openAccessibilitySettings
            )
            StatusActionRow(
                title: "Input Monitoring",
                value: viewModel.isRuntimeReady ? "Ready" : "Required",
                symbol: viewModel.isRuntimeReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                isReady: viewModel.isRuntimeReady,
                actionTitle: "Open",
                action: viewModel.openInputMonitoringSettings
            )
        }
        .padding(.top, 2)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    viewModel.setLaunchAtLogin(!viewModel.launchAgentInstalled)
                } label: {
                    HStack(spacing: 8) {
                        Text("Launch at Login")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        SwitchPill(isOn: viewModel.launchAgentInstalled)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    viewModel.quit()
                } label: {
                    Text("Quit")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }

            if let launchAgentError = viewModel.launchAgentError {
                Text(launchAgentError)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.top, 2)
    }

    private var statusColor: Color {
        if !viewModel.isRuntimeReady {
            return .orange
        }
        return viewModel.isEnabled ? .green : .secondary
    }

    private var statusSymbol: String {
        if !viewModel.isRuntimeReady {
            return "exclamationmark.triangle.fill"
        }
        return viewModel.isEnabled ? "bolt.fill" : "pause.fill"
    }
}

private struct PermissionConfigStep: View {
    var title: String
    var detail: String
    var isReady: Bool
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isReady ? .green : .orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ActionChip(title: actionTitle, action: action)
            }
        }
    }
}

private struct DirectionKey: View {
    var mapping: CapsloxPresentationMapping
    var symbol: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Text(mapping.input)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(mapping.output)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 88, height: 56)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.22), lineWidth: 1)
        )
    }
}

private struct UtilityKey: View {
    var mapping: CapsloxPresentationMapping

    var body: some View {
        HStack(spacing: 8) {
            Text(mapping.input)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .frame(width: 24, height: 24)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(mapping.output)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.18), lineWidth: 1)
        )
    }
}

private struct StatusActionRow: View {
    var title: String
    var value: String
    var symbol: String
    var isReady: Bool
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isReady ? .green : .orange)
                .frame(width: 15)
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            ActionChip(title: actionTitle, action: action)
        }
    }
}

private struct ActionChip: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.13))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct SwitchPill: View {
    var isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color.green.opacity(0.9) : Color(nsColor: .tertiaryLabelColor).opacity(0.28))
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                .padding(2)
        }
        .frame(width: 36, height: 20)
    }
}

private enum CapsloxStatusIcon {
    static func makeImage(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: image.size).fill()

        let columns = 5
        let rows = 3
        let gap = size * 0.09
        let square = (size - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let totalHeight = square * CGFloat(rows) + gap * CGFloat(rows - 1)
        let yOffset = (size - totalHeight) / 2

        for row in 0..<rows {
            for column in 0..<columns {
                let isDark = (row + column) % 2 == 1
                (isDark ? NSColor.labelColor : NSColor.secondaryLabelColor).setFill()
                let rect = NSRect(
                    x: CGFloat(column) * (square + gap),
                    y: yOffset + CGFloat(rows - row - 1) * (square + gap),
                    width: square,
                    height: square
                )
                NSBezierPath(roundedRect: rect, xRadius: square * 0.18, yRadius: square * 0.18).fill()
            }
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

private struct CapsMovPermissionPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    Image(nsImage: CapsloxStatusIcon.makeImage(size: 28))
                        .frame(width: 28, height: 28)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(CapsloxPresentation.appDisplayName)
                        .font(.system(size: 17, weight: .semibold))
                    Text(CapsloxPresentation.permissionConfigTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("Needs Permission", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.14))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(CapsloxPresentation.permissionConfigSteps, id: \.input) { step in
                    PermissionConfigStep(
                        title: step.input,
                        detail: step.output,
                        isReady: false,
                        actionTitle: step.input == "Accessibility" ? "Open Accessibility" : "Open Input Monitoring",
                        action: {}
                    )
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("Enable both permissions, then restart CapsMov.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            previewFooter
        }
        .padding(14)
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct CapsMovMainPreview: View {
    private let utilityColumns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    Image(nsImage: CapsloxStatusIcon.makeImage(size: 28))
                        .frame(width: 28, height: 28)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(CapsloxPresentation.appDisplayName)
                        .font(.system(size: 17, weight: .semibold))
                    Text("250 ms tap threshold")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("Running", systemImage: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.14))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Caps Navigation")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("E S D F")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                VStack(spacing: 7) {
                    HStack(spacing: 7) {
                        Spacer(minLength: 0)
                        DirectionKey(mapping: .init(input: "E", output: "Up"), symbol: "arrow.up")
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 7) {
                        DirectionKey(mapping: .init(input: "S", output: "Left"), symbol: "arrow.left")
                        DirectionKey(mapping: .init(input: "D", output: "Down"), symbol: "arrow.down")
                        DirectionKey(mapping: .init(input: "F", output: "Right"), symbol: "arrow.right")
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("More Keys")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: utilityColumns, alignment: .leading, spacing: 7) {
                    ForEach(CapsloxPresentation.utilityMappings, id: \.input) { mapping in
                        UtilityKey(mapping: mapping)
                    }
                }
            }

            previewFooter
        }
        .padding(14)
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private var previewFooter: some View {
    HStack {
        HStack(spacing: 8) {
            Text("Launch at Login")
                .font(.system(size: 12, weight: .medium))
            SwitchPill(isOn: true)
        }
        Spacer()
        Text("Quit")
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    .padding(.top, 2)
}

@MainActor
private func renderPreview(to path: String, permissionConfig: Bool) throws {
    let renderer = ImageRenderer(content: permissionConfig ? AnyView(CapsMovPermissionPreview()) : AnyView(CapsMovMainPreview()))
    renderer.scale = 2
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: URL(fileURLWithPath: path))
}

if let previewPath = argumentValue(after: "--render-ui-preview") {
    do {
        try renderPreview(
            to: previewPath,
            permissionConfig: CommandLine.arguments.contains("--permission-config")
        )
        print("rendered \(previewPath)")
        exit(0)
    } catch {
        fputs("Failed to render UI preview: \(error)\n", stderr)
        exit(1)
    }
}

private let app = NSApplication.shared
private let delegate = CapsloxAppDelegate()
app.delegate = delegate
app.run()
