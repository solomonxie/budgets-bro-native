import SwiftUI

struct SearchablePickerItem: Identifiable, Hashable {
    let id: Int
    let title: String
}

/// Fuzzy(-ish — substring, case-insensitive) search sheet over a picked
/// list, with "type your own" as the first option when `onCustom` is set —
/// the payee-field treatment per docs/design/uiux/components.md, reused for
/// every free-form picker rather than one-off plain `Picker`s.
struct SearchablePickerSheet: View {
    let title: String
    let items: [SearchablePickerItem]
    var onSelect: (SearchablePickerItem) -> Void
    var onCustom: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [SearchablePickerItem] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let onCustom, !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        onCustom(query)
                        dismiss()
                    } label: {
                        Label("Use \"\(query)\"", systemImage: "plus")
                    }
                }
                ForEach(filtered) { item in
                    Button(item.title) {
                        onSelect(item)
                        dismiss()
                    }
                    .foregroundStyle(.primary)
                }
            }
            .searchable(text: $query, prompt: "Search")
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// A row that opens a `SearchablePickerSheet` — the button-that-looks-like-
/// a-field pattern every picker field in Add Transaction uses.
struct PickerFieldButton: View {
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).foregroundStyle(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
