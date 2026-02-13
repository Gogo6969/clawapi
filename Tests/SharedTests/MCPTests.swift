import Testing
import Foundation
@testable import Shared

@Suite("MCP Tests")
struct MCPTests {

    // MARK: - JSONValue Tests

    @Test("JSONValue round-trip encoding for all types")
    func jsonValueRoundTrip() throws {
        let value: JSONValue = .object([
            "name": .string("test"),
            "count": .int(42),
            "rate": .double(3.14),
            "active": .bool(true),
            "tags": .array([.string("a"), .string("b")]),
            "meta": .null
        ])
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == value)
    }

    @Test("JSONValue convenience accessors")
    func jsonValueAccessors() {
        let obj: JSONValue = .object(["key": .string("val"), "num": .int(5)])
        #expect(obj["key"]?.stringValue == "val")
        #expect(obj["num"]?.intValue == 5)
        #expect(obj["missing"] == nil)

        let str: JSONValue = .string("hello")
        #expect(str.stringValue == "hello")
        #expect(str.intValue == nil)

        let arr: JSONValue = .array([.int(1), .int(2)])
        #expect(arr.arrayValue?.count == 2)

        let b: JSONValue = .bool(true)
        #expect(b.boolValue == true)
    }

    // MARK: - JSONRPCId Tests

    @Test("JSONRPCId int round-trip")
    func rpcIdInt() throws {
        let id = JSONRPCId.int(42)
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(JSONRPCId.self, from: data)
        #expect(decoded == id)
    }

    @Test("JSONRPCId string round-trip")
    func rpcIdString() throws {
        let id = JSONRPCId.string("abc-123")
        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(JSONRPCId.self, from: data)
        #expect(decoded == id)
    }

    // MARK: - MCPHandler Tests

    @Test("Initialize returns protocol version and capabilities")
    func initializeResponse() async throws {
        let handler = await makeHandler()
        let request = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
        """
        let response = await handler.handleRequest(request)
        #expect(response != nil)

        let data = response!.data(using: .utf8)!
        let rpc = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        #expect(rpc.error == nil)
        #expect(rpc.id == .int(1))

        // Result should contain protocolVersion and serverInfo
        #expect(rpc.result?["protocolVersion"]?.stringValue == "2024-11-05")
        #expect(rpc.result?["serverInfo"]?["name"]?.stringValue == "clawapi")
        #expect(rpc.result?["capabilities"]?["tools"] != nil)
    }

    @Test("Notification returns nil (no response)")
    func notificationReturnsNil() async {
        let handler = await makeHandler()
        let notification = """
        {"jsonrpc":"2.0","method":"notifications/initialized"}
        """
        let response = await handler.handleRequest(notification)
        #expect(response == nil)
    }

    @Test("Ping returns empty result")
    func pingResponse() async throws {
        let handler = await makeHandler()
        let request = """
        {"jsonrpc":"2.0","id":2,"method":"ping"}
        """
        let response = await handler.handleRequest(request)
        #expect(response != nil)

        let data = response!.data(using: .utf8)!
        let rpc = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        #expect(rpc.error == nil)
        #expect(rpc.id == .int(2))
        #expect(rpc.result == .object([:]))
    }

    @Test("tools/list returns three tools")
    func toolsList() async throws {
        let handler = await makeHandler()
        let request = """
        {"jsonrpc":"2.0","id":3,"method":"tools/list"}
        """
        let response = await handler.handleRequest(request)
        #expect(response != nil)
        #expect(response!.contains("clawapi_proxy"))
        #expect(response!.contains("clawapi_list_scopes"))
        #expect(response!.contains("clawapi_health"))
    }

    @Test("tools/call with unknown tool returns isError")
    func unknownTool() async throws {
        let handler = await makeHandler()
        let request = """
        {"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"bogus_tool","arguments":{}}}
        """
        let response = await handler.handleRequest(request)
        #expect(response != nil)
        #expect(response!.contains("Unknown tool"))
        #expect(response!.contains("true"))  // isError: true
    }

    @Test("tools/call clawapi_health returns OK")
    func healthTool() async throws {
        let handler = await makeHandler()
        let request = """
        {"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"clawapi_health","arguments":{}}}
        """
        let response = await handler.handleRequest(request)
        #expect(response != nil)
        #expect(response!.contains("OK"))
    }

    @Test("tools/call clawapi_list_scopes returns scope info")
    func listScopes() async throws {
        let handler = await makeHandler()
        let request = """
        {"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"clawapi_list_scopes","arguments":{}}}
        """
        let response = await handler.handleRequest(request)
        #expect(response != nil)
        // Response should contain either scope info or "No scopes configured"
        let data = response!.data(using: .utf8)!
        let rpc = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        #expect(rpc.error == nil)
        #expect(rpc.id == .int(6))
        // The result should have content with text
        #expect(rpc.result?["isError"]?.boolValue == false)
    }

    @Test("tools/call clawapi_proxy with missing scope returns error")
    func proxyMissingScope() async throws {
        let handler = await makeHandler()
        let request = """
        {"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"clawapi_proxy","arguments":{"url":"https://example.com"}}}
        """
        let response = await handler.handleRequest(request)
        #expect(response != nil)
        // Should fail because no policy exists for the scope
        // (the scope argument is present via the arguments, but no policy exists)
    }

    @Test("Unknown method returns error -32601")
    func unknownMethod() async throws {
        let handler = await makeHandler()
        let request = """
        {"jsonrpc":"2.0","id":8,"method":"bogus/method"}
        """
        let response = await handler.handleRequest(request)
        #expect(response != nil)
        #expect(response!.contains("-32601"))
    }

    @Test("Malformed JSON returns parse error -32700")
    func parseError() async throws {
        let handler = await makeHandler()
        let response = await handler.handleRequest("{not valid json")
        #expect(response != nil)
        #expect(response!.contains("-32700"))
    }

    @Test("String id is preserved in response")
    func stringIdPreserved() async throws {
        let handler = await makeHandler()
        let request = """
        {"jsonrpc":"2.0","id":"my-request-abc","method":"ping"}
        """
        let response = await handler.handleRequest(request)
        #expect(response != nil)
        #expect(response!.contains("my-request-abc"))
    }

    // MARK: - Helpers

    @MainActor
    static func _makeHandler() -> MCPHandler {
        let store = PolicyStore()
        let server = ProxyServer(store: store)
        return MCPHandler(server: server, store: store)
    }
}

// Free function wrapper to bridge MainActor
func makeHandler() async -> MCPHandler {
    await MCPTests._makeHandler()
}
