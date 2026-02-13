import Testing
import Foundation
@testable import Shared

@Suite("AuditLogger Tests")
struct AuditLoggerTests {

    private func makeTempDir() -> URL {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }

    @Test("Logs entries and reads them back")
    func logAndRead() async {
        let dir = makeTempDir()
        let logger = AuditLogger(directory: dir)

        let entry1 = AuditEntry(scope: "test:a", requestingHost: "a.com", reason: "test 1", result: .approved)
        let entry2 = AuditEntry(scope: "test:b", requestingHost: "b.com", reason: "test 2", result: .denied, detail: "blocked")

        await logger.log(entry1)
        await logger.log(entry2)

        let entries = await logger.readEntries()
        #expect(entries.count == 2)
        #expect(entries[0].scope == "test:a")
        #expect(entries[1].scope == "test:b")
        #expect(entries[1].detail == "blocked")
    }

    @Test("Read respects limit")
    func readLimit() async {
        let dir = makeTempDir()
        let logger = AuditLogger(directory: dir)

        for i in 0..<10 {
            let entry = AuditEntry(scope: "test:\(i)", requestingHost: "host", reason: "r\(i)", result: .approved)
            await logger.log(entry)
        }

        let limited = await logger.readEntries(limit: 3)
        #expect(limited.count == 3)
    }

    @Test("Empty log returns empty array")
    func emptyLog() async {
        let dir = makeTempDir()
        let logger = AuditLogger(directory: dir)
        let entries = await logger.readEntries()
        #expect(entries.isEmpty)
    }
}
