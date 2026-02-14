import Foundation
import OSLog

private let logger = Logger(subsystem: "com.clawapi", category: "Billing")

/// Result of a billing/usage query for a single provider.
public struct BillingInfo: Sendable {
    public let scope: String
    public let balance: String?       // e.g. "$12.45 remaining"
    public let usage: String?         // e.g. "$3.21 used this month"
    public let detail: String?        // Extra info
    public let dashboardURL: URL?     // Link to provider's billing page
    public let error: String?
    public let queriedAt: Date

    public init(
        scope: String,
        balance: String? = nil,
        usage: String? = nil,
        detail: String? = nil,
        dashboardURL: URL? = nil,
        error: String? = nil,
        queriedAt: Date = Date()
    ) {
        self.scope = scope
        self.balance = balance
        self.usage = usage
        self.detail = detail
        self.dashboardURL = dashboardURL
        self.error = error
        self.queriedAt = queriedAt
    }
}

/// Queries billing / credit balance endpoints for supported providers.
public enum BillingService {

    /// Providers that support billing queries.
    /// All require a separate admin/management key.
    public static let supportedScopes: Set<String> = [
        "openai", "xai", "anthropic", "openrouter"
    ]

    /// Dashboard URLs for providers in the OpenClaw catalog.
    public static func dashboardURL(for scope: String) -> URL? {
        switch scope {
        case "openai":      URL(string: "https://platform.openai.com/usage")
        case "xai":         URL(string: "https://console.x.ai")
        case "anthropic":   URL(string: "https://console.anthropic.com/settings/billing")
        case "google-ai":   URL(string: "https://console.cloud.google.com/billing")
        case "mistral":     URL(string: "https://console.mistral.ai/billing")
        case "groq":        URL(string: "https://console.groq.com/settings/billing")
        case "openrouter":  URL(string: "https://openrouter.ai/credits")
        case "huggingface": URL(string: "https://huggingface.co/settings/billing")
        case "cerebras":    URL(string: "https://cloud.cerebras.ai/billing")
        default: nil
        }
    }

    /// Query billing info for a provider.
    public static func query(scope: String, keychain: KeychainService) async -> BillingInfo {
        let dashboard = dashboardURL(for: scope)

        guard supportedScopes.contains(scope) else {
            return BillingInfo(
                scope: scope,
                dashboardURL: dashboard,
                error: "Billing query not supported for this provider"
            )
        }

        // All supported providers need an admin/management key
        let adminKey: String
        do {
            adminKey = try keychain.retrieveAdminKey(forScope: scope)
        } catch {
            return BillingInfo(
                scope: scope,
                dashboardURL: dashboard,
                error: "No admin key configured. Add one to check balance."
            )
        }

        switch scope {
        case "xai":
            return await queryXAI(adminKey: adminKey, dashboard: dashboard)
        case "openai":
            return await queryOpenAI(adminKey: adminKey, dashboard: dashboard)
        case "anthropic":
            return await queryAnthropic(adminKey: adminKey, dashboard: dashboard, scope: scope)
        case "openrouter":
            return await queryOpenRouter(adminKey: adminKey, dashboard: dashboard)
        default:
            return BillingInfo(scope: scope, dashboardURL: dashboard, error: "Unsupported")
        }
    }

    // MARK: - OpenRouter Credits

    /// OpenRouter: GET https://openrouter.ai/api/v1/credits
    /// Requires a Management API key.
    private static func queryOpenRouter(adminKey: String, dashboard: URL?) async -> BillingInfo {
        let url = URL(string: "https://openrouter.ai/api/v1/credits")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(adminKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return BillingInfo(scope: "openrouter", dashboardURL: dashboard, error: "Invalid response")
            }
            guard http.statusCode == 200 else {
                logger.error("OpenRouter billing returned \(http.statusCode)")
                return BillingInfo(scope: "openrouter", dashboardURL: dashboard,
                                   error: "HTTP \(http.statusCode) — check your Management API key")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any] {
                let totalCredits = dataObj["total_credits"] as? Double ?? 0
                let totalUsage = dataObj["total_usage"] as? Double ?? 0
                let remaining = totalCredits - totalUsage
                return BillingInfo(
                    scope: "openrouter",
                    balance: String(format: "$%.2f remaining", remaining),
                    usage: String(format: "$%.2f used of $%.2f", totalUsage, totalCredits),
                    dashboardURL: dashboard
                )
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            return BillingInfo(scope: "openrouter", detail: body, dashboardURL: dashboard)
        } catch {
            logger.error("OpenRouter billing error: \(error.localizedDescription)")
            return BillingInfo(scope: "openrouter", dashboardURL: dashboard, error: error.localizedDescription)
        }
    }

    // MARK: - xAI Balance

    /// xAI: The billing endpoints require a team_id. We first list teams, then query balance.
    /// Requires a Management API key from console.x.ai.
    private static func queryXAI(adminKey: String, dashboard: URL?) async -> BillingInfo {
        // Step 1: Get the team ID
        let teamsURL = URL(string: "https://management-api.x.ai/v1/teams")!
        var teamsReq = URLRequest(url: teamsURL)
        teamsReq.setValue("Bearer \(adminKey)", forHTTPHeaderField: "Authorization")
        teamsReq.timeoutInterval = 15

        do {
            let (teamsData, teamsResp) = try await URLSession.shared.data(for: teamsReq)
            guard let teamsHttp = teamsResp as? HTTPURLResponse, teamsHttp.statusCode == 200 else {
                let code = (teamsResp as? HTTPURLResponse)?.statusCode ?? 0
                return BillingInfo(scope: "xai", dashboardURL: dashboard,
                                   error: "HTTP \(code) listing teams — check your Management API key")
            }
            // Try to parse team list and get first team's ID
            guard let teamsJson = try? JSONSerialization.jsonObject(with: teamsData),
                  let teamId = extractTeamId(from: teamsJson) else {
                // If we can't parse teams, try the flat balance endpoint as fallback
                return await queryXAIFallback(adminKey: adminKey, dashboard: dashboard)
            }

            // Step 2: Query prepaid balance for the team
            let balanceURL = URL(string: "https://management-api.x.ai/v1/billing/teams/\(teamId)/prepaid/balance")!
            var balanceReq = URLRequest(url: balanceURL)
            balanceReq.setValue("Bearer \(adminKey)", forHTTPHeaderField: "Authorization")
            balanceReq.timeoutInterval = 15

            let (balData, balResp) = try await URLSession.shared.data(for: balanceReq)
            guard let balHttp = balResp as? HTTPURLResponse, balHttp.statusCode == 200 else {
                let code = (balResp as? HTTPURLResponse)?.statusCode ?? 0
                return BillingInfo(scope: "xai", dashboardURL: dashboard,
                                   error: "HTTP \(code) querying balance")
            }
            if let json = try? JSONSerialization.jsonObject(with: balData) as? [String: Any] {
                if let balance = json["balance"] as? Double {
                    return BillingInfo(
                        scope: "xai",
                        balance: String(format: "$%.2f remaining", balance),
                        dashboardURL: dashboard
                    )
                }
                // Try other field names
                if let amount = json["amount"] as? Double {
                    return BillingInfo(
                        scope: "xai",
                        balance: String(format: "$%.2f remaining", amount),
                        dashboardURL: dashboard
                    )
                }
            }
            let body = String(data: balData, encoding: .utf8) ?? "Unknown"
            return BillingInfo(scope: "xai", detail: body, dashboardURL: dashboard)
        } catch {
            logger.error("xAI billing error: \(error.localizedDescription)")
            return BillingInfo(scope: "xai", dashboardURL: dashboard, error: error.localizedDescription)
        }
    }

    private static func extractTeamId(from json: Any) -> String? {
        // Could be { "data": [{ "id": "team_xxx", ... }] } or [{ "id": "..." }]
        if let dict = json as? [String: Any],
           let data = dict["data"] as? [[String: Any]],
           let first = data.first,
           let id = first["id"] as? String {
            return id
        }
        if let array = json as? [[String: Any]],
           let first = array.first,
           let id = first["id"] as? String {
            return id
        }
        return nil
    }

    /// Fallback: try flat /v1/balance endpoint (older xAI API)
    private static func queryXAIFallback(adminKey: String, dashboard: URL?) async -> BillingInfo {
        let url = URL(string: "https://management-api.x.ai/v1/balance")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(adminKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                return BillingInfo(scope: "xai", dashboardURL: dashboard,
                                   error: "HTTP \(code) — check your Management API key")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let balance = json["balance"] as? Double {
                return BillingInfo(
                    scope: "xai",
                    balance: String(format: "$%.2f remaining", balance),
                    dashboardURL: dashboard
                )
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            return BillingInfo(scope: "xai", detail: body, dashboardURL: dashboard)
        } catch {
            return BillingInfo(scope: "xai", dashboardURL: dashboard, error: error.localizedDescription)
        }
    }

    // MARK: - OpenAI Costs

    /// OpenAI: GET /v1/organization/costs?start_time=...&bucket_width=1d
    /// Requires an Admin API key (sk-admin-...).
    private static func queryOpenAI(adminKey: String, dashboard: URL?) async -> BillingInfo {
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        let startTime = Int(thirtyDaysAgo.timeIntervalSince1970)

        let url = URL(string: "https://api.openai.com/v1/organization/costs?start_time=\(startTime)&bucket_width=1d")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(adminKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return BillingInfo(scope: "openai", dashboardURL: dashboard, error: "Invalid response")
            }
            guard http.statusCode == 200 else {
                logger.error("OpenAI billing returned \(http.statusCode)")
                return BillingInfo(scope: "openai", dashboardURL: dashboard,
                                   error: "HTTP \(http.statusCode) — requires Admin API key (sk-admin-...)")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let buckets = json["data"] as? [[String: Any]] {
                // Sum all cost amounts across all buckets. Values are in USD (not cents).
                var totalUSD = 0.0
                for bucket in buckets {
                    if let results = bucket["results"] as? [[String: Any]] {
                        for result in results {
                            if let amount = result["amount"] as? [String: Any],
                               let value = amount["value"] as? Double {
                                totalUSD += value
                            }
                        }
                    }
                }
                return BillingInfo(
                    scope: "openai",
                    usage: String(format: "$%.2f used (last 30 days)", totalUSD),
                    dashboardURL: dashboard
                )
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            return BillingInfo(scope: "openai", detail: body, dashboardURL: dashboard)
        } catch {
            logger.error("OpenAI billing error: \(error.localizedDescription)")
            return BillingInfo(scope: "openai", dashboardURL: dashboard, error: error.localizedDescription)
        }
    }

    // MARK: - Anthropic Costs

    /// Anthropic: GET /v1/organizations/cost_report?starting_at=...&ending_at=...&bucket_width=1d
    /// Requires an Admin API key (sk-ant-admin-...).
    private static func queryAnthropic(adminKey: String, dashboard: URL?, scope: String) async -> BillingInfo {
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let startDate = fmt.string(from: startOfMonth)
        let endDate = fmt.string(from: now)

        let urlStr = "https://api.anthropic.com/v1/organizations/cost_report?starting_at=\(startDate)&ending_at=\(endDate)&bucket_width=1d"
        guard let url = URL(string: urlStr) else {
            return BillingInfo(scope: scope, dashboardURL: dashboard, error: "Invalid URL")
        }
        var request = URLRequest(url: url)
        request.setValue(adminKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return BillingInfo(scope: scope, dashboardURL: dashboard, error: "Invalid response")
            }
            guard http.statusCode == 200 else {
                logger.error("Anthropic billing returned \(http.statusCode)")
                // If cost_report fails, try usage_report as fallback
                if http.statusCode == 404 {
                    return await queryAnthropicUsage(adminKey: adminKey, dashboard: dashboard, scope: scope)
                }
                return BillingInfo(scope: scope, dashboardURL: dashboard,
                                   error: "HTTP \(http.statusCode) — requires Admin key (sk-ant-admin-...)")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let buckets = json["data"] as? [[String: Any]] {
                // Sum cost values across all buckets
                var totalCents = 0.0
                for bucket in buckets {
                    if let results = bucket["results"] as? [[String: Any]] {
                        for result in results {
                            if let cost = result["cost_usd_cents"] as? Double {
                                totalCents += cost
                            }
                        }
                    }
                }
                let dollars = totalCents / 100.0
                return BillingInfo(
                    scope: scope,
                    usage: String(format: "$%.2f used this month", dollars),
                    dashboardURL: dashboard
                )
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            return BillingInfo(scope: scope, detail: body, dashboardURL: dashboard)
        } catch {
            logger.error("Anthropic billing error: \(error.localizedDescription)")
            return BillingInfo(scope: scope, dashboardURL: dashboard, error: error.localizedDescription)
        }
    }

    /// Fallback: query usage_report/messages for token counts
    private static func queryAnthropicUsage(adminKey: String, dashboard: URL?, scope: String) async -> BillingInfo {
        let now = Date()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let startDate = fmt.string(from: startOfMonth)
        let endDate = fmt.string(from: now)

        let urlStr = "https://api.anthropic.com/v1/organizations/usage_report/messages?starting_at=\(startDate)&ending_at=\(endDate)&bucket_width=1d"
        guard let url = URL(string: urlStr) else {
            return BillingInfo(scope: scope, dashboardURL: dashboard, error: "Invalid URL")
        }
        var request = URLRequest(url: url)
        request.setValue(adminKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                return BillingInfo(scope: scope, dashboardURL: dashboard,
                                   error: "HTTP \(code) — requires Admin key (sk-ant-admin-...)")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let buckets = json["data"] as? [[String: Any]] {
                var totalInput = 0
                var totalOutput = 0
                for bucket in buckets {
                    if let results = bucket["results"] as? [[String: Any]] {
                        for result in results {
                            totalInput += result["input_tokens"] as? Int ?? 0
                            totalOutput += result["output_tokens"] as? Int ?? 0
                        }
                    }
                }
                let total = totalInput + totalOutput
                if total > 0 {
                    let totalK = Double(total) / 1000.0
                    return BillingInfo(
                        scope: scope,
                        usage: String(format: "%.1fK tokens this month", totalK),
                        detail: String(format: "Input: %dK · Output: %dK", totalInput / 1000, totalOutput / 1000),
                        dashboardURL: dashboard
                    )
                }
                return BillingInfo(scope: scope, usage: "No usage this month", dashboardURL: dashboard)
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            return BillingInfo(scope: scope, detail: body, dashboardURL: dashboard)
        } catch {
            return BillingInfo(scope: scope, dashboardURL: dashboard, error: error.localizedDescription)
        }
    }
}
