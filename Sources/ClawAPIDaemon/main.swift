import Foundation
import Shared
import OSLog

private let logger = Logger(subsystem: "com.clawapi.daemon", category: "main")

// MARK: - Daemon Entry Point

@MainActor
func run() async {
    let args = CommandLine.arguments

    guard args.count >= 2 else {
        printUsage()
        exit(1)
    }

    let command = args[1]

    switch command {
    case "proxy":
        let portString = parseFlag("--port", from: args) ?? "9090"
        let port = UInt16(portString) ?? 9090
        await handleProxy(port: port)

    case "issue":
        guard args.count >= 3 else {
            fputs("Error: 'issue' requires a scope argument\n", stderr)
            fputs("Usage: clawapi-daemon issue <scope> [--reason <reason>] [--host <host>]\n", stderr)
            exit(1)
        }
        let scope = args[2]
        let reason = parseFlag("--reason", from: args) ?? "CLI request"
        let host = parseFlag("--host", from: args) ?? "localhost"

        await handleIssue(scope: scope, reason: reason, host: host)

    case "list":
        await handleList()

    case "pending":
        await handlePending()

    case "mcp":
        await handleMCP()

    case "help", "--help", "-h":
        printUsage()

    default:
        fputs("Unknown command: \(command)\n", stderr)
        printUsage()
        exit(1)
    }
}

// MARK: - Proxy Command

@MainActor
func handleProxy(port: UInt16) async {
    let store = PolicyStore()
    let auditLogger = AuditLogger()
    let keychain = KeychainService()

    let server = ProxyServer(
        port: port,
        store: store,
        keychain: keychain,
        auditLogger: auditLogger
    )

    print("ClawAPI Server")
    print("=====================")
    print()
    print("Starting ClawAPI on port \(port)...")
    print()

    // Handle SIGINT/SIGTERM gracefully
    let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT)
    let sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM)
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)

    sigintSource.setEventHandler {
        print("\nShutting down...")
        exit(0)
    }
    sigtermSource.setEventHandler {
        exit(0)
    }
    sigintSource.resume()
    sigtermSource.resume()

    do {
        try server.start()
    } catch {
        fputs("Failed to start proxy: \(error.localizedDescription)\n", stderr)
        exit(1)
    }

    // Keep the process alive — GCD handles connections
    dispatchMain()
}

// MARK: - MCP Command (stdio transport)

@MainActor
func handleMCP() async {
    let store = PolicyStore()
    let auditLogger = AuditLogger()
    let keychain = KeychainService()

    // Create a ProxyServer without starting it — we only use processProxyRequest()
    let server = ProxyServer(store: store, keychain: keychain, auditLogger: auditLogger)
    let handler = MCPHandler(server: server, store: store)

    // All diagnostic output must go to stderr — stdout is reserved for JSON-RPC
    fputs("ClawAPI MCP server (stdio transport) ready\n", stderr)

    // Read newline-delimited JSON-RPC from stdin, write responses to stdout
    while let line = readLine(strippingNewline: true) {
        guard !line.isEmpty else { continue }

        if let response = await handler.handleRequest(line) {
            print(response)
            fflush(stdout)
        }
        // Notifications return nil — no output
    }

    // stdin closed — parent process terminated us
    fputs("ClawAPI MCP server stdin closed, exiting\n", stderr)
}

// MARK: - Issue Command

@MainActor
func handleIssue(scope: String, reason: String, host: String) async {
    let store = PolicyStore()
    let auditLogger = AuditLogger()

    print("Issuing credential for scope: \(scope)")
    print("  Reason: \(reason)")
    print("  Host: \(host)")
    print()

    guard let policy = store.policy(forScope: scope) else {
        let entry = AuditEntry(
            scope: scope,
            requestingHost: host,
            reason: reason,
            result: .denied,
            detail: "No policy found for scope"
        )
        await auditLogger.log(entry)
        store.addAuditEntry(entry)
        print("DENIED: No policy found for scope '\(scope)'")
        logger.warning("Denied request for unknown scope: \(scope)")
        exit(1)
    }

    // Validate host against allowed domains
    if !policy.allowedDomains.isEmpty && !policy.allowedDomains.contains(host) {
        let entry = AuditEntry(
            scope: scope,
            requestingHost: host,
            reason: reason,
            result: .denied,
            detail: "Host '\(host)' not in allowed domains: \(policy.allowedDomains.joined(separator: ", "))"
        )
        await auditLogger.log(entry)
        store.addAuditEntry(entry)
        print("DENIED: Host '\(host)' is not in the allowed domain list")
        logger.warning("Denied request from unauthorized host: \(host) for scope: \(scope)")
        exit(1)
    }

    switch policy.approvalMode {
    case .auto:
        // Auto-approve: retrieve secret and return
        let keychain = KeychainService()
        if policy.hasSecret, let secret = try? keychain.retrieveString(forScope: scope) {
            let entry = AuditEntry(
                scope: scope,
                requestingHost: host,
                reason: reason,
                result: .approved,
                detail: "Auto-approved with secret"
            )
            await auditLogger.log(entry)
            store.addAuditEntry(entry)
            print("APPROVED (auto)")
            print("Secret: \(secret.prefix(4))****")
            logger.info("Auto-approved scope: \(scope)")
        } else {
            let entry = AuditEntry(
                scope: scope,
                requestingHost: host,
                reason: reason,
                result: .approved,
                detail: "Auto-approved (no secret stored)"
            )
            await auditLogger.log(entry)
            store.addAuditEntry(entry)
            print("APPROVED (auto, no secret)")
            logger.info("Auto-approved scope without secret: \(scope)")
        }

    case .manual:
        print("PENDING: This scope requires manual approval.")
        print("  Open the ClawAPI app to approve or deny this request.")
        let request = PendingRequest(
            scope: scope,
            requestingHost: host,
            reason: reason
        )
        store.addPendingRequest(request)
        logger.info("Manual approval required for scope: \(scope)")

        // Post distributed notification
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.clawapi.pendingRequest"),
            object: nil,
            userInfo: ["scope": scope, "host": host],
            deliverImmediately: true
        )

    case .pending:
        print("QUEUED: This scope is in pending mode.")
        print("  The request has been queued for review.")
        let request = PendingRequest(
            scope: scope,
            requestingHost: host,
            reason: reason
        )
        store.addPendingRequest(request)
        logger.info("Queued pending request for scope: \(scope)")

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("com.clawapi.pendingRequest"),
            object: nil,
            userInfo: ["scope": scope, "host": host],
            deliverImmediately: true
        )
    }
}

@MainActor
func handleList() async {
    let store = PolicyStore()
    let policies = store.policies

    if policies.isEmpty {
        print("No providers configured.")
        return
    }

    print("Configured providers:")
    print(String(repeating: "-", count: 70))
    for policy in policies {
        let mode = policy.approvalMode.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0)
        let secret = policy.hasSecret ? "yes" : "no "
        let cred = policy.credentialType.rawValue
        print("  [\(mode)] \(policy.scope.padding(toLength: 25, withPad: " ", startingAt: 0)) secret=\(secret)  type=\(cred)  domains=\(policy.allowedDomains.joined(separator: ","))")
    }
    print(String(repeating: "-", count: 70))
    print("Total: \(policies.count) provider(s)")
}

@MainActor
func handlePending() async {
    let store = PolicyStore()
    let pending = store.pendingRequests

    if pending.isEmpty {
        print("No pending requests.")
        return
    }

    print("Pending requests:")
    print(String(repeating: "-", count: 70))
    for request in pending {
        print("  \(request.scope)")
        print("    Host:   \(request.requestingHost)")
        print("    Reason: \(request.reason)")
        print("    At:     \(request.requestedAt)")
        print()
    }
    print("Total: \(pending.count) pending request(s)")
}

// MARK: - Helpers

func parseFlag(_ flag: String, from args: [String]) -> String? {
    guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
        return nil
    }
    return args[index + 1]
}

func printUsage() {
    print("""
    ClawAPI Daemon - Credential Tool & Broker

    Usage:
      clawapi-daemon <command> [options]

    Commands:
      proxy              Start the HTTP server (default port: 9090)
        --port <port>    Port to listen on (default: 9090)

      mcp                Start MCP server on stdio (JSON-RPC over stdin/stdout)
                         Used by MCPorter to connect OpenClaw to ClawAPI

      issue <scope>      Request a credential for the given scope
        --reason         Reason for the request
        --host           Requesting host

      list               List all configured providers
      pending            Show pending approval requests
      help               Show this help message

    HTTP Usage:
      OpenClaw sends POST requests to http://127.0.0.1:9090/proxy with JSON:
        {
          "scope": "openai",
          "method": "POST",
          "url": "https://api.openai.com/v1/chat/completions",
          "headers": {"Content-Type": "application/json"},
          "body": "{\\"model\\": \\"gpt-4\\", ...}",
          "reason": "Chat completion"
        }

      ClawAPI injects the API key and forwards the request.
      OpenClaw receives only the API response — never the credential.

    MCP Usage:
      The ClawAPI app automatically registers with MCPorter on launch.
      OpenClaw discovers ClawAPI and launches it on demand — no setup needed.

      Manual registration (if not using the app):
        mcporter config add clawapi --command clawapi-daemon --arg mcp --scope home

      The server also accepts MCP requests at POST /mcp (JSON-RPC 2.0).

    Examples:
      clawapi-daemon proxy
      clawapi-daemon proxy --port 8080
      clawapi-daemon mcp
      clawapi-daemon issue github --reason "Deploy" --host api.github.com
      clawapi-daemon list
    """)
}

// MARK: - Run

await run()
