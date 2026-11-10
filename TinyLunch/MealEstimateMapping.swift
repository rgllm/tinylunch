import Foundation

enum MealEstimateMapping {
    static let maxItems = 20
    static let promptVersion = "apple-on-device-image-v2"

    struct Draft {
        var name: String
        var canEstimate: Bool
        var grams: Double
        var kcalPer100g: Double
        var assumptions: String
        var alternativeNames: [String] = []
    }

    static func foods(containsFood: Bool, items: [Draft]) -> [FoodItem] {
        guard containsFood else { return [] }
        return items.prefix(maxItems).map { item(from: $0, fallbackName: "Unidentified food") }
    }

    static func item(from draft: Draft, fallbackName: String) -> FoodItem {
        let name = String(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        let assumptions = String(draft.assumptions.prefix(400))
        let displayName = name.isEmpty ? fallbackName : name
        var item = FoodItem(name: displayName, grams: nil, kcalPer100g: nil, preparation: assumptions)
        var seen = Set([displayName.lowercased()])
        item.alternativeNames = draft.alternativeNames.compactMap { value in
            let value = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
            guard !value.isEmpty, seen.insert(value.lowercased()).inserted else { return nil }
            return value
        }.prefix(3).map { $0 }
        if draft.canEstimate {
            if draft.grams.isFinite, draft.grams > 0, draft.grams <= 10_000 {
                item.grams = draft.grams
            }
            if draft.kcalPer100g.isFinite, draft.kcalPer100g >= 0, draft.kcalPer100g <= 1_000 {
                item.kcalPer100g = draft.kcalPer100g
            }
        }
        return item
    }
}
