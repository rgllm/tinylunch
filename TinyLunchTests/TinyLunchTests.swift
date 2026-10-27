import XCTest
@testable import TinyLunch

final class TinyLunchTests: XCTestCase {
    func testPartialTotalAndPortionScaling() {
        var rice = FoodItem(name: "Rice", grams: 150, kcalPer100g: 130, preparation: "Cooked")
        let unknown = FoodItem(name: "Sauce", grams: nil, kcalPer100g: nil, preparation: "")
        let meal = Meal(items: [rice, unknown])
        XCTAssertEqual(meal.calories, 195)
        XCTAssertTrue(meal.isIncomplete)
        rice.grams = 300
        XCTAssertEqual(rice.calories, 390)
        XCTAssertNil(Meal(items: [unknown]).calories)
    }

    func testInvalidNumbersNeverBecomeZero() {
        for value in [Double.nan, .infinity, -1, 10_001, 0] {
            XCTAssertNil(FoodItem(name: "Food", grams: value, kcalPer100g: 100, preparation: "").calories)
        }
        XCTAssertEqual(FoodItem(name: "Water", grams: 200, kcalPer100g: 0, preparation: "").calories, 0)
        XCTAssertNil(FoodItem(name: "Food", grams: 100, kcalPer100g: .infinity, preparation: "").calories)
    }

    func testPhotoEstimateMappingKeepsUnknownAndRejectsInvalidNumbers() {
        let foods = MealEstimateMapping.foods(containsFood: true, items: [
            .init(name: " Rice ", canEstimate: true, grams: 150, kcalPer100g: 130, assumptions: "Cooked"),
            .init(name: "Sauce", canEstimate: false, grams: 40, kcalPer100g: 90, assumptions: "Unknown"),
            .init(name: "Oil", canEstimate: true, grams: .nan, kcalPer100g: 884, assumptions: "Poured"),
            .init(name: "", canEstimate: true, grams: 10_001, kcalPer100g: 100, assumptions: "")
        ])
        XCTAssertEqual(foods.count, 4)
        XCTAssertEqual(foods[0].name, "Rice")
        XCTAssertEqual(foods[0].calories, 195)
        XCTAssertNil(foods[1].calories)
        XCTAssertEqual(foods[1].name, "Sauce")
        XCTAssertNil(foods[2].calories)
        XCTAssertEqual(foods[3].name, "Unidentified food")
        XCTAssertNil(foods[3].calories)
        XCTAssertTrue(MealEstimateMapping.foods(containsFood: false, items: [
            .init(name: "Rice", canEstimate: true, grams: 150, kcalPer100g: 130, assumptions: "")
        ]).isEmpty)
    }

    func testHistoryPersistenceDuplicatesDeletionAndCorruption() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MealStore(directory: directory)
        let meal = Meal(items: [FoodItem(name: "Unknown", grams: nil, kcalPer100g: nil, preparation: "")])
        _ = try await store.save(meal)
        let duplicates = try await store.save(meal)
        XCTAssertEqual(duplicates.count, 1)
        let reopened = try await MealStore(directory: directory).load()
        XCTAssertEqual(reopened, [meal])
        let removed = try await store.delete(meal.id)
        XCTAssertTrue(removed.isEmpty)
        let file = directory.appendingPathComponent("meals.json")
        try Data("broken".utf8).write(to: file)
        do { _ = try await store.save(meal); XCTFail("Must preserve unreadable store") } catch {}
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "broken")
    }

    func testLegacyArchiveDecodesAsEstimatedAndNewArchiveRoundTrips() async throws {
        let created = FoodItem(name: "Rice", grams: 150, kcalPer100g: 130, preparation: "Cooked")
        XCTAssertEqual(created.energyBasis, .estimated)
        XCTAssertNil(created.catalogID)
        XCTAssertNil(created.catalogVersion)
        let mapped = MealEstimateMapping.item(
            from: .init(name: "Rice", canEstimate: true, grams: 150, kcalPer100g: 130, assumptions: "Cooked"),
            fallbackName: "Unidentified food"
        )
        XCTAssertEqual(mapped.energyBasis, .estimated)
        XCTAssertNil(mapped.catalogID)
        XCTAssertNil(mapped.catalogVersion)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("meals.json")
        let mealID = try XCTUnwrap(UUID(uuidString: "A1B2C3D4-E5F6-4789-A123-456789ABCDEF"))
        let riceID = try XCTUnwrap(UUID(uuidString: "11111111-2222-4333-8444-555555555555"))
        let sauceID = try XCTUnwrap(UUID(uuidString: "22222222-3333-4444-8555-666666666666"))
        let waterID = try XCTUnwrap(UUID(uuidString: "33333333-4444-4555-8666-777777777777"))
        let legacy = """
        {"schemaVersion":1,"meals":[{"id":"\(mealID.uuidString)","savedAt":780000000,"estimatorVersion":"apple-on-device-prompt-v1","items":[{"id":"\(riceID.uuidString)","name":"Rice","grams":150,"kcalPer100g":130,"preparation":"Cooked","portionConfirmed":true},{"id":"\(sauceID.uuidString)","name":"Sauce","preparation":"","portionConfirmed":false},{"id":"\(waterID.uuidString)","name":"Water","grams":200,"kcalPer100g":0,"preparation":"Tap","portionConfirmed":false,"energyBasis":null,"catalogID":null,"catalogVersion":null}]}]}
        """
        try Data(legacy.utf8).write(to: file)
        let before = try Data(contentsOf: file)
        let loaded = try await MealStore(directory: directory).load()
        XCTAssertEqual(try Data(contentsOf: file), before)
        XCTAssertEqual(loaded.count, 1)
        let meal = try XCTUnwrap(loaded.first)
        XCTAssertEqual(meal.id, mealID)
        XCTAssertEqual(meal.savedAt, Date(timeIntervalSinceReferenceDate: 780_000_000))
        XCTAssertEqual(meal.estimatorVersion, "apple-on-device-prompt-v1")
        XCTAssertEqual(meal.calories, 195)
        XCTAssertTrue(meal.isIncomplete)
        XCTAssertEqual(meal.items.count, 3)
        XCTAssertEqual(meal.items[0].id, riceID)
        XCTAssertEqual(meal.items[0].name, "Rice")
        XCTAssertEqual(meal.items[0].grams, 150)
        XCTAssertEqual(meal.items[0].kcalPer100g, 130)
        XCTAssertEqual(meal.items[0].preparation, "Cooked")
        XCTAssertTrue(meal.items[0].portionConfirmed)
        XCTAssertEqual(meal.items[0].calories, 195)
        XCTAssertEqual(meal.items[0].energyBasis, .estimated)
        XCTAssertNil(meal.items[0].catalogID)
        XCTAssertNil(meal.items[0].catalogVersion)
        XCTAssertEqual(meal.items[1].id, sauceID)
        XCTAssertNil(meal.items[1].calories)
        XCTAssertEqual(meal.items[1].energyBasis, .estimated)
        XCTAssertNil(meal.items[1].catalogID)
        XCTAssertNil(meal.items[1].catalogVersion)
        XCTAssertEqual(meal.items[2].id, waterID)
        XCTAssertEqual(meal.items[2].calories, 0)
        XCTAssertEqual(meal.items[2].energyBasis, .estimated)
        XCTAssertNil(meal.items[2].catalogID)
        XCTAssertNil(meal.items[2].catalogVersion)

        let freshDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: freshDirectory) }
        let estimated = FoodItem(name: "Rice", grams: 150, kcalPer100g: 130, preparation: "Cooked", portionConfirmed: true)
        let catalogued = FoodItem(
            name: "Banana",
            grams: 120,
            kcalPer100g: 89,
            preparation: "Fresh",
            energyBasis: .database,
            catalogID: "fdc-173944",
            catalogVersion: "usda-sr-legacy-2018"
        )
        let freshMeal = Meal(
            savedAt: Date(timeIntervalSinceReferenceDate: 780_000_000),
            items: [estimated, catalogued],
            estimatorVersion: "apple-on-device-prompt-v1"
        )
        let store = MealStore(directory: freshDirectory)
        _ = try await store.save(freshMeal)
        let archived = try String(contentsOf: freshDirectory.appendingPathComponent("meals.json"), encoding: .utf8)
        XCTAssertTrue(archived.contains("\"schemaVersion\":1"))
        XCTAssertTrue(archived.contains("\"energyBasis\":\"estimated\""))
        XCTAssertTrue(archived.contains("\"energyBasis\":\"database\""))
        XCTAssertTrue(archived.contains("\"catalogID\":null"))
        XCTAssertTrue(archived.contains("\"catalogVersion\":null"))
        XCTAssertTrue(archived.contains("\"catalogID\":\"fdc-173944\""))
        XCTAssertTrue(archived.contains("\"catalogVersion\":\"usda-sr-legacy-2018\""))
        let reopened = try await MealStore(directory: freshDirectory).load()
        XCTAssertEqual(reopened, [freshMeal])
        XCTAssertEqual(reopened.first?.items.first?.energyBasis, .estimated)
        XCTAssertNil(reopened.first?.items.first?.catalogID)
        XCTAssertNil(reopened.first?.items.first?.catalogVersion)
        XCTAssertEqual(reopened.first?.items.last?.energyBasis, .database)
        XCTAssertEqual(reopened.first?.items.last?.catalogID, "fdc-173944")
        XCTAssertEqual(reopened.first?.items.last?.catalogVersion, "usda-sr-legacy-2018")
        XCTAssertEqual(reopened.first?.items[0].calories, 195)
        XCTAssertEqual(reopened.first?.items[1].calories, 120 * 89 / 100)
        XCTAssertEqual(reopened.first?.isIncomplete, false)
    }

    func testVoiceOverGroupsNameEnergyAndEstimate() {
        let rice = FoodItem(name: "Rice", grams: 150, kcalPer100g: 130, preparation: "Cooked")
        let sauce = FoodItem(name: "Sauce", grams: nil, kcalPer100g: nil, preparation: "Unknown")
        let riceParts = spokenParts(rice.accessibilityDescription)
        XCTAssertEqual(riceParts.first, "Rice")
        XCTAssertTrue(riceParts.contains("Estimated"))
        XCTAssertTrue(rice.accessibilityDescription.localizedCaseInsensitiveContains("kilocalories"))
        XCTAssertTrue(rice.accessibilityDescription.contains(195.formatted(.number.precision(.fractionLength(0)))))
        XCTAssertTrue(rice.accessibilityDescription.contains("Suggested portion"))
        XCTAssertTrue(rice.accessibilityDescription.contains("Cooked"))
        XCTAssertTrue(rice.showsEstimatedBadge)
        XCTAssertFalse(spokenParts(sauce.accessibilityDescription).contains("Estimated"))
        XCTAssertTrue(spokenParts(sauce.accessibilityDescription).contains("Not estimated"))
        XCTAssertFalse(sauce.showsEstimatedBadge)

        let water = FoodItem(name: "Water", grams: 200, kcalPer100g: 0, preparation: "Still", portionConfirmed: true)
        XCTAssertEqual(water.calories, 0)
        XCTAssertTrue(water.showsEstimatedBadge)
        XCTAssertTrue(water.accessibilityDescription.contains("Confirmed portion"))
        XCTAssertFalse(water.accessibilityDescription.contains("No estimate"))

        let meal = Meal(items: [rice, sauce])
        XCTAssertTrue(meal.spokenEnergy.localizedCaseInsensitiveContains("kilocalories"))
        XCTAssertTrue(meal.historyAccessibilityLabel.hasPrefix("Rice, Sauce, \(meal.spokenEnergy), Incomplete estimate"))
        XCTAssertEqual(Meal(items: [sauce]).spokenEnergy, "No estimate")
    }

    private func spokenParts(_ label: String) -> [String] {
        label.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
