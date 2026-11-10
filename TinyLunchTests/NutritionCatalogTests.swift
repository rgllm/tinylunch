import XCTest
@testable import TinyLunch

final class NutritionCatalogTests: XCTestCase {
    private let banana = CatalogRecord(id: "fdc-1", name: "Bananas, raw", preparation: "raw", kcalPer100g: 89)
    private let rice = CatalogRecord(id: "fdc-2", name: "Rice, cooked", preparation: "cooked", kcalPer100g: 130)

    func testExactMatchAndAmbiguousOrMissingMatches() async throws {
        let catalog = try NutritionCatalog(records: [banana, rice,
            CatalogRecord(id: "fdc-3", name: "Rice, raw", preparation: "raw", kcalPer100g: 360)], version: "test-v1")
        let found = try await catalog.search(name: "Banana", preparation: "Raw")
        XCTAssertEqual(found.automaticMatch, banana)
        let ambiguous = try await catalog.search(name: "Rice")
        XCTAssertNil(ambiguous.automaticMatch)
        XCTAssertEqual(ambiguous.candidates.count, 2)
        let cooked = try await catalog.search(name: "Rice", preparation: "Cooked")
        XCTAssertEqual(cooked.automaticMatch, rice)
        XCTAssertEqual(cooked.candidates, [rice])
        let absent = try await catalog.search(name: "Bacalhau à Brás")
        XCTAssertTrue(absent.candidates.isEmpty)
        XCTAssertNil(absent.automaticMatch)
    }

    func testAddedIngredientsOrNegatedPreparationDoNotAutoMatchPlainFood() async throws {
        let catalog = try NutritionCatalog(records: [rice], version: "v1")
        for preparation in ["Cooked with butter", "Not cooked", "Cooked or raw", "Cooked; sauce unknown"] {
            let result = try await catalog.search(name: "Rice", preparation: preparation)
            XCTAssertNil(result.automaticMatch)
        }
    }

    func testBananaToppingAndUnresolvedIdentityNeverUsePlainBananaAutomatically() async throws {
        let catalog = try NutritionCatalog(records: [banana], version: "v1")
        for preparation in ["Raw, topped with peanut butter", "Raw, could be plantain", "Raw, possibly plantain"] {
            let result = try await catalog.search(name: "Banana", preparation: preparation)
            XCTAssertNil(result.automaticMatch)
        }
    }

    func testUncertainIdentityDoesNotAutomaticallyUseCatalog() async throws {
        let catalog = try NutritionCatalog(records: [banana], version: "test-v1")
        let item = FoodItem(name: "Banana", grams: 100, kcalPer100g: 90, preparation: "Raw", alternativeNames: ["Plantain", "Sweet potato"])
        let resolved = try await catalog.resolve(item)
        XCTAssertEqual(resolved, item)
    }

    func testDuplicateExactNamesNeverAutoSelectEvenWithShortList() async throws {
        let rows = (1...8).map { CatalogRecord(id: "fdc-\($0)", name: "Rice, cooked", preparation: "cooked", kcalPer100g: Double($0)) }
        let catalog = try NutritionCatalog(records: rows, version: "test-v1")
        let result = try await catalog.search(name: "Rice", preparation: "Cooked")
        XCTAssertNil(result.automaticMatch)
        XCTAssertEqual(result.candidates.count, 5)
    }

    func testRawCookedAndBreadedFoodsStaySeparate() async throws {
        let rows = [
            CatalogRecord(id: "raw", name: "Chicken, raw", preparation: "raw", kcalPer100g: 120),
            CatalogRecord(id: "grilled", name: "Chicken, grilled", preparation: "grilled", kcalPer100g: 165),
            CatalogRecord(id: "breaded", name: "Chicken, fried, breaded", preparation: "fried, breaded", kcalPer100g: 280)
        ]
        let catalog = try NutritionCatalog(records: rows, version: "test-v1")
        let grilled = try await catalog.search(name: "Chicken", preparation: "Grilled")
        XCTAssertEqual(grilled.candidates.map(\.id), ["grilled"])
        let breaded = try await catalog.search(name: "Breaded chicken", preparation: "Fried")
        XCTAssertEqual(breaded.candidates.map(\.id), ["breaded"])
    }

    func testMissingMatchKeepsModelValueAndZeroIsValid() async throws {
        let catalog = try NutritionCatalog(records: [banana], version: "test-v1")
        let model = FoodItem(name: "Duck rice", grams: 200, kcalPer100g: 180, preparation: "Baked")
        let resolved = try await catalog.resolve(model)
        XCTAssertEqual(resolved, model)
        XCTAssertEqual(resolved.calories, 360)
        let water = CatalogRecord(id: "water", name: "Water", preparation: "", kcalPer100g: 0)
        XCTAssertEqual(model.usingCatalog(water, version: "test-v1").calories, 0)
        for energy in [Double.nan, .infinity, -1, 1001] {
            XCTAssertThrowsError(try NutritionCatalog(records: [.init(id: "bad", name: "Food", preparation: "", kcalPer100g: energy)], version: "test"))
        }
    }

    func testPortionsRescaleButDescriptionChangesInvalidateProvenance() {
        var item = FoodItem(name: "Banana", grams: 100, kcalPer100g: 90, preparation: "Raw").usingCatalog(banana, version: "test-v1")
        item.grams = 200
        XCTAssertEqual(item.calories, 178)
        XCTAssertEqual(item.catalogID, banana.id)
        let edited = item.changingDescription(name: item.name, preparation: "Fried", grams: 200)
        XCTAssertNil(edited.calories)
        XCTAssertNil(edited.kcalPer100g)
        XCTAssertNil(edited.catalogID)
        XCTAssertNil(edited.catalogVersion)
        XCTAssertEqual(edited.energyBasis, .estimated)
        XCTAssertEqual(edited.id, item.id)
    }

    func testSavedSnapshotDoesNotChangeWhenCatalogChanges() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = FoodItem(name: "Banana", grams: 100, kcalPer100g: 90, preparation: "Raw").usingCatalog(banana, version: "old")
        let saved = Meal(items: [item])
        _ = try await MealStore(directory: directory).save(saved)
        let changed = CatalogRecord(id: banana.id, name: banana.name, preparation: "raw", kcalPer100g: 200)
        let updatedCatalog = try NutritionCatalog(records: [changed], version: "new")
        let newEstimate = try await updatedCatalog.resolve(FoodItem(name: "Banana", grams: 100, kcalPer100g: 1, preparation: "Raw"))
        XCTAssertEqual(newEstimate.kcalPer100g, 200)
        let reopened = try await MealStore(directory: directory).load()
        XCTAssertEqual(reopened, [saved])
        XCTAssertEqual(reopened.first?.items.first?.kcalPer100g, 89)
        XCTAssertEqual(reopened.first?.items.first?.catalogVersion, "old")
    }

    func testCatalogRejectsRemoteResourceURLs() async throws {
        let catalog = NutritionCatalog(resource: URL(string: "https://example.invalid/catalog.json"))
        do {
            _ = try await catalog.search(name: "Banana")
            XCTFail("Remote resources must be rejected before reading")
        } catch NutritionCatalog.CatalogError.unavailable {}
    }

    func testBundledCatalogLoadsAndContainsBothDatasets() async throws {
        let catalog = NutritionCatalog()
        let result = try await catalog.search(name: "Bananas, raw")
        XCTAssertEqual(result.version, NutritionCatalog.bundledVersion)
        XCTAssertFalse(result.candidates.isEmpty)
    }
}
