import SwiftUI
import UniformTypeIdentifiers

struct GenericCSVImportView: View {
    private let accountsRepo = AccountsRepository()

    @State private var accounts: [Account] = []
    @State private var selectedAccountId: Int?
    @State private var isFileImporterPresented = false
    @State private var header: [String] = []
    @State private var rows: [[String]] = []
    @State private var dateColumn = 0
    @State private var payeeColumn: Int?
    @State private var amountColumn = 0
    @State private var memoColumn: Int?
    @State private var resultMessage: String?

    var body: some View {
        Form {
            Picker("Account", selection: $selectedAccountId) {
                ForEach(accounts) { account in
                    Text(account.name).tag(Optional(account.id))
                }
            }
            Button(rows.isEmpty ? "Choose CSV File" : "Choose a Different File") { isFileImporterPresented = true }

            if !header.isEmpty {
                Section("Column Mapping") {
                    columnPicker("Date", selection: $dateColumn)
                    optionalColumnPicker("Payee", selection: $payeeColumn)
                    columnPicker("Amount", selection: $amountColumn)
                    optionalColumnPicker("Memo", selection: $memoColumn)
                }
                Button("Import \(rows.count - 1) Rows") { runImport() }
                    .disabled(selectedAccountId == nil)
            }

            if let resultMessage {
                Text(resultMessage).font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Import Bank CSV")
        .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            loadFile(result)
        }
        .task { accounts = accountsRepo.all(); selectedAccountId = accounts.first?.id }
    }

    private func columnPicker(_ label: String, selection: Binding<Int>) -> some View {
        Picker(label, selection: selection) {
            ForEach(header.indices, id: \.self) { index in
                Text(header[index]).tag(index)
            }
        }
    }

    private func optionalColumnPicker(_ label: String, selection: Binding<Int?>) -> some View {
        Picker(label, selection: selection) {
            Text("None").tag(Int?.none)
            ForEach(header.indices, id: \.self) { index in
                Text(header[index]).tag(Optional(index))
            }
        }
    }

    private func loadFile(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let parsed = CSV.parse(text)
        guard let firstRow = parsed.first else { return }
        header = firstRow
        rows = parsed
    }

    private func runImport() {
        guard let accountId = selectedAccountId else { return }
        let mapping = ColumnMapping(dateColumn: dateColumn, payeeColumn: payeeColumn, amountColumn: amountColumn, memoColumn: memoColumn)
        let outcome = GenericCSVImporter.importRows(rows, header: header, mapping: mapping, accountId: accountId)
        resultMessage = "\(outcome.inserted) inserted, \(outcome.updated) updated."
    }
}
