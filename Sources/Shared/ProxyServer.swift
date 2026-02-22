import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "ProxyServer")

/// A lightweight HTTP proxy server that runs on localhost.
/// OpenClaw sends requests here — ClawAPI injects credentials and forwards to the real API.
/// OpenClaw never sees any credential.
public final class ProxyServer: Sendable {
    private let port: UInt16
    private let store: PolicyStore
    private let keychain: KeychainService
    private let auditLogger: AuditLogger

    // nonisolated(unsafe) because these are only mutated in start()/stop() which are called sequentially
    nonisolated(unsafe) private var serverSocket: Int32 = -1
    nonisolated(unsafe) private var acceptSource: DispatchSourceRead?
    nonisolated(unsafe) private var isRunning = false
    nonisolated(unsafe) private var mcpHandler: MCPHandler?

    private let socketQueue = DispatchQueue(label: "com.clawapi.proxy.socket", qos: .userInitiated)
    private let connectionQueue = DispatchQueue(label: "com.clawapi.proxy.connections", qos: .userInitiated, attributes: .concurrent)

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()

    private let decoder: JSONDecoder = {
        JSONDecoder()
    }()

    public init(
        port: UInt16 = 9090,
        store: PolicyStore,
        keychain: KeychainService = KeychainService(),
        auditLogger: AuditLogger = AuditLogger()
    ) {
        self.port = port
        self.store = store
        self.keychain = keychain
        self.auditLogger = auditLogger
    }

    // MARK: - Start / Stop

    public func start() throws {
        guard !isRunning else {
            logger.warning("Proxy server already running")
            return
        }

        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw ProxyServerError.socketCreationFailed
        }

        // Allow port reuse
        var reuseAddr: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        // Set non-blocking
        let flags = fcntl(serverSocket, F_GETFL)
        _ = fcntl(serverSocket, F_SETFL, flags | O_NONBLOCK)

        // Bind to localhost only
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverSocket, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            Darwin.close(serverSocket)
            throw ProxyServerError.bindFailed(port)
        }

        guard listen(serverSocket, 128) == 0 else {
            Darwin.close(serverSocket)
            throw ProxyServerError.listenFailed
        }

        isRunning = true
        mcpHandler = MCPHandler(server: self, store: store)

        // Use GCD dispatch source for non-blocking accept
        let source = DispatchSource.makeReadSource(fileDescriptor: serverSocket, queue: socketQueue)
        source.setEventHandler { [weak self] in
            self?.acceptConnections()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.serverSocket, fd >= 0 {
                Darwin.close(fd)
            }
        }
        acceptSource = source
        source.resume()

        logger.info("Proxy server listening on http://127.0.0.1:\(self.port)")
        print("🛡️  ClawAPI running on http://127.0.0.1:\(port)")
        print("   OpenClaw sends requests here — credentials are injected server-side.")
        print("   OpenClaw never sees your passwords or API keys.")
        print()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        acceptSource?.cancel()
        acceptSource = nil
        serverSocket = -1
        logger.info("Proxy server stopped")
        print("ClawAPI server stopped.")
    }

    // MARK: - Accept Connections (GCD)

    private func acceptConnections() {
        while true {
            let clientSocket = accept(serverSocket, nil, nil)
            guard clientSocket >= 0 else { return } // No more pending connections

            // Read the request synchronously on a GCD thread, then hand off to async
            connectionQueue.async { [self] in
                self.readAndDispatch(clientSocket)
            }
        }
    }

    // MARK: - Connection Handler

    /// Reads the HTTP request synchronously (on a GCD thread), then dispatches
    /// proxy processing via Task (async) which writes the response when done.
    private func readAndDispatch(_ socket: Int32) {
        // Read the full HTTP request (blocking read on GCD thread — fine)
        guard let rawRequest = readHTTPRequest(from: socket) else {
            sendErrorResponse(to: socket, status: 400, message: "Failed to read request")
            Darwin.close(socket)
            return
        }

        // Parse HTTP request line and headers
        guard let (httpMethod, httpPath, _, httpBody) = parseHTTPRequest(rawRequest) else {
            sendErrorResponse(to: socket, status: 400, message: "Malformed HTTP request")
            Darwin.close(socket)
            return
        }

        logger.info("Request: \(httpMethod) \(httpPath)")

        // Health check endpoint (fast path — no async needed)
        if httpPath == "/health" {
            let json = "{\"status\":\"ok\",\"port\":\(port)}"
            sendHTTPResponse(to: socket, status: 200, contentType: "application/json", body: json)
            Darwin.close(socket)
            return
        }

        // MCP endpoint — JSON-RPC over HTTP
        if httpPath == "/mcp" {
            if httpMethod == "OPTIONS" {
                // CORS preflight
                let headers = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: POST\r\nAccess-Control-Allow-Headers: Content-Type, Mcp-Session-Id, Mcp-Protocol-Version\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                if let data = headers.data(using: .utf8) {
                    data.withUnsafeBytes { ptr in
                        if let base = ptr.baseAddress { _ = send(socket, base, data.count, 0) }
                    }
                }
                Darwin.close(socket)
                return
            }

            guard httpMethod == "POST" else {
                sendErrorResponse(to: socket, status: 405, message: "MCP endpoint accepts POST only")
                Darwin.close(socket)
                return
            }

            let handler = self.mcpHandler ?? MCPHandler(server: self, store: store)
            Task { @Sendable in
                if let responseJSON = await handler.handleRequest(httpBody) {
                    self.sendHTTPResponse(to: socket, status: 200, contentType: "application/json", body: responseJSON)
                } else {
                    // Notification — HTTP 202 Accepted, no body
                    let noContent = "HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                    if let data = noContent.data(using: .utf8) {
                        data.withUnsafeBytes { ptr in
                            if let base = ptr.baseAddress { _ = send(socket, base, data.count, 0) }
                        }
                    }
                }
                Darwin.close(socket)
            }
            return
        }

        // Only accept POST /proxy
        guard httpMethod == "POST" && httpPath == "/proxy" else {
            sendErrorResponse(to: socket, status: 404, message: "Not found. Use POST /proxy or POST /mcp")
            Darwin.close(socket)
            return
        }

        // Parse the ProxyRequest JSON
        guard let bodyData = httpBody.data(using: .utf8),
              let proxyRequest = try? decoder.decode(ProxyRequest.self, from: bodyData) else {
            sendErrorResponse(to: socket, status: 400, message: "Invalid JSON body. Expected: {\"scope\":\"...\",\"method\":\"GET\",\"url\":\"https://...\"}")
            Darwin.close(socket)
            return
        }

        // Process async — the Task owns the socket and closes it when done
        Task { @Sendable [self] in
            let response = await self.processProxyRequest(proxyRequest)

            if let responseData = try? self.encoder.encode(response),
               let responseJSON = String(data: responseData, encoding: .utf8) {
                self.sendHTTPResponse(to: socket, status: 200, contentType: "application/json", body: responseJSON)
            } else {
                self.sendErrorResponse(to: socket, status: 500, message: "Failed to encode response")
            }
            Darwin.close(socket)
        }
    }

    // MARK: - Proxy Logic

    func processProxyRequest(_ request: ProxyRequest) async -> ProxyResponse {
        let reason = request.reason ?? "Proxy request"

        // 1. Look up policy
        let policy = await MainActor.run { store.policy(forScope: request.scope) }
        guard let policy else {
            let entry = AuditEntry(
                scope: request.scope,
                requestingHost: "proxy",
                reason: reason,
                result: .denied,
                detail: "No policy found for scope"
            )
            await auditLogger.log(entry)
            await MainActor.run { store.addAuditEntry(entry) }
            return ProxyResponse(statusCode: 403, error: "No policy found for scope '\(request.scope)'")
        }

        // 2. Check if provider is enabled
        guard policy.isEnabled else {
            let entry = AuditEntry(
                scope: request.scope,
                requestingHost: URL(string: request.url)?.host ?? "unknown",
                reason: reason,
                result: .denied,
                detail: "Provider is disabled"
            )
            await auditLogger.log(entry)
            await MainActor.run { store.addAuditEntry(entry) }
            return ProxyResponse(statusCode: 403, error: "Provider '\(request.scope)' is disabled. Enable it in ClawAPI to allow requests.")
        }

        // 3. Validate target URL domain against allowed domains
        if let urlHost = URL(string: request.url)?.host, !policy.allowedDomains.isEmpty {
            let domainAllowed = policy.allowedDomains.contains { allowed in
                urlHost == allowed || urlHost.hasSuffix("." + allowed)
            }
            if !domainAllowed {
                let entry = AuditEntry(
                    scope: request.scope,
                    requestingHost: urlHost,
                    reason: reason,
                    result: .denied,
                    detail: "Target domain '\(urlHost)' not in allowed domains: \(policy.allowedDomains.joined(separator: ", "))"
                )
                await auditLogger.log(entry)
                await MainActor.run { store.addAuditEntry(entry) }
                return ProxyResponse(statusCode: 403, error: "Domain '\(urlHost)' is not allowed for scope '\(request.scope)'")
            }
        }

        // 4. Check approval mode
        guard policy.approvalMode == .auto else {
            let entry = AuditEntry(
                scope: request.scope,
                requestingHost: URL(string: request.url)?.host ?? "unknown",
                reason: reason,
                result: .denied,
                detail: "Proxy only supports auto-approved scopes (current: \(policy.approvalMode.rawValue))"
            )
            await auditLogger.log(entry)
            await MainActor.run { store.addAuditEntry(entry) }
            return ProxyResponse(statusCode: 403, error: "Scope '\(request.scope)' requires manual approval. Direct HTTP mode only works with auto-approved connections.")
        }

        // 5. Retrieve credential from Keychain
        var secret: String?
        if policy.hasSecret {
            secret = try? keychain.retrieveString(forScope: request.scope)
            if secret == nil {
                let entry = AuditEntry(
                    scope: request.scope,
                    requestingHost: URL(string: request.url)?.host ?? "unknown",
                    reason: reason,
                    result: .error,
                    detail: "Failed to retrieve credential from Keychain"
                )
                await auditLogger.log(entry)
                await MainActor.run { store.addAuditEntry(entry) }
                return ProxyResponse(statusCode: 500, error: "Failed to retrieve credential for scope '\(request.scope)'")
            }
        }

        // 6. Build the outgoing request WITH credentials injected
        guard let targetURL = URL(string: request.url) else {
            return ProxyResponse(statusCode: 400, error: "Invalid target URL: \(request.url)")
        }

        var urlRequest = URLRequest(url: targetURL)
        urlRequest.httpMethod = request.method.uppercased()
        urlRequest.timeoutInterval = 30

        // Set any extra headers from the proxy request
        if let extraHeaders = request.headers {
            for (key, value) in extraHeaders {
                // Don't let the caller override auth headers
                let lowerKey = key.lowercased()
                if lowerKey == "authorization" || lowerKey == "cookie" {
                    continue  // Skip — we inject these ourselves
                }
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Inject the credential based on type
        if let secret {
            switch policy.credentialType {
            case .bearerToken:
                urlRequest.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
            case .basicAuth:
                let encoded = Data(secret.utf8).base64EncodedString()
                urlRequest.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
            case .cookie:
                urlRequest.setValue(secret, forHTTPHeaderField: "Cookie")
            case .customHeader:
                let headerName = policy.customHeaderName ?? "X-API-Key"
                urlRequest.setValue(secret, forHTTPHeaderField: headerName)
            }
        }

        // Set body if present
        if let body = request.body {
            urlRequest.httpBody = body.data(using: .utf8)
            // Default content type if not set
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        // 7. Forward the request
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                return ProxyResponse(statusCode: 502, error: "Invalid response from target")
            }

            // Build response headers (filter out sensitive ones)
            var responseHeaders: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                let keyStr = "\(key)"
                let lowerKey = keyStr.lowercased()
                // Don't forward set-cookie or auth challenge headers
                if lowerKey != "set-cookie" && lowerKey != "www-authenticate" {
                    responseHeaders[keyStr] = "\(value)"
                }
            }

            let responseBody = String(data: data, encoding: .utf8)

            // Log success
            let entry = AuditEntry(
                scope: request.scope,
                requestingHost: targetURL.host ?? "unknown",
                reason: reason,
                result: .approved,
                detail: "Proxied \(request.method.uppercased()) \(request.url) → \(httpResponse.statusCode)"
            )
            await auditLogger.log(entry)
            await MainActor.run { store.addAuditEntry(entry) }

            // Post health notification so the app can update status dots in real-time
            let health = ProviderHealthCheck.classifyStatusCode(httpResponse.statusCode, body: responseBody)
            if health != .healthy {
                DistributedNotificationCenter.default().postNotificationName(
                    NSNotification.Name(providerHealthNotification.rawValue),
                    object: nil,
                    userInfo: [
                        "scope": request.scope,
                        "statusCode": httpResponse.statusCode,
                        "detail": "\(health)",
                    ],
                    deliverImmediately: true
                )
            }

            logger.info("Proxied \(request.method) \(request.url) → \(httpResponse.statusCode) for scope '\(request.scope)'")

            return ProxyResponse(
                statusCode: httpResponse.statusCode,
                headers: responseHeaders,
                body: responseBody
            )

        } catch {
            let entry = AuditEntry(
                scope: request.scope,
                requestingHost: targetURL.host ?? "unknown",
                reason: reason,
                result: .error,
                detail: "Request failed: \(error.localizedDescription)"
            )
            await auditLogger.log(entry)
            await MainActor.run { store.addAuditEntry(entry) }

            return ProxyResponse(statusCode: 502, error: "Request failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Raw HTTP Parsing

    private func readHTTPRequest(from socket: Int32) -> String? {
        // Set socket to blocking for reads (we're on a dedicated thread)
        let flags = fcntl(socket, F_GETFL)
        _ = fcntl(socket, F_SETFL, flags & ~O_NONBLOCK)

        var buffer = [UInt8](repeating: 0, count: 131072)
        var accumulated = Data()
        var contentLength: Int? = nil
        var bodyStartOffset: Int? = nil

        // Read until we have complete headers + body
        while true {
            let bytesRead = recv(socket, &buffer, buffer.count, 0)
            if bytesRead <= 0 { break }
            accumulated.append(contentsOf: buffer[0..<bytesRead])

            // Find header/body boundary if not yet found
            if bodyStartOffset == nil {
                // Search for \r\n\r\n in the accumulated bytes
                for i in 0..<(accumulated.count - 3) {
                    if accumulated[i] == 0x0D && accumulated[i+1] == 0x0A &&
                       accumulated[i+2] == 0x0D && accumulated[i+3] == 0x0A {
                        bodyStartOffset = i + 4
                        // Parse Content-Length from header bytes
                        if let headerStr = String(data: accumulated[0..<i], encoding: .utf8) {
                            // Match "content-length:" with optional space
                            if let clRange = headerStr.range(of: "content-length:", options: .caseInsensitive) {
                                var afterCL = headerStr[clRange.upperBound...]
                                // Skip optional whitespace
                                while afterCL.first == " " || afterCL.first == "\t" {
                                    afterCL = afterCL.dropFirst()
                                }
                                if let nlRange = afterCL.range(of: "\r\n") {
                                    contentLength = Int(String(afterCL[afterCL.startIndex..<nlRange.lowerBound]).trimmingCharacters(in: .whitespaces))
                                } else {
                                    // Last header line might not have \r\n
                                    contentLength = Int(String(afterCL).trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                            }
                        }
                        break
                    }
                }
            }

            // Check if we have enough data
            if let bodyStart = bodyStartOffset {
                let bodyLen = accumulated.count - bodyStart
                if let cl = contentLength {
                    if bodyLen >= cl {
                        return String(data: accumulated, encoding: .utf8)
                    }
                } else {
                    // No Content-Length header — return what we have
                    return String(data: accumulated, encoding: .utf8)
                }
            }

            // Safety: don't read forever
            if accumulated.count > 2_097_152 { break }
        }

        return accumulated.isEmpty ? nil : String(data: accumulated, encoding: .utf8)
    }

    private func parseHTTPRequest(_ raw: String) -> (method: String, path: String, headers: [String: String], body: String)? {
        guard let headerEnd = raw.range(of: "\r\n\r\n") else { return nil }

        let headerSection = String(raw[raw.startIndex..<headerEnd.lowerBound])
        let body = String(raw[headerEnd.upperBound...])

        let lines = headerSection.split(separator: "\r\n", maxSplits: 1000, omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return nil }

        // Parse request line: "POST /proxy HTTP/1.1"
        let requestLineParts = lines[0].split(separator: " ")
        guard requestLineParts.count >= 2 else { return nil }

        let method = String(requestLineParts[0])
        let path = String(requestLineParts[1])

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colonRange = line.range(of: ": ") {
                let key = String(line[line.startIndex..<colonRange.lowerBound])
                let value = String(line[colonRange.upperBound...])
                headers[key] = value
            }
        }

        return (method, path, headers, body)
    }

    // MARK: - HTTP Response Writing

    private func sendHTTPResponse(to socket: Int32, status: Int, contentType: String, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 202: statusText = "Accepted"
        case 204: statusText = "No Content"
        case 400: statusText = "Bad Request"
        case 403: statusText = "Forbidden"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        case 500: statusText = "Internal Server Error"
        case 502: statusText = "Bad Gateway"
        default: statusText = "Unknown"
        }

        let bodyData = body.data(using: .utf8) ?? Data()
        let response = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: \(contentType)\r\nContent-Length: \(bodyData.count)\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n"

        var responseData = response.data(using: .utf8) ?? Data()
        responseData.append(bodyData)

        responseData.withUnsafeBytes { ptr in
            if let baseAddress = ptr.baseAddress {
                _ = send(socket, baseAddress, responseData.count, 0)
            }
        }
    }

    private func sendErrorResponse(to socket: Int32, status: Int, message: String) {
        let json = "{\"error\":\"\(message)\",\"statusCode\":\(status)}"
        sendHTTPResponse(to: socket, status: status, contentType: "application/json", body: json)
    }

}

// MARK: - Errors

public enum ProxyServerError: Error, LocalizedError {
    case socketCreationFailed
    case bindFailed(UInt16)
    case listenFailed

    public var errorDescription: String? {
        switch self {
        case .socketCreationFailed: "Failed to create socket"
        case .bindFailed(let port): "Failed to bind to port \(port). Is another process using it?"
        case .listenFailed: "Failed to listen on socket"
        }
    }
}
