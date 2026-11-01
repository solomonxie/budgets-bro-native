import SwiftUI

/// 1:1 port of budgets-bro's `src/components/ui/TabBarIcon.tsx` — same
/// paths on the same 24x24 grid, hand-drawn `Shape`s instead of an SVG
/// dependency per AGENTS.md's no-third-party-by-default rule.
enum TabIconName {
    case budget, accounts, add, insights
}

struct TabBarIcon: View {
    let name: TabIconName
    var color: Color
    var size: CGFloat = 22

    var body: some View {
        Group {
            switch name {
            case .budget:
                BudgetIconShape().stroke(color, style: lineStyle)
            case .accounts:
                AccountsIconShape().stroke(color, style: lineStyle)
            case .add:
                // Bolder stroke than the others — an action button standing
                // in for a tab, not a destination.
                AddIconShape().stroke(color, style: StrokeStyle(lineWidth: 2.6 * scale, lineCap: .round))
            case .insights:
                InsightsIconShape().stroke(color, style: lineStyle)
            }
        }
        .frame(width: size, height: size)
    }

    private var scale: CGFloat { size / 24 }
    private var lineStyle: StrokeStyle {
        StrokeStyle(lineWidth: 1.8 * scale, lineCap: .round, lineJoin: .round)
    }
}

private struct BudgetIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var p = Path()
        p.addRoundedRect(
            in: CGRect(x: 3 * s, y: 4 * s, width: 18 * s, height: 16 * s),
            cornerSize: CGSize(width: 2 * s, height: 2 * s)
        )
        p.move(to: CGPoint(x: 3 * s, y: 9 * s))
        p.addLine(to: CGPoint(x: 21 * s, y: 9 * s))
        p.move(to: CGPoint(x: 8 * s, y: 13.5 * s))
        p.addLine(to: CGPoint(x: 11 * s, y: 13.5 * s))
        p.move(to: CGPoint(x: 8 * s, y: 16.5 * s))
        p.addLine(to: CGPoint(x: 14 * s, y: 16.5 * s))
        return p
    }
}

private struct AccountsIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var p = Path()
        p.move(to: CGPoint(x: 3 * s, y: 10 * s))
        p.addLine(to: CGPoint(x: 12 * s, y: 4 * s))
        p.addLine(to: CGPoint(x: 21 * s, y: 10 * s))
        for x: CGFloat in [5, 10, 14, 19] {
            p.move(to: CGPoint(x: x * s, y: 10 * s))
            p.addLine(to: CGPoint(x: x * s, y: 19 * s))
        }
        p.move(to: CGPoint(x: 3 * s, y: 19 * s))
        p.addLine(to: CGPoint(x: 21 * s, y: 19 * s))
        return p
    }
}

private struct AddIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var p = Path()
        p.move(to: CGPoint(x: 12 * s, y: 4 * s))
        p.addLine(to: CGPoint(x: 12 * s, y: 20 * s))
        p.move(to: CGPoint(x: 4 * s, y: 12 * s))
        p.addLine(to: CGPoint(x: 20 * s, y: 12 * s))
        return p
    }
}

private struct InsightsIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        var p = Path()
        p.move(to: CGPoint(x: 4 * s, y: 20 * s))
        p.addLine(to: CGPoint(x: 4 * s, y: 11 * s))
        p.move(to: CGPoint(x: 11 * s, y: 20 * s))
        p.addLine(to: CGPoint(x: 11 * s, y: 6 * s))
        p.move(to: CGPoint(x: 18 * s, y: 20 * s))
        p.addLine(to: CGPoint(x: 18 * s, y: 7 * s))
        return p
    }
}
