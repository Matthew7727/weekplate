import Foundation

@main struct CoreSmoke {
    static func main() {
        let chicken = Ingredient(name: "Chicken", grams: 800, kcalPer100g: 165)
        let recipe = Recipe(name: "Chicken bowls", batchServings: 4, ingredients: [chicken])
        precondition(abs(recipe.calories(for: 1.5) - 495) < 0.001)
        precondition(abs(recipe.ingredientGrams(chicken, for: 1.5) - 300) < 0.001)
        precondition(!Recipe(name: "Draft", batchServings: 2,
                             ingredients: [Ingredient(name: "Unknown", grams: 100, kcalPer100g: 0)]).hasNutrition)

        let monday = WeekMath.start(of: Date())
        let sunday = WeekMath.calendar.date(byAdding: .day, value: -1, to: monday)!
        let tuesday = WeekMath.calendar.date(byAdding: .day, value: 1, to: monday)!
        let entries = [
            FoodEntry(name: "Old", calories: 500, date: sunday, meal: .dinner, source: .manual),
            FoodEntry(name: "Now", calories: 650, date: tuesday, meal: .lunch, source: .recipe)
        ]
        precondition(WeekMath.total(entries, inWeekOf: monday) == 650)

        let recipes = RecipeTextImporter.parse("# Lentil chilli\nServings: 4 portions\nSimmer\n---\nRecipe: Oats\nServings: 2\nMix")
        precondition(recipes.count == 2 && recipes[0].batchServings == 4)
        precondition(recipes[0].notes.contains("Simmer") && !recipes[0].hasNutrition)

        var data = AppData()
        data.goalHistory = [GoalChange(effectiveWeek: monday, calories: 12_000)]
        precondition(data.goal(for: sunday) == 14_000 && data.goal(for: monday) == 12_000)

        let weights = [WeightEntry(date: monday, kilograms: 80),
                       WeightEntry(date: WeekMath.calendar.date(byAdding: .day, value: 14, to: monday)!, kilograms: 79)]
        precondition(abs(WeightTrend.projectedKilograms(weights, daysAhead: 28)! - 77) < 0.001)
        print("Weekplate core smoke tests passed")
    }
}
