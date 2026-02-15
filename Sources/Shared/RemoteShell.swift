import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "RemoteShell")

// MARK: - Remote Shell Errors

public enum RemoteShellError: LocalizedError, Sendable {
    case connectionFailed(String)
    case commandFailed(exitCode: Int32, stderr: String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg):
            return "SSH connection failed: \(msg)"
        case .commandFailed(let code, let stderr):
            return "Remote command failed (exit \(code)): \(stderr)"
        case .timeout:
            return "SSH connection timed out"
        }
    }
}

// MARK: - Remote Shell

public enum RemoteShell {

    /// Build the base SSH argument list for a given connection settings.
    private static func sshArgs(settings: ConnectionSettings) -> [String] {
        var args = [
            "/usr/bin/ssh",
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=accept-new",
            "-p", "\(settings.sshPort)",
        ]
        // Expand ~ in key path
        let keyPath = NSString(string: settings.sshKeyPath).expandingTildeInPath
        if FileManager.default.fileExists(atPath: keyPath) {
            args += ["-i", keyPath]
        }
        args.append("\(settings.sshUser)@\(settings.sshHost)")
        return args
    }

    /// Run an SSH command and return (exitCode, stdout, stderr).
    @discardableResult
    public static func execute(
        command: String,
        settings: ConnectionSettings
    ) throws -> (exitCode: Int32, stdout: String, stderr: String) {
        let args = sshArgs(settings: settings) + [command]

        logger.debug("SSH exec: \(args.dropFirst().joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst())

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return (process.terminationStatus, stdout, stderr)
    }

    /// Read a remote file's contents via SSH.
    public static func readFile(path: String, settings: ConnectionSettings) throws -> Data {
        let result = try execute(command: "cat '\(path)'", settings: settings)
        guard result.exitCode == 0 else {
            throw RemoteShellError.commandFailed(exitCode: result.exitCode, stderr: result.stderr)
        }
        guard let data = result.stdout.data(using: .utf8) else {
            throw RemoteShellError.commandFailed(exitCode: -1, stderr: "Failed to decode file content")
        }
        return data
    }

    /// Write data to a remote file via SSH (atomic: writes to temp then moves).
    public static func writeFile(data: Data, path: String, settings: ConnectionSettings) throws {
        let args = sshArgs(settings: settings)

        // Ensure the parent directory exists, write to temp file, then mv for atomicity
        let dir = (path as NSString).deletingLastPathComponent
        let tmpPath = "/tmp/clawapi-\(UUID().uuidString.prefix(8)).tmp"
        let command = "mkdir -p '\(dir)' && cat > '\(tmpPath)' && mv '\(tmpPath)' '\(path)'"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: args[0])
        process.arguments = Array(args.dropFirst()) + [command]

        let stdinPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardError = stderrPipe

        try process.run()

        // Write data to stdin and close
        stdinPipe.fileHandleForWriting.write(data)
        stdinPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw RemoteShellError.commandFailed(exitCode: process.terminationStatus, stderr: stderr)
        }

        logger.info("Wrote \(data.count) bytes to remote: \(path)")
    }

    /// Check if a file exists on the remote host.
    public static func fileExists(path: String, settings: ConnectionSettings) -> Bool {
        guard let result = try? execute(command: "test -f '\(path)' && echo YES", settings: settings) else {
            return false
        }
        return result.exitCode == 0 && result.stdout.contains("YES")
    }

    /// Check if a directory exists on the remote host.
    public static func directoryExists(path: String, settings: ConnectionSettings) -> Bool {
        guard let result = try? execute(command: "test -d '\(path)' && echo YES", settings: settings) else {
            return false
        }
        return result.exitCode == 0 && result.stdout.contains("YES")
    }

    /// Test the SSH connection. Returns nil on success, error message on failure.
    public static func testConnection(settings: ConnectionSettings) -> String? {
        do {
            let result = try execute(command: "echo OK", settings: settings)
            if result.exitCode == 0 && result.stdout.contains("OK") {
                logger.info("SSH connection test succeeded: \(settings.sshUser)@\(settings.sshHost)")
                return nil // Success
            }
            return "Unexpected response: \(result.stderr.isEmpty ? result.stdout : result.stderr)"
        } catch {
            logger.error("SSH connection test failed: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }
}
