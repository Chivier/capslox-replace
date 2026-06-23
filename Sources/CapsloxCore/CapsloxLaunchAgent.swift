import Foundation

public enum CapsloxLaunchAgent {
    public static let label = "com.capsmov.app"
    public static let legacyLabel = "com.capslox.app"

    public static func plist(
        executablePath: String,
        logDirectory: String,
        tapThresholdMilliseconds: UInt64?
    ) -> String {
        let environmentBlock: String
        if let tapThresholdMilliseconds {
            environmentBlock = """

              <key>EnvironmentVariables</key>
              <dict>
                <key>CAPSLOX_TAP_THRESHOLD_MS</key>
                <string>\(tapThresholdMilliseconds)</string>
              </dict>
            """
        } else {
            environmentBlock = ""
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(label)</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(executablePath.xmlEscaped)</string>
          </array>
          <key>RunAtLoad</key>
          <true/>\(environmentBlock)
          <key>StandardOutPath</key>
          <string>\(logDirectory.xmlEscaped)/CapsMov.log</string>
          <key>StandardErrorPath</key>
          <string>\(logDirectory.xmlEscaped)/CapsMov.err.log</string>
        </dict>
        </plist>
        """
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
