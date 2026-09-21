import SwiftUI

/// Per docs/design/uiux/accounts.md — placeholder until Phase 1 (T1.2).
struct AccountsView: View {
    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            Text("Accounts")
                .foregroundStyle(.white)
        }
        .navigationTitle("Accounts")
    }
}
