import Foundation
import CryptoKit
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "UpdateChecker")

// MARK: - Models

/// The remote update manifest hosted on GitHub.
public struct UpdateManifest: Codable, Sendable, Equatable {
    public let version: String
    public let build: String
    public let minimumSystemVersion: String
    public let releaseNotes: String
    public let downloadURL: URL
    public let sha256: String
}

/// Observable state of the update process.
public enum UpdateStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case available(UpdateManifest)
    case downloading(progress: Double)
    case installing
    case error(String)
}

// MARK: - UpdateChecker

@MainActor
public final class UpdateChecker: ObservableObject {
    @Published public var status: UpdateStatus = .idle

    /// Convenience for UI — true when an update is available.
    public var hasUpdate: Bool {
        if case .available = status { return true }
        return false
    }

    public init() {}

    // MARK: - Check for Updates

    public func checkForUpdates() async {
        status = .checking

        do {
            let (data, response) = try await URLSession.shared.data(from: AppVersion.updateManifestURL)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                status = .upToDate  // No manifest found → treat as up to date
                logger.info("Update manifest returned \(httpResponse.statusCode), treating as up-to-date")
                return
            }

            let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)

            // Check minimum system version
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            let osString = "\(osVersion.majorVersion).\(osVersion.minorVersion)"
            if isNewerVersion(manifest.minimumSystemVersion, than: osString) {
                status = .upToDate  // Update requires newer macOS than we have
                logger.info("Update requires macOS \(manifest.minimumSystemVersion), we have \(osString)")
                return
            }

            if isNewerVersion(manifest.version, than: AppVersion.current) {
                status = .available(manifest)
                logger.info("Update available: \(manifest.version) (current: \(AppVersion.current))")
            } else {
                status = .upToDate
                logger.info("Up to date: \(AppVersion.current)")
            }
        } catch {
            logger.error("Update check failed: \(error.localizedDescription)")
            status = .error("Could not check for updates: \(error.localizedDescription)")
        }
    }

    // MARK: - Download and Install

    public func downloadAndInstall(manifest: UpdateManifest) async {
        // Enforce HTTPS
        guard manifest.downloadURL.scheme == "https" else {
            status = .error("Update download URL must use HTTPS.")
            return
        }

        status = .downloading(progress: 0)

        do {
            // 1. Prepare temp directory
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("clawapi-update-\(manifest.version)")
            try? FileManager.default.removeItem(at: tempDir)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let zipURL = tempDir.appendingPathComponent("ClawAPI.zip")

            // 2. Download the zip
            logger.info("Downloading update from \(manifest.downloadURL)")
            let (downloadedURL, _) = try await URLSession.shared.download(from: manifest.downloadURL)
            try FileManager.default.moveItem(at: downloadedURL, to: zipURL)

            status = .downloading(progress: 0.5)

            // 3. Verify SHA-256
            let fileData = try Data(contentsOf: zipURL)
            let digest = SHA256.hash(data: fileData)
            let hash = digest.map { String(format: "%02x", $0) }.joined()

            guard hash == manifest.sha256 else {
                logger.error("SHA-256 mismatch: expected \(manifest.sha256), got \(hash)")
                status = .error("Download integrity check failed. The file may be corrupted.")
                return
            }

            status = .downloading(progress: 0.8)

            // 4. Unzip using ditto
            let extractDir = tempDir.appendingPathComponent("extracted")
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

            let ditto = Process()
            ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            ditto.arguments = ["-xk", zipURL.path, extractDir.path]
            try ditto.run()
            ditto.waitUntilExit()

            guard ditto.terminationStatus == 0 else {
                status = .error("Failed to extract update archive.")
                return
            }

            // 5. Find the .app bundle
            let contents = try FileManager.default.contentsOfDirectory(
                at: extractDir, includingPropertiesForKeys: nil)
            guard let newAppURL = contents.first(where: { $0.pathExtension == "app" }) else {
                status = .error("No .app bundle found in the update archive.")
                return
            }

            status = .downloading(progress: 1.0)

            // 6. Replace and relaunch
            try replaceAndRelaunch(with: newAppURL)

        } catch {
            logger.error("Update failed: \(error.localizedDescription)")
            status = .error("Update failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Replace and Relaunch

    private func replaceAndRelaunch(with newAppURL: URL) throws {
        status = .installing

        // Get current .app bundle path
        let currentAppURL = Bundle.main.bundleURL
        guard currentAppURL.pathExtension == "app" else {
            status = .error("Cannot determine current app location. Are you running from a .app bundle?")
            return
        }

        let parentDir = currentAppURL.deletingLastPathComponent()
        let backupURL = parentDir.appendingPathComponent("ClawAPI-old.app")

        // Remove old backup if it exists
        try? FileManager.default.removeItem(at: backupURL)

        // Move current app to backup
        try FileManager.default.moveItem(at: currentAppURL, to: backupURL)

        // Copy new app into place
        try FileManager.default.copyItem(at: newAppURL, to: currentAppURL)

        logger.info("Update installed. Relaunching...")

        // Relaunch: shell script waits for our PID to die, then opens the new app and cleans up
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        open "\(currentAppURL.path)"
        rm -rf "\(backupURL.path)"
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        try process.run()

        // Exit the current app — the relaunch script waits for this PID to die
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            exit(0)
        }
    }

    // MARK: - Semver Comparison

    /// Returns true if version `a` is newer than version `b`.
    public func isNewerVersion(_ a: String, than b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(partsA.count, partsB.count) {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }
        return false
    }
}
