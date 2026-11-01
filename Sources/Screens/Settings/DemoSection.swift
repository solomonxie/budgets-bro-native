import SwiftUI

/// Sample household budget for screenshots, in its own database; real data and backups are left alone.
struct DemoSection: View {
    @AppStorage(AppData.demoKey) private var demoOn = false
    @State private var resetCount = 0

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { demoOn }, set: { AppData.setDemo($0) })) {
                Label("Demo mode", systemImage: "sparkles.rectangle.stack")
            }
            if demoOn {
                Button {
                    DemoSeed.seed()
                    resetCount += 1
                } label: {
                    Label("Reset demo data", systemImage: "arrow.counterclockwise")
                }
                .sensoryFeedback(.success, trigger: resetCount)
            }
        } header: {
            Text("Demo")
        } footer: {
            Text("A year of sample accounts, budgets and spending in a separate database, for screenshots. Your own data and backups aren't touched; turn off to go back.")
        }
    }
}
