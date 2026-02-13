import Foundation

/// Detects whether OpenClaw is installed on the current machine.
/// Checks for the `~/.openclaw/` directory, which OpenClaw creates on first run.
public enum OpenClawDetection {
    public static var isInstalled: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let openclawDir = home.appendingPathComponent(".openclaw")
        return FileManager.default.fileExists(atPath: openclawDir.path)
    }
}
