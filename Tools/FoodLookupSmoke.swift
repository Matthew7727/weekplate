import Foundation

@main struct FoodLookupSmoke {
    static func main() async throws {
        let service = OpenFoodFactsService()
        let results = try await service.search("oats")
        precondition(!results.isEmpty)
        precondition(Set(results.map { "\($0.name.lowercased())|\($0.brand.lowercased())|\($0.unit.rawValue)" }).count == results.count)
        let product = try await service.barcode("3017624010701")
        precondition(product.kcalPer100 > 0)
        let drink = try await service.barcode("5449000000996")
        precondition(drink.unit == .millilitres)
        print("Food lookup smoke tests passed: \(results.count) unique search results, \(product.name), \(drink.name) per 100ml")
    }
}
