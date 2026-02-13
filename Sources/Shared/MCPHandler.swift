import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "MCPHandler")

/// Handles MCP (Model Context Protocol) JSON-RPC requests.
/// Stateless struct — safe to pass across concurrency boundaries.
public struct MCPHandler: Sendable {
    private let server: ProxyServer
    private let store: PolicyStore

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()

    private let decoder: JSONDecoder = {
        JSONDecoder()
    }()

    public init(server: ProxyServer, store: PolicyStore) {
        self.server = server
        self.store = store
    }

    // MARK: - Public Entry Point

    /// Handle a raw JSON-RPC string. Returns the JSON-RPC response string,
    /// or nil for notifications (which require no response).
    public func handleRequest(_ json: String) async -> String? {
        guard let data = json.data(using: .utf8),
              let request = try? decoder.decode(JSONRPCRequest.self, from: data) else {
            // Parse error — still need to respond (use null id)
            return encode(JSONRPCResponse(id: nil, error: .parseError()))
        }

        // Notifications have no id — no response expected
        let isNotification = request.id == nil

        switch request.method {
        case "initialize":
            return encode(handleInitialize(id: request.id))

        case "notifications/initialized", "notifications/cancelled":
            // Notifications — no response
            return nil

        case "ping":
            return encode(handlePing(id: request.id))

        case "tools/list":
            return encode(handleToolsList(id: request.id))

        case "tools/call":
            let response = await handleToolsCall(id: request.id, params: request.params)
            return encode(response)

        default:
            if isNotification { return nil }
            return encode(JSONRPCResponse(id: request.id, error: .methodNotFound(request.method)))
        }
    }

    // MARK: - Method Handlers

    private func handleInitialize(id: JSONRPCId?) -> JSONRPCResponse {
        let result: JSONValue = .object([
            "protocolVersion": .string("2024-11-05"),
            "capabilities": .object([
                "tools": .object([:])
            ]),
            "serverInfo": .object([
                "name": .string("clawapi"),
                "version": .string(AppVersion.current),
                "description": .string("ClawAPI — Secure API tool for OpenClaw. Injects API keys and tokens into requests server-side.")
            ])
        ])
        logger.info("MCP initialized")
        return JSONRPCResponse(id: id, result: result)
    }

    private func handlePing(id: JSONRPCId?) -> JSONRPCResponse {
        JSONRPCResponse(id: id, result: .object([:]))
    }

    private func handleToolsList(id: JSONRPCId?) -> JSONRPCResponse {
        let tools: JSONValue = .object([
            "tools": .array([
                // 1. clawapi_proxy
                .object([
                    "name": .string("clawapi_proxy"),
                    "description": .string("Forward an HTTP request through ClawAPI. ClawAPI injects the stored credential (API key, token, etc.) for the given scope. You never see the credential — only the API response."),
                    "inputSchema": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "scope": .object([
                                "type": .string("string"),
                                "description": .string("Scope identifier matching a configured connection (e.g. 'openai', 'github:read')")
                            ]),
                            "method": .object([
                                "type": .string("string"),
                                "description": .string("HTTP method: GET, POST, PUT, DELETE, PATCH"),
                                "default": .string("GET")
                            ]),
                            "url": .object([
                                "type": .string("string"),
                                "description": .string("Full target URL (e.g. 'https://api.openai.com/v1/models')")
                            ]),
                            "headers": .object([
                                "type": .string("object"),
                                "description": .string("Optional extra HTTP headers. Auth headers are injected by ClawAPI — do not include them."),
                                "additionalProperties": .object(["type": .string("string")])
                            ]),
                            "body": .object([
                                "type": .string("string"),
                                "description": .string("Optional request body (for POST/PUT/PATCH)")
                            ]),
                            "reason": .object([
                                "type": .string("string"),
                                "description": .string("Short description of why this request is needed (for audit logging)")
                            ])
                        ]),
                        "required": .array([.string("scope"), .string("url")])
                    ])
                ]),
                // 2. clawapi_list_scopes
                .object([
                    "name": .string("clawapi_list_scopes"),
                    "description": .string("List all configured credential scopes/connections in ClawAPI, including service names, approval modes, allowed domains, and task-type tags (what each provider is best for). Use this to discover which APIs you can access and pick the best provider for your task."),
                    "inputSchema": .object([
                        "type": .string("object"),
                        "properties": .object([:])
                    ])
                ]),
                // 3. clawapi_health
                .object([
                    "name": .string("clawapi_health"),
                    "description": .string("Check ClawAPI server health status."),
                    "inputSchema": .object([
                        "type": .string("object"),
                        "properties": .object([:])
                    ])
                ])
            ])
        ])
        return JSONRPCResponse(id: id, result: tools)
    }

    private func handleToolsCall(id: JSONRPCId?, params: JSONValue?) async -> JSONRPCResponse {
        guard let params = params?.objectValue,
              let name = params["name"]?.stringValue else {
            return JSONRPCResponse(id: id, error: .invalidParams("Missing 'name' in tools/call params"))
        }

        let arguments = params["arguments"]?.objectValue ?? [:]

        switch name {
        case "clawapi_proxy":
            return await callProxy(id: id, arguments: arguments)
        case "clawapi_list_scopes":
            return await callListScopes(id: id)
        case "clawapi_health":
            return callHealth(id: id)
        default:
            return JSONRPCResponse(id: id, result: .toolResult(
                text: "Unknown tool: '\(name)'. Available tools: clawapi_proxy, clawapi_list_scopes, clawapi_health",
                isError: true
            ))
        }
    }

    // MARK: - Tool Implementations

    private func callProxy(id: JSONRPCId?, arguments: [String: JSONValue]) async -> JSONRPCResponse {
        guard let scope = arguments["scope"]?.stringValue else {
            return JSONRPCResponse(id: id, result: .toolResult(text: "Missing required argument: 'scope'", isError: true))
        }
        guard let url = arguments["url"]?.stringValue else {
            return JSONRPCResponse(id: id, result: .toolResult(text: "Missing required argument: 'url'", isError: true))
        }

        let method = arguments["method"]?.stringValue ?? "GET"
        let body = arguments["body"]?.stringValue
        let reason = arguments["reason"]?.stringValue

        // Extract headers from arguments
        var headers: [String: String]?
        if let headersObj = arguments["headers"]?.objectValue {
            headers = [:]
            for (key, value) in headersObj {
                if let str = value.stringValue {
                    headers?[key] = str
                }
            }
        }

        let proxyRequest = ProxyRequest(
            scope: scope,
            method: method,
            url: url,
            headers: headers,
            body: body,
            reason: reason ?? "MCP tool call"
        )

        let response = await server.processProxyRequest(proxyRequest)

        // Format the result as a readable text block
        var resultText = "HTTP \(response.statusCode)"
        if let error = response.error {
            resultText += "\nError: \(error)"
        }
        if let responseBody = response.body {
            resultText += "\n\n\(responseBody)"
        }

        let isError = response.statusCode >= 400
        logger.info("MCP proxy call: \(method) \(url) → \(response.statusCode)")
        return JSONRPCResponse(id: id, result: .toolResult(text: resultText, isError: isError))
    }

    private func callListScopes(id: JSONRPCId?) async -> JSONRPCResponse {
        let policies = await MainActor.run { store.policies }

        if policies.isEmpty {
            return JSONRPCResponse(id: id, result: .toolResult(text: "No scopes configured. Add connections in the ClawAPI app."))
        }

        // Sort by priority (1 = highest/MAIN)
        let sorted = policies.sorted { $0.priority < $1.priority }

        var lines: [String] = ["Available scopes (by priority):\n"]
        for (index, p) in sorted.enumerated() {
            let rank = index == 0 ? "#1 MAIN" : "#\(index + 1)"
            let domains = p.allowedDomains.isEmpty ? "(all domains)" : p.allowedDomains.joined(separator: ", ")
            lines.append("  \(rank)  \(p.scope) (\(p.serviceName))")
            lines.append("    Mode: \(p.approvalMode.rawValue) | Type: \(p.credentialType.rawValue) | Domains: \(domains)")
            lines.append("    Has credential: \(p.hasSecret ? "yes" : "no") | Enabled: \(p.isEnabled ? "yes" : "no")")
            if !p.preferredFor.isEmpty {
                lines.append("    Best for: \(p.preferredFor.joined(separator: ", "))")
            }
            lines.append("")
        }
        lines.append("Total: \(policies.count) scope(s)")
        lines.append("Priority order: #1 is the MAIN provider. Reorder in the ClawAPI app by dragging rows.")

        return JSONRPCResponse(id: id, result: .toolResult(text: lines.joined(separator: "\n")))
    }

    private func callHealth(id: JSONRPCId?) -> JSONRPCResponse {
        JSONRPCResponse(id: id, result: .toolResult(text: "ClawAPI is running. Status: OK"))
    }

    // MARK: - Helpers

    private func encode(_ response: JSONRPCResponse) -> String {
        guard let data = try? encoder.encode(response),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32603,\"message\":\"Failed to encode response\"}}"
        }
        return json
    }
}
