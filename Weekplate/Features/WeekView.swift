import SwiftUI

struct WeekView: View {
    @ObservedObject var store: AppStore
    @State private var week = Date()
    @State private var selectedDay = Date()
    @State private var showLog = false
    @State private var showPlan = false

    private var days: [Date] { WeekMath.days(of: week) }
    private var period: GoalPeriod { store.data.goalPeriod }
    private var consumed: Double {
        period == .weekly ? WeekMath.total(store.data.foodEntries, inWeekOf: week)
                           : WeekMath.total(store.data.foodEntries, on: selectedDay)
    }
    private var consumedMacros: MacroTotals {
        period == .weekly ? WeekMath.macros(store.data.foodEntries, inWeekOf: week)
                           : WeekMath.macros(store.data.foodEntries, on: selectedDay)
    }
    private var macroGoal: MacroTotals {
        store.data.macroGoal(for: period == .weekly ? week : selectedDay)
            .scaled(by: period.factor)
    }
    private var missingMacroCount: Int {
        store.data.foodEntries.filter {
            $0.macros == nil && (period == .weekly
                ? WeekMath.start(of: $0.date) == WeekMath.start(of: week)
                : WeekMath.calendar.isDate($0.date, inSameDayAs: selectedDay))
        }.count
    }
    private var selectedPlans: [PlanItem] {
        store.data.plan.filter { WeekMath.calendar.isDate($0.date, inSameDayAs: selectedDay) }
            .sorted { $0.meal.rawValue < $1.meal.rawValue }
    }
    private var selectedEntries: [FoodEntry] {
        store.data.foodEntries.filter { WeekMath.calendar.isDate($0.date, inSameDayAs: selectedDay) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeading(eyebrow: "Meal prep, meet momentum", title: "YOUR WEEK.",
                              subtitle: "Plan it Sunday. Make it yours every day.")
                periodSwitcher
                hero
                MacroSummaryCard(consumed: consumedMacros, goal: macroGoal,
                                 missingEntries: missingMacroCount)
                weekNavigator
                dayStrip
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: selectedDay.formatted(.dateTime.weekday(.wide)), color: Brand.blue)
                        Text("On the plate").font(.system(size: 25, weight: .black, design: .rounded))
                    }
                    Spacer()
                    PillButton(title: "Plan", symbol: "plus", color: Brand.blue) { showPlan = true }
                }
                if selectedPlans.isEmpty && selectedEntries.isEmpty {
                    WCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                                .font(.largeTitle).foregroundStyle(Brand.coral)
                            Text("A blank plate, for now.").font(.headline)
                            Text("Plan a recipe or log something you ate.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(selectedPlans) { item in
                    planRow(item)
                }
                ForEach(selectedEntries) { entry in
                    entryRow(entry)
                }
                PillButton(title: "Log something else", symbol: "plus.circle.fill") { showLog = true }
                    .padding(.bottom, 25)
            }
            .padding(20)
        }
        .sheet(isPresented: $showLog) { ManualFoodView(store: store, date: selectedDay) }
        .sheet(isPresented: $showPlan) { PlanRecipeView(store: store, date: selectedDay) }
    }

    private var periodSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(GoalPeriod.allCases) { option in
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        store.data.goalPeriod = option
                    }
                } label: {
                    Text(option.rawValue.uppercased())
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(period == option ? .white : .secondary)
                        .padding(.horizontal, 20).padding(.vertical, 11)
                        .background(period == option ? Brand.blue : .clear, in: Capsule())
                }
                .buttonStyle(MotionButtonStyle())
            }
        }
        .padding(5)
        .background(Brand.blue.opacity(0.12), in: Capsule())
    }

    private var hero: some View {
        WCard(color: Brand.lime) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Eyebrow(text: "\(period.rawValue) intake", color: .black.opacity(0.65))
                    Spacer()
                    Image(systemName: "bolt.fill").font(.title2)
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(consumed.kcalText)
                        .font(.system(size: 49, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                    Text("/ \(macroGoal.calories.kcalText) kcal")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.black.opacity(0.15))
                        Capsule().fill(Brand.coral)
                            .frame(width: proxy.size.width * min(consumed / max(macroGoal.calories, 1), 1))
                    }
                }
                .frame(height: 12)
                Text(consumed <= macroGoal.calories
                     ? "\((macroGoal.calories - consumed).kcalText) kcal left in your \(period.rawValue.lowercased()) target"
                     : "\((consumed - macroGoal.calories).kcalText) kcal above your \(period.rawValue.lowercased()) target")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.black)
        }
        .animation(.spring(response: 0.65, dampingFraction: 0.8), value: consumed)
    }

    private var weekNavigator: some View {
        HStack {
            Button { shift(-7) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text("\(days[0].formatted(.dateTime.day().month(.abbreviated))) – \(days[6].formatted(.dateTime.day().month(.abbreviated)))")
                .font(.system(size: 18, weight: .black, design: .rounded))
            Spacer()
            Button { shift(7) } label: { Image(systemName: "chevron.right") }
        }
        .buttonStyle(.plain)
    }

    private var dayStrip: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let value = WeekMath.total(store.data.foodEntries, on: day)
                let isSelected = WeekMath.calendar.isDate(day, inSameDayAs: selectedDay)
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedDay = day } } label: {
                    VStack(spacing: 8) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                        Text(day.formatted(.dateTime.day()))
                            .font(.system(size: 17, weight: .black, design: .rounded))
                        Capsule()
                            .fill(value > 0 ? Brand.coral : Color.gray.opacity(0.3))
                            .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12).padding(.horizontal, 3)
                    .background(isSelected ? Brand.blue : Color.clear, in: RoundedRectangle(cornerRadius: 17))
                    .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(MotionButtonStyle())
            }
        }
    }

    private func planRow(_ item: PlanItem) -> some View {
        let recipe = store.data.recipes.first { $0.id == item.recipeID }
        return WCard {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 13).fill(Brand.lilac).frame(width: 43, height: 43)
                    .overlay(Image(systemName: "fork.knife").foregroundStyle(.black))
                VStack(alignment: .leading, spacing: 3) {
                    Text(recipe?.name ?? "Deleted recipe").font(.headline)
                    Text("\(item.meal.rawValue) · \(item.servings.portionText) portions · \((recipe?.calories(for: item.servings) ?? 0).kcalText) kcal")
                        .font(.caption).foregroundStyle(.secondary)
                    if let macros = recipe?.macros(for: item.servings) {
                        Text("C \(macros.carbs.portionText) · P \(macros.protein.portionText) · F \(macros.fat.portionText) g")
                            .font(.caption2).foregroundStyle(Brand.blue)
                    }
                }
                Spacer()
                if item.loggedEntryID == nil {
                    Button("Eat") { store.logPlanned(item) }
                        .font(.subheadline.bold()).foregroundStyle(Brand.blue)
                        .disabled(recipe?.hasNutrition != true)
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.coral)
                }
                Button { store.removePlan(item.id) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Remove planned \(recipe?.name ?? "meal")")
            }
        }
    }

    private func entryRow(_ entry: FoodEntry) -> some View {
        WCard {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name).font(.headline)
                    Text("\(entry.meal.rawValue) · \(entry.source.rawValue.capitalized)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let macros = entry.macros {
                        Text("C \(macros.carbs.portionText) · P \(macros.protein.portionText) · F \(macros.fat.portionText) g")
                            .font(.caption2).foregroundStyle(Brand.blue)
                    }
                }
                Spacer()
                Text("\(entry.calories.kcalText)").font(.headline)
                Button { store.removeEntry(entry.id) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Remove \(entry.name)")
            }
        }
    }

    private func shift(_ days: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            week = WeekMath.calendar.date(byAdding: .day, value: days, to: week) ?? week
            selectedDay = WeekMath.start(of: week)
        }
    }
}

struct PlanRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    @State var date: Date
    @State private var recipeID: UUID?
    @State private var servings = 1.0
    @State private var meal: Meal = .lunch

    var body: some View {
        NavigationStack {
            Form {
                if store.data.recipes.isEmpty {
                    Text("Add a recipe first in the Recipes tab.")
                } else {
                    Picker("Recipe", selection: $recipeID) {
                        Text("Choose a recipe").tag(nil as UUID?)
                        ForEach(store.data.recipes) { recipe in
                            Text(recipe.name).tag(recipe.id as UUID?)
                        }
                    }
                    DatePicker("Day", selection: $date, displayedComponents: .date)
                    Picker("Meal", selection: $meal) {
                        ForEach(Meal.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("\(servings.portionText) portions", value: $servings, in: 0.5...20, step: 0.5)
                    if let recipe = store.data.recipes.first(where: { $0.id == recipeID }) {
                        Text("\(recipe.calories(for: servings).kcalText) kcal planned")
                            .foregroundStyle(.secondary)
                        if let macros = recipe.macros(for: servings) {
                            Text("C \(macros.carbs.portionText) · P \(macros.protein.portionText) · F \(macros.fat.portionText) g")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Plan a meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let recipeID {
                            store.add(PlanItem(recipeID: recipeID, date: date, meal: meal, servings: servings))
                            dismiss()
                        }
                    }
                    .disabled(recipeID == nil)
                }
            }
        }
    }
}

struct ManualFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    @State var date: Date
    @State var name = ""
    @State var calories = 0.0
    @State var meal: Meal = .snack
    @State var source: EntrySource = .manual
    @State private var carbsText = ""
    @State private var proteinText = ""
    @State private var fatText = ""

    private var anyMacroEntered: Bool {
        !carbsText.isEmpty || !proteinText.isEmpty || !fatText.isEmpty
    }
    private var macros: MacroTotals? {
        guard let carbs = Double(carbsText), let protein = Double(proteinText),
              let fat = Double(fatText) else { return nil }
        let totals = MacroTotals(carbs: carbs, protein: protein, fat: fat)
        return totals.isValid ? totals : nil
    }
    private var caloriesToLog: Double { calories > 0 ? calories : (macros?.calories ?? 0) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("What did you eat?", text: $name)
                Section("Energy") {
                    TextField("Calories eaten", value: $calories, format: .number)
                        .keyboardType(.decimalPad)
                    Text("If you leave calories at zero, complete macros will calculate them.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Macros in grams (optional)") {
                    TextField("Carbs", text: $carbsText).keyboardType(.decimalPad)
                    TextField("Protein", text: $proteinText).keyboardType(.decimalPad)
                    TextField("Fat", text: $fatText).keyboardType(.decimalPad)
                    if let macros {
                        Text("Macro estimate: \(macros.calories.kcalText) kcal")
                            .font(.subheadline.bold())
                    } else if anyMacroEntered {
                        Text("Enter all three macros to track them.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                DatePicker("Day", selection: $date, displayedComponents: .date)
                Picker("Meal", selection: $meal) {
                    ForEach(Meal.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .navigationTitle("Log food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.add(FoodEntry(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                            calories: caloriesToLog, date: date, meal: meal,
                                            source: source, macros: macros))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              caloriesToLog <= 0 || (anyMacroEntered && macros == nil))
                }
            }
        }
    }
}
