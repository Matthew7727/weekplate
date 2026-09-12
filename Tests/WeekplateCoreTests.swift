import XCTest
@testable import WeekplateCore

final class WeekplateCoreTests: XCTestCase {
    func testBatchPortionsScaleIngredientsAndCalories() {
        let chicken = Ingredient(name: "Chicken", grams: 800, kcalPer100g: 165)
        let recipe = Recipe(name: "Chicken bowls", batchServings: 4, ingredients: [chicken])
        XCTAssertEqual(recipe.caloriesPerServing, 330, accuracy: 0.001)
        XCTAssertEqual(recipe.calories(for: 1.5), 495, accuracy: 0.001)
        XCTAssertEqual(recipe.ingredientGrams(chicken, for: 1.5), 300, accuracy: 0.001)
        XCTAssertFalse(Recipe(name: "Draft", batchServings: 2,
                              ingredients: [Ingredient(name: "Unknown", grams: 100, kcalPer100g: 0)]).hasNutrition)
    }

    func testWeeklyTotalsUseMondayBoundary() {
        let monday = WeekMath.start(of: Date())
        let previousSunday = WeekMath.calendar.date(byAdding: .day, value: -1, to: monday)!
        let tuesday = WeekMath.calendar.date(byAdding: .day, value: 1, to: monday)!
        let entries = [
            FoodEntry(name: "Old", calories: 500, date: previousSunday, meal: .dinner, source: .manual),
            FoodEntry(name: "Current", calories: 650, date: tuesday, meal: .lunch, source: .recipe)
        ]
        XCTAssertEqual(WeekMath.total(entries, inWeekOf: monday), 650)
    }

    func testRecipeImportPreservesTextAndMultipleHeadings() {
        let recipes = RecipeTextImporter.parse("# Lentil chilli\nServings: 4 portions\nSimmer lentils\n---\nRecipe: Oat pots\nServings: 2\nMix oats")
        XCTAssertEqual(recipes.count, 2)
        XCTAssertEqual(recipes[0].name, "Lentil chilli")
        XCTAssertEqual(recipes[0].batchServings, 4)
        XCTAssertTrue(recipes[0].notes.contains("Simmer lentils"))
        XCTAssertFalse(recipes[0].hasNutrition)
    }

    func testWeightTrendNeedsDistinctDays() {
        let now = Date()
        let later = WeekMath.calendar.date(byAdding: .day, value: 14, to: now)!
        let weights = [WeightEntry(date: now, kilograms: 80), WeightEntry(date: later, kilograms: 79)]
        XCTAssertEqual(WeightTrend.projectedKilograms(weights, daysAhead: 28)!, 77, accuracy: 0.001)
        XCTAssertNil(WeightTrend.projectedKilograms([weights[0]], daysAhead: 28))
    }

    func testGoalHistoryDoesNotRewriteEarlierWeeks() {
        var data = AppData()
        let current = WeekMath.start(of: Date())
        let previous = WeekMath.calendar.date(byAdding: .day, value: -7, to: current)!
        data.goalHistory = [GoalChange(effectiveWeek: current, calories: 12_000)]
        XCTAssertEqual(data.goal(for: previous), 14_000)
        XCTAssertEqual(data.goal(for: current), 12_000)
    }

    func testMacroGoalsAndRecipePortions() {
        let goal = MacroTotals(carbs: 220, protein: 145, fat: 60)
        XCTAssertEqual(goal.calories, 2_000)
        XCTAssertEqual(goal.scaled(by: 7).calories, 14_000)
        let ingredient = Ingredient(name: "Oats", grams: 400, kcalPer100g: 0,
                                    macrosPer100g: MacroTotals(carbs: 60, protein: 13, fat: 7))
        let recipe = Recipe(name: "Oat pots", batchServings: 4, ingredients: [ingredient])
        XCTAssertEqual(recipe.macros(for: 1.5)?.carbs, 90)
        XCTAssertEqual(recipe.calories(for: 1.5), 532.5)
    }

    func testOldSavedDataLoadsWithMacroDefaults() throws {
        let entry = FoodEntry(name: "Old meal", calories: 500, date: Date(),
                              meal: .lunch, source: .manual)
        var old = AppData()
        old.foodEntries = [entry]
        old.weeklyGoal = 12_600
        let encoded = try JSONEncoder().encode(old)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in ["dailyMacroGoal", "macroGoalHistory", "goalPeriod"] { object.removeValue(forKey: key) }
        var entries = try XCTUnwrap(object["foodEntries"] as? [[String: Any]])
        entries[0].removeValue(forKey: "macros")
        object["foodEntries"] = entries
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(AppData.self, from: legacy)
        XCTAssertEqual(decoded.foodEntries.first?.name, "Old meal")
        XCTAssertNil(decoded.foodEntries.first?.macros)
        XCTAssertEqual(decoded.dailyMacroGoal.calories, 1_800)
        XCTAssertEqual(decoded.goal(for: Date()), 12_600)
    }
}
