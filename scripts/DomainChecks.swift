import Foundation

@main
struct DomainChecks {
    static func main() async throws {
        let candidates = MealEstimateMapping.foods(containsFood: true, items: [
            .init(name: "Cod fritters", canEstimate: true, grams: 100, kcalPer100g: 220,
                  assumptions: "Visual portion", alternativeNames: ["Fish cakes", "Croquettes", "COD FRITTERS", "Fish cakes"])
        ])
        precondition(candidates.count == 1)
        precondition(candidates[0].alternativeNames == ["Fish cakes", "Croquettes"])
        precondition(Meal(items: candidates).calories == 220)
        precondition(MealEstimateMapping.foods(containsFood: false, items: []).isEmpty)
        let unknown = MealEstimateMapping.item(from: .init(name: "Sauce", canEstimate: false, grams: 20,
            kcalPer100g: 100, assumptions: "Unknown"), fallbackName: "Food")
        precondition(unknown.calories == nil)
        precondition(Meal(items: candidates + [unknown]).isIncomplete)
        let decoded = try JSONDecoder().decode([FoodItem].self, from: JSONEncoder().encode(candidates))
        precondition(decoded == candidates)
        let banana = CatalogRecord(id: "banana", name: "Bananas, raw", preparation: "raw", kcalPer100g: 89)
        let rice = CatalogRecord(id: "rice", name: "Rice, cooked", preparation: "cooked", kcalPer100g: 130)
        let rawRice = CatalogRecord(id: "raw-rice", name: "Rice, raw", preparation: "raw", kcalPer100g: 360)
        let catalog = try NutritionCatalog(records: [banana, rice, rawRice], version: "v1")
        let exact = try await catalog.search(name: "Banana", preparation: "Raw")
        precondition(exact.automaticMatch == banana)
        let ambiguous = try await catalog.search(name: "Rice")
        precondition(ambiguous.automaticMatch == nil && ambiguous.candidates.count == 2)
        let cooked = try await catalog.search(name: "Rice", preparation: "Cooked")
        precondition(cooked.candidates == [rice] && cooked.automaticMatch == rice)
        let uncertain = try await catalog.search(name: "Rice", preparation: "Cooked or raw")
        precondition(uncertain.automaticMatch == nil)
        let enriched = try await catalog.search(name: "Rice", preparation: "Cooked with butter")
        precondition(enriched.automaticMatch == nil)
        for preparation in ["Raw, topped with peanut butter", "Raw, could be plantain", "Raw, possibly plantain"] {
            let result = try await catalog.search(name: "Banana", preparation: preparation)
            precondition(result.automaticMatch == nil)
        }
        let unknownDish = FoodItem(name: "Bacalhau à Brás", grams: 200, kcalPer100g: 180, preparation: "Mixed dish")
        let fallback = try await catalog.resolve(unknownDish)
        precondition(fallback == unknownDish && fallback.calories == 360)
        let unidentified = FoodItem(name: "Banana", grams: 100, kcalPer100g: 90, preparation: "Raw", alternativeNames: ["Plantain"])
        let unresolved = try await catalog.resolve(unidentified)
        precondition(unresolved == unidentified)
        var selected = unknownDish.usingCatalog(banana, version: "v1")
        selected.grams = 200
        precondition(selected.calories == 178 && selected.catalogID == "banana")
        let changed = selected.changingDescription(name: "Banana", preparation: "Fried", grams: 200)
        precondition(changed.kcalPer100g == nil && changed.catalogID == nil && changed.catalogVersion == nil)
        precondition(changed.id == selected.id && changed.energyBasis == .estimated)
        let oldSnapshot = try JSONEncoder().encode(Meal(items: [selected, unknown]))
        let replacement = try NutritionCatalog(records: [.init(id: "banana", name: "Bananas, raw", preparation: "raw", kcalPer100g: 200)], version: "v2")
        let replacementValue = try await replacement.record(id: "banana")
        precondition(replacementValue.record.kcalPer100g == 200)
        let old = try JSONDecoder().decode(Meal.self, from: oldSnapshot)
        precondition(old.items[0] == selected && old.items[0].catalogVersion == "v1" && old.isIncomplete)
        for value in [Double.nan, .infinity, -1, 1001] {
            do {
                _ = try NutritionCatalog(records: [.init(id: "invalid", name: "Food", preparation: "", kcalPer100g: value)], version: "bad")
                preconditionFailure("Invalid energy accepted")
            } catch NutritionCatalog.CatalogError.invalidResource {}
        }
        let water = CatalogRecord(id: "water", name: "Water", preparation: "", kcalPer100g: 0)
        precondition(selected.usingCatalog(water, version: "v1").calories == 0)
        let realCatalog = NutritionCatalog(resource: URL(fileURLWithPath: CommandLine.arguments[1]))
        let actualBananas = try await realCatalog.search(name: "Bananas, raw")
        precondition(!actualBananas.candidates.isEmpty && actualBananas.version == NutritionCatalog.bundledVersion)
        let realRow = try await realCatalog.record(id: "fdc-173944")
        precondition(realRow.record.name == "Bananas, raw" && realRow.record.kcalPer100g == 89)
        print("PASS local search, ambiguity, preparation, fallback, provenance invalidation, scaling, zero energy, snapshot isolation, bundled USDA resource")
        print("PASS identification alternatives, unknown/no-food outcomes, arithmetic, Codable snapshot")
    }
}
