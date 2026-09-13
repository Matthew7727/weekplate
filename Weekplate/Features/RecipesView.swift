import SwiftUI

struct RecipesView: View {
    @ObservedObject var store: AppStore
    @State private var showNew = false
    @State private var showAIBuilder = false
    @State private var showPantry = false
    @State private var selectedRecipe: Recipe?
    @AppStorage("weekplate.aiEnabled") private var aiEnabled = false

    private var aiAvailable: Bool { aiEnabled && ClaudeKeychain.hasKey }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeading(eyebrow: "Your kitchen, organised", title: "RECIPES.",
                              subtitle: "Build a batch. Flex the portions.", alignment: .center)
                HStack(spacing: 7) {
                    RecipeActionButton(title: "New recipe", symbol: "plus", color: Brand.coral) { showNew = true }
                    if aiAvailable {
                        RecipeActionButton(title: "Create with AI", symbol: "sparkles", color: Brand.blue) { showAIBuilder = true }
                    }
                    RecipeActionButton(title: "Pantry", symbol: "basket", color: Brand.lilac) { showPantry = true }
                }
                .frame(maxWidth: .infinity)
                if store.data.recipes.isEmpty {
                    WCard(color: Brand.lilac) {
                        VStack(alignment: .leading, spacing: 9) {
                            Image(systemName: "book.closed.fill").font(.largeTitle)
                            Text("Start with Sunday’s staples.")
                                .font(.system(size: 23, weight: .black))
                            Text("Add a recipe to start building your weekly staples. You can add calorie values as you go.")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.black)
                    }
                }
                ForEach(store.data.recipes.sorted { $0.createdAt > $1.createdAt }) { recipe in
                    Button { selectedRecipe = recipe } label: {
                        WCard {
                            HStack(alignment: .top, spacing: 15) {
                                Rectangle().fill(Brand.coral)
                                    .frame(width: 54, height: 54)
                                    .overlay(Image(systemName: "fork.knife").font(.title2).foregroundStyle(.white))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(recipe.name).font(.system(size: 19, weight: .black))
                                    Text("Batch of \(recipe.batchServings.portionText) · \(recipe.ingredients.count) ingredients")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(recipe.hasNutrition ? "\(recipe.caloriesPerServing.kcalText) kcal / portion" : "Add nutrition to log")
                                        .font(.subheadline.bold()).foregroundStyle(Brand.blue)
                                    if let macros = recipe.macrosPerServing {
                                        Text("C \(macros.carbs.portionText) · P \(macros.protein.portionText) · F \(macros.fat.portionText) g")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.removeRecipe(recipe.id)
                        } label: {
                            Label("Delete recipe", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(20)
        }
        .sheet(isPresented: $showNew) { RecipeEditorView(store: store) }
        .sheet(isPresented: $showAIBuilder) {
            AIRecipeBuilderFlowView(store: store) { _ in
                showAIBuilder = false
            }
        }
        .sheet(isPresented: $showPantry) { PantryView(store: store) }
        .sheet(item: $selectedRecipe) { recipe in RecipeDetailView(store: store, recipeID: recipe.id) }
    }
}

private struct RecipeActionButton: View {
    let title: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(color == Brand.lilac ? .black : .white)
                .padding(.horizontal, 9)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(color, in: Rectangle())
        }
        .buttonStyle(MotionButtonStyle())
    }
}

struct RecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    let recipeID: UUID
    @State private var portions = 1.0
    @State private var date = Date()
    @State private var meal: Meal = .lunch
    @State private var showEditor = false
    @State private var showDelete = false

    private var recipe: Recipe? { store.data.recipes.first { $0.id == recipeID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let recipe {
                    VStack(alignment: .leading, spacing: 20) {
                        ScreenHeading(eyebrow: "Batch recipe", title: recipe.name.uppercased(),
                                      subtitle: "Original batch makes \(recipe.batchServings.portionText) portions",
                                      alignment: .center)
                        WCard(color: Brand.lime) {
                            VStack(alignment: .leading, spacing: 10) {
                                Eyebrow(text: "Make it yours", color: .black.opacity(0.6))
                                Stepper("\(portions.portionText) portions", value: $portions, in: 0.5...20, step: 0.5)
                                    .font(.title3.bold())
                                Text(recipe.hasNutrition ? "\(recipe.calories(for: portions).kcalText) kcal" : "Nutrition needed")
                                    .font(.system(size: 35, weight: .black))
                                    .contentTransition(.numericText())
                            }
                            .foregroundStyle(.black)
                        }
                        if let macros = recipe.macros(for: portions) {
                            WCard {
                                VStack(alignment: .leading, spacing: 9) {
                                    Eyebrow(text: "For your portions", color: Brand.blue)
                                    Text("Carbs \(macros.carbs.portionText) g · Protein \(macros.protein.portionText) g · Fat \(macros.fat.portionText) g")
                                        .font(.subheadline.bold())
                                        .contentTransition(.numericText())
                                }
                            }
                        }
                        if !recipe.ingredients.isEmpty {
                            Eyebrow(text: "Ingredients", color: Brand.blue)
                            ForEach(recipe.ingredients) { ingredient in
                                WCard {
                                    HStack {
                                        Text(ingredient.name).font(.headline)
                                        Spacer()
                                        Text("\(recipe.ingredientGrams(ingredient, for: portions).rounded().formatted()) \(ingredient.unit.rawValue)")
                                            .font(.headline).foregroundStyle(Brand.blue)
                                    }
                                }
                            }
                        }
                        if !recipe.notes.isEmpty {
                            WCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Eyebrow(text: "Method & notes")
                                    Text(recipe.notes).font(.subheadline)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        DatePicker("Day", selection: $date, displayedComponents: .date)
                        Picker("Meal", selection: $meal) {
                            ForEach(Meal.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            PillButton(title: "Plan this", symbol: "calendar", color: Brand.blue) {
                                store.add(PlanItem(recipeID: recipe.id, date: date, meal: meal, servings: portions))
                                dismiss()
                            }
                            PillButton(title: "Log now", symbol: "checkmark", color: Brand.coral) {
                                store.add(FoodEntry(name: recipe.name, calories: recipe.calories(for: portions),
                                                    date: date, meal: meal, source: .recipe,
                                                    servings: portions, recipeID: recipe.id,
                                                    macros: recipe.macros(for: portions)))
                                dismiss()
                            }
                            .disabled(!recipe.hasNutrition)
                        }
                        Button("Delete recipe", role: .destructive) { showDelete = true }
                            .font(.subheadline.bold())
                    }
                    .padding(20)
                    .animation(.spring(response: 0.38, dampingFraction: 0.78), value: portions)
                }
            }
            .navigationTitle("Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Edit") { showEditor = true } }
                ToolbarItem(placement: .secondaryAction) {
                    Button(role: .destructive) { showDelete = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete recipe")
                }
            }
            .sheet(isPresented: $showEditor) {
                if let recipe { RecipeEditorView(store: store, existing: recipe) }
            }
            .confirmationDialog("Delete this recipe and its planned meals?", isPresented: $showDelete) {
                Button("Delete recipe", role: .destructive) {
                    store.removeRecipe(recipeID)
                    dismiss()
                }
            }
        }
    }
}

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    @State private var recipe: Recipe
    @State private var manualCalories = ""
    @State private var manualCarbs = ""
    @State private var manualProtein = ""
    @State private var manualFat = ""

    init(store: AppStore, existing: Recipe? = nil) {
        self.store = store
        _recipe = State(initialValue: existing ?? Recipe(name: "", batchServings: 4))
        _manualCalories = State(initialValue: existing?.manualCaloriesPerServing.map { String($0) } ?? "")
        _manualCarbs = State(initialValue: existing?.manualMacrosPerServing.map { String($0.carbs) } ?? "")
        _manualProtein = State(initialValue: existing?.manualMacrosPerServing.map { String($0.protein) } ?? "")
        _manualFat = State(initialValue: existing?.manualMacrosPerServing.map { String($0.fat) } ?? "")
    }

    private var anyManualMacro: Bool { !manualCarbs.isEmpty || !manualProtein.isEmpty || !manualFat.isEmpty }
    private var parsedManualMacros: MacroTotals? {
        guard let carbs = Double(manualCarbs), let protein = Double(manualProtein),
              let fat = Double(manualFat) else { return nil }
        let totals = MacroTotals(carbs: carbs, protein: protein, fat: fat)
        return totals.isValid ? totals : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $recipe.name)
                    Stepper("Batch makes \(recipe.batchServings.portionText) portions",
                            value: $recipe.batchServings, in: 1...40, step: 1)
                }
                Section {
                    TextField("Kcal per portion (optional)", text: $manualCalories)
                        .keyboardType(.decimalPad)
                    Text("If entered, this overrides the ingredient total.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: { Text("Quick calorie value") }
                Section("Macros per portion") {
                    TextField("Carbs (g)", text: $manualCarbs).keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $manualProtein).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $manualFat).keyboardType(.decimalPad)
                    Text("Enter all three for a quick recipe, or add them ingredient by ingredient below.")
                        .font(.caption).foregroundStyle(.secondary)
                    if let parsedManualMacros {
                        Text("Macro estimate: \(parsedManualMacros.calories.kcalText) kcal / portion")
                            .font(.subheadline.bold())
                    }
                }
                Section("Ingredients") {
                    ForEach($recipe.ingredients) { $ingredient in
                        IngredientEditorRow(ingredient: $ingredient) {
                            recipe.ingredients.removeAll { $0.id == ingredient.id }
                        }
                    }
                    Button("Add ingredient") {
                        recipe.ingredients.append(Ingredient(name: "", grams: 100, kcalPer100g: 0))
                    }
                }
                Section("Method & notes") {
                    TextEditor(text: $recipe.notes).frame(minHeight: 150)
                }
            }
            .navigationTitle(recipe.name.isEmpty ? "New recipe" : "Edit recipe")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let manual = Double(manualCalories)
                        recipe.manualCaloriesPerServing = (manual ?? 0) > 0 ? manual : nil
                        recipe.manualMacrosPerServing = parsedManualMacros
                        recipe.ingredients.removeAll { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }
                        store.upsert(recipe)
                        dismiss()
                    }
                    .disabled(recipe.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              (anyManualMacro && parsedManualMacros == nil))
                }
            }
        }
    }
}

private struct IngredientEditorRow: View {
    @Binding var ingredient: Ingredient
    let onDelete: () -> Void

    private func macroBinding(_ keyPath: WritableKeyPath<MacroTotals, Double>) -> Binding<Double> {
        Binding(get: { ingredient.macrosPer100g?[keyPath: keyPath] ?? 0 }, set: { value in
            var macros = ingredient.macrosPer100g ?? .zero
            macros[keyPath: keyPath] = value
            ingredient.macrosPer100g = macros
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Ingredient", text: $ingredient.name)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
            }
            HStack {
                TextField("Batch amount", value: $ingredient.grams, format: .number)
                    .keyboardType(.decimalPad)
                Picker("Unit", selection: $ingredient.unit) {
                    Text("g").tag(FoodUnit.grams)
                    Text("ml").tag(FoodUnit.millilitres)
                }
                .labelsHidden().pickerStyle(.menu)
                TextField("Kcal / 100\(ingredient.unit.rawValue)", value: $ingredient.kcalPer100g, format: .number)
                    .keyboardType(.decimalPad)
            }
            if ingredient.macrosPer100g == nil {
                Button("Add carbs, protein & fat") { ingredient.macrosPer100g = .zero }
                    .font(.caption.bold()).foregroundStyle(Brand.blue)
            } else {
                HStack {
                    TextField("C /100\(ingredient.unit.rawValue)", value: macroBinding(\.carbs), format: .number)
                    TextField("P /100\(ingredient.unit.rawValue)", value: macroBinding(\.protein), format: .number)
                    TextField("F /100\(ingredient.unit.rawValue)", value: macroBinding(\.fat), format: .number)
                }
                .keyboardType(.decimalPad)
                Button("Remove macro values") { ingredient.macrosPer100g = nil }
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
