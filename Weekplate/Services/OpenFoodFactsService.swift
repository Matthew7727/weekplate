import Foundation

struct FoodProduct: Identifiable {
    let id: String
    let name: String
    let brand: String
    let kcalPer100g: Double
    let macrosPer100g: MacroTotals?
    let servingSize: String
}

enum FoodLookupError: LocalizedError {
    case invalidResponse, noProduct, missingNutrition
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Food search is unavailable right now. Please try again."
        case .noProduct: "No product found for that barcode. You can add it manually."
        case .missingNutrition: "This product has no calorie data. You can add it manually."
        }
    }
}

struct OpenFoodFactsService {
    func search(_ term: String) async throws -> [FoodProduct] {
        guard var components = URLComponents(string: "https://search.openfoodfacts.org/search") else {
            throw FoodLookupError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: term),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments,serving_size")
        ]
        guard let url = components.url else { throw FoodLookupError.invalidResponse }
        let root = try await request(url)
        let products = root["hits"] as? [[String: Any]] ?? []
        return products.compactMap(Self.product)
    }

    func barcode(_ code: String) async throws -> FoodProduct {
        guard let safeCode = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(safeCode).json?fields=code,product_name,brands,nutriments,serving_size") else {
            throw FoodLookupError.invalidResponse
        }
        let root = try await request(url)
        guard let raw = root["product"] as? [String: Any] else { throw FoodLookupError.noProduct }
        guard let product = Self.product(raw) else { throw FoodLookupError.missingNutrition }
        return product
    }

    private func request(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.setValue("Weekplate/0.1 (local iOS prototype)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FoodLookupError.invalidResponse
        }
        return object
    }

    private static func product(_ raw: [String: Any]) -> FoodProduct? {
        guard let name = raw["product_name"] as? String, !name.isEmpty,
              let nutrition = raw["nutriments"] as? [String: Any] else { return nil }
        let carbs = number(nutrition["carbohydrates_100g"])
        let protein = number(nutrition["proteins_100g"])
        let fat = number(nutrition["fat_100g"])
        let macros: MacroTotals? = {
            guard let carbs, let protein, let fat else { return nil }
            let value = MacroTotals(carbs: carbs, protein: protein, fat: fat)
            return value.isValid ? value : nil
        }()
        let kcal = number(nutrition["energy-kcal_100g"]) ?? macros?.calories ?? 0
        guard kcal > 0 else { return nil }
        let brand = (raw["brands"] as? String) ?? (raw["brands"] as? [String])?.first ?? ""
        return FoodProduct(id: raw["code"] as? String ?? UUID().uuidString,
                           name: name, brand: brand,
                           kcalPer100g: kcal, macrosPer100g: macros,
                           servingSize: raw["serving_size"] as? String ?? "")
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }
}
