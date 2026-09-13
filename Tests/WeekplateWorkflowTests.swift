import XCTest
@testable import WeekplateCore

final class WeekplateWorkflowTests: XCTestCase {
    private let calendar = WeekMath.calendar

    private func date(_ weekday: Int, in week: Date = Date()) -> Date {
        let monday = WeekMath.start(of: week)
        return calendar.date(byAdding: .day, value: weekday - 1, to: monday)!
    }

    func testPlanAndLogRecipeWorkflowUpdatesTotalsAndMacros() {
        let ingredient = Ingredient(name: "Oats", grams: 400, kcalPer100g: 0,
                                    macrosPer100g: MacroTotals(carbs: 60, protein: 13, fat: 7))
        let recipe = Recipe(name: "Overnight oats", batchServings: 4, ingredients: [ingredient])
        let plan = PlanItem(recipeID: recipe.id, date: date(2), meal: .breakfast, servings: 1.5)
        var data = AppData()
        data.recipes = [recipe]
        data.plan = [plan]

        let plannedRecipe = try! XCTUnwrap(data.recipes.first { $0.id == plan.recipeID })
        let entry = FoodEntry(name: plannedRecipe.name,
                              calories: plannedRecipe.calories(for: plan.servings),
                              date: plan.date, meal: plan.meal, source: .recipe,
                              servings: plan.servings, recipeID: plannedRecipe.id,
                              macros: plannedRecipe.macros(for: plan.servings))
        data.foodEntries.append(entry)
        data.plan[0].loggedEntryID = entry.id

        XCTAssertEqual(data.foodEntries.count, 1)
        XCTAssertEqual(WeekMath.total(data.foodEntries, on: date(2)), 532.5, accuracy: 0.001)
        XCTAssertEqual(WeekMath.macros(data.foodEntries, on: date(2)).carbs, 90, accuracy: 0.001)
        XCTAssertEqual(data.plan[0].loggedEntryID, entry.id)
    }

    func testManualEntryCanDeriveCaloriesFromCompleteMacros() {
        let macros = MacroTotals(carbs: 30, protein: 20, fat: 10)
        let entry = FoodEntry(name: "Homemade snack", calories: macros.calories,
                              date: date(2), meal: .snack, source: .manual, macros: macros)

        XCTAssertEqual(entry.calories, 290, accuracy: 0.001)
        XCTAssertEqual(WeekMath.macros([entry], on: date(2)), macros)
        XCTAssertEqual(WeekMath.total([entry], on: date(2)), macros.calories, accuracy: 0.001)
    }

    func testPackagedFoodPortionScalesCaloriesAndMacrosFromPer100gValues() {
        let per100g = MacroTotals(carbs: 50, protein: 10, fat: 5)
        let grams = 37.5
        let entry = FoodEntry(name: "Cereal", calories: 420 * grams / 100,
                              date: date(1), meal: .breakfast, source: .packaged,
                              macros: per100g.scaled(by: grams / 100))

        XCTAssertEqual(entry.calories, 157.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(entry.macros?.carbs), 18.75, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(entry.macros?.fat), 1.875, accuracy: 0.001)
    }

    func testFoodLookupParserAcceptsStringNumbersAndArrayBrands() throws {
        let raw: [String: Any] = [
            "code": "123",
            "product_name": "Granola",
            "brands": ["Acme", "Breakfast Co"],
            "serving_size": "45 g",
            "nutriments": [
                "energy-kcal_100g": "471",
                "carbohydrates_100g": "62.5",
                "proteins_100g": 9.0,
                "fat_100g": 18.0
            ]
        ]

        let product = try XCTUnwrap(FoodProductParser.parse(raw))

        XCTAssertEqual(product.id, "123")
        XCTAssertEqual(product.name, "Granola")
        XCTAssertEqual(product.brand, "Acme")
        XCTAssertEqual(product.servingSize, "45 g")
        XCTAssertEqual(product.kcalPer100g, 471)
        XCTAssertEqual(product.macrosPer100g, MacroTotals(carbs: 62.5, protein: 9, fat: 18))
    }

    func testFoodLookupParserCanDeriveCaloriesFromCompleteMacros() throws {
        let raw: [String: Any] = [
            "product_name": "Macro bar",
            "nutriments": [
                "carbohydrates_100g": 40,
                "proteins_100g": 20,
                "fat_100g": 10
            ]
        ]

        let product = try XCTUnwrap(FoodProductParser.parse(raw))

        XCTAssertEqual(product.kcalPer100g, 330, accuracy: 0.001)
        XCTAssertEqual(product.macrosPer100g, MacroTotals(carbs: 40, protein: 20, fat: 10))
        XCTAssertFalse(product.id.isEmpty)
    }

    func testFoodLookupParserRejectsUnusableProducts() {
        let missingName: [String: Any] = ["nutriments": ["energy-kcal_100g": 100]]
        let missingNutrition: [String: Any] = ["product_name": "Unknown"]
        let zeroNutrition: [String: Any] = [
            "product_name": "Empty",
            "nutriments": ["energy-kcal_100g": 0]
        ]
        let incompleteMacros: [String: Any] = [
            "product_name": "Partial",
            "nutriments": ["carbohydrates_100g": 40, "proteins_100g": 10]
        ]

        XCTAssertNil(FoodProductParser.parse(missingName))
        XCTAssertNil(FoodProductParser.parse(missingNutrition))
        XCTAssertNil(FoodProductParser.parse(zeroNutrition))
        XCTAssertNil(FoodProductParser.parse(incompleteMacros))
    }

    func testEveryMealAndEntrySourceCanRoundTripThroughCodable() throws {
        let date = self.date(4)
        let entries = Meal.allCases.enumerated().flatMap { mealIndex, meal in
            EntrySource.allCases.enumerated().map { sourceIndex, source in
                FoodEntry(name: "\(meal.rawValue) \(source.rawValue)",
                          calories: Double(mealIndex + sourceIndex + 1) * 100,
                          date: date, meal: meal, source: source,
                          servings: 0.5 + Double(mealIndex + sourceIndex))
            }
        }

        let decoded = try JSONDecoder().decode([FoodEntry].self,
                                                from: JSONEncoder().encode(entries))

        XCTAssertEqual(decoded, entries)
        XCTAssertEqual(Set(decoded.map(\.meal)), Set(Meal.allCases))
        XCTAssertEqual(Set(decoded.map(\.source)), Set(EntrySource.allCases))
    }

    func testGoalPeriodThemeAndMacroOptionSetsExposeEveryUserChoice() {
        XCTAssertEqual(Set(GoalPeriod.allCases), [.daily, .weekly])
        XCTAssertEqual(GoalPeriod.daily.factor, 1)
        XCTAssertEqual(GoalPeriod.weekly.factor, 7)
        XCTAssertEqual(Set(AppTheme.allCases), [.system, .light, .dark])
        XCTAssertEqual(MacroTotals.zero.calories, 0)
        XCTAssertFalse(MacroTotals.zero.isValid)
    }

    func testRecipeNutritionPrecedenceKeepsManualCaloriesAndMacrosIndependent() {
        let ingredient = Ingredient(name: "Rice", grams: 200, kcalPer100g: 350)
        let recipe = Recipe(name: "Rice bowl", batchServings: 2, ingredients: [ingredient],
                            manualCaloriesPerServing: 500,
                            manualMacrosPerServing: MacroTotals(carbs: 60, protein: 20, fat: 8))

        XCTAssertEqual(recipe.caloriesPerServing, 500)
        XCTAssertEqual(recipe.macrosPerServing, MacroTotals(carbs: 60, protein: 20, fat: 8))
        XCTAssertEqual(recipe.calories(for: 0.5), 250, accuracy: 0.001)
        XCTAssertTrue(recipe.hasNutrition)
    }

    func testRecipeWithZeroBatchServingsUsesOneAsTheCalculationFloor() {
        let recipe = Recipe(name: "Quick meal", batchServings: 0,
                            ingredients: [Ingredient(name: "Egg", grams: 100, kcalPer100g: 155)])

        XCTAssertEqual(recipe.caloriesPerServing, 155, accuracy: 0.001)
        XCTAssertEqual(recipe.ingredientGrams(recipe.ingredients[0], for: 2), 200, accuracy: 0.001)
        XCTAssertTrue(recipe.hasNutrition)
    }

    func testInvalidManualMacrosDoNotBecomeNutrition() {
        let negative = MacroTotals(carbs: 20, protein: -1, fat: 5)
        let nonFinite = MacroTotals(carbs: .infinity, protein: 10, fat: 5)
        let recipe = Recipe(name: "Unverified", batchServings: 2,
                            manualMacrosPerServing: negative)

        XCTAssertFalse(negative.isValid)
        XCTAssertFalse(nonFinite.isValid)
        XCTAssertFalse(recipe.hasNutrition)
    }

    func testDeletingLoggedEntryMakesPlannedMealAvailableAgain() {
        let recipe = Recipe(name: "Soup", batchServings: 2,
                            manualCaloriesPerServing: 300)
        let entryID = UUID()
        let plan = PlanItem(recipeID: recipe.id, date: date(3), meal: .dinner,
                            servings: 1, loggedEntryID: entryID)
        var data = AppData()
        data.recipes = [recipe]
        data.plan = [plan]
        data.foodEntries = [FoodEntry(id: entryID, name: recipe.name, calories: 300,
                                      date: plan.date, meal: plan.meal, source: .recipe,
                                      recipeID: recipe.id)]

        data.foodEntries.removeAll { $0.id == entryID }
        for index in data.plan.indices where data.plan[index].loggedEntryID == entryID {
            data.plan[index].loggedEntryID = nil
        }

        XCTAssertTrue(data.foodEntries.isEmpty)
        XCTAssertNil(data.plan[0].loggedEntryID)
    }

    func testDeletingRecipeCleansUpItsPlannedMealsButKeepsLoggedHistory() {
        let keep = Recipe(name: "Keep", batchServings: 1, manualCaloriesPerServing: 400)
        let remove = Recipe(name: "Remove", batchServings: 1, manualCaloriesPerServing: 500)
        var data = AppData()
        data.recipes = [keep, remove]
        data.plan = [
            PlanItem(recipeID: keep.id, date: date(1), meal: .lunch, servings: 1),
            PlanItem(recipeID: remove.id, date: date(2), meal: .dinner, servings: 1)
        ]
        data.foodEntries = [FoodEntry(name: remove.name, calories: 500, date: date(2),
                                      meal: .dinner, source: .recipe, recipeID: remove.id)]

        data.recipes.removeAll { $0.id == remove.id }
        data.plan.removeAll { $0.recipeID == remove.id }

        XCTAssertEqual(data.recipes.map(\.id), [keep.id])
        XCTAssertEqual(data.plan.map(\.recipeID), [keep.id])
        XCTAssertEqual(data.foodEntries.first?.recipeID, remove.id)
    }

    func testDailyAndWeeklyViewsUseTheSameMondayToSundayWindow() {
        let monday = date(1)
        let sunday = date(7)
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
        let entries = [
            FoodEntry(name: "Monday", calories: 400, date: monday, meal: .breakfast, source: .manual),
            FoodEntry(name: "Sunday", calories: 600, date: sunday, meal: .dinner, source: .manual),
            FoodEntry(name: "Next week", calories: 800, date: nextMonday, meal: .lunch, source: .manual)
        ]

        XCTAssertEqual(WeekMath.total(entries, inWeekOf: sunday), 1_000)
        XCTAssertEqual(WeekMath.total(entries, on: sunday), 600)
        XCTAssertEqual(WeekMath.total(entries, inWeekOf: nextMonday), 800)
    }

    func testGoalAndMacroHistoryChangesApplyOnlyFromTheirEffectiveWeek() {
        let current = WeekMath.start(of: Date())
        let previous = calendar.date(byAdding: .day, value: -7, to: current)!
        var data = AppData()
        data.weeklyGoal = 14_000
        data.goalHistory = [GoalChange(effectiveWeek: current, calories: 12_600)]
        data.macroGoalHistory = [MacroGoalChange(effectiveWeek: current,
                                                  dailyMacros: MacroTotals(carbs: 180, protein: 160, fat: 50))]

        XCTAssertEqual(data.goal(for: previous), 14_000)
        XCTAssertEqual(data.goal(for: current), 12_600)
        XCTAssertEqual(data.macroGoal(for: previous), .defaultDaily)
        XCTAssertEqual(data.macroGoal(for: current).protein, 160)
    }

    func testMultipleHistoricalGoalChangesSelectTheLatestChangeForEachWeek() {
        let current = WeekMath.start(of: Date())
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: current)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: current)!
        var data = AppData()
        data.goalHistory = [
            GoalChange(effectiveWeek: twoWeeksAgo, calories: 13_000),
            GoalChange(effectiveWeek: lastWeek, calories: 14_000),
            GoalChange(effectiveWeek: current, calories: 15_000)
        ]

        XCTAssertEqual(data.goal(for: twoWeeksAgo), 13_000)
        XCTAssertEqual(data.goal(for: lastWeek), 14_000)
        XCTAssertEqual(data.goal(for: current), 15_000)
        XCTAssertEqual(data.goal(for: calendar.date(byAdding: .day, value: 3, to: lastWeek)!), 14_000)
    }

    func testSettingWeeklyGoalScalesDailyMacroTargetAndPreservesCalories() {
        let daily = MacroTotals(carbs: 200, protein: 150, fat: 70)
        var data = AppData()
        data.goalPeriod = .weekly
        data.dailyMacroGoal = daily
        data.weeklyGoal = daily.calories * 7
        let currentWeek = WeekMath.start(of: Date())
        data.goalHistory = [GoalChange(effectiveWeek: currentWeek, calories: data.weeklyGoal)]
        data.macroGoalHistory = [MacroGoalChange(effectiveWeek: currentWeek, dailyMacros: daily)]

        XCTAssertEqual(data.goal(for: Date()), 14_210, accuracy: 0.001)
        XCTAssertEqual(data.macroGoal(for: Date()), daily)
        XCTAssertEqual(daily.scaled(by: GoalPeriod.weekly.factor).calories, 14_210, accuracy: 0.001)
    }

    func testImportThenEditNutritionMakesRecipeLoggableAtPortions() {
        let imported = RecipeTextImporter.parse("""
        # Tomato pasta
        Servings: 4 portions
        Boil pasta and stir through sauce.
        """)
        var recipe = try! XCTUnwrap(imported.first)
        XCTAssertFalse(recipe.hasNutrition)

        recipe.manualCaloriesPerServing = 475
        recipe.manualMacrosPerServing = MacroTotals(carbs: 65, protein: 18, fat: 12)

        XCTAssertTrue(recipe.hasNutrition)
        XCTAssertEqual(recipe.calories(for: 1.5), 712.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(recipe.macros(for: 1.5)?.fat), 18, accuracy: 0.001)
        XCTAssertTrue(recipe.notes.contains("Boil pasta"))
    }

    func testRecipeImportHandlesMixedHeadingsSeparatorsAndDecimalComma() {
        let recipes = RecipeTextImporter.parse("""
        Recipe: Chilli
        Servings: 2,5
        ---
        ## Pancakes
        Servings: 6
        ---
        Not a recipe block
        """)

        XCTAssertEqual(recipes.map(\.name), ["Chilli", "Pancakes", "Not a recipe block"])
        XCTAssertEqual(recipes[0].batchServings, 2.5, accuracy: 0.001)
        XCTAssertEqual(recipes[1].batchServings, 6, accuracy: 0.001)
    }

    func testRecipeImportNormalisesWindowsLineEndingsAndKeepsMethodText() {
        let recipes = RecipeTextImporter.parse("# Soup\r\nServings: 3\r\n\r\nStir slowly")

        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes[0].name, "Soup")
        XCTAssertEqual(recipes[0].batchServings, 3)
        XCTAssertFalse(recipes[0].notes.contains("\r"))
        XCTAssertTrue(recipes[0].notes.contains("Stir slowly"))
    }

    func testEmptyOrWhitespaceRecipeImportDoesNotCreateDrafts() {
        XCTAssertTrue(RecipeTextImporter.parse("").isEmpty)
        XCTAssertTrue(RecipeTextImporter.parse(" \n\n\t").isEmpty)
        XCTAssertTrue(RecipeTextImporter.parse("---\n---").isEmpty)
    }

    func testDataRoundTripPreservesRecipePlanEntryAndWeightRelationships() throws {
        let recipe = Recipe(name: "Curry", batchServings: 3,
                            manualCaloriesPerServing: 620,
                            manualMacrosPerServing: MacroTotals(carbs: 55, protein: 32, fat: 21))
        let plan = PlanItem(recipeID: recipe.id, date: date(4), meal: .dinner,
                            servings: 2)
        let entry = FoodEntry(name: recipe.name, calories: 1_240, date: plan.date,
                              meal: plan.meal, source: .recipe, servings: 2,
                              recipeID: recipe.id, macros: recipe.macros(for: 2))
        var original = AppData()
        original.recipes = [recipe]
        original.plan = [plan]
        original.foodEntries = [entry]
        original.weights = [WeightEntry(date: date(5), kilograms: 78.4)]
        original.targetWeightKg = 72
        original.theme = .dark

        let decoded = try JSONDecoder().decode(AppData.self,
                                               from: JSONEncoder().encode(original))

        XCTAssertEqual(decoded.recipes, original.recipes)
        XCTAssertEqual(decoded.plan, original.plan)
        XCTAssertEqual(decoded.foodEntries, original.foodEntries)
        XCTAssertEqual(decoded.weights, original.weights)
        XCTAssertEqual(try XCTUnwrap(decoded.targetWeightKg), 72)
        XCTAssertEqual(decoded.theme, .dark)
    }

    func testPartialSavedDataRestoresAllAppDefaults() throws {
        let json = Data("{\"weeklyGoal\": 12600}".utf8)
        let data = try JSONDecoder().decode(AppData.self, from: json)

        XCTAssertTrue(data.recipes.isEmpty)
        XCTAssertTrue(data.foodEntries.isEmpty)
        XCTAssertTrue(data.plan.isEmpty)
        XCTAssertEqual(data.weeklyGoal, 12_600)
        XCTAssertEqual(data.dailyMacroGoal.calories, 1_800, accuracy: 0.001)
        XCTAssertEqual(data.goalPeriod, .weekly)
        XCTAssertEqual(data.theme, .system)
        XCTAssertNil(data.targetWeightKg)
    }

    func testAdherenceClampsOverAndUnderTargetWithoutChangingTheGoal() {
        XCTAssertEqual(WeekMath.adherence(14_000, goal: 14_000), 1)
        XCTAssertEqual(WeekMath.adherence(7_000, goal: 14_000), 0.5, accuracy: 0.001)
        XCTAssertEqual(WeekMath.adherence(28_000, goal: 14_000), 0)
        XCTAssertEqual(WeekMath.adherence(1_000, goal: 0), 0)
    }

    func testWeeklyMacroTotalsIgnoreMissingMacrosButKeepTheirCalories() {
        let withMacros = FoodEntry(name: "Tracked", calories: 400, date: date(2),
                                   meal: .lunch, source: .manual,
                                   macros: MacroTotals(carbs: 40, protein: 20, fat: 10))
        let withoutMacros = FoodEntry(name: "Untracked macros", calories: 250, date: date(2),
                                      meal: .dinner, source: .manual)

        XCTAssertEqual(WeekMath.total([withMacros, withoutMacros], inWeekOf: date(2)), 650)
        XCTAssertEqual(WeekMath.macros([withMacros, withoutMacros], inWeekOf: date(2)),
                       MacroTotals(carbs: 40, protein: 20, fat: 10))
    }

    func testRecipeIngredientMacrosAggregateAcrossAllIngredients() {
        let recipe = Recipe(name: "Balanced bowl", batchServings: 2, ingredients: [
            Ingredient(name: "Rice", grams: 200, kcalPer100g: 0,
                       macrosPer100g: MacroTotals(carbs: 28, protein: 3, fat: 0.3)),
            Ingredient(name: "Beans", grams: 150, kcalPer100g: 0,
                       macrosPer100g: MacroTotals(carbs: 22, protein: 9, fat: 0.5))
        ])

        XCTAssertEqual(try XCTUnwrap(recipe.macrosPerServing?.carbs), 44.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(recipe.macrosPerServing?.protein), 9.75, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(recipe.macrosPerServing?.fat), 0.675, accuracy: 0.001)
        XCTAssertEqual(recipe.caloriesPerServing, 223.075, accuracy: 0.001)
    }

    func testWeightProjectionRequiresDistinctDatesAndUsesAllMeasurements() {
        let first = date(1)
        let sameDay = WeightEntry(date: first, kilograms: 80)
        let later = WeightEntry(date: calendar.date(byAdding: .day, value: 14, to: first)!, kilograms: 79)
        let middle = WeightEntry(date: calendar.date(byAdding: .day, value: 7, to: first)!, kilograms: 79.5)

        XCTAssertNil(WeightTrend.projectedKilograms([sameDay, WeightEntry(date: first, kilograms: 79)], daysAhead: 28))
        XCTAssertEqual(WeightTrend.projectedKilograms([sameDay, middle, later], daysAhead: 28)!, 77, accuracy: 0.001)
    }
}