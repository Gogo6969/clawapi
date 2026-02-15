import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "ConnectionSettings")

// MARK: - Connection Mode

public enum ConnectionMode: String, Codable, Sendable {
    case local
    case remote
}

// MARK: - Connection Settings

public struct ConnectionSettings: Codable, Sendable {
    public var mode: ConnectionMode
    public var sshHost: String
    public var sshUser: String
    public var sshKeyPath: String
    public var sshPort: Int
    public var remoteOpenClawPath: String

    public init(
        mode: ConnectionMode = .local,
        sshHost: String = "",
        sshUser: String = "",
        sshKeyPath: String = "~/.ssh/id_ed25519",
        sshPort: Int = 22,
        remoteOpenClawPath: String = "~/.openclaw"
    ) {
        self.mode = mode
        self.sshHost = sshHost
        self.sshUser = sshUser
        self.sshKeyPath = sshKeyPath
        self.sshPort = sshPort
        self.remoteOpenClawPath = remoteOpenClawPath
    }

    // MARK: - Persistence

    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClawAPI")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("connection.json")
    }()

    public static func load() -> ConnectionSettings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(ConnectionSettings.self, from: data) else {
            return ConnectionSettings() // Default: local mode
        }
        logger.info("Loaded connection settings: mode=\(settings.mode.rawValue)")
        return settings
    }

    public func save() {
        do {
            let data = try JSONEncoder().encode(self)
            try data.write(to: Self.fileURL, options: .atomic)
            logger.info("Saved connection settings: mode=\(self.mode.rawValue)")
        } catch {
            logger.error("Failed to save connection settings: \(error.localizedDescription)")
        }
    }

    // MARK: - Computed Paths

    /// Remote path to openclaw.json
    public var remoteConfigPath: String {
        "\(remoteOpenClawPath)/openclaw.json"
    }

    /// Remote path to auth-profiles.json
    public var remoteAuthProfilesPath: String {
        "\(remoteOpenClawPath)/agents/main/agent/auth-profiles.json"
    }

    /// Whether the SSH fields are filled in enough to attempt a connection
    public var hasSSHCredentials: Bool {
        !sshHost.isEmpty && !sshUser.isEmpty
    }
}
