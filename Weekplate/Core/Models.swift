import Foundation

struct MacroTotals: Codable, Equatable {
    var carbs: Double
    var protein: Double
    var fat: Double

    static let zero = MacroTotals(carbs: 0, protein: 0, fat: 0)
    static let defaultDaily = MacroTotals(carbs: 220, protein: 145, fat: 60) // 2,000 kcal
    var calories: Double { carbs * 4 + protein * 4 + fat * 9 }
    var isValid: Bool {
        [carbs, protein, fat].allSatisfy { $0.isFinite && $0 >= 0 } && calories > 0
    }
    func scaled(by factor: Double) -> MacroTotals {
        MacroTotals(carbs: carbs * factor, protein: protein * factor, fat: fat * factor)
    }
    static func + (lhs: MacroTotals, rhs: MacroTotals) -> MacroTotals {
        MacroTotals(carbs: lhs.carbs + rhs.carbs,
                    protein: lhs.protein + rhs.protein, fat: lhs.fat + rhs.fat)
    }
}

struct Ingredient: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var grams: Double // Stored name retained for existing recipe files; this is ml when unit is millilitres.
    var kcalPer100g: Double // Per 100 of the selected unit.
    var macrosPer100g: MacroTotals? = nil
    var unit: FoodUnit = .grams

    init(id: UUID = UUID(), name: String, grams: Double, kcalPer100g: Double,
         macrosPer100g: MacroTotals? = nil, unit: FoodUnit = .grams) {
        self.id = id
        self.name = name
        self.grams = grams
        self.kcalPer100g = kcalPer100g
        self.macrosPer100g = macrosPer100g
        self.unit = unit
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, grams, kcalPer100g, macrosPer100g, unit
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        grams = try values.decode(Double.self, forKey: .grams)
        kcalPer100g = try values.decode(Double.self, forKey: .kcalPer100g)
        macrosPer100g = try values.decodeIfPresent(MacroTotals.self, forKey: .macrosPer100g)
        unit = try values.decodeIfPresent(FoodUnit.self, forKey: .unit) ?? .grams
    }

    var calories: Double { grams * (kcalPer100g > 0 ? kcalPer100g : (macrosPer100g?.calories ?? 0)) / 100 }
    var macros: MacroTotals? { macrosPer100g?.scaled(by: grams / 100) }
}

struct Recipe: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var batchServings: Double
    var ingredients: [Ingredient] = []
    var manualCaloriesPerServing: Double? = nil
    var manualMacrosPerServing: MacroTotals? = nil
    var notes: String = ""
    var createdAt = Date()

    var caloriesPerServing: Double {
        if let manualCaloriesPerServing, manualCaloriesPerServing > 0 { return manualCaloriesPerServing }
        if let manualMacrosPerServing { return manualMacrosPerServing.calories }
        return ingredients.reduce(0) { $0 + $1.calories } / max(batchServings, 1)
    }

    var macrosPerServing: MacroTotals? {
        if let manualMacrosPerServing { return manualMacrosPerServing }
        guard !ingredients.isEmpty, ingredients.allSatisfy({ $0.macrosPer100g != nil }) else { return nil }
        return ingredients.reduce(.zero) { $0 + ($1.macros ?? .zero) }.scaled(by: 1 / max(batchServings, 1))
    }

    var hasNutrition: Bool {
        (manualCaloriesPerServing ?? 0) > 0 || (manualMacrosPerServing?.isValid ?? false) ||
        (!ingredients.isEmpty && ingredients.allSatisfy {
            $0.grams > 0 && ($0.kcalPer100g > 0 || $0.macrosPer100g != nil)
        } && caloriesPerServing > 0)
    }
    func calories(for servings: Double) -> Double { caloriesPerServing * servings }
    func macros(for servings: Double) -> MacroTotals? { macrosPerServing?.scaled(by: servings) }
    func ingredientGrams(_ ingredient: Ingredient, for servings: Double) -> Double {
        ingredient.grams * servings / max(batchServings, 1)
    }
}

struct FoodEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var calories: Double
    var date: Date
    var meal: Meal
    var source: EntrySource
    var servings: Double = 1
    var recipeID: UUID? = nil
    var macros: MacroTotals? = nil
    var quantity: Double? = nil
    var quantityUnit: FoodUnit? = nil
}

enum Meal: String, CaseIterable, Codable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    var id: String { rawValue }
}

enum EntrySource: String, Codable, CaseIterable {
    case recipe, packaged, manual
}

struct PlanItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var recipeID: UUID
    var date: Date
    var meal: Meal
    var servings: Double
    var loggedEntryID: UUID? = nil
}

struct WeightEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var kilograms: Double
}

struct GoalChange: Codable, Equatable {
    var effectiveWeek: Date
    var calories: Double
}

struct MacroGoalChange: Codable, Equatable {
    var effectiveWeek: Date
    var dailyMacros: MacroTotals
}

enum GoalPeriod: String, Codable, CaseIterable, Identifiable {
    case daily = "Daily", weekly = "Weekly"
    var id: String { rawValue }
    var factor: Double { self == .weekly ? 7 : 1 }
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
}

struct AppData: Codable {
    var recipes: [Recipe] = []
    var foodEntries: [FoodEntry] = []
    var plan: [PlanItem] = []
    var weights: [WeightEntry] = []
    var weeklyGoal: Double = 14_000
    var goalHistory: [GoalChange] = []
    var dailyMacroGoal: MacroTotals = .defaultDaily
    var macroGoalHistory: [MacroGoalChange] = []
    var goalPeriod: GoalPeriod = .weekly
    var goalProfile: GoalProfile? = nil
    var targetWeightKg: Double? = nil
    var theme: AppTheme = .system

    init() {}

    private enum CodingKeys: String, CodingKey {
        case recipes, foodEntries, plan, weights, weeklyGoal, goalHistory
        case dailyMacroGoal, macroGoalHistory, goalPeriod, goalProfile, targetWeightKg, theme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipes = try container.decodeIfPresent([Recipe].self, forKey: .recipes) ?? []
        foodEntries = try container.decodeIfPresent([FoodEntry].self, forKey: .foodEntries) ?? []
        plan = try container.decodeIfPresent([PlanItem].self, forKey: .plan) ?? []
        weights = try container.decodeIfPresent([WeightEntry].self, forKey: .weights) ?? []
        weeklyGoal = try container.decodeIfPresent(Double.self, forKey: .weeklyGoal) ?? 14_000
        goalHistory = try container.decodeIfPresent([GoalChange].self, forKey: .goalHistory) ?? []
        dailyMacroGoal = try container.decodeIfPresent(MacroTotals.self, forKey: .dailyMacroGoal)
            ?? .defaultDaily.scaled(by: weeklyGoal / 14_000)
        macroGoalHistory = try container.decodeIfPresent([MacroGoalChange].self, forKey: .macroGoalHistory) ?? []
        goalPeriod = try container.decodeIfPresent(GoalPeriod.self, forKey: .goalPeriod) ?? .weekly
        goalProfile = try container.decodeIfPresent(GoalProfile.self, forKey: .goalProfile)
        targetWeightKg = try container.decodeIfPresent(Double.self, forKey: .targetWeightKg)
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
    }

    func goal(for week: Date) -> Double {
        let start = WeekMath.start(of: week)
        return goalHistory.filter { $0.effectiveWeek <= start }
            .max { $0.effectiveWeek < $1.effectiveWeek }?.calories ??
            (goalHistory.isEmpty ? weeklyGoal : 14_000)
    }

    func macroGoal(for date: Date) -> MacroTotals {
        let start = WeekMath.start(of: date)
        if let change = macroGoalHistory.filter({ $0.effectiveWeek <= start })
            .max(by: { $0.effectiveWeek < $1.effectiveWeek }) {
            return change.dailyMacros
        }
        if goalHistory.isEmpty { return dailyMacroGoal }
        return .defaultDaily.scaled(by: goal(for: date) / 14_000)
    }
}

enum WeekMath {
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    static func start(of date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func days(of date: Date) -> [Date] {
        let first = start(of: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    static func total(_ entries: [FoodEntry], inWeekOf date: Date) -> Double {
        let startDate = start(of: date)
        let endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? date
        return entries.filter { $0.date >= startDate && $0.date < endDate }
            .reduce(0) { $0 + $1.calories }
    }

    static func total(_ entries: [FoodEntry], on date: Date) -> Double {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.calories }
    }

    static func macros(_ entries: [FoodEntry], inWeekOf date: Date) -> MacroTotals {
        let startDate = start(of: date)
        let endDate = calendar.date(byAdding: .day, value: 7, to: startDate) ?? date
        return entries.filter { $0.date >= startDate && $0.date < endDate }
            .reduce(.zero) { $0 + ($1.macros ?? .zero) }
    }

    static func macros(_ entries: [FoodEntry], on date: Date) -> MacroTotals {
        entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(.zero) { $0 + ($1.macros ?? .zero) }
    }

    static func adherence(_ consumed: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return max(0, 1 - abs(consumed - goal) / goal)
    }
}

enum WeightTrend {
    // A straight-line projection of recorded weigh-ins, not a metabolic prediction.
    static func projectedKilograms(_ entries: [WeightEntry], daysAhead: Double) -> Double? {
        let sorted = entries.sorted { $0.date < $1.date }
        guard sorted.count >= 2, let first = sorted.first, let last = sorted.last else { return nil }
        let points = sorted.map {
            (x: $0.date.timeIntervalSince(first.date) / 86_400, y: $0.kilograms)
        }
        let meanX = points.reduce(0) { $0 + $1.x } / Double(points.count)
        let meanY = points.reduce(0) { $0 + $1.y } / Double(points.count)
        let denominator = points.reduce(0) { $0 + pow($1.x - meanX, 2) }
        guard denominator > 0 else { return nil }
        let slope = points.reduce(0) { $0 + ($1.x - meanX) * ($1.y - meanY) } / denominator
        let lastX = last.date.timeIntervalSince(first.date) / 86_400
        return meanY + slope * (lastX + daysAhead - meanX)
    }
}

enum RecipeTextImporter {
    static func parse(_ text: String) -> [Recipe] {
        let normalised = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalised.components(separatedBy: "\n")
        var blocks: [[String]] = []
        var current: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                if !current.isEmpty { blocks.append(current); current = [] }
            } else if ((1...3).contains(line.prefix(while: { $0 == "#" }).count) && line.contains("# ") ||
                       line.lowercased().hasPrefix("recipe:")) && !current.isEmpty {
                blocks.append(current)
                current = [line]
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { blocks.append(current) }
        return blocks.compactMap { block in
            let trimmed = block.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let first = trimmed.first(where: { !$0.isEmpty }) else { return nil }
            let name = first.replacingOccurrences(of: #"^#{1,3}\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"(?i)^recipe:\s*"#, with: "", options: .regularExpression)
            let servingsLine = trimmed.first { $0.lowercased().hasPrefix("servings:") }
            let servings = servingsLine.flatMap { line -> Double? in
                guard let range = line.range(of: #"\d+(?:[.,]\d+)?"#, options: .regularExpression) else { return nil }
                return Double(line[range].replacingOccurrences(of: ",", with: "."))
            } ?? 1
            return Recipe(name: name, batchServings: max(servings, 1), notes: block.joined(separator: "\n"))
        }
    }
}
