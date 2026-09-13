import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AppStore
    @State private var carbsText = ""
    @State private var proteinText = ""
    @State private var fatText = ""
    @State private var editingPeriod: GoalPeriod = .weekly
    @State private var showGoalGuide = false
    @State private var targetWeightText = ""
    @State private var newWeightText = ""
    @State private var weightDate = Date()

    private var latestWeight: WeightEntry? {
        store.data.weights.max { $0.date < $1.date }
    }
    private var period: GoalPeriod { editingPeriod }
    private var periodBinding: Binding<GoalPeriod> {
        Binding(get: { editingPeriod }, set: { newPeriod in
            guard newPeriod != editingPeriod else { return }
            let factor = newPeriod.factor / editingPeriod.factor
            if let value = Double(carbsText) { carbsText = String(Int((value * factor).rounded())) }
            if let value = Double(proteinText) { proteinText = String(Int((value * factor).rounded())) }
            if let value = Double(fatText) { fatText = String(Int((value * factor).rounded())) }
            editingPeriod = newPeriod
            if let value = Double(carbsText) { carbsText = String(Int(value.rounded())) }
            store.setGoalPeriod(newPeriod)
        })
    }
    private var proposedGoal: MacroTotals? {
        guard let carbs = Int(carbsText), let protein = Int(proteinText),
              let fat = Int(fatText) else { return nil }
        let goal = MacroTotals(carbs: Double(carbs), protein: Double(protein), fat: Double(fat))
        return goal.isValid ? goal : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeading(eyebrow: "Your settings", title: "YOUR PACE.",
                              subtitle: "Set a target that works for you.", alignment: .center)
                WCard(color: Brand.coral) {
                    VStack(alignment: .center, spacing: 10) {
                        Eyebrow(text: "\(period.rawValue) goal", color: .white.opacity(0.75))
                        Text("\(store.data.dailyMacroGoal.scaled(by: period.factor).calories.kcalText) kcal")
                            .font(.system(size: 37, weight: .black))
                            .contentTransition(.numericText())
                        Text("Set by your carb, protein and fat goals")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white)
                }
                WCard {
                    VStack(alignment: .center, spacing: 12) {
                        Eyebrow(text: "Build your target", color: Brand.blue)
                        Text("Want a starting point based on your day, training and goals?")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        PillButton(title: "Guide me to a goal", symbol: "sparkles", color: Brand.blue) {
                            showGoalGuide = true
                        }
                        Picker("Goal period", selection: periodBinding) {
                            ForEach(GoalPeriod.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        goalField("Carbs", text: $carbsText, color: Brand.blue)
                        goalField("Protein", text: $proteinText, color: Brand.coral)
                        goalField("Fat", text: $fatText, color: Brand.lilac)
                        Text("\((proposedGoal?.calories ?? 0).kcalText) kcal / \(period.rawValue.lowercased()) from 4 kcal/g carbs, 4 protein, 9 fat")
                            .font(.subheadline.bold())
                            .contentTransition(.numericText())
                        PillButton(title: "Set goal", symbol: "checkmark", color: Brand.blue) {
                            guard let proposedGoal else { return }
                            store.setMacroGoal(proposedGoal, period: period)
                            loadGoalFields()
                        }
                        .disabled(proposedGoal == nil)
                    }
                }
                WCard {
                    VStack(alignment: .center, spacing: 12) {
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
                    VStack(alignment: .center, spacing: 12) {
                        Eyebrow(text: "Appearance", color: Brand.blue)
                        Picker("Theme", selection: $store.data.theme) {
                            ForEach(AppTheme.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if let error = store.storageError {
                    Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Text("Weekplate keeps your recipes and logs on this device. Weeks run Monday to Sunday.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .onAppear {
            targetWeightText = store.data.targetWeightKg.map { String($0) } ?? ""
            editingPeriod = store.data.goalPeriod
            loadGoalFields()
        }
        .sheet(isPresented: $showGoalGuide, onDismiss: loadGoalFields) {
            GoalGuideView(store: store)
        }
    }

    private func goalField(_ title: String, text: Binding<String>, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title).font(.subheadline.bold()).frame(width: 70, alignment: .leading)
            TextField("Whole grams", text: text)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let wholeNumber = newValue.filter { $0.isNumber }
                    if wholeNumber != newValue { text.wrappedValue = wholeNumber }
                }
            Text("g").foregroundStyle(.secondary)
        }
    }

    private func loadGoalFields() {
        let goal = store.data.dailyMacroGoal.scaled(by: period.factor)
        carbsText = String(Int(goal.carbs.rounded()))
        proteinText = String(Int(goal.protein.rounded()))
        fatText = String(Int(goal.fat.rounded()))
    }

    private func saveTargetWeight() {
        if targetWeightText.isEmpty {
            store.data.targetWeightKg = nil
        } else if let value = Double(targetWeightText), value > 0 {
            store.data.targetWeightKg = value
        }
    }
}
