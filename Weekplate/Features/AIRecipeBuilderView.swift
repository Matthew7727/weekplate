import SwiftUI

struct PantryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                if store.data.pantryIngredients.isEmpty {
                    ContentUnavailableView("Your pantry is empty", systemImage: "basket",
                                           description: Text("Save ingredients here to ask AI to cook with what you have."))
                } else {
                    ForEach(store.data.pantryIngredients.sorted { $0.name < $1.name }) { ingredient in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ingredient.name).font(.headline)
                            Text("C \(ingredient.macrosPer100g.carbs.portionText) · P \(ingredient.macrosPer100g.protein.portionText) · F \(ingredient.macrosPer100g.fat.portionText) g / 100\(ingredient.unit.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(ingredient.source.rawValue).font(.caption2.bold()).foregroundStyle(Brand.blue)
                        }
                    }
                    .onDelete { offsets in
                        let sorted = store.data.pantryIngredients.sorted { $0.name < $1.name }
                        for index in offsets { store.removePantryIngredient(sorted[index].id) }
                    }
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Add") { showNew = true } }
            }
            .sheet(isPresented: $showNew) { PantryIngredientEditor(store: store) }
        }
    }
}

private struct PantryIngredientEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    @State private var name = ""
    @State private var kcal = ""
    @State private var carbs = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var unit: FoodUnit = .grams

    private var macros: MacroTotals? {
        guard let carbs = Double(carbs), let protein = Double(protein), let fat = Double(fat) else { return nil }
        let value = MacroTotals(carbs: carbs, protein: protein, fat: fat)
        return value.isValid ? value : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") { TextField("Name", text: $name) }
                Section("Nutrition per 100") {
                    Picker("Unit", selection: $unit) {
                        Text("g").tag(FoodUnit.grams)
                        Text("ml").tag(FoodUnit.millilitres)
                    }
                    TextField("Kcal", text: $kcal).keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbs).keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add pantry item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let macros else { return }
                        store.upsertPantryIngredient(PantryIngredient(name: name, kcalPer100g: Double(kcal) ?? macros.calories,
                                                                     macrosPer100g: macros, unit: unit))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || macros == nil)
                }
            }
        }
    }
}

struct AIRecipeBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    let onRecipeSaved: (Recipe) -> Void
    @State private var servings = 4.0
    @State private var carbs = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var vibe = "Italian"
    @State private var maxMinutes = 35.0
    @State private var constraints = ""
    @State private var mode: AIIngredientMode = .pantryFirst
    @State private var selectedPantryIDs = Set<UUID>()
    @State private var isGenerating = false
    @State private var error: String?
    @State private var draft: AIRecipeDraft?
    @State private var generationRequest: AIRecipeRequest?
    @State private var showReview = false
    @State private var showPantry = false

    init(store: AppStore, onRecipeSaved: @escaping (Recipe) -> Void = { _ in }) {
        self.store = store
        self.onRecipeSaved = onRecipeSaved
    }

    private var targets: MacroTotals? {
        guard let carbs = Double(carbs), let protein = Double(protein), let fat = Double(fat) else { return nil }
        let value = MacroTotals(carbs: carbs, protein: protein, fat: fat)
        return value.isValid ? value : nil
    }
    private var chosenPantry: [PantryIngredient] {
        store.data.pantryIngredients.filter { selectedPantryIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your target per portion") {
                    TextField("Carbs (g)", text: $carbs).keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat).keyboardType(.decimalPad)
                    if let targets { Text("\(targets.calories.kcalText) kcal from your macro target").font(.caption).foregroundStyle(.secondary) }
                    Stepper("Makes \(Int(servings)) portions", value: $servings, in: 1...12, step: 1)
                }
                Section("Recipe brief") {
                    TextField("Vibe, e.g. Italian", text: $vibe)
                    Stepper("Up to \(Int(maxMinutes)) minutes", value: $maxMinutes, in: 10...90, step: 5)
                    TextField("Avoid, equipment, or other notes", text: $constraints, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Ingredients") {
                    Picker("Mode", selection: $mode) {
                        ForEach(AIIngredientMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if !store.data.pantryIngredients.isEmpty && mode != .aiChooses {
                        ForEach(store.data.pantryIngredients.sorted { $0.name < $1.name }) { item in
                            Toggle(item.name, isOn: Binding(get: { selectedPantryIDs.contains(item.id) }, set: { enabled in
                                if enabled { selectedPantryIDs.insert(item.id) } else { selectedPantryIDs.remove(item.id) }
                            }))
                        }
                    } else if store.data.pantryIngredients.isEmpty {
                        Text("No pantry items yet. AI can still use familiar UK-supermarket ingredients.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button("Manage pantry") { showPantry = true }.font(.subheadline.bold())
                }
                Section {
                    Text("Claude will only suggest familiar UK-supermarket ingredients. Nutrition for new items is an estimate to review before saving.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        Task { await generate() }
                    } label: {
                        HStack { Spacer(); if isGenerating { ProgressView().tint(.white) }; Text(isGenerating ? "Building recipe…" : "Generate recipe"); Spacer() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Brand.blue)
                    .disabled(targets == nil || vibe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating || (mode == .pantryOnly && chosenPantry.isEmpty))
                }
            }
            .navigationTitle("Create with AI")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear {
                let goal = store.data.macroGoal(for: Date())
                carbs = goal.carbs.portionText; protein = goal.protein.portionText; fat = goal.fat.portionText
            }
            .sheet(isPresented: $showPantry) { PantryView(store: store) }
            .sheet(isPresented: $showReview) {
                if let draft, let generationRequest {
                    AIRecipeReviewView(store: store, draft: draft, request: generationRequest) { recipe in
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onRecipeSaved(recipe)
                        }
                    }
                }
            }
            .alert("Couldn’t build recipe", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func generate() async {
        guard let targets else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let request = AIRecipeRequest(targetsPerServing: targets, servings: Int(servings),
                vibe: vibe, maxMinutes: Int(maxMinutes), constraints: constraints, mode: mode, pantry: chosenPantry)
            draft = try await ClaudeRecipeService().generate(request)
            generationRequest = request
            showReview = draft != nil
        } catch { self.error = error.localizedDescription }
    }
}

private struct AIRecipeReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    let request: AIRecipeRequest
    let onRecipeSaved: (Recipe) -> Void
    @State private var draft: AIRecipeDraft
    @State private var saveSuggested = true
    @State private var showEditor = false
    @State private var feedback = ""
    @State private var isRegenerating = false
    @State private var error: String?
    @FocusState private var feedbackFocused: Bool

    init(store: AppStore, draft: AIRecipeDraft, request: AIRecipeRequest,
         onRecipeSaved: @escaping (Recipe) -> Void) {
        self.store = store
        self.request = request
        self.onRecipeSaved = onRecipeSaved
        _draft = State(initialValue: draft)
    }

    private var recipe: Recipe { draft.recipe }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeading(eyebrow: "AI recipe draft", title: draft.name.uppercased(),
                                  subtitle: "Review estimates before saving")
                    WCard(color: Brand.lime) {
                        VStack(alignment: .leading, spacing: 7) {
                            Eyebrow(text: "Whole batch", color: .black.opacity(0.6))
                            if let total = recipe.totalMacros {
                                Text("C \(total.carbs.portionText) · P \(total.protein.portionText) · F \(total.fat.portionText) g")
                                    .font(.title3.bold())
                            }
                            Text("\(recipe.totalCalories.kcalText) kcal · \(draft.servings.portionText) portions")
                                .font(.subheadline)
                        }.foregroundStyle(.black)
                    }
                    if let perServing = recipe.macrosPerServing {
                        WCard {
                            VStack(alignment: .leading, spacing: 5) {
                                Eyebrow(text: "Per portion", color: Brand.blue)
                                Text("C \(perServing.carbs.portionText) · P \(perServing.protein.portionText) · F \(perServing.fat.portionText) g")
                                    .font(.headline)
                                Text("\(recipe.caloriesPerServing.kcalText) kcal")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Eyebrow(text: "Ingredients", color: Brand.blue)
                    ForEach(draft.ingredients) { ingredient in
                        WCard {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack { Text(ingredient.name).font(.headline); Spacer(); Text("\(ingredient.amount.portionText) \(ingredient.unit.rawValue)").foregroundStyle(Brand.blue) }
                                let macro = ingredient.asIngredient().macros ?? .zero
                                Text("C \(macro.carbs.portionText) · P \(macro.protein.portionText) · F \(macro.fat.portionText) g")
                                    .font(.caption).foregroundStyle(.secondary)
                                if ingredient.origin == .suggested { Text("AI nutrition estimate").font(.caption2.bold()).foregroundStyle(Brand.coral) }
                                Button("Swap this ingredient") {
                                    feedback = "Replace \(ingredient.name) with a common UK-supermarket alternative that better fits the recipe and macro target."
                                    feedbackFocused = true
                                }
                                .font(.caption.bold()).foregroundStyle(Brand.blue)
                            }
                        }
                    }
                    WCard(color: Brand.blue) {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "Change the recipe", color: .white.opacity(0.75))
                            Text("Tell Claude what to swap or change. It will rebuild this draft around the same targets.")
                                .font(.subheadline)
                            TextField("e.g. No mushrooms, more protein, make it spicy…", text: $feedback, axis: .vertical)
                                .focused($feedbackFocused)
                                .lineLimit(2...4)
                                .padding(10).background(.white, in: Rectangle()).foregroundStyle(.black)
                            Button {
                                Task { await regenerate() }
                            } label: {
                                HStack { Spacer(); if isRegenerating { ProgressView().tint(Brand.blue) }; Text(isRegenerating ? "Updating recipe…" : "Regenerate with feedback"); Spacer() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .foregroundStyle(Brand.blue)
                            .disabled(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRegenerating)
                        }
                        .foregroundStyle(.white)
                    }
                    Toggle("Save suggested ingredients to Pantry", isOn: $saveSuggested)
                    Text("You can edit every amount and nutrition value before saving.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        PillButton(title: "Edit", symbol: "pencil", color: Brand.blue) { showEditor = true }
                        PillButton(title: "Save recipe", symbol: "checkmark", color: Brand.coral) { save() }
                    }
                }.padding(20)
            }
            .navigationTitle("Review recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .sheet(isPresented: $showEditor) { RecipeEditorView(store: store, existing: recipe) }
            .alert("Couldn’t update recipe", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }

    private func save() {
        if saveSuggested {
            for ingredient in draft.ingredients where ingredient.origin == .suggested {
                store.upsertPantryIngredient(PantryIngredient(name: ingredient.name, kcalPer100g: ingredient.kcalPer100g,
                    macrosPer100g: ingredient.macrosPer100g, unit: ingredient.unit, source: .aiEstimate))
            }
        }
        store.upsert(recipe)
        dismiss()
        onRecipeSaved(recipe)
    }

    private func regenerate() async {
        let message = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        isRegenerating = true
        defer { isRegenerating = false }
        do {
            draft = try await ClaudeRecipeService().refine(request, currentDraft: draft, feedback: message)
            feedback = ""
            feedbackFocused = false
        } catch {
            self.error = error.localizedDescription
        }
    }
}
