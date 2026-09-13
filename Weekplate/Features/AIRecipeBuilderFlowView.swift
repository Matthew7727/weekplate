import SwiftUI

private enum AIRecipeFlowStep: Int, CaseIterable, Identifiable {
    case fuel, flavour, pantry, guardrails, summary
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .fuel: "Set the target."
        case .flavour: "Pick the direction."
        case .pantry: "Choose your ingredients."
        case .guardrails: "Add your rules."
        case .summary: "Make it yours."
        }
    }
    var subtitle: String {
        switch self {
        case .fuel: "Tell AI what one portion needs to do for you."
        case .flavour: "Give the recipe a mood and a time limit."
        case .pantry: "Start with what is already in your kitchen."
        case .guardrails: "Anything to avoid, use up, or work around?"
        case .summary: "Check the brief before Weekplate starts cooking."
        }
    }
}

struct AIRecipeBuilderFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: AppStore
    let onRecipeSaved: (Recipe) -> Void

    @State private var step: AIRecipeFlowStep = .fuel
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
    @State private var showGeneration = false
    @State private var generationPhase = 0
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
    private var chosenPantry: [PantryIngredient] { store.data.pantryIngredients.filter { selectedPantryIDs.contains($0.id) } }
    private var canContinue: Bool {
        switch step {
        case .fuel: targets != nil
        case .flavour: !vibe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .pantry: mode != .pantryOnly || !chosenPantry.isEmpty
        case .guardrails, .summary: true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                progress
                TabView(selection: $step) {
                    fuelPage.tag(AIRecipeFlowStep.fuel)
                    flavourPage.tag(AIRecipeFlowStep.flavour)
                    pantryPage.tag(AIRecipeFlowStep.pantry)
                    guardrailsPage.tag(AIRecipeFlowStep.guardrails)
                    summaryPage.tag(AIRecipeFlowStep.summary)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                footer
            }
            .background(Brand.background(colorScheme).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { loadDefaults() }
            .sheet(isPresented: $showPantry) { PantryView(store: store) }
            .sheet(isPresented: $showReview) {
                if let draft, let generationRequest {
                    AIRecipeReviewView(store: store, draft: draft, request: generationRequest) { recipe in
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onRecipeSaved(recipe) }
                    }
                }
            }
            .fullScreenCover(isPresented: $showGeneration) {
                AIRecipeGenerationView(phase: $generationPhase, isGenerating: isGenerating, error: error,
                                       onRetry: { Task { await generate() } },
                                       onBack: { showGeneration = false; error = nil })
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: "Create with AI", color: Brand.blue)
                Text(step.title.uppercased()).font(.system(size: 28, weight: .black)).tracking(-1)
            }
            Spacer()
            Button("Close") { dismiss() }.font(.subheadline.bold()).foregroundStyle(Brand.blue)
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }

    private var progress: some View {
        HStack(spacing: 5) {
            ForEach(AIRecipeFlowStep.allCases) { item in
                Rectangle().fill(item.rawValue <= step.rawValue ? Brand.coral : Brand.blue.opacity(0.16)).frame(height: 5)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var footer: some View {
        HStack {
            if step != .fuel {
                Button { withAnimation { step = AIRecipeFlowStep(rawValue: step.rawValue - 1)! } } label: {
                    Label("Back", systemImage: "arrow.left").font(.subheadline.bold()).foregroundStyle(Brand.blue)
                }
            }
            Spacer()
            if step == .summary {
                PillButton(title: "Generate", symbol: "sparkles", color: Brand.coral) { Task { await generate() } }
            } else {
                PillButton(title: "Continue", symbol: "arrow.right", color: Brand.blue) {
                    guard canContinue else { return }
                    withAnimation { step = AIRecipeFlowStep(rawValue: step.rawValue + 1)! }
                }.opacity(canContinue ? 1 : 0.45)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }

    private func page(_ step: AIRecipeFlowStep, @ViewBuilder content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(step.subtitle).font(.subheadline).foregroundStyle(.secondary)
                content()
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var fuelPage: some View {
        page(.fuel) {
            WCard {
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: "Per portion", color: Brand.blue)
                    HStack(spacing: 8) {
                        macroField("Carbs", text: $carbs, color: Brand.blue)
                        macroField("Protein", text: $protein, color: Brand.coral)
                        macroField("Fat", text: $fat, color: Brand.lilac)
                    }
                    if let targets { Text("\(targets.calories.kcalText) kcal from your macro target").font(.caption.bold()).foregroundStyle(Brand.blue) }
                }
            }
            WCard(color: Brand.lime) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Eyebrow(text: "Batch size", color: .black.opacity(0.55)); Text("Makes \(Int(servings)) portions").font(.title3.bold()) }
                    Spacer(); Stepper("", value: $servings, in: 1...12, step: 1).labelsHidden()
                }.foregroundStyle(.black)
            }
        }
    }

    private var flavourPage: some View {
        page(.flavour) {
            WCard(color: Brand.lilac) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Recipe mood", color: .black.opacity(0.55))
                    TextField("Italian, smoky, fresh…", text: $vibe).font(.title3.bold()).padding(12).background(.white, in: Rectangle()).foregroundStyle(.black)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(["Italian", "Mexican", "Comfort food", "Fresh", "Spicy"], id: \.self) { option in
                            Button(option) { vibe = option }.font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 9).background(.black.opacity(0.1), in: Rectangle()).foregroundStyle(.black)
                        } }
                    }
                }.foregroundStyle(.black)
            }
            WCard {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Time limit", color: Brand.blue)
                    HStack { Text("Up to \(Int(maxMinutes)) minutes").font(.headline); Spacer(); Stepper("", value: $maxMinutes, in: 10...90, step: 5).labelsHidden() }
                }
            }
        }
    }

    private var pantryPage: some View {
        page(.pantry) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(AIIngredientMode.allCases) { option in
                    Button { mode = option } label: {
                        HStack { Image(systemName: mode == option ? "checkmark.square.fill" : "square").font(.title3); VStack(alignment: .leading) { Text(option.rawValue).font(.headline); Text(modeDescription(option)).font(.caption).foregroundStyle(.secondary) }; Spacer() }
                            .foregroundStyle(mode == option ? Brand.blue : .primary).padding(15).background(mode == option ? Brand.blue.opacity(0.1) : Brand.surface(colorScheme), in: Rectangle()).overlay(Rectangle().stroke(Brand.ink(colorScheme).opacity(0.12)))
                    }.buttonStyle(.plain)
                }
            }
            if !store.data.pantryIngredients.isEmpty && mode != .aiChooses {
                WCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Use these", color: Brand.blue)
                        ForEach(store.data.pantryIngredients.sorted { $0.name < $1.name }) { item in
                            Button { togglePantry(item.id) } label: { HStack { Image(systemName: selectedPantryIDs.contains(item.id) ? "checkmark.square.fill" : "square"); Text(item.name); Spacer() }.foregroundStyle(selectedPantryIDs.contains(item.id) ? Brand.blue : .primary) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            Button("Manage pantry") { showPantry = true }.font(.subheadline.bold()).foregroundStyle(Brand.blue)
        }
    }

    private var guardrailsPage: some View {
        page(.guardrails) {
            WCard(color: Brand.blue) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Your brief", color: .white.opacity(0.7))
                    Text("Tell AI what to avoid or work around.").font(.headline)
                    TextEditor(text: $constraints).frame(minHeight: 150).padding(8).background(.white, in: Rectangle()).foregroundStyle(.black)
                    Text("Optional · allergies, equipment, ingredients to use up, or anything else.").font(.caption).foregroundStyle(.white.opacity(0.72))
                }.foregroundStyle(.white)
            }
        }
    }

    private var summaryPage: some View {
        page(.summary) {
            if let targets {
                WCard(color: Brand.lime) { VStack(alignment: .leading, spacing: 6) { Eyebrow(text: "Target", color: .black.opacity(0.55)); Text("C \(targets.carbs.portionText) · P \(targets.protein.portionText) · F \(targets.fat.portionText) g").font(.title3.bold()); Text("\(targets.calories.kcalText) kcal · \(Int(servings)) portions").font(.subheadline) }.foregroundStyle(.black) }
            }
            summaryRow("Flavour", value: "\(vibe) · up to \(Int(maxMinutes)) min", step: .flavour)
            summaryRow("Ingredients", value: mode.rawValue + (chosenPantry.isEmpty ? "" : " · \(chosenPantry.map(\.name).joined(separator: ", "))"), step: .pantry)
            summaryRow("Guardrails", value: constraints.isEmpty ? "None added" : constraints, step: .guardrails)
            Text("Nutrition for new ingredients is an estimate. You’ll review everything before saving.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func summaryRow(_ title: String, value: String, step target: AIRecipeFlowStep) -> some View {
        Button { withAnimation { step = target } } label: {
            HStack(alignment: .top) { VStack(alignment: .leading, spacing: 4) { Eyebrow(text: title, color: Brand.blue); Text(value).font(.headline).multilineTextAlignment(.leading) }; Spacer(); Image(systemName: "pencil").foregroundStyle(Brand.blue) }
                .padding(16).background(Brand.surface(colorScheme), in: Rectangle()).overlay(Rectangle().stroke(Brand.ink(colorScheme).opacity(0.12)))
        }.buttonStyle(.plain)
    }

    private func macroField(_ title: String, text: Binding<String>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).font(.caption.bold()).foregroundStyle(color); TextField("0", text: text).keyboardType(.decimalPad).font(.title3.bold()).padding(10).background(color.opacity(0.1), in: Rectangle()) }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func modeDescription(_ mode: AIIngredientMode) -> String {
        switch mode { case .pantryOnly: "Only use ingredients you select"; case .pantryFirst: "Prioritise what you already have"; case .aiChooses: "Let AI build the shopping list" }
    }
    private func togglePantry(_ id: UUID) { if selectedPantryIDs.contains(id) { selectedPantryIDs.remove(id) } else { selectedPantryIDs.insert(id) } }
    private func loadDefaults() { guard carbs.isEmpty else { return }; let goal = store.data.macroGoal(for: Date()); carbs = goal.carbs.portionText; protein = goal.protein.portionText; fat = goal.fat.portionText }

    private func generate() async {
        guard let targets else { return }
        error = nil; isGenerating = true; generationPhase = 0; showGeneration = true
        do {
            let request = AIRecipeRequest(targetsPerServing: targets, servings: Int(servings), vibe: vibe, maxMinutes: Int(maxMinutes), constraints: constraints, mode: mode, pantry: chosenPantry)
            draft = try await ClaudeRecipeService().generate(request); generationRequest = request
            isGenerating = false; showGeneration = false; showReview = draft != nil
        } catch let generationError { isGenerating = false; error = generationError.localizedDescription }
    }
}

private struct AIRecipeGenerationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var phase: Int
    let isGenerating: Bool
    let error: String?
    let onRetry: () -> Void
    let onBack: () -> Void
    private let phases = ["Reading your targets", "Finding the flavour", "Balancing the batch", "Plating the draft"]
    @State private var spinning = false

    var body: some View {
        ZStack {
            Brand.blue.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle().fill(Brand.coral).frame(width: 250, height: 250)
                    Circle().fill(Brand.lime).frame(width: 190, height: 190)
                    ForEach(0..<8, id: \.self) { index in Circle().fill(Brand.blue).frame(width: 13, height: 13).offset(y: -78).rotationEffect(.degrees(Double(index) * 45)) }
                    Image(systemName: "fork.knife").font(.system(size: 58, weight: .black)).foregroundStyle(Brand.blue)
                }.rotationEffect(.degrees(spinning ? 360 : 0))
                Text(error == nil ? phases[min(phase, phases.count - 1)].uppercased() : "THE KITCHEN HIT A SNAG").font(.system(size: 18, weight: .black)).tracking(1.2).foregroundStyle(.white).multilineTextAlignment(.center)
                if let error {
                    Text(error).font(.subheadline).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center).padding(.horizontal, 28)
                    HStack { PillButton(title: "Try again", symbol: "arrow.clockwise", color: Brand.coral, action: onRetry); Button("Back to summary", action: onBack).font(.subheadline.bold()).foregroundStyle(.white) }
                } else { Text("Weekplate is building a recipe around your brief.").font(.subheadline).foregroundStyle(.white.opacity(0.7)) }
                Spacer()
            }.padding(24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) { spinning = true }
            Task { @MainActor in
                while isGenerating && phase < phases.count - 1 { try? await Task.sleep(for: .seconds(2.2)); if isGenerating { withAnimation { phase += 1 } } }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(error == nil ? "Generating recipe. \(phases[min(phase, phases.count - 1)])" : "Recipe generation failed. \(error ?? "")")
    }
}
