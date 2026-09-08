import XCTest
@testable import Nosh

final class NoshTests: XCTestCase {
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
}
