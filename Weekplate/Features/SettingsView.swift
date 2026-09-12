import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var carbsText = ""
    @State private var proteinText = ""
    @State private var fatText = ""
    @State private var targetWeightText = ""
    @State private var newWeightText = ""
    @State private var weightDate = Date()

    private var latestWeight: WeightEntry? {
        store.data.weights.max { $0.date < $1.date }
    }
    private var period: GoalPeriod { store.data.goalPeriod }
    private var proposedGoal: MacroTotals? {
        guard let carbs = Double(carbsText), let protein = Double(proteinText),
              let fat = Double(fatText) else { return nil }
        let goal = MacroTotals(carbs: carbs, protein: protein, fat: fat)
        return goal.isValid ? goal : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeading(eyebrow: "Your settings", title: "YOUR PACE.",
                              subtitle: "Set a target that works for you.")
                WCard(color: Brand.coral) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "\(period.rawValue) goal", color: .white.opacity(0.75))
                        Text("\(store.data.dailyMacroGoal.scaled(by: period.factor).calories.kcalText) kcal")
                            .font(.system(size: 37, weight: .black, design: .rounded))
                            .contentTransition(.numericText())
                        Text("Set by your carb, protein and fat goals")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white)
                }
                WCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Build your target", color: Brand.blue)
                        Picker("Goal period", selection: $store.data.goalPeriod) {
                            ForEach(GoalPeriod.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: store.data.goalPeriod) { old, new in
                            let factor = new.factor / old.factor
                            if let value = Double(carbsText) { carbsText = (value * factor).portionText }
                            if let value = Double(proteinText) { proteinText = (value * factor).portionText }
                            if let value = Double(fatText) { fatText = (value * factor).portionText }
                        }
                        goalField("Carbs", text: $carbsText, color: Brand.blue)
                        goalField("Protein", text: $proteinText, color: Brand.coral)
                        goalField("Fat", text: $fatText, color: Brand.lilac)
                        Text("\((proposedGoal?.calories ?? 0).kcalText) kcal / \(period.rawValue.lowercased()) from 4 kcal/g carbs, 4 protein, 9 fat")
                            .font(.subheadline.bold())
                            .contentTransition(.numericText())
                        PillButton(title: "Set goal", symbol: "checkmark", color: Brand.blue) {
                            if let proposedGoal { store.setMacroGoal(proposedGoal, period: period) }
                        }
                        .disabled(proposedGoal == nil)
                    }
                }
                WCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Weight", color: Brand.blue)
                        if let latestWeight {
                            Text("Latest: \(latestWeight.kilograms.formatted(.number.precision(.fractionLength(1)))) kg")
                                .font(.headline)
                        }
                        HStack {
                            TextField("New weigh-in (kg)", text: $newWeightText)
                                .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                            DatePicker("Date", selection: $weightDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        PillButton(title: "Add weigh-in", symbol: "plus", color: Brand.blue) {
                            if let value = Double(newWeightText), value > 0 {
                                store.addWeight(value, date: weightDate)
                                newWeightText = ""
                            }
                        }
                        .disabled((Double(newWeightText) ?? 0) <= 0)
                        TextField("Target weight in kg (optional)", text: $targetWeightText)
                            .keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                            .onSubmit { saveTargetWeight() }
                        Button("Save weight target") { saveTargetWeight() }
                            .font(.subheadline.bold()).foregroundStyle(Brand.blue)
                    }
                }
                WCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Appearance", color: Brand.blue)
                        Picker("Theme", selection: $store.data.theme) {
                            ForEach(AppTheme.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if let error = store.storageError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                Text("Weekplate keeps your recipes and logs on this device. Weeks run Monday to Sunday.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .onAppear {
            targetWeightText = store.data.targetWeightKg.map { String($0) } ?? ""
            loadGoalFields()
        }
    }

    private func goalField(_ title: String, text: Binding<String>, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title).font(.subheadline.bold()).frame(width: 70, alignment: .leading)
            TextField("Grams", text: text).keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
            Text("g").foregroundStyle(.secondary)
        }
    }

    private func loadGoalFields() {
        let goal = store.data.dailyMacroGoal.scaled(by: period.factor)
        carbsText = goal.carbs.portionText
        proteinText = goal.protein.portionText
        fatText = goal.fat.portionText
    }

    private func saveTargetWeight() {
        if targetWeightText.isEmpty {
            store.data.targetWeightKg = nil
        } else if let value = Double(targetWeightText), value > 0 {
            store.data.targetWeightKg = value
        }
    }
}
