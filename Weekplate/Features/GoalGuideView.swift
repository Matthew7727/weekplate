import SwiftUI

struct GoalGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var store: AppStore
    @State private var profile: GoalProfile
    @State private var step = 0

    init(store: AppStore) {
        self.store = store
        var starting = store.data.goalProfile ?? GoalProfile()
        if store.data.goalProfile == nil,
           let weight = store.data.weights.max(by: { $0.date < $1.date }) {
            starting.weightKg = weight.kilograms
        }
        _profile = State(initialValue: starting)
    }

    private var estimate: GoalEstimate? { GoalEstimator.estimate(profile) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 7) {
                        ForEach(0..<3, id: \.self) { index in
                            Rectangle().fill(index <= step ? Brand.coral : Brand.blue.opacity(0.16))
                                .frame(height: 7)
                        }
                    }
                    ScreenHeading(eyebrow: "Step \(step + 1) of 3", title: title,
                                  subtitle: subtitle)
                    switch step {
                    case 0: bodyInputs
                    case 1: routineInputs
                    default: resultView
                    }
                    Spacer(minLength: 16)
                    if step < 2 {
                        PillButton(title: "Continue", symbol: "arrow.right", color: Brand.blue) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { step += 1 }
                        }
                        .disabled(estimate == nil)
                    } else {
                        PillButton(title: "Use these goals", symbol: "checkmark", color: Brand.coral) {
                            store.setEstimatedGoal(profile)
                            dismiss()
                        }
                        .disabled(estimate == nil)
                    }
                }
                .padding(20)
            }
            .background(Brand.background(scheme))
            .navigationTitle("Goal guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == 0 ? "Cancel" : "Back") {
                        if step == 0 { dismiss() }
                        else { withAnimation { step -= 1 } }
                    }
                }
            }
        }
    }

    private var title: String {
        switch step {
        case 0: "START WITH YOU."
        case 1: "YOUR REAL WEEK."
        default: "A STARTING POINT."
        }
    }

    private var subtitle: String {
        switch step {
        case 0: "A few measurements help estimate your resting energy."
        case 1: "Choose the routine and goal that feel most like yours."
        default: "Review the estimate, then fine-tune it as you track."
        }
    }

    private var bodyInputs: some View {
        VStack(spacing: 14) {
            WCard {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Your starting point", color: Brand.blue)
                    numberField("Age", value: $profile.ageYears, unit: "years")
                    numberField("Height", value: $profile.heightCm, unit: "cm")
                    numberField("Current weight", value: $profile.weightKg, unit: "kg")
                }
            }
            WCard {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Resting energy method", color: Brand.blue)
                    Picker("Equation", selection: $profile.restingMethod) {
                        ForEach(RestingMethod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    if profile.restingMethod == .custom {
                        numberField("Known resting estimate", value: $profile.customRestingKcal, unit: "kcal/day")
                    }
                    Text("The Mifflin–St Jeor study published male and female equation constants. Choose the one that fits, or enter a resting estimate you already know.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if estimate == nil {
                Text("Enter valid adult measurements and choose a resting energy method to continue.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var routineInputs: some View {
        VStack(spacing: 14) {
            WCard {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Movement", color: Brand.blue)
                    Text("Think about your whole week: work, walking and workouts.")
                        .font(.subheadline)
                    Picker("Typical activity", selection: $profile.activity) {
                        ForEach(ActivityLevel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
            WCard {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Training", color: Brand.blue)
                    Picker("Training focus", selection: $profile.training) {
                        ForEach(TrainingFocus.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Text("Training focus shapes the suggested protein target.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            WCard {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "What you want", color: Brand.blue)
                    Picker("Goal", selection: $profile.direction) {
                        ForEach(GoalDirection.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Text("Gradual loss starts 10% below estimated maintenance; gradual gain starts 5% above.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resultView: some View {
        VStack(spacing: 14) {
            if let estimate {
                WCard(color: Brand.lime) {
                    VStack(alignment: .leading, spacing: 9) {
                        Eyebrow(text: "Your daily starting target", color: .black.opacity(0.6))
                        Text("\(estimate.dailyMacros.calories.kcalText) kcal")
                            .font(.system(size: 42, weight: .black))
                        Text("\((estimate.dailyMacros.calories * 7).kcalText) kcal across a week")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.black)
                }
                WCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "How we got there", color: Brand.blue)
                        resultLine("Resting estimate", value: estimate.restingKcal)
                        resultLine("Maintenance / TDEE", value: estimate.tdeeKcal)
                        resultLine("Adjusted for your goal", value: estimate.targetKcal)
                    }
                }
                WCard {
                    VStack(alignment: .leading, spacing: 11) {
                        Eyebrow(text: "Suggested daily macros", color: Brand.blue)
                        ForEach(MacroKind.allCases) { kind in
                            HStack {
                                Circle().fill(kind.color).frame(width: 10, height: 10)
                                Text(kind.rawValue).font(.headline)
                                Spacer()
                                Text("\(kind.amount(in: estimate.dailyMacros).kcalText) g")
                                    .font(.headline)
                            }
                        }
                    }
                }
                Text("TDEE is an estimate, not a measurement. Watch your weight trend and energy over time, then adjust the macro goals in Settings. This guide is for adults and does not account for medical needs.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func resultLine(_ title: String, value: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value.kcalText) kcal").fontWeight(.bold)
        }
        .font(.subheadline)
    }

    private func numberField(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title).font(.subheadline.bold())
            Spacer()
            TextField(title, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func numberField(_ title: String, value: Binding<Int>, unit: String) -> some View {
        HStack {
            Text(title).font(.subheadline.bold())
            Spacer()
            TextField(title, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}
