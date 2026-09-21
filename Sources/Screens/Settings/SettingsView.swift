import SwiftUI
import UniformTypeIdentifiers

/// Per docs/design/uiux/settings.md — sections in order: App Lock, Payees,
/// AI Keys, Local Backup, iCloud Backup, S3, Data.
struct SettingsView: View {
    private let payeesRepo = PayeesRepository()
    private let appSettings = AppSettingsRepository()
    private let boardsRepo = BoardsRepository()
    private var boardContext: BoardContext { BoardContext.shared }

    @State private var boards: [Board] = []
    @State private var isAddingBoard = false
    @State private var newBoardName = ""
    @State private var renamingBoard: Board?
    @State private var renameBoardText = ""
    @State private var deletingBoard: Board?

    @State private var payees: [Payee] = []
    @State private var renamingPayee: Payee?
    @State private var renameText = ""
    @State private var apiKey = ""
    private let appLock = AppLockController.shared
    @State private var isSettingPasscode = false
    @State private var newPasscode = ""

    @State private var localBackups: [BackupFile] = []
    @State private var restoreConfirmFile: BackupFile?
    @State private var localBackupMessage: String?

    @State private var iCloudBackups: [BackupFile] = []
    @State private var iCloudMessage: String?

    @State private var s3Bucket = ""
    @State private var s3Region = "us-east-1"
    @State private var s3Prefix = ""
    @State private var s3AccessKey = ""
    @State private var s3SecretKey = ""
    @State private var s3StatusMessage: String?
    @State private var isBusyWithS3 = false
    @State private var isAddingS3 = false

    @State private var isImportingYNAB = false
    @State private var importMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                boardSection
                appLockSection
                payeesSection
                aiKeysSection
                backupSection
                dataSection
            }
            .navigationTitle("Settings")
            .sheet(item: $renamingPayee) { payee in renameSheet(payee: payee) }
            .sheet(isPresented: $isSettingPasscode) { passcodeSheet }
            .sheet(isPresented: $isAddingBoard) { addBoardSheet }
            .sheet(item: $renamingBoard) { board in renameBoardSheet(board: board) }
            .alert("Delete this board?", isPresented: Binding(get: { deletingBoard != nil }, set: { if !$0 { deletingBoard = nil } })) {
                Button("Cancel", role: .cancel) { deletingBoard = nil }
                Button("Delete", role: .destructive) {
                    if let board = deletingBoard { deleteBoard(board) }
                    deletingBoard = nil
                }
            } message: {
                Text("This permanently deletes everything in this board — accounts, transactions, all of it.")
            }
            .alert("Restore this backup?", isPresented: Binding(get: { restoreConfirmFile != nil }, set: { if !$0 { restoreConfirmFile = nil } })) {
                Button("Cancel", role: .cancel) { restoreConfirmFile = nil }
                Button("Restore", role: .destructive) {
                    if let file = restoreConfirmFile { restoreLocal(file) }
                    restoreConfirmFile = nil
                }
            } message: {
                Text("This replaces everything currently in the app with this backup's data.")
            }
            .fileImporter(isPresented: $isImportingYNAB, allowedContentTypes: [.zip]) { result in
                importYNAB(result)
            }
            .task { reload() }
        }
    }

    // MARK: Board — see budgets-bro's `useBoards`/`SettingsScreen` board list.

    private var boardSection: some View {
        Section {
            ForEach(boards) { board in
                Button {
                    boardContext.currentBoardId = board.id
                    reload()
                } label: {
                    HStack {
                        Image(systemName: board.id == boardContext.currentBoardId ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(board.id == boardContext.currentBoardId ? Theme.accent : Theme.textMuted)
                        Text(board.name).foregroundStyle(.primary)
                        Spacer()
                        Menu {
                            Button("Rename") {
                                renameBoardText = board.name
                                renamingBoard = board
                            }
                            if boards.count > 1 {
                                Button("Delete", role: .destructive) { deletingBoard = board }
                            }
                        } label: {
                            Image(systemName: "ellipsis").foregroundStyle(Theme.textMuted)
                        }
                    }
                }
            }
            Button("+ New Board") { isAddingBoard = true }.foregroundStyle(Theme.accent)
            Button("Create Demo Board") {
                DemoBoardSeeder.seed()
                reload()
            }.foregroundStyle(Theme.accent)
        } header: {
            Text("Board")
        }
    }

    private var addBoardSheet: some View {
        NavigationStack {
            Form {
                TextField("Board name", text: $newBoardName)
            }
            .navigationTitle("New Board")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isAddingBoard = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let id = boardsRepo.create(name: newBoardName)
                        boardContext.currentBoardId = id
                        // Seed the common starting pair so a brand-new board
                        // isn't unusable until accounts are added by hand.
                        let accountsRepo = AccountsRepository()
                        accountsRepo.create(name: "Cash", type: .cash, onBudget: true, openingBalanceCents: 0)
                        accountsRepo.create(name: "Savings", type: .savings, onBudget: true, openingBalanceCents: 0)
                        newBoardName = ""
                        isAddingBoard = false
                        reload()
                    }
                    .disabled(newBoardName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func renameBoardSheet(board: Board) -> some View {
        NavigationStack {
            Form {
                TextField("Board name", text: $renameBoardText)
            }
            .navigationTitle("Rename Board")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { renamingBoard = nil } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        boardsRepo.rename(id: board.id, name: renameBoardText)
                        renamingBoard = nil
                        reload()
                    }
                }
            }
        }
    }

    /// Falls back to whatever board is left after deleting the active one.
    private func deleteBoard(_ board: Board) {
        boardsRepo.delete(id: board.id)
        if boardContext.currentBoardId == board.id {
            boardContext.currentBoardId = boardsRepo.all().first?.id ?? board.id
        }
        reload()
    }

    // MARK: App Lock

    private var appLockSection: some View {
        Section {
            Picker("Lock", selection: Binding(
                get: { appLock.mode },
                set: { newMode in
                    if newMode == .passcode, !appLock.hasPasscode {
                        isSettingPasscode = true
                    }
                    appLock.mode = newMode
                }
            )) {
                ForEach(AppLockMode.allCases) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            if appLock.mode == .passcode {
                Button("Change Passcode") { isSettingPasscode = true }
            }
        } header: {
            Text("App Lock")
        }
    }

    private var passcodeSheet: some View {
        NavigationStack {
            Form {
                SecureField("4-digit passcode", text: $newPasscode)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Set Passcode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isSettingPasscode = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appLock.setPasscode(newPasscode)
                        newPasscode = ""
                        isSettingPasscode = false
                    }
                    .disabled(newPasscode.count != 4)
                }
            }
        }
    }

    // MARK: Payees

    private var payeesSection: some View {
        Section {
            Text("Payees are matched by name across every transaction. Renaming one here relabels its history.")
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

    // MARK: AI Keys

    private var aiKeysSection: some View {
        Section {
            SecureField("API key", text: $apiKey)
                .autocorrectionDisabled()
            Text("Sent straight from this device to the provider when you run an analysis — never stored or seen by us. The key itself never leaves this device, including in backups.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Save Key") { Keychain.set(apiKey, for: SecretKey.aiAPIKey) }
                .disabled(apiKey.isEmpty)
        } header: {
            Text("AI Keys")
        }
    }

    // MARK: Backup — one list of destinations, per-row ⋯ menu, per
    // docs/design/uiux/settings.md's "Backup destinations" convention.

    private var backupSection: some View {
        Section {
            Text("Every sync writes a full copy of this board's data.")
                .font(.caption)
                .foregroundStyle(.secondary)

            destinationRow(name: "This device", subtitle: localBackups.first.map { "Last: \($0.name)" } ?? "No backups yet") {
                Button("Backup Now") { createLocalBackup() }
                if let latest = localBackups.first {
                    Button("Restore Latest") { restoreConfirmFile = latest }
                }
                ForEach(localBackups) { file in
                    Button("Delete \(file.name)", role: .destructive) {
                        try? LocalBackupRepository.delete(file)
                        reload()
                    }
                }
            }

            if ICloudBackupRepository.isAvailable {
                destinationRow(name: "iCloud", subtitle: iCloudBackups.first.map { "Last: \($0.name)" } ?? "No backups yet") {
                    Button("Backup Now") { createICloudBackup() }
                    if let latest = iCloudBackups.first {
                        Button("Restore Latest") { restoreICloud(latest) }
                    }
                }
            } else {
                Text("iCloud isn't available on this build yet — needs the iCloud container entitlement and a signed-in iCloud account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if hasS3Config {
                destinationRow(name: s3Bucket, subtitle: "s3://\(s3Bucket)/\(s3Prefix)") {
                    Button("Backup Now") { backupS3() }
                    Button("Restore Latest") { restoreS3() }
                    Button("Delete Connection", role: .destructive) { deleteS3Config() }
                }
            } else if isAddingS3 {
                s3Form
            } else {
                Button("+ Add S3 Backup") { isAddingS3 = true }.foregroundStyle(Theme.accent)
            }

            if let message = localBackupMessage ?? iCloudMessage ?? s3StatusMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Backup")
        }
    }

    private func destinationRow(name: String, subtitle: String, @ViewBuilder menu: () -> some View) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                menu()
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var s3Form: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Bucket", text: $s3Bucket).autocorrectionDisabled()
            TextField("Region", text: $s3Region).autocorrectionDisabled()
            TextField("Folder (key prefix)", text: $s3Prefix).autocorrectionDisabled()
            SecureField("Access Key ID", text: $s3AccessKey).autocorrectionDisabled()
            SecureField("Secret Access Key", text: $s3SecretKey).autocorrectionDisabled()
            Button(isBusyWithS3 ? "Validating…" : "Save & Validate") { saveAndValidateS3() }
                .disabled(isBusyWithS3 || s3Bucket.isEmpty || s3AccessKey.isEmpty || s3SecretKey.isEmpty)
            Text("Secrets are stored in the Keychain, never in the database or any export.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hasS3Config: Bool {
        !s3Bucket.isEmpty && Keychain.get(SecretKey.s3AccessKeyID) != nil
    }

    private var s3Config: S3Config {
        S3Config(
            bucket: s3Bucket,
            region: s3Region,
            accessKeyID: Keychain.get(SecretKey.s3AccessKeyID) ?? s3AccessKey,
            secretAccessKey: Keychain.get(SecretKey.s3SecretAccessKey) ?? s3SecretKey,
            prefix: s3Prefix
        )
    }

    // MARK: Data

    private var dataSection: some View {
        Section {
            Button("Import from YNAB") { isImportingYNAB = true }
            if let importMessage {
                Text(importMessage).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Data")
        }
    }

    // MARK: Actions

    private func reload() {
        boards = boardsRepo.all()
        payees = payeesRepo.all()
        apiKey = Keychain.get(SecretKey.aiAPIKey) ?? ""
        localBackups = LocalBackupRepository.list()
        iCloudBackups = ICloudBackupRepository.list()
        s3Bucket = appSettings.get("s3_bucket") ?? ""
        s3Region = appSettings.get("s3_region") ?? "us-east-1"
        s3Prefix = appSettings.get("s3_prefix") ?? ""
    }

    private func createLocalBackup() {
        do {
            _ = try LocalBackupRepository.createSnapshot()
            localBackupMessage = "Backed up."
            reload()
        } catch {
            localBackupMessage = error.localizedDescription
        }
    }

    private func restoreLocal(_ file: BackupFile) {
        do {
            try LocalBackupRepository.restore(from: file.url)
            localBackupMessage = "Restored."
        } catch {
            localBackupMessage = error.localizedDescription
        }
    }

    private func createICloudBackup() {
        do {
            _ = try ICloudBackupRepository.createSnapshot()
            iCloudMessage = "Backed up to iCloud."
            reload()
        } catch {
            iCloudMessage = error.localizedDescription
        }
    }

    private func restoreICloud(_ file: BackupFile) {
        do {
            try ICloudBackupRepository.restore(from: file.url)
            iCloudMessage = "Restored from iCloud."
        } catch {
            iCloudMessage = error.localizedDescription
        }
    }

    private func saveAndValidateS3() {
        isBusyWithS3 = true
        s3StatusMessage = nil
        let config = S3Config(bucket: s3Bucket, region: s3Region, accessKeyID: s3AccessKey, secretAccessKey: s3SecretKey, prefix: s3Prefix)
        Task {
            do {
                try await S3BackupRepository(config: config).validate()
                appSettings.set("s3_bucket", s3Bucket)
                appSettings.set("s3_region", s3Region)
                appSettings.set("s3_prefix", s3Prefix)
                Keychain.set(s3AccessKey, for: SecretKey.s3AccessKeyID)
                Keychain.set(s3SecretKey, for: SecretKey.s3SecretAccessKey)
                await MainActor.run {
                    s3StatusMessage = "Validated and saved."
                    isBusyWithS3 = false
                    isAddingS3 = false
                }
            } catch {
                await MainActor.run {
                    s3StatusMessage = error.localizedDescription
                    isBusyWithS3 = false
                }
            }
        }
    }

    private func backupS3() {
        isBusyWithS3 = true
        Task {
            do {
                try await S3BackupRepository(config: s3Config).backupNow()
                await MainActor.run { s3StatusMessage = "Backed up to S3."; isBusyWithS3 = false }
            } catch {
                await MainActor.run { s3StatusMessage = error.localizedDescription; isBusyWithS3 = false }
            }
        }
    }

    private func restoreS3() {
        isBusyWithS3 = true
        Task {
            do {
                try await S3BackupRepository(config: s3Config).restoreLatest()
                await MainActor.run { s3StatusMessage = "Restored from S3."; isBusyWithS3 = false }
            } catch {
                await MainActor.run { s3StatusMessage = error.localizedDescription; isBusyWithS3 = false }
            }
        }
    }

    private func deleteS3Config() {
        Keychain.remove(SecretKey.s3AccessKeyID)
        Keychain.remove(SecretKey.s3SecretAccessKey)
        appSettings.set("s3_bucket", nil)
        appSettings.set("s3_region", nil)
        appSettings.set("s3_prefix", nil)
        s3Bucket = ""
        s3Region = "us-east-1"
        s3Prefix = ""
        s3AccessKey = ""
        s3SecretKey = ""
    }

    private func importYNAB(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let outcome = try YNABImporter.importZip(at: url)
                importMessage = "\(outcome.inserted) inserted, \(outcome.updated) updated, \(outcome.accountsCreated) accounts + \(outcome.categoriesCreated) categories created."
            } catch {
                importMessage = error.localizedDescription
            }
        case let .failure(error):
            importMessage = error.localizedDescription
        }
    }
}
