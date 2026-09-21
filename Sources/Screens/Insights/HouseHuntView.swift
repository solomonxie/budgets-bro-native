import SwiftUI

/// A shortlist of listings with price/sqft, down payment, and monthly
/// payment derived on the fly — same assumptions for every house, so a
/// comparison is fair. Streamlined vs. the original's much wider field set
/// and side-by-side compare — see IMPLEMENTATION_PLAN.md.
struct HouseHuntView: View {
    private let repository = HouseHuntRepository()

    @State private var listings: [HouseHuntListing] = []
    @State private var isAddPresented = false

    var body: some View {
        List {
            ForEach(listings) { listing in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(listing.community).font(.headline)
                        Spacer()
                        Text(Money.wholeDollars(listing.askingPriceCents))
                    }
                    HStack {
                        if let pricePerSqft = listing.pricePerSqft {
                            Text(String(format: "$%.0f/sqft", pricePerSqft)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Down: \(Money.wholeDollars(listing.downPaymentCents))").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Est. payment: \(Money.exact(listing.monthlyPaymentCents))/mo")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            }
            .onDelete { offsets in
                for index in offsets { repository.delete(id: listings[index].id) }
                reload()
            }
        }
        .navigationTitle("House Hunt")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAddPresented = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isAddPresented) {
            AddListingView { reload() }
        }
        .task { reload() }
    }

    private func reload() {
        listings = repository.all()
    }
}

private struct AddListingView: View {
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var community = ""
    @State private var priceText = ""
    @State private var beds = ""
    @State private var baths = ""
    @State private var sqft = ""
    @State private var downPercent = "20"
    @State private var rate = "6.5"
    @State private var termYears = "30"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Community", text: $community)
                TextField("Asking price", text: $priceText).keyboardType(.decimalPad)
                TextField("Beds", text: $beds).keyboardType(.numberPad)
                TextField("Baths", text: $baths).keyboardType(.decimalPad)
                TextField("Area (sqft)", text: $sqft).keyboardType(.numberPad)
                TextField("Down payment %", text: $downPercent).keyboardType(.decimalPad)
                TextField("Rate %", text: $rate).keyboardType(.decimalPad)
                TextField("Term (years)", text: $termYears).keyboardType(.numberPad)
            }
            .navigationTitle("Add Listing")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HouseHuntRepository().create(HouseHuntListing(
                            id: 0, community: community,
                            askingPriceCents: Int((Double(priceText) ?? 0) * 100),
                            beds: Int(beds), baths: Double(baths), areaSqft: Int(sqft),
                            downPaymentPercent: Double(downPercent) ?? 20,
                            ratePercent: Double(rate) ?? 6.5,
                            termMonths: (Int(termYears) ?? 30) * 12,
                            notes: nil, rating: nil
                        ))
                        onSave()
                        dismiss()
                    }
                    .disabled(community.isEmpty || priceText.isEmpty)
                }
            }
        }
    }
}
