import Foundation

enum FoodSearch {
    static func curated(_ products: [FoodProduct], matching query: String) -> [FoodProduct] {
        let normalizedQuery = normalize(query)
        var picked: [String: (product: FoodProduct, index: Int)] = [:]
        for (index, product) in products.enumerated() {
            let key = "\(normalize(product.name))|\(normalize(product.brand))|\(product.unit.rawValue)"
            guard !key.isEmpty else { continue }
            if let current = picked[key] {
                if quality(product) > quality(current.product) {
                    picked[key] = (product, current.index)
                }
            } else {
                picked[key] = (product, index)
            }
        }
        return picked.values.sorted {
            let first = relevance($0.product, query: normalizedQuery)
            let second = relevance($1.product, query: normalizedQuery)
            return first == second ? $0.index < $1.index : first > second
        }.prefix(20).map(\.product)
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func quality(_ product: FoodProduct) -> Int {
        (product.macrosPer100 == nil ? 0 : 3) +
        (product.brand.isEmpty ? 0 : 1) +
        (product.servingSize.isEmpty ? 0 : 1)
    }

    private static func relevance(_ product: FoodProduct, query: String) -> Int {
        let name = normalize(product.name)
        let brand = normalize(product.brand)
        let match: Int
        if name == query { match = 100 }
        else if name.hasPrefix(query) { match = 70 }
        else if name.contains(query) { match = 45 }
        else if brand.contains(query) { match = 20 }
        else { match = 0 }
        return match + quality(product)
    }
}
