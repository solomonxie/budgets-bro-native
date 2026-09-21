import SwiftUI

/// Per docs/DESIGN.md's AI analysis feature — vendor picker, opt-in
/// detailed mode, disclosure of what leaves the device, one real request
/// at run time (no separate "Test Connection").
struct AIAnalysisView: View {
    @State private var provider: AIProvider = .openAI
    @State private var detailedMode = false
    @State private var isRunning = false
    @State private var result: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $provider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                Toggle("Detailed mode", isOn: $detailedMode)
                Text(detailedMode
                    ? "Sends raw payee/memo/amount data for this month to \(provider.displayName)."
                    : "Sends only aggregated category totals for this month to \(provider.displayName). The key itself never leaves this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(isRunning ? "Analyzing…" : "Analyze") { run() }
                    .disabled(isRunning)
            }
            if let result {
                Section("Result") {
                    Text(result)
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(Theme.negative)
                }
            }
        }
        .navigationTitle("AI Analysis")
    }

    private func run() {
        guard let key = Keychain.get(SecretKey.aiAPIKey), !key.isEmpty else {
            errorMessage = "No API key saved — add one in Settings."
            return
        }
        isRunning = true
        errorMessage = nil
        result = nil
        let prompt = AIAnalysis.buildPrompt(mode: detailedMode ? .detailed : .aggregate, month: currentMonth())
        Task {
            do {
                let response = try await AIClient.complete(provider: provider, apiKey: key, prompt: prompt)
                await MainActor.run {
                    result = response
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }
}
