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

    func testDrinkAmountsAndRecipeMillilitres() throws {
        let milk = Ingredient(name: "Milk", grams: 750, kcalPer100g: 50,
                              macrosPer100g: MacroTotals(carbs: 5, protein: 3.5, fat: 2),
                              unit: .millilitres)
        let recipe = Recipe(name: "Shake", batchServings: 3, ingredients: [milk])
        XCTAssertEqual(recipe.ingredientGrams(milk, for: 1), 250)
        XCTAssertEqual(recipe.macrosPerServing?.carbs, 12.5)
        let restored = try JSONDecoder().decode(Ingredient.self, from: JSONEncoder().encode(milk))
        XCTAssertEqual(restored.unit, .millilitres)
        let old = #"{"id":"00000000-0000-0000-0000-000000000001","name":"Oats","grams":100,"kcalPer100g":370}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(Ingredient.self, from: old).unit, .grams)
    }

    func testSearchGroupsDuplicateListingsAndPrefersCompleteNutrition() {
        let first = FoodProduct(id: "1", name: "Oat Milk", brand: "Shop", kcalPer100g: 45,
                                macrosPer100g: nil, unit: .millilitres, servingSize: "", quantity: "1 L")
        let richer = FoodProduct(id: "2", name: "Oat-Milk", brand: "Shop", kcalPer100g: 46,
                                 macrosPer100g: MacroTotals(carbs: 6, protein: 1, fat: 2),
                                 unit: .millilitres, servingSize: "250 ml", quantity: "500 ml")
        let other = FoodProduct(id: "3", name: "Oat Milk Zero", brand: "Shop", kcalPer100g: 20,
                                macrosPer100g: nil, unit: .millilitres, servingSize: "", quantity: "1 L")
        let found = FoodSearch.curated([first, richer, other], matching: "oat milk")
        XCTAssertEqual(found.count, 2)
        XCTAssertEqual(found.first?.id, "2")
    }

    func testGoalEstimateUsesRestingEquationAndMacroEnergy() {
        var profile = GoalProfile()
        profile.ageYears = 30
        profile.heightCm = 175
        profile.weightKg = 80
        profile.restingMethod = .male
        profile.activity = .lightlyActive
        profile.training = .strength
        profile.direction = .gentleLoss
        let estimate = GoalEstimator.estimate(profile)!
        XCTAssertEqual(estimate.restingKcal, 1748.75, accuracy: 0.01)
        XCTAssertEqual(estimate.tdeeKcal, 2448.25, accuracy: 0.01)
        XCTAssertEqual(estimate.dailyMacros.calories, estimate.targetKcal, accuracy: 0.01)
        XCTAssertEqual(estimate.dailyMacros.protein, 128, accuracy: 0.01)
        profile.restingMethod = .choose
        XCTAssertNil(GoalEstimator.estimate(profile))
    }
}
