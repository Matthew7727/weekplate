import Foundation
import Security

enum ClaudeKeychain {
    private static let service = "com.mattecc.weekplate.claude"
    private static let account = "api-key"

    static var hasKey: Bool { (try? read())?.isEmpty == false }

    static func save(_ key: String) throws {
        let data = Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw ClaudeKeychainError.unavailable(status) }
    }

    static func read() throws -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw ClaudeKeychainError.unavailable(status)
        }
        return key
    }

    static func remove() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }
}

enum ClaudeKeychainError: LocalizedError {
    case unavailable(OSStatus)
    var errorDescription: String? { "Weekplate could not securely store the Claude key." }
}

enum AIIngredientMode: String, CaseIterable, Identifiable {
    case pantryOnly = "Use my pantry"
    case pantryFirst = "Pantry first"
    case aiChooses = "AI chooses"
    var id: String { rawValue }
}

struct AIRecipeRequest {
    var targetsPerServing: MacroTotals
    var servings: Int
    var vibe: String
    var maxMinutes: Int?
    var constraints: String
    var mode: AIIngredientMode
    var pantry: [PantryIngredient]
}

enum AIIngredientOrigin: String, Codable {
    case pantry
    case suggested

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
            .lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self = value == "pantry" ? .pantry : .suggested
    }
}

enum UKAvailability: String, Codable {
    case standardUKSupermarket
    case substitutionNeeded

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
            .lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        self = ["standarduksupermarket", "uksupermarket", "commonuksupermarket", "standard"].contains(value)
            ? .standardUKSupermarket : .substitutionNeeded
    }
}

struct AIRecipeIngredient: Identifiable, Codable {
    var id = UUID()
    var name: String
    var amount: Double
    var unit: FoodUnit
    var kcalPer100g: Double
    var macrosPer100g: MacroTotals
    var origin: AIIngredientOrigin
    var availability: UKAvailability
    var substitution: String?

    private enum CodingKeys: String, CodingKey {
        case name, ingredient, amount, quantity, grams, unit, kcalPer100g, caloriesPer100g, kcalPer100, calories
        case macrosPer100g, macros, carbs, carbohydrates, protein, proteins, fat, fats, origin, availability, substitution
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeFirstString(for: [.name, .ingredient])
        amount = try values.decodeFirstDouble(for: [.amount, .quantity, .grams])
        let unitText = (try? values.decodeFirstString(for: [.unit])) ?? "g"
        switch unitText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "g", "gram", "grams": unit = .grams
        case "ml", "millilitre", "millilitres", "milliliter", "milliliters": unit = .millilitres
        default: throw DecodingError.dataCorruptedError(forKey: .unit, in: values, debugDescription: "Unsupported unit")
        }
        kcalPer100g = try values.decodeFirstDouble(for: [.kcalPer100g, .caloriesPer100g, .kcalPer100, .calories])
        if let nested = try? values.nestedContainer(keyedBy: CodingKeys.self, forKey: .macrosPer100g) {
            macrosPer100g = try Self.decodeMacros(from: nested)
        } else if let nested = try? values.nestedContainer(keyedBy: CodingKeys.self, forKey: .macros) {
            macrosPer100g = try Self.decodeMacros(from: nested)
        } else {
            macrosPer100g = try Self.decodeMacros(from: values)
        }
        origin = (try? values.decode(AIIngredientOrigin.self, forKey: .origin)) ?? .suggested
        availability = (try? values.decode(UKAvailability.self, forKey: .availability)) ?? .substitutionNeeded
        substitution = try values.decodeIfPresent(String.self, forKey: .substitution)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(name, forKey: .name)
        try values.encode(amount, forKey: .amount)
        try values.encode(unit, forKey: .unit)
        try values.encode(kcalPer100g, forKey: .kcalPer100g)
        try values.encode(macrosPer100g, forKey: .macrosPer100g)
        try values.encode(origin, forKey: .origin)
        try values.encode(availability, forKey: .availability)
        try values.encodeIfPresent(substitution, forKey: .substitution)
    }

    func asIngredient() -> Ingredient {
        Ingredient(name: name, grams: amount, kcalPer100g: kcalPer100g,
                   macrosPer100g: macrosPer100g, unit: unit)
    }

    private static func decodeMacros(from values: KeyedDecodingContainer<CodingKeys>) throws -> MacroTotals {
        MacroTotals(carbs: try values.decodeFirstDouble(for: [.carbs, .carbohydrates]),
                    protein: try values.decodeFirstDouble(for: [.protein, .proteins]),
                    fat: try values.decodeFirstDouble(for: [.fat, .fats]))
    }
}

struct AIRecipeDraft: Codable {
    var name: String
    var servings: Double
    var ingredients: [AIRecipeIngredient]
    var method: [String]
    var prepMinutes: Int?
    var cookMinutes: Int?

    private enum CodingKeys: String, CodingKey {
        case name, title, servings, batchServings, ingredients, method, instructions, prepMinutes, cookMinutes
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeFirstString(for: [.name, .title])
        servings = try values.decodeFirstDouble(for: [.servings, .batchServings])
        ingredients = try values.decode([AIRecipeIngredient].self, forKey: .ingredients)
        if let steps = try? values.decode([String].self, forKey: .method) {
            method = steps
        } else if let steps = try? values.decode([String].self, forKey: .instructions) {
            method = steps
        } else if let text = try? values.decode(String.self, forKey: .method) {
            method = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        } else if let text = try? values.decode(String.self, forKey: .instructions) {
            method = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        } else {
            throw DecodingError.keyNotFound(CodingKeys.method, .init(codingPath: values.codingPath, debugDescription: "Missing method"))
        }
        prepMinutes = try? values.decode(Int.self, forKey: .prepMinutes)
        cookMinutes = try? values.decode(Int.self, forKey: .cookMinutes)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(name, forKey: .name)
        try values.encode(servings, forKey: .servings)
        try values.encode(ingredients, forKey: .ingredients)
        try values.encode(method, forKey: .method)
        try values.encodeIfPresent(prepMinutes, forKey: .prepMinutes)
        try values.encodeIfPresent(cookMinutes, forKey: .cookMinutes)
    }

    var recipe: Recipe {
        Recipe(name: name, batchServings: servings, ingredients: ingredients.map { $0.asIngredient() },
               notes: method.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(for keys: [Key]) throws -> String {
        for key in keys {
            if let value = try? decode(String.self, forKey: key), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        throw DecodingError.keyNotFound(keys[0], .init(codingPath: codingPath, debugDescription: "Missing text value"))
    }

    func decodeFirstDouble(for keys: [Key]) throws -> Double {
        for key in keys {
            if let value = try? decode(Double.self, forKey: key) { return value }
            if let value = try? decode(Int.self, forKey: key) { return Double(value) }
            if let text = try? decode(String.self, forKey: key) {
                if let value = Double(text) { return value }
                if let range = text.range(of: #"-?\d+(?:\.\d+)?"#, options: .regularExpression),
                   let value = Double(text[range]) { return value }
            }
        }
        throw DecodingError.keyNotFound(keys[0], .init(codingPath: codingPath, debugDescription: "Missing numeric value"))
    }
}

enum ClaudeRecipeError: LocalizedError {
    case missingKey, invalidResponse(String), unsafeIngredient(String), invalidNutrition(String), requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: "Connect your Claude API key in Settings to use AI recipes."
        case .invalidResponse(let message): message
        case .unsafeIngredient(let name): "\(name) is not a standard UK-supermarket ingredient. Try again for a simpler recipe."
        case .invalidNutrition(let name): "\(name) has incomplete nutrition. Please try generating again."
        case .requestFailed(let message): message
        }
    }
}

struct ClaudeRecipeService {
    // Kept in one place so the model can be updated without touching recipe UI.
    private let model = "claude-sonnet-4-5-20250929"

    func generate(_ input: AIRecipeRequest) async throws -> AIRecipeDraft {
        try await perform(input, currentDraft: nil, feedback: nil)
    }

    func refine(_ input: AIRecipeRequest, currentDraft: AIRecipeDraft, feedback: String) async throws -> AIRecipeDraft {
        try await perform(input, currentDraft: currentDraft, feedback: feedback)
    }

    private func perform(_ input: AIRecipeRequest, currentDraft: AIRecipeDraft?, feedback: String?) async throws -> AIRecipeDraft {
        guard let key = try ClaudeKeychain.read(), !key.isEmpty else { throw ClaudeRecipeError.missingKey }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let encodedRequest = try JSONEncoder().encode(ClaudeMessageRequest(
            model: model, maxTokens: 1_600, system: systemPrompt,
            messages: [.init(role: "user", content: prompt(for: input, currentDraft: currentDraft, feedback: feedback))]
        ))
        var requestBody = try JSONSerialization.jsonObject(with: encodedRequest) as? [String: Any] ?? [:]
        requestBody["output_config"] = recipeOutputConfiguration
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeRecipeError.invalidResponse("Claude returned an invalid network response. Please try again.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(ClaudeAPIError.self, from: data).error.message) ?? "Claude could not generate a recipe right now."
            throw ClaudeRecipeError.requestFailed(detail)
        }
        let message = try JSONDecoder().decode(ClaudeMessageResponse.self, from: data)
        guard let text = message.content.first(where: { $0.type == "text" })?.text else {
            throw ClaudeRecipeError.invalidResponse("Claude did not return recipe text. Please try again.")
        }
        guard let jsonData = jsonData(from: text) else {
            throw ClaudeRecipeError.invalidResponse("Claude returned a recipe without readable JSON. Please try again.")
        }
        let decoded: AIRecipeDraft
        do {
            decoded = try JSONDecoder().decode(AIRecipeDraft.self, from: jsonData)
        } catch {
            throw ClaudeRecipeError.invalidResponse("Claude’s recipe is missing or mislabelling a required field: \(decodeMessage(error))")
        }
        var draft = decoded
        for index in draft.ingredients.indices where draft.ingredients[index].origin == .pantry {
            guard let pantryItem = matchingPantryItem(for: draft.ingredients[index].name, pantry: input.pantry) else {
                throw ClaudeRecipeError.invalidResponse("Claude could not match one of its pantry ingredients to your saved pantry. Please try again.")
            }
            // The model chooses an amount; saved pantry nutrition is always the source of truth.
            draft.ingredients[index].name = pantryItem.name
            draft.ingredients[index].unit = pantryItem.unit
            draft.ingredients[index].kcalPer100g = pantryItem.kcalPer100g
            draft.ingredients[index].macrosPer100g = pantryItem.macrosPer100g
        }
        try validate(draft, mode: input.mode)
        return draft
    }

    private var systemPrompt: String {
        """
        You are Weekplate's recipe planner.
        Build practical recipes that aim for the requested macros. Every ingredient must be a familiar, ordinary UK supermarket item likely found at Aldi, M&S, Tesco or similar. Do not use specialist-only items, obscure imports, branded products, supplements, or live stock claims. Give all amounts in g or ml, including items normally counted by piece.
        For pantry ingredients, preserve the supplied nutrition values and use origin "pantry". New items use origin "suggested" and availability "standardUKSupermarket". Set availability "substitutionNeeded" for anything that fails the availability rule.
        Nutrition must be per 100g or per 100ml and include kcalPer100g plus complete carbs, protein and fat.
        """
    }

    private var recipeOutputConfiguration: [String: Any] {
        let macroSchema: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "properties": ["carbs": ["type": "number"], "protein": ["type": "number"], "fat": ["type": "number"]],
            "required": ["carbs", "protein", "fat"]
        ]
        let ingredientSchema: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "properties": [
                "name": ["type": "string"], "amount": ["type": "number"],
                "unit": ["type": "string", "enum": ["g", "ml"]],
                "kcalPer100g": ["type": "number"], "macrosPer100g": macroSchema,
                "origin": ["type": "string", "enum": ["pantry", "suggested"]],
                "availability": ["type": "string", "enum": ["standardUKSupermarket", "substitutionNeeded"]],
                "substitution": ["type": "string"]
            ],
            "required": ["name", "amount", "unit", "kcalPer100g", "macrosPer100g", "origin", "availability", "substitution"]
        ]
        let schema: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "properties": [
                "name": ["type": "string"], "servings": ["type": "number"],
                "ingredients": ["type": "array", "items": ingredientSchema],
                "method": ["type": "array", "items": ["type": "string"]],
                "prepMinutes": ["type": "integer"], "cookMinutes": ["type": "integer"]
            ],
            "required": ["name", "servings", "ingredients", "method", "prepMinutes", "cookMinutes"]
        ]
        return ["format": ["type": "json_schema", "schema": schema]]
    }

    private func prompt(for input: AIRecipeRequest, currentDraft: AIRecipeDraft?, feedback: String?) -> String {
        let pantry = input.pantry.map {
            ["name": $0.name, "unit": $0.unit.rawValue,
             "kcalPer100": String($0.kcalPer100g),
             "carbs": String($0.macrosPer100g.carbs), "protein": String($0.macrosPer100g.protein),
             "fat": String($0.macrosPer100g.fat)]
                .map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        }.joined(separator: " | ")
        var request = """
        Create a \(input.servings)-portion recipe. Target per portion: \(input.targetsPerServing.carbs)g carbs, \(input.targetsPerServing.protein)g protein, \(input.targetsPerServing.fat)g fat. Vibe: \(input.vibe).
        Ingredient mode: \(input.mode.rawValue). \(input.maxMinutes.map { "Keep total active cooking within \($0) minutes." } ?? "")
        Constraints: \(input.constraints.isEmpty ? "none" : input.constraints)
        Pantry nutrition records: \(pantry.isEmpty ? "none" : pantry)
        """
        if let currentDraft, let feedback {
            let currentRecipe = currentDraft.recipe
            let actual = currentRecipe.macrosPerServing.map {
                "Current per-portion macros: \($0.carbs)g carbs, \($0.protein)g protein, \($0.fat)g fat."
            } ?? "Current recipe has incomplete macros."
            let encodedDraft = (try? JSONEncoder().encode(currentDraft))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "unavailable"
            request += """

            This is a revision, not a new unrelated recipe. Keep what still works, honour the feedback, and improve macro fit where possible.
            User feedback: \(feedback)
            \(actual)
            Current draft JSON: \(encodedDraft)
            """
        }
        return request
    }

    private func validate(_ draft: AIRecipeDraft, mode: AIIngredientMode) throws {
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              draft.servings > 0, !draft.ingredients.isEmpty, !draft.method.isEmpty else {
            throw ClaudeRecipeError.invalidResponse("Claude’s recipe is missing a name, portions, ingredients, or method. Please try again.")
        }
        for ingredient in draft.ingredients {
            if mode == .pantryOnly && ingredient.origin != .pantry {
                throw ClaudeRecipeError.invalidResponse("Claude added an ingredient even though you selected Use my pantry. Please try again.")
            }
            guard ingredient.amount > 0, ingredient.amount.isFinite,
                  ingredient.kcalPer100g >= 0, ingredient.kcalPer100g.isFinite,
                  ingredient.macrosPer100g.carbs >= 0, ingredient.macrosPer100g.protein >= 0,
                  ingredient.macrosPer100g.fat >= 0 else {
                throw ClaudeRecipeError.invalidNutrition(ingredient.name)
            }
            guard ingredient.availability == .standardUKSupermarket else {
                throw ClaudeRecipeError.unsafeIngredient(ingredient.name)
            }
        }
    }

    private func matchingPantryItem(for name: String, pantry: [PantryIngredient]) -> PantryIngredient? {
        let normalised = name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        return pantry.first {
            $0.name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined() == normalised
        }
    }

    private func jsonData(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        for index in text.indices[start...] {
            let character = text[index]
            if inString {
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { inString = false }
                continue
            }
            if character == "\"" { inString = true }
            else if character == "{" { depth += 1 }
            else if character == "}" {
                depth -= 1
                if depth == 0 { return String(text[start...index]).data(using: .utf8) }
            }
        }
        return nil
    }

    private func decodeMessage(_ error: Error) -> String {
        switch error {
        case DecodingError.keyNotFound(_, let context): return context.debugDescription
        case DecodingError.typeMismatch(_, let context): return context.debugDescription
        case DecodingError.dataCorrupted(let context): return context.debugDescription
        default: return "check the ingredient nutrition and try again"
        }
    }
}

private struct ClaudeMessageRequest: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]
    enum CodingKeys: String, CodingKey { case model, system, messages; case maxTokens = "max_tokens" }
}

private struct ClaudeMessageResponse: Decodable {
    struct Content: Decodable { let type: String; let text: String? }
    let content: [Content]
}

private struct ClaudeAPIError: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}
