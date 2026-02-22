import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "HealthCheck")

/// Health status of a provider's API key / connectivity.
public enum ProviderHealth: Sendable, Equatable {
    /// Not yet checked — no data available.
    case unknown
    /// Provider responded successfully during real usage.
    case healthy
    /// Key is invalid (401/403) or quota exhausted (402/429-quota).
    case dead(reason: String)
    /// Provider is unreachable (network error, timeout).
    case unreachable(reason: String)
    /// Currently checking (manual check in progress).
    case checking
}

/// Distributed notification posted by the daemon when a proxy response
/// returns an HTTP error that indicates a dead/unreachable provider.
/// `userInfo` keys: "scope" (String), "statusCode" (Int), "detail" (String).
public let providerHealthNotification = Notification.Name("com.clawapi.providerHealth")

/// Determines provider health **passively** from real proxy traffic (audit log)
/// and supports manual checks via free GET /models endpoints (no tokens consumed).
public enum ProviderHealthCheck {

    /// Normalize a colon-qualified policy scope (e.g. "openai:completions") to its
    /// base provider scope ("openai") so it matches ServiceCatalog and check configs.
    private static func baseScope(_ scope: String) -> String {
        scope.split(separator: ":").first.map(String.init) ?? scope
    }

    // MARK: - Passive: Derive health from audit log

    /// Scan recent audit entries to determine health for all enabled providers.
    /// Looks at the most recent proxy result per scope:
    /// - "→ 401" / "→ 403" → dead (invalid key)
    /// - "→ 402" → dead (payment required)
    /// - "→ 429" with quota keywords → dead (quota exhausted)
    /// - "→ 2xx" → healthy
    /// - error entries → unreachable
    /// Providers with no audit entries remain `.unknown`.
    public static func deriveFromAuditLog(entries: [AuditEntry], scopes: [String]) -> [String: ProviderHealth] {
        var results: [String: ProviderHealth] = [:]

        for scope in scopes {
            // Find the most recent audit entry for this scope that came from proxy traffic
            guard let latest = entries.first(where: { $0.scope == scope && $0.detail?.contains("Proxied") == true }) else {
                // Also check for error entries
                if let errorEntry = entries.first(where: { $0.scope == scope && $0.result == .error }) {
                    results[scope] = .unreachable(reason: errorEntry.detail ?? "Error")
                }
                continue
            }

            guard let detail = latest.detail else { continue }

            // Parse "Proxied POST https://... → 429"
            if let arrowRange = detail.range(of: "→ ") {
                let statusStr = String(detail[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if let statusCode = Int(statusStr) {
                    let health = classifyStatusCode(statusCode, body: nil)
                    results[scope] = health
                }
            }
        }

        return results
    }

    // MARK: - Manual: Free endpoint checks (GET /models — no tokens)

    /// Manually check a single provider using a free endpoint (GET /models).
    /// Does NOT consume any tokens. Only verifies the API key is valid.
    /// For local providers, checks if the server is reachable.
    public static func manualCheck(scope: String, keychain: KeychainService) async -> ProviderHealth {
        let base = baseScope(scope)
        let template = ServiceCatalog.find(base)

        // OAuth providers: check if profile exists (must be checked before
        // the requiresKey gate, since OAuth providers also have requiresKey=false)
        if let t = template, case .oauth = t.authMethod {
            return checkOAuth(scope: base)
        }

        // Local providers: just check if the server is reachable
        if let t = template, !t.requiresKey {
            return await checkLocal(scope: base)
        }

        // API key providers: retrieve key from ClawAPI Keychain or OpenClaw auth-profiles
        let key: String
        if let k = try? keychain.retrieveString(forScope: scope) {
            key = k
        } else if scope != base, let k = try? keychain.retrieveString(forScope: base) {
            key = k
        } else if let k = OpenClawConfig.readKeyFromAuthProfiles(scope: base) {
            key = k
        } else {
            logger.warning("No API key found for \(scope) (checked keychain + auth-profiles)")
            return .dead(reason: "No API key")
        }

        return await checkWithKey(scope: base, key: key)
    }

    /// Manually check all enabled providers concurrently.
    public static func manualCheckAll(policies: [ScopePolicy], keychain: KeychainService) async -> [String: ProviderHealth] {
        let enabled = policies.filter { $0.isEnabled }
        return await withTaskGroup(of: (String, ProviderHealth).self) { group in
            for policy in enabled {
                group.addTask {
                    let health = await manualCheck(scope: policy.scope, keychain: keychain)
                    return (policy.scope, health)
                }
            }
            var results: [String: ProviderHealth] = [:]
            for await (scope, health) in group {
                results[scope] = health
            }
            return results
        }
    }

    // MARK: - Status code classification (shared by proxy + manual check)

    /// Classify an HTTP status code into a health status.
    /// `body` is optional response body text for distinguishing rate-limit from quota-exceeded on 429.
    public static func classifyStatusCode(_ statusCode: Int, body: String?) -> ProviderHealth {
        switch statusCode {
        case 200...299:
            return .healthy
        case 401, 403:
            return .dead(reason: "Invalid API key")
        case 402:
            return .dead(reason: "Payment required")
        case 429:
            let lower = body?.lowercased() ?? ""
            if lower.contains("quota") || lower.contains("exceeded") || lower.contains("insufficient")
                || lower.contains("billing") || lower.contains("limit reached") {
                return .dead(reason: "Quota exhausted")
            }
            // Rate limited but key is still valid
            return .healthy
        case 404:
            // Model not found but key is valid
            return .healthy
        case 500...599:
            return .unreachable(reason: "Server error (\(statusCode))")
        default:
            return .unreachable(reason: "HTTP \(statusCode)")
        }
    }

    // MARK: - Private: Local providers

    private static func checkLocal(scope: String) async -> ProviderHealth {
        let url: URL?
        switch scope {
        case "ollama":
            url = URL(string: "http://localhost:11434/api/tags")
        case "lmstudio":
            url = URL(string: "http://localhost:1234/v1/models")
        case "litellm":
            url = URL(string: "http://localhost:4000/v1/models")
        default:
            return .unknown
        }

        guard let url else { return .unknown }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                return .healthy
            }
            return .unreachable(reason: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        } catch {
            return .unreachable(reason: "Not running")
        }
    }

    // MARK: - Private: OAuth providers

    private static func checkOAuth(scope: String) -> ProviderHealth {
        let profiles = OpenClawConfig.listOAuthProfiles()
        if profiles.contains(where: { $0.provider == scope }) {
            return .healthy
        }
        return .dead(reason: "No OAuth token")
    }

    // MARK: - Private: API key providers (free GET /models)

    private static func checkWithKey(scope: String, key: String) async -> ProviderHealth {
        let config = providerCheckConfig(scope: scope)

        guard let url = URL(string: config.url) else {
            return .unknown
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        switch config.authStyle {
        case .bearer:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .customHeader(let name):
            request.setValue(key, forHTTPHeaderField: name)
        }

        for (header, value) in config.extraHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .unreachable(reason: "Invalid response")
            }

            let body = String(data: data, encoding: .utf8)
            logger.info("Manual check \(scope): HTTP \(http.statusCode)")
            return classifyStatusCode(http.statusCode, body: body)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                return .unreachable(reason: "Timeout")
            case .cannotConnectToHost, .cannotFindHost:
                return .unreachable(reason: "Cannot connect")
            case .notConnectedToInternet:
                return .unreachable(reason: "No internet")
            default:
                return .unreachable(reason: error.localizedDescription)
            }
        } catch {
            return .unreachable(reason: error.localizedDescription)
        }
    }

    // MARK: - Provider endpoint configs (all use GET /models — free, no tokens)

    private enum AuthStyle {
        case bearer
        case customHeader(String)
    }

    private struct CheckConfig {
        let url: String
        let authStyle: AuthStyle
        let extraHeaders: [(String, String)]
    }

    private static func providerCheckConfig(scope: String) -> CheckConfig {
        switch scope {
        case "openai":
            return CheckConfig(url: "https://api.openai.com/v1/models", authStyle: .bearer, extraHeaders: [])
        case "xai":
            return CheckConfig(url: "https://api.x.ai/v1/models", authStyle: .bearer, extraHeaders: [])
        case "mistral":
            return CheckConfig(url: "https://api.mistral.ai/v1/models", authStyle: .bearer, extraHeaders: [])
        case "groq":
            return CheckConfig(url: "https://api.groq.com/openai/v1/models", authStyle: .bearer, extraHeaders: [])
        case "openrouter":
            return CheckConfig(url: "https://openrouter.ai/api/v1/auth/key", authStyle: .bearer, extraHeaders: [])
        case "cerebras":
            return CheckConfig(url: "https://api.cerebras.ai/v1/models", authStyle: .bearer, extraHeaders: [])
        case "together":
            return CheckConfig(url: "https://api.together.xyz/v1/models", authStyle: .bearer, extraHeaders: [])
        case "venice":
            return CheckConfig(url: "https://api.venice.ai/api/v1/models", authStyle: .bearer, extraHeaders: [])
        case "kimi-coding":
            return CheckConfig(url: "https://api.moonshot.ai/v1/models", authStyle: .bearer, extraHeaders: [])
        case "minimax":
            return CheckConfig(url: "https://api.minimax.chat/v1/models", authStyle: .bearer, extraHeaders: [])
        case "zai":
            return CheckConfig(url: "https://api.z.ai/v1/models", authStyle: .bearer, extraHeaders: [])
        case "opencode":
            return CheckConfig(url: "https://api.opencode.ai/v1/models", authStyle: .bearer, extraHeaders: [])
        case "vercel-ai-gateway":
            return CheckConfig(url: "https://sdk.vercel.ai/v1/models", authStyle: .bearer, extraHeaders: [])
        case "huggingface":
            return CheckConfig(url: "https://api-inference.huggingface.co/models", authStyle: .bearer, extraHeaders: [])
        case "qwen-portal":
            return CheckConfig(url: "https://portal.qwen.ai/v1/models", authStyle: .bearer, extraHeaders: [])
        case "volcengine":
            return CheckConfig(url: "https://ark.cn-beijing.volces.com/api/v3/models", authStyle: .bearer, extraHeaders: [])
        case "byteplus":
            return CheckConfig(url: "https://ark.ap-southeast.bytepluses.com/api/v3/models", authStyle: .bearer, extraHeaders: [])
        case "qianfan":
            return CheckConfig(url: "https://qianfan.baidubce.com/v2/models", authStyle: .bearer, extraHeaders: [])
        case "anthropic", "claude":
            return CheckConfig(
                url: "https://api.anthropic.com/v1/models",
                authStyle: .customHeader("x-api-key"),
                extraHeaders: [("anthropic-version", "2023-06-01")])
        case "google-ai":
            return CheckConfig(
                url: "https://generativelanguage.googleapis.com/v1beta/models",
                authStyle: .customHeader("x-goog-api-key"),
                extraHeaders: [])
        case "xiaomi":
            return CheckConfig(
                url: "https://api.xiaomimimo.com/anthropic/v1/models",
                authStyle: .customHeader("x-api-key"),
                extraHeaders: [("anthropic-version", "2023-06-01")])
        default:
            let template = ServiceCatalog.find(scope)
            let baseURL = template?.domains.first.map { "https://\($0)" } ?? ""
            return CheckConfig(url: "\(baseURL)/v1/models", authStyle: .bearer, extraHeaders: [])
        }
    }
}
