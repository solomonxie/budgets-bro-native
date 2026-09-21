import Foundation

struct CityCostOfLiving {
    let city: String
    let currency: String
    /// Rough total monthly cost for one person (rent + food + transport +
    /// utilities), in the city's own currency — a dated, compiled estimate,
    /// not a live figure. See docs/design/market-data/DESIGN.md.
    let monthlyCostLocal: Double
}

/// Compiled 2026-era estimates for a handful of cities — a smaller table
/// than the original's 17, and with no per-category bucket mapping (just a
/// single total vs. the user's own total average). See IMPLEMENTATION_PLAN.md.
enum CostOfLivingData {
    static let cities: [CityCostOfLiving] = [
        CityCostOfLiving(city: "New York", currency: "USD", monthlyCostLocal: 4200),
        CityCostOfLiving(city: "San Francisco", currency: "USD", monthlyCostLocal: 4400),
        CityCostOfLiving(city: "Toronto", currency: "CAD", monthlyCostLocal: 3600),
        CityCostOfLiving(city: "Vancouver", currency: "CAD", monthlyCostLocal: 3800),
        CityCostOfLiving(city: "London", currency: "GBP", monthlyCostLocal: 2900),
        CityCostOfLiving(city: "Berlin", currency: "EUR", monthlyCostLocal: 2200),
        CityCostOfLiving(city: "Tokyo", currency: "JPY", monthlyCostLocal: 220_000),
        CityCostOfLiving(city: "Sydney", currency: "AUD", monthlyCostLocal: 3900),
        CityCostOfLiving(city: "Singapore", currency: "SGD", monthlyCostLocal: 3400),
        CityCostOfLiving(city: "Shanghai", currency: "CNY", monthlyCostLocal: 12000),
    ]
}
