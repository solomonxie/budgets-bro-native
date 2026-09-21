import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case openAI, anthropic
    var id: String { rawValue }
    var displayName: String { self == .openAI ? "OpenAI" : "Anthropic" }
}

enum AIError: LocalizedError {
    case missingKey
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: "No API key saved — add one in Settings."
        case let .requestFailed(message): message
        }
    }
}

/// Direct `URLSession` calls to the provider's REST API — no SDK, per
/// AGENTS.md. See docs/DESIGN.md's AI analysis feature section.
enum AIClient {
    static func complete(provider: AIProvider, apiKey: String, prompt: String) async throws -> String {
        switch provider {
        case .openAI: try await completeOpenAI(apiKey: apiKey, prompt: prompt)
        case .anthropic: try await completeAnthropic(apiKey: apiKey, prompt: prompt)
        }
    }

    private static func completeOpenAI(apiKey: String, prompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": prompt]],
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw AIError.requestFailed(String(data: data, encoding: .utf8) ?? "Request failed")
        }
        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }

            let choices: [Choice]
        }
        return try JSONDecoder().decode(ChatResponse.self, from: data).choices.first?.message.content ?? ""
    }

    private static func completeAnthropic(apiKey: String, prompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "claude-3-5-haiku-20241022",
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]],
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw AIError.requestFailed(String(data: data, encoding: .utf8) ?? "Request failed")
        }
        struct MessageResponse: Decodable {
            struct Content: Decodable { let text: String }
            let content: [Content]
        }
        return try JSONDecoder().decode(MessageResponse.self, from: data).content.first?.text ?? ""
    }
}

enum AIAnalysisMode {
    case aggregate, detailed
}

/// Builds the analysis payload from local SQLite — aggregated category
/// totals by default, raw transactions only in opt-in detailed mode. See
/// docs/DESIGN.md's privacy tradeoff section: this is the boundary that
/// decides what leaves the device.
enum AIAnalysis {
    static func buildPrompt(mode: AIAnalysisMode, month: String) -> String {
        let categoriesRepo = CategoriesRepository()
        let transactionsRepo = TransactionsRepository()
        let activity = transactionsRepo.activityCentsByCategory(month: month)

        var lines = ["Here is this month's (\(month)) spending by category:"]
        for category in categoriesRepo.categories() {
            let spent = -min(activity[category.id] ?? 0, 0)
            if spent > 0 {
                lines.append("- \(category.name): \(Money.exact(spent))")
            }
        }
        if mode == .detailed {
            lines.append("\nRecent transactions:")
            for item in transactionsRepo.forMonth(month).prefix(50) {
                lines.append("- \(item.date) \(item.payeeName ?? "No Payee") \(Money.exact(item.amountCents)) [\(item.categoryName ?? "Uncategorized")]")
            }
        }
        lines.append("\nGive a brief analysis of spending patterns, any concerning trends, and one actionable suggestion.")
        return lines.joined(separator: "\n")
    }
}
