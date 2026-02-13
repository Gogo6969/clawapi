import Foundation
import OSLog

private let osLogger = Logger(subsystem: "com.clawapi", category: "Audit")

public actor AuditLogger {
    private let logFileURL: URL
    private let encoder: JSONEncoder

    public init(directory: URL? = nil) {
        let base = directory ?? PolicyStore.defaultDirectory
        self.logFileURL = base.appendingPathComponent("audit.log")

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = .sortedKeys
        self.encoder = enc

        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    }

    // MARK: - Log entry

    public func log(_ entry: AuditEntry) {
        // Write JSONL line to file
        if let data = try? encoder.encode(entry),
           let line = String(data: data, encoding: .utf8)
        {
            appendLine(line)
        }

        // Mirror to unified logging
        switch entry.result {
        case .approved:
            osLogger.info("[\(entry.scope)] \(entry.result.rawValue): \(entry.reason) from \(entry.requestingHost)")
        case .denied:
            osLogger.warning("[\(entry.scope)] \(entry.result.rawValue): \(entry.reason) from \(entry.requestingHost) — \(entry.detail ?? "no detail")")
        case .error:
            osLogger.error("[\(entry.scope)] \(entry.result.rawValue): \(entry.reason) from \(entry.requestingHost) — \(entry.detail ?? "no detail")")
        }
    }

    // MARK: - Read log

    public func readEntries(limit: Int = 100) -> [AuditEntry] {
        guard let data = try? Data(contentsOf: logFileURL),
              let content = String(data: data, encoding: .utf8)
        else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .suffix(limit)

        return lines.compactMap { line in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(AuditEntry.self, from: lineData)
        }
    }

    // MARK: - Private

    private func appendLine(_ line: String) {
        let lineWithNewline = line + "\n"
        guard let data = lineWithNewline.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFileURL, options: .atomic)
        }
    }

    private func ensureDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
