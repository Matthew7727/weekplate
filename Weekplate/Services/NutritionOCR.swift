import UIKit
import Vision

struct NutritionScan: Identifiable {
    let id = UUID()
    let text: String
    let suggestedKcal: Double?
    let suggestedMacros: MacroTotals?
    let image: UIImage
}

enum NutritionOCR {
    static func scan(_ image: UIImage) throws -> NutritionScan {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(data: image.jpegData(compressionQuality: 0.9) ?? Data()).perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let text = lines.joined(separator: "\n")
        let pattern = #"(?i)(\d+(?:[.,]\d+)?)\s*kcal"#
        let match = text.range(of: pattern, options: .regularExpression)
        let number = match.map { String(text[$0]) }
            .flatMap { $0.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".," )).inverted).first }
            .flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
        func macro(_ names: String) -> Double? {
            for line in lines {
                let pattern = "(?i)^\\s*(?:\\b(?:\(names))\\b)\\s*[:–-]?\\s*(\\d+(?:[.,]\\d+)?)\\s*g?\\b"
                guard let expression = try? NSRegularExpression(pattern: pattern),
                      let match = expression.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                      let range = Range(match.range(at: 1), in: line) else { continue }
                return Double(line[range].replacingOccurrences(of: ",", with: "."))
            }
            return nil
        }
        let macros: MacroTotals? = {
            guard let carbs = macro("carbohydrate|carbohydrates|carbs"),
                  let protein = macro("protein|proteins"),
                  let fat = macro("fat|fats|total fat") else { return nil }
            let value = MacroTotals(carbs: carbs, protein: protein, fat: fat)
            return value.isValid ? value : nil
        }()
        return NutritionScan(text: text, suggestedKcal: number, suggestedMacros: macros, image: image)
    }
}
