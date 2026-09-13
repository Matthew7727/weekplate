import Foundation

enum FoodUnit: String, Codable {
    case grams = "g"
    case millilitres = "ml"
}

struct FoodProduct: Identifiable, Equatable {
    let id: String
    let name: String
    let brand: String
    let kcalPer100g: Double
    let macrosPer100g: MacroTotals?
    let unit: FoodUnit
    let servingSize: String
    let quantity: String

    init(id: String, name: String, brand: String, kcalPer100g: Double,
         macrosPer100g: MacroTotals?, unit: FoodUnit = .grams,
         servingSize: String, quantity: String = "") {
        self.id = id
        self.name = name
        self.brand = brand
        self.kcalPer100g = kcalPer100g
        self.macrosPer100g = macrosPer100g
        self.unit = unit
        self.servingSize = servingSize
        self.quantity = quantity
    }

    var kcalPer100: Double { kcalPer100g }
    var macrosPer100: MacroTotals? { macrosPer100g }
    var per100Label: String { "per 100\(unit.rawValue)" }
}

enum FoodProductParser {
    static func parse(_ raw: [String: Any]) -> FoodProduct? {
        guard let name = raw["product_name"] as? String, !name.isEmpty,
              let nutrition = raw["nutriments"] as? [String: Any] else { return nil }
        func nutrient(_ key: String) -> Double? {
            number(nutrition["\(key)_100g"]) ?? number(nutrition["\(key)_100ml"])
        }
        let carbs = nutrient("carbohydrates")
        let protein = nutrient("proteins")
        let fat = nutrient("fat")
        let macros: MacroTotals? = {
            guard let carbs, let protein, let fat else { return nil }
            let value = MacroTotals(carbs: carbs, protein: protein, fat: fat)
            return value.isValid ? value : nil
        }()
        let kcal = nutrient("energy-kcal") ?? macros?.calories ?? 0
        guard kcal > 0 else { return nil }
        let brand = (raw["brands"] as? String) ?? (raw["brands"] as? [String])?.first ?? ""
        return FoodProduct(id: raw["code"] as? String ?? UUID().uuidString,
                           name: name, brand: brand, kcalPer100g: kcal,
                           macrosPer100g: macros, unit: foodUnit(raw),
                           servingSize: raw["serving_size"] as? String ?? "",
                           quantity: raw["quantity"] as? String ?? "")
    }

    private static func foodUnit(_ raw: [String: Any]) -> FoodUnit {
        let unit = (raw["product_quantity_unit"] as? String ?? "").lowercased()
        if ["ml", "cl", "dl", "l"].contains(unit) { return .millilitres }
        if ["g", "kg"].contains(unit) { return .grams }
        let text = "\(raw["quantity"] as? String ?? "") \(raw["serving_size"] as? String ?? "")".lowercased()
        if text.range(of: #"\b\d+(?:[.,]\d+)?\s*(?:ml|cl|dl|l)\b"#, options: .regularExpression) != nil {
            return .millilitres
        }
        let categories = raw["categories_tags"] as? [String] ?? []
        if categories.contains(where: { $0.contains("beverages") || $0.contains("drinks") }) {
            return .millilitres
        }
        return .grams
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }
}
