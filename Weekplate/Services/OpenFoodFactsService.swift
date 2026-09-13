import Foundation

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
            URLQueryItem(name: "page_size", value: "60"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,nutriments,serving_size,quantity,product_quantity_unit,categories_tags")
        ]
        guard let url = components.url else { throw FoodLookupError.invalidResponse }
        let root = try await request(url)
        let products = root["hits"] as? [[String: Any]] ?? []
        return FoodSearch.curated(products.compactMap(FoodProductParser.parse), matching: term)
    }

    func barcode(_ code: String) async throws -> FoodProduct {
        guard let safeCode = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(safeCode).json?fields=code,product_name,brands,nutriments,serving_size,quantity,product_quantity_unit,categories_tags") else {
            throw FoodLookupError.invalidResponse
        }
        let root = try await request(url)
        guard let raw = root["product"] as? [String: Any] else { throw FoodLookupError.noProduct }
        guard let product = FoodProductParser.parse(raw) else { throw FoodLookupError.missingNutrition }
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

}
