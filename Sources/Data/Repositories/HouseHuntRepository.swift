import Foundation

/// CRUD for `house_hunt_listings` — a shortlist of listings with derived
/// metrics computed at read time via `Amortization`. Streamlined vs. the
/// original's much wider field set (roof/furnace age, windows, catchment,
/// commute, etc.) and no side-by-side compare — see IMPLEMENTATION_PLAN.md.
final class HouseHuntRepository {
    private let database: Database
    init(database: Database = .shared) { self.database = database }

    func all() -> [HouseHuntListing] {
        database.query(
            """
            SELECT id, community, asking_price_cents, beds, baths, area_sqft, down_payment_percent, rate_percent, term_months, notes, rating
            FROM house_hunt_listings ORDER BY created_at DESC
            """,
            row: Self.map
        )
    }

    @discardableResult
    func create(_ listing: HouseHuntListing) -> Int {
        Int(database.run(
            """
            INSERT INTO house_hunt_listings
                (community, asking_price_cents, beds, baths, area_sqft, down_payment_percent, rate_percent, term_months, notes, rating)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            [listing.community, listing.askingPriceCents, listing.beds, listing.baths, listing.areaSqft, listing.downPaymentPercent, listing.ratePercent, listing.termMonths, listing.notes, listing.rating]
        ))
    }

    func delete(id: Int) {
        database.run("DELETE FROM house_hunt_listings WHERE id = ?", [id])
    }

    private static func map(_ row: Row) -> HouseHuntListing {
        HouseHuntListing(
            id: row.int(0),
            community: row.text(1) ?? "",
            askingPriceCents: row.int(2),
            beds: row.isNull(3) ? nil : row.int(3),
            baths: row.isNull(4) ? nil : row.double(4),
            areaSqft: row.isNull(5) ? nil : row.int(5),
            downPaymentPercent: row.double(6),
            ratePercent: row.double(7),
            termMonths: row.int(8),
            notes: row.text(9),
            rating: row.isNull(10) ? nil : row.int(10)
        )
    }
}

extension HouseHuntListing {
    var downPaymentCents: Int { Int(Double(askingPriceCents) * downPaymentPercent / 100) }
    var mortgageAmountCents: Int { askingPriceCents - downPaymentCents }
    var monthlyPaymentCents: Int { Amortization.monthlyPaymentCents(principalCents: mortgageAmountCents, annualRatePercent: ratePercent, termMonths: termMonths) }
    var pricePerSqft: Double? { areaSqft.map { Double(askingPriceCents) / 100 / Double($0) } }
}
