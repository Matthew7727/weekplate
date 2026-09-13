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
    private var weights: [WeightEntry] { store.data.weights.sorted { $0.date < $1.date } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeading(eyebrow: "The bigger picture", title: "TRENDS.",
                              subtitle: "See your rhythm beyond one day.", alignment: .center)
                rhythmCard
                Eyebrow(text: "Last 8 weeks", color: Brand.blue)
                weeklyChart
                weeklyReadout
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

    private var rhythmCard: some View {
        let loggedWeeks = completedWeeks.filter { $0.consumed > 0 }
        let average = loggedWeeks.isEmpty ? nil : loggedWeeks.reduce(0) { $0 + $1.consumed } / Double(loggedWeeks.count)
        let best = loggedWeeks.max { WeekMath.adherence($0.consumed, goal: $0.goal) < WeekMath.adherence($1.consumed, goal: $1.goal) }
        return WCard(color: Brand.blue) {
            VStack(alignment: .center, spacing: 10) {
                Eyebrow(text: "Your rhythm", color: .white.opacity(0.72))
                Text(average.map { $0.kcalText } ?? "—")
                    .font(.system(size: 44, weight: .black))
                Text(average == nil ? "Log a full week to see your average." : "average kcal across your logged weeks")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Divider().overlay(.white.opacity(0.3))
                HStack(spacing: 22) {
                    VStack(spacing: 2) {
                        Text("\(loggedWeeks.count)").font(.title3.bold())
                        Text("weeks logged").font(.caption)
                    }
                    VStack(spacing: 2) {
                        Text(best?.id.formatted(.dateTime.day().month(.abbreviated)) ?? "—")
                            .font(.title3.bold())
                        Text("closest week").font(.caption)
                    }
                }
                .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
        }
    }

    private var weeklyChart: some View {
        let highest = max(weeks.map(\.goal).max() ?? 1, weeks.map(\.consumed).max() ?? 1)
        return WCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Calories by week").font(.headline)
                    Spacer()
                    Text("Target shown as line").font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weeks) { week in
                        VStack(spacing: 7) {
                            GeometryReader { proxy in
                                ZStack(alignment: .bottom) {
                                    Rectangle().fill(Brand.blue.opacity(0.12)).frame(height: proxy.size.height)
                                    Rectangle().fill(week.consumed > week.goal ? Brand.coral : Brand.blue)
                                        .frame(height: max(4, proxy.size.height * min(week.consumed / highest, 1)))
                                    Rectangle().fill(Brand.coral).frame(height: 2)
                                        .offset(y: -proxy.size.height * (1 - min(week.goal / highest, 1)))
                                }
                            }
                            .frame(height: 130)
                            Text(week.id.formatted(.dateTime.month(.abbreviated)))
                                .font(.caption2.bold())
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var weeklyReadout: some View {
        return WCard {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Trend note", color: Brand.blue)
                Text("Look for a steady pattern, not a perfect line.")
                    .font(.headline)
                Text("Trends are here to show direction, not perfection. Keep logging and the picture gets clearer.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
