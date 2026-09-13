import SwiftUI

enum MacroKind: String, CaseIterable, Identifiable {
    case carbs = "Carbs", protein = "Protein", fat = "Fat"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .carbs: Brand.blue
        case .protein: Brand.coral
        case .fat: Brand.lilac
        }
    }
    func amount(in totals: MacroTotals) -> Double {
        switch self {
        case .carbs: totals.carbs
        case .protein: totals.protein
        case .fat: totals.fat
        }
    }
}

struct MacroProgressRow: View {
    let kind: MacroKind
    let consumed: Double
    let goal: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle().fill(kind.color).frame(width: 9, height: 9)
                Text(kind.rawValue).font(.system(size: 15, weight: .bold))
                Spacer()
                Text("\(consumed.formatted(.number.precision(.fractionLength(0...1)))) / \(goal.formatted(.number.precision(.fractionLength(0...1)))) g")
                    .font(.system(size: 13, weight: .bold))
                    .contentTransition(.numericText())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(kind.color.opacity(0.16))
                    Rectangle().fill(kind.color)
                        .frame(width: proxy.size.width * min(consumed / max(goal, 1), 1))
                }
            }
            .frame(height: 9)
            .animation(.spring(response: 0.65, dampingFraction: 0.78), value: consumed)
            .animation(.spring(response: 0.65, dampingFraction: 0.78), value: goal)
        }
    }
}

struct MacroSummaryCard: View {
    let consumed: MacroTotals
    let goal: MacroTotals
    let missingEntries: Int

    var body: some View {
        WCard {
            VStack(alignment: .leading, spacing: 17) {
                Eyebrow(text: "Macro balance", color: Brand.blue)
                ForEach(MacroKind.allCases) { kind in
                    MacroProgressRow(kind: kind,
                                     consumed: kind.amount(in: consumed),
                                     goal: kind.amount(in: goal))
                }
                if missingEntries > 0 {
                    Text("\(missingEntries) calorie-only log\(missingEntries == 1 ? "" : "s") not included in macro totals.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
