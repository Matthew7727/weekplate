import Foundation
import SwiftUI

struct ActionToast: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
}

@MainActor final class AppStore: ObservableObject {
    @Published var data: AppData { didSet { save() } }
    @Published var storageError: String?
    @Published var toast: ActionToast?

    private let fileURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Weekplate", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("weekplate.json")
        if let bytes = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: bytes) {
            data = decoded
        } else {
            data = AppData()
        }
    }

    private func save() {
        do {
            let bytes = try JSONEncoder().encode(data)
            try bytes.write(to: fileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "Could not save your changes: \(error.localizedDescription)"
        }
    }

    func upsert(_ recipe: Recipe) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if let index = data.recipes.firstIndex(where: { $0.id == recipe.id }) {
                data.recipes[index] = recipe
            } else {
                data.recipes.append(recipe)
            }
        }
        announce("Recipe saved", symbol: "fork.knife")
    }

    func upsertPantryIngredient(_ ingredient: PantryIngredient) {
        if let index = data.pantryIngredients.firstIndex(where: { $0.id == ingredient.id }) {
            data.pantryIngredients[index] = ingredient
        } else {
            data.pantryIngredients.append(ingredient)
        }
        announce("Ingredient saved", symbol: "basket.fill")
    }

    func removePantryIngredient(_ id: UUID) {
        data.pantryIngredients.removeAll { $0.id == id }
    }

    func removeRecipe(_ id: UUID) {
        data.recipes.removeAll { $0.id == id }
        data.plan.removeAll { $0.recipeID == id }
    }

    func add(_ entry: FoodEntry) {
        withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) { data.foodEntries.append(entry) }
        announce("Meal logged!", symbol: "sparkles")
    }
    func add(_ item: PlanItem) {
        withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) { data.plan.append(item) }
        announce("Added to your plan", symbol: "calendar.badge.checkmark")
    }
    func removePlan(_ id: UUID) { data.plan.removeAll { $0.id == id } }
    func addWeight(_ kilograms: Double, date: Date) {
        data.weights.append(WeightEntry(date: date, kilograms: kilograms))
        announce("Weigh-in saved", symbol: "chart.line.uptrend.xyaxis")
    }

    func setMacroGoal(_ macros: MacroTotals, period: GoalPeriod) {
        guard macros.isValid else { return }
        let daily = macros.scaled(by: 1 / period.factor)
        let week = WeekMath.start(of: Date())
        var next = data
        next.goalPeriod = period
        next.dailyMacroGoal = daily
        next.macroGoalHistory.removeAll { $0.effectiveWeek == week }
        next.macroGoalHistory.append(MacroGoalChange(effectiveWeek: week, dailyMacros: daily))
        next.goalHistory.removeAll { $0.effectiveWeek == week }
        next.goalHistory.append(GoalChange(effectiveWeek: week, calories: daily.calories * 7))
        next.weeklyGoal = daily.calories * 7
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { data = next }
        announce("Goals set!", symbol: "target")
    }

    func setGoalPeriod(_ period: GoalPeriod) {
        guard data.goalPeriod != period else { return }
        var next = data
        next.goalPeriod = period
        data = next
    }

    func setEstimatedGoal(_ profile: GoalProfile) {
        guard let estimate = GoalEstimator.estimate(profile) else { return }
        let displayPeriod = data.goalPeriod
        setMacroGoal(estimate.dailyMacros, period: .daily)
        data.goalPeriod = displayPeriod
        data.goalProfile = profile
    }

    func logPlanned(_ item: PlanItem) {
        guard item.loggedEntryID == nil,
              let recipe = data.recipes.first(where: { $0.id == item.recipeID }),
              recipe.hasNutrition,
              let index = data.plan.firstIndex(where: { $0.id == item.id }) else { return }
        let entry = FoodEntry(name: recipe.name, calories: recipe.calories(for: item.servings),
                              date: item.date, meal: item.meal, source: .recipe,
                              servings: item.servings, recipeID: recipe.id,
                              macros: recipe.macros(for: item.servings))
        withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
            data.foodEntries.append(entry)
            data.plan[index].loggedEntryID = entry.id
        }
        announce("Prep paid off!", symbol: "sparkles")
    }

    func removeEntry(_ id: UUID) {
        data.foodEntries.removeAll { $0.id == id }
        for index in data.plan.indices where data.plan[index].loggedEntryID == id {
            data.plan[index].loggedEntryID = nil
        }
    }

    func importText(_ text: String) -> Int {
        let recipes = RecipeTextImporter.parse(text)
        data.recipes.append(contentsOf: recipes)
        if !recipes.isEmpty { announce("Recipes imported", symbol: "book.closed.fill") }
        return recipes.count
    }

    private func announce(_ title: String, symbol: String) {
        let notice = ActionToast(title: title, symbol: symbol)
        toast = notice
        Task {
            try? await Task.sleep(for: .seconds(2.1))
            if toast?.id == notice.id { toast = nil }
        }
    }
}
