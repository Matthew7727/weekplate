import Charts
import SwiftUI

private struct WeekPoint: Identifiable {
    let id: Date
    let consumed: Double
    let goal: Double
    let macros: MacroTotals
    let macroGoal: MacroTotals
}

struct TrendsView: View {
    @ObservedObject var store: AppStore

    private var weeks: [WeekPoint] {
        (0..<8).reversed().compactMap { offset in
            guard let date = WeekMath.calendar.date(byAdding: .weekOfYear, value: -offset, to: Date()) else { return nil }
            return WeekPoint(id: WeekMath.start(of: date),
                             consumed: WeekMath.total(store.data.foodEntries, inWeekOf: date),
                             goal: store.data.goal(for: date),
                             macros: WeekMath.macros(store.data.foodEntries, inWeekOf: date),
                             macroGoal: store.data.macroGoal(for: date).scaled(by: 7))
        }
    }

    private var completedWeeks: [WeekPoint] { Array(weeks.dropLast()) }
    private var averageAdherence: Double? {
        let active = completedWeeks.filter { $0.consumed > 0 }
        guard !active.isEmpty else { return nil }
        return active.reduce(0) { $0 + WeekMath.adherence($1.consumed, goal: $1.goal) } / Double(active.count)
    }
    private var weights: [WeightEntry] { store.data.weights.sorted { $0.date < $1.date } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeading(eyebrow: "The bigger picture", title: "TRENDS.",
                              subtitle: "See your rhythm beyond one day.")
                WCard(color: Brand.lilac) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "Weeks near target", color: .black.opacity(0.65))
                        Text(averageAdherence.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                        Text("Average closeness to your weekly goal across completed weeks with logs.")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.black)
                }
                Eyebrow(text: "Last 8 weeks", color: Brand.blue)
                ForEach(weeks) { week in
                    WCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(week.id.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.headline)
                                Spacer()
                                Text("\(week.consumed.kcalText) / \(week.goal.kcalText)")
                                    .font(.subheadline.bold())
                            }
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Brand.blue.opacity(0.15))
                                    Capsule().fill(Brand.coral)
                                        .frame(width: proxy.size.width * min(week.consumed / max(week.goal, 1), 1))
                                }
                            }
                            .frame(height: 9)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: week.consumed)
                            ForEach(MacroKind.allCases) { kind in
                                MacroProgressRow(kind: kind,
                                                 consumed: kind.amount(in: week.macros),
                                                 goal: kind.amount(in: week.macroGoal))
                            }
                        }
                    }
                }
                Eyebrow(text: "Weight trend", color: Brand.blue)
                if weights.isEmpty {
                    WCard { Text("Add weigh-ins in You to see a trend and a four-week projection.") }
                } else {
                    WCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Latest: \(weights.last!.kilograms.formatted(.number.precision(.fractionLength(1)))) kg")
                                .font(.title3.bold())
                            if weights.count >= 2 {
                                Chart(weights) { entry in
                                    LineMark(x: .value("Date", entry.date),
                                             y: .value("Weight", entry.kilograms))
                                        .foregroundStyle(Brand.blue)
                                    PointMark(x: .value("Date", entry.date),
                                              y: .value("Weight", entry.kilograms))
                                        .foregroundStyle(Brand.coral)
                                }
                                .frame(height: 190)
                            }
                            if let target = store.data.targetWeightKg {
                                Text("Your target: \(target.formatted(.number.precision(.fractionLength(1)))) kg")
                                    .font(.subheadline.bold()).foregroundStyle(Brand.coral)
                            }
                            if let projection = WeightTrend.projectedKilograms(weights, daysAhead: 28) {
                                Text("At this pace: ~\(projection.formatted(.number.precision(.fractionLength(1)))) kg in 4 weeks")
                                    .font(.headline).foregroundStyle(Brand.blue)
                                Text("A straight-line estimate from your weigh-ins; real weight can vary.")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Add another weigh-in on a different day for a trend estimate.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}
