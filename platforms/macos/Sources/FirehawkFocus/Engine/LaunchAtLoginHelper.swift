import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginHelper: ObservableObject {
    public static let shared = LaunchAtLoginHelper()

    @Published public var isEnabled: Bool = false

    private let label = "com.lordfirehawk.firehawk-focus"
    private let legacyLabel = "org.lordfirehawk.firehawk-focus"

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    private var legacyLaunchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(legacyLabel).plist")
    }

    public init() {
        migrateLegacyAgentIfNeeded()
        checkStatus()
    }

    public func checkStatus() {
        self.isEnabled = FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    public func setEnabled(_ enable: Bool) {
        clearSMAppServiceIfPresent()
        if enable {
            writeLaunchAgent()
            bootstrapAgent()
            self.isEnabled = true
            return
        }

        bootoutAgent(label: label)
        bootoutAgent(label: legacyLabel)
        try? FileManager.default.removeItem(at: launchAgentURL)
        try? FileManager.default.removeItem(at: legacyLaunchAgentURL)
        self.isEnabled = false
    }

    private func migrateLegacyAgentIfNeeded() {
        clearSMAppServiceIfPresent()
        let fm = FileManager.default
        if fm.fileExists(atPath: legacyLaunchAgentURL.path) {
            bootoutAgent(label: legacyLabel)
            try? fm.removeItem(at: legacyLaunchAgentURL)
            if !fm.fileExists(atPath: launchAgentURL.path) {
                writeLaunchAgent()
                bootstrapAgent()
            }
        }
    }

    private func clearSMAppServiceIfPresent() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                // Not registered, or already cleared — fine for personal installs.
            }
        }
    }

    private func writeLaunchAgent() {
        let appPath = Bundle.main.bundlePath
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/bin/open</string>
                <string>-a</string>
                <string>\(appPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>
        """
        let dir = launchAgentURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? plistContent.write(to: launchAgentURL, atomically: true, encoding: .utf8)
    }

    private func runLaunchctl(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private func bootstrapAgent() {
        let domain = "gui/\(getuid())"
        runLaunchctl(["bootout", "\(domain)/\(label)"])
        runLaunchctl(["bootstrap", domain, launchAgentURL.path])
    }

    private func bootoutAgent(label: String) {
        runLaunchctl(["bootout", "gui/\(getuid())/\(label)"])
    }
}
