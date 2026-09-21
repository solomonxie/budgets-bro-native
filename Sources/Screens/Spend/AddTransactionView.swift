import SwiftUI

/// Per docs/design/uiux/spend.md — placeholder until Phase 3 (T3.2).
struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.page.ignoresSafeArea()
                Text("Add Transaction")
                    .foregroundStyle(.white)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
