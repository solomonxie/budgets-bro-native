import SwiftUI

/// Ported from budgets-bro's `MonthNav.tsx` — stepping arrows plus a
/// tappable label that unfolds the OS wheel spinner in place, directly
/// under the bar, rather than in a sheet floating over the page it
/// filters. Shared by Budget and Insights, same as the original.
struct MonthNav: View {
    @Binding var month: String
    var onChange: () -> Void = {}

    @State private var isExpanded = false
    @State private var draftDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                arrowButton("chevron.left") { step(-1) }
                Button {
                    draftDate = parseDate(month + "-01")
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Text(monthLabel(month))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isExpanded ? Theme.accent : Theme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                arrowButton("chevron.right") { step(1) }
            }
            .padding(4)

            if isExpanded {
                VStack(spacing: 8) {
                    DatePicker("", selection: $draftDate, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .frame(maxWidth: .infinity)
                    Button {
                        month = monthString(from: draftDate)
                        withAnimation { isExpanded = false }
                        onChange()
                    } label: {
                        Text("Done")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(8)
                .background(Theme.surface)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.border, lineWidth: 1))
    }

    private func arrowButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 76, height: 40)
                .background(Theme.border.opacity(0.001)) // keeps the whole slab tappable
        }
    }

    private func step(_ delta: Int) {
        var components = DateComponents()
        components.month = delta
        if let newDate = Calendar.current.date(byAdding: components, to: parseDate(month + "-01")) {
            month = monthString(from: newDate)
            onChange()
        }
    }

    private func monthLabel(_ month: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: month) else { return month }
        let display = DateFormatter()
        display.dateFormat = "MMMM yyyy"
        return display.string(from: date)
    }
}
