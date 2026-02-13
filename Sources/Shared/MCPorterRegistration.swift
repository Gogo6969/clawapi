import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi.shared", category: "mcporter")

/// Automatically registers ClawAPI as an MCP server in MCPorter's config.
/// Called on every app launch — idempotent and self-healing.
public struct MCPorterRegistration {

    /// Ensures `~/.mcporter/mcporter.json` contains the clawapi server entry.
    /// Silent on failure — logs to os_log but never throws or shows UI.
    public static func ensureRegistered() {
        do {
            try _ensureRegistered()
        } catch {
            logger.warning("MCPorter registration failed: \(error.localizedDescription)")
        }
    }

    private static func _ensureRegistered() throws {
        // 0. Only register if OpenClaw is actually installed
        guard OpenClawDetection.isInstalled else {
            logger.info("OpenClaw not detected, skipping MCPorter registration")
            return
        }

        // 1. Resolve the ClawAPIDaemon binary path.
        //    It lives next to the current executable (same build output directory).
        guard let daemonURL = daemonBinaryURL() else {
            logger.warning("Could not locate ClawAPIDaemon binary")
            return
        }

        // Verify the binary actually exists
        guard FileManager.default.isExecutableFile(atPath: daemonURL.path) else {
            logger.warning("ClawAPIDaemon not found at \(daemonURL.path)")
            return
        }

        // 2. Build the path to ~/.mcporter/mcporter.json
        let home = FileManager.default.homeDirectoryForCurrentUser
        let mcporterDir = home.appendingPathComponent(".mcporter")
        let configURL = mcporterDir.appendingPathComponent("mcporter.json")

        // 3. Create directory if needed
        try FileManager.default.createDirectory(at: mcporterDir, withIntermediateDirectories: true)

        // 4. Read existing config or start fresh
        var config: [String: Any]
        if let data = try? Data(contentsOf: configURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            config = json
        } else {
            config = ["mcpServers": [String: Any](), "imports": [Any]()]
        }

        // 5. Get or create the mcpServers dictionary
        var servers = config["mcpServers"] as? [String: Any] ?? [:]

        // 6. Check if clawapi entry already exists with the correct command
        if let existing = servers["clawapi"] as? [String: Any],
           let existingCommand = existing["command"] as? String,
           existingCommand == daemonURL.path {
            // Already registered with the correct path — nothing to do
            logger.debug("MCPorter: clawapi already registered at \(daemonURL.path)")
            return
        }

        // 7. Add or update the clawapi entry
        servers["clawapi"] = [
            "command": daemonURL.path,
            "args": ["mcp"],
            "description": "ClawAPI – secure API tool that injects credentials into requests without exposing them"
        ] as [String: Any]

        config["mcpServers"] = servers

        // Ensure imports array exists
        if config["imports"] == nil {
            config["imports"] = [Any]()
        }

        // 8. Write back
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL, options: .atomic)

        logger.info("MCPorter: registered clawapi → \(daemonURL.path)")
    }

    /// Finds the ClawAPIDaemon binary next to the current executable.
    private static func daemonBinaryURL() -> URL? {
        // CommandLine.arguments[0] gives us the current executable path
        let executablePath = CommandLine.arguments[0]
        let executableURL = URL(fileURLWithPath: executablePath).standardized
        let directory = executableURL.deletingLastPathComponent()
        let daemonURL = directory.appendingPathComponent("ClawAPIDaemon")

        if FileManager.default.isExecutableFile(atPath: daemonURL.path) {
            return daemonURL
        }

        // Fallback: check if the executable itself is ClawAPIDaemon (running from daemon)
        if executableURL.lastPathComponent == "ClawAPIDaemon" {
            return executableURL
        }

        return nil
    }
}
