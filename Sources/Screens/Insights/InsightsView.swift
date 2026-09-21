import SwiftUI

/// Per docs/design/uiux/insights.md — placeholder until Phase 3 (T3.5).
struct InsightsView: View {
    var body: some View {
        ZStack {
            Theme.page.ignoresSafeArea()
            Text("Insights")
                .foregroundStyle(.white)
        }
        .navigationTitle("Insights")
    }
}
