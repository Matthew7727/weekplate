import Foundation

@main struct FoodLookupSmoke {
    static func main() async throws {
        let service = OpenFoodFactsService()
        let results = try await service.search("oats")
        precondition(!results.isEmpty)
        let product = try await service.barcode("3017624010701")
        precondition(product.kcalPer100g > 0)
        print("Food lookup smoke tests passed: \(results.count) search results, \(product.name)")
    }
}
