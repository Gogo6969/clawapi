import Foundation

/// Detects whether OpenClaw is installed (locally or on a remote VPS).
/// Checks for the `~/.openclaw/` directory, which OpenClaw creates on first run.
public enum OpenClawDetection {
    public static var isInstalled: Bool {
        let settings = OpenClawConfig.connectionSettings
        if settings.mode == .remote {
            return settings.hasSSHCredentials &&
                RemoteShell.directoryExists(path: settings.remoteOpenClawPath, settings: settings)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let openclawDir = home.appendingPathComponent(".openclaw")
        return FileManager.default.fileExists(atPath: openclawDir.path)
    }
}
