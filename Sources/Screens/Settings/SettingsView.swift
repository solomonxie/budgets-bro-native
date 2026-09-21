import SwiftUI

/// Per docs/design/uiux/settings.md — sections in order: Payees, AI Keys,
/// S3, Local Backup, Data. S3/backup/data sections are stubbed (Phase 5/7)
/// using the shared "coming soon" card the design doc calls for, not a
/// half-built form.
struct SettingsView: View {
    private let payeesRepo = PayeesRepository()

    @State private var payees: [Payee] = []
    @State private var renamingPayee: Payee?
    @State private var renameText = ""
    @State private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Payees are matched by name across every transaction. Renaming one here relabels its history — see docs/design/uiux/settings.md.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(payees) { payee in
                        Button {
                            renameText = payee.name
                            renamingPayee = payee
                        } label: {
                            Text(payee.name).foregroundStyle(.primary)
                        }
                    }
                } header: {
                    Text("Payees")
                }

                Section {
                    SecureField("API key", text: $apiKey)
                        .autocorrectionDisabled()
                    Text("Sent straight from this device to the provider when you run an analysis — never stored or seen by us. The key itself never leaves this device, including in backups.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Save Key") {
                        Keychain.set(apiKey, for: SecretKey.aiAPIKey)
                    }
                    .disabled(apiKey.isEmpty)
                } header: {
                    Text("AI Keys")
                }

                ComingSoonSection(title: "S3 Backup")
                ComingSoonSection(title: "Local Backup")
                ComingSoonSection(title: "Data")
            }
            .navigationTitle("Settings")
            .sheet(item: $renamingPayee) { payee in
                renameSheet(payee: payee)
            }
            .task { reload() }
        }
    }

    private func renameSheet(payee: Payee) -> some View {
        NavigationStack {
            Form {
                TextField("Name", text: $renameText)
            }
            .navigationTitle("Rename Payee")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { renamingPayee = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        payeesRepo.rename(id: payee.id, to: renameText)
                        renamingPayee = nil
                        reload()
                    }
                }
            }
        }
    }

    private func reload() {
        payees = payeesRepo.all()
        apiKey = Keychain.get(SecretKey.aiAPIKey) ?? ""
    }
}

/// Every "coming soon" screen/section uses this shared stub — per
/// docs/design/uiux — styled as a real card, not plain left-aligned text.
private struct ComingSoonSection: View {
    let title: String

    var body: some View {
        Section {
            Text("Not built yet — see docs/IMPLEMENTATION_PLAN.md.")
                .foregroundStyle(.secondary)
        } header: {
            Text(title)
        }
    }
}
