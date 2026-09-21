import Foundation

/// ECB rates via frankfurter.app — no key, per docs/design/market-data/DESIGN.md
/// (ported from the original). Cached in `app_settings` once a day rather
/// than refetched on every view.
enum ExchangeRatesClient {
    struct Rates: Codable {
        let base: String
        let date: String
        let rates: [String: Double]
    }

    private static let cacheKey = "exchange_rates_cache"
    private static let settings = AppSettingsRepository()

    static func latest(base: String) async -> Rates? {
        if let cached = cachedRates(), cached.base == base, isFromToday(cached.date) {
            return cached
        }
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=\(base)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(Rates.self, from: data) else {
            return cachedRates()
        }
        if let encoded = try? JSONEncoder().encode(decoded), let json = String(data: encoded, encoding: .utf8) {
            settings.set(cacheKey, json)
        }
        return decoded
    }

    /// A pair's rate over the last `days` days, for the Exchange Rates
    /// trend line. Not cached — fetched on demand when that page opens.
    static func history(base: String, target: String, days: Int) async -> [(date: String, rate: Double)] {
        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: end) else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let urlString = "https://api.frankfurter.app/\(formatter.string(from: start))..\(formatter.string(from: end))?from=\(base)&to=\(target)"
        guard let url = URL(string: urlString) else { return [] }
        struct HistoryResponse: Decodable {
            let rates: [String: [String: Double]]
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(HistoryResponse.self, from: data) else { return [] }
        return decoded.rates.compactMap { date, rates in rates[target].map { (date, $0) } }.sorted { $0.date < $1.date }
    }

    private static func cachedRates() -> Rates? {
        guard let json = settings.get(cacheKey), let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Rates.self, from: data)
    }

    private static func isFromToday(_ dateString: String) -> Bool {
        dateString == today()
    }
}
