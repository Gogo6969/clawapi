import Foundation
import Shared
import OSLog

// clawapi-cli — lightweight CLI for testing the credential broker

@MainActor
func run() async {
    let args = CommandLine.arguments

    guard args.count >= 2 else {
        printUsage()
        exit(1)
    }

    let command = args[1]

    switch command {
    case "issue":
        guard args.count >= 3 else {
            fputs("Error: scope required. Usage: clawapi-cli issue <scope> [--reason <text>]\n", stderr)
            exit(1)
        }
        let scope = args[2]
        let reason = parseFlag("--reason", from: args) ?? "CLI test"
        await issue(scope: scope, reason: reason)

    case "add":
        guard args.count >= 4 else {
            fputs("Error: Usage: clawapi-cli add <service> <scope> [--mode auto|manual|pending] [--domains d1,d2] [--secret <key>] [--type bearer|header|cookie|basic]\n", stderr)
            exit(1)
        }
        let service = args[2]
        let scope = args[3]
        let modeStr = parseFlag("--mode", from: args) ?? "auto"
        let domainsStr = parseFlag("--domains", from: args) ?? ""
        let secret = parseFlag("--secret", from: args)
        let typeStr = parseFlag("--type", from: args) ?? "bearer"
        let headerName = parseFlag("--header-name", from: args)
        await addScope(service: service, scope: scope, modeStr: modeStr, domainsStr: domainsStr, secret: secret, typeStr: typeStr, headerName: headerName)

    case "remove":
        guard args.count >= 3 else {
            fputs("Error: scope required. Usage: clawapi-cli remove <scope>\n", stderr)
            exit(1)
        }
        await removeScope(scope: args[2])

    case "list":
        await list()

    case "logs":
        let limit = Int(parseFlag("--limit", from: args) ?? "20") ?? 20
        await showLogs(limit: limit)

    case "help", "--help", "-h":
        printUsage()

    default:
        fputs("Unknown command: \(command)\n", stderr)
        printUsage()
        exit(1)
    }
}

// MARK: - Commands

@MainActor
func issue(scope: String, reason: String) async {
    let store = PolicyStore()
    let auditLogger = AuditLogger()

    guard let policy = store.policy(forScope: scope) else {
        print("Error: No policy for scope '\(scope)'")
        exit(1)
    }

    switch policy.approvalMode {
    case .auto:
        let entry = AuditEntry(scope: scope, requestingHost: "cli", reason: reason, result: .approved, detail: "CLI auto-issue")
        await auditLogger.log(entry)
        store.addAuditEntry(entry)

        if policy.hasSecret {
            let keychain = KeychainService()
            if let secret = try? keychain.retrieveString(forScope: scope) {
                print("OK: \(secret.prefix(4))****")
            } else {
                print("OK: (secret not in keychain)")
            }
        } else {
            print("OK: approved (no secret)")
        }

    case .manual, .pending:
        let request = PendingRequest(scope: scope, requestingHost: "cli", reason: reason)
        store.addPendingRequest(request)
        print("Queued for \(policy.approvalMode.rawValue) approval. Open the app to review.")
    }
}

@MainActor
func addScope(service: String, scope: String, modeStr: String, domainsStr: String, secret: String?, typeStr: String, headerName: String?) async {
    let store = PolicyStore()
    let mode = ScopeApprovalMode(rawValue: modeStr) ?? .auto
    let domains = domainsStr.isEmpty ? [] : domainsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let credType = CredentialType(rawValue: typeStr) ?? .bearerToken
    let hasSecret = secret != nil && !secret!.isEmpty

    let policy = ScopePolicy(
        serviceName: service,
        scope: scope,
        allowedDomains: domains,
        approvalMode: mode,
        hasSecret: hasSecret,
        credentialType: credType,
        customHeaderName: headerName
    )

    // Store secret in Keychain if provided
    if hasSecret, let secret {
        let keychain = KeychainService()
        do {
            try keychain.save(string: secret, forScope: scope)
            print("Secret stored in Keychain.")
        } catch {
            fputs("Warning: Failed to store secret: \(error.localizedDescription)\n", stderr)
        }
    }

    store.addPolicy(policy)
    print("Added scope '\(scope)' for \(service) (mode: \(mode.rawValue), type: \(credType.rawValue), secret: \(hasSecret ? "yes" : "no"))")
}

@MainActor
func removeScope(scope: String) async {
    let store = PolicyStore()
    guard let policy = store.policy(forScope: scope) else {
        print("Error: No policy for scope '\(scope)'")
        exit(1)
    }
    store.removePolicy(policy)
    print("Removed scope '\(scope)'")
}

@MainActor
func list() async {
    let store = PolicyStore()
    if store.policies.isEmpty {
        print("No scopes configured.")
        return
    }
    for p in store.policies {
        let mode = p.approvalMode.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0)
        print("  [\(mode)] \(p.scope) (\(p.serviceName))")
    }
}

@MainActor
func showLogs(limit: Int) async {
    let auditLogger = AuditLogger()
    let entries = await auditLogger.readEntries(limit: limit)
    if entries.isEmpty {
        print("No audit log entries.")
        return
    }
    for e in entries {
        let ts = ISO8601DateFormatter().string(from: e.timestamp)
        print("\(ts) [\(e.result.rawValue)] \(e.scope) — \(e.reason)")
    }
}

// MARK: - Helpers

func parseFlag(_ flag: String, from args: [String]) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func printUsage() {
    print("""
    clawapi-cli — ClawAPI Credential Broker CLI

    Commands:
      add <service> <scope> [options]       Add a connection
        --mode auto|manual|pending          Approval mode (default: auto)
        --domains d1,d2                     Allowed domains (comma-separated)
        --secret <key>                      API key or credential to store
        --type bearer|header|cookie|basic   Credential injection type (default: bearer)
        --header-name <name>                Custom header name (for --type header)

      remove <scope>                        Remove a connection
      issue <scope> [--reason <text>]       Request a credential (direct)
      list                                  List configured scopes
      logs [--limit N]                      Show recent audit entries
      help                                  Show this help

    Examples:
      clawapi-cli add OpenAI openai --secret sk-abc123 --domains api.openai.com
      clawapi-cli add GitHub github --secret ghp_xyz --type bearer --domains api.github.com
      clawapi-cli list
      clawapi-cli remove openai
    """)
}

await run()
