import Foundation

enum RestingMethod: String, Codable, CaseIterable, Identifiable {
    case choose = "Choose a method"
    case male = "Male equation"
    case female = "Female equation"
    case custom = "My own resting estimate"
    var id: String { rawValue }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case mostlySeated = "Mostly seated"
    case lightlyActive = "Some walking or 1–3 workouts"
    case active = "Active days or 3–5 workouts"
    case veryActive = "Physical work or most days training"
    var id: String { rawValue }
    var multiplier: Double {
        switch self {
        case .mostlySeated: 1.2
        case .lightlyActive: 1.4
        case .active: 1.6
        case .veryActive: 1.8
        }
    }
}

enum TrainingFocus: String, Codable, CaseIterable, Identifiable {
    case everyday = "General health"
    case strength = "Strength training"
    case endurance = "Endurance training"
    var id: String { rawValue }
    var proteinPerKg: Double {
        switch self {
        case .everyday: 1.0
        case .strength: 1.6
        case .endurance: 1.4
        }
    }
}

enum GoalDirection: String, Codable, CaseIterable, Identifiable {
    case maintain = "Maintain weight"
    case gentleLoss = "Gradual weight loss"
    case gentleGain = "Gradual weight gain"
    var id: String { rawValue }
    var targetFactor: Double {
        switch self {
        case .maintain: 1
        case .gentleLoss: 0.9
        case .gentleGain: 1.05
        }
    }
}

struct GoalProfile: Codable, Equatable {
    var ageYears = 30
    var heightCm = 170.0
    var weightKg = 75.0
    var restingMethod: RestingMethod = .choose
    var customRestingKcal = 0.0
    var activity: ActivityLevel = .lightlyActive
    var training: TrainingFocus = .everyday
    var direction: GoalDirection = .maintain
}

struct GoalEstimate: Equatable {
    let restingKcal: Double
    let tdeeKcal: Double
    let targetKcal: Double
    let dailyMacros: MacroTotals
}

enum GoalEstimator {
    // Mifflin–St Jeor estimates resting energy expenditure for adults. Activity
    // multipliers and goal adjustments are planning assumptions, not predictions.
    static func estimate(_ profile: GoalProfile) -> GoalEstimate? {
        guard (18...100).contains(profile.ageYears),
              (100...230).contains(profile.heightCm),
              (30...350).contains(profile.weightKg) else { return nil }
        let resting: Double
        switch profile.restingMethod {
        case .choose: return nil
        case .male:
            resting = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.ageYears) + 5
        case .female:
            resting = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * Double(profile.ageYears) - 161
        case .custom:
            guard (600...5000).contains(profile.customRestingKcal) else { return nil }
            resting = profile.customRestingKcal
        }
        guard resting > 0 else { return nil }
        let tdee = resting * profile.activity.multiplier
        let target = tdee * profile.direction.targetFactor
        // Fat uses 30% of estimated target energy. Protein follows the training
        // choice and is capped at 35% so all three macro targets remain usable.
        let protein = min(profile.weightKg * profile.training.proteinPerKg, target * 0.35 / 4)
        let fat = target * 0.30 / 9
        let carbs = max(0, (target - protein * 4 - fat * 9) / 4)
        return GoalEstimate(restingKcal: resting, tdeeKcal: tdee,
                            targetKcal: target,
                            dailyMacros: MacroTotals(carbs: carbs, protein: protein, fat: fat))
    }
}
