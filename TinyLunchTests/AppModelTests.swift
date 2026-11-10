import XCTest
@testable import TinyLunch

final class AppModelTests: XCTestCase {
    @MainActor func testCatalogChoiceWorksWithoutModelAndPreservesPortion() async throws {
        let estimator = CorrectionEstimator()
        let record = CatalogRecord(id: "banana", name: "Bananas, raw", preparation: "raw", kcalPer100g: 89)
        let catalog = try NutritionCatalog(records: [record], version: "v1")
        let model = makeModel(estimator: estimator, catalog: catalog)
        model.modelAvailability = .appleIntelligenceNotEnabled
        let food = FoodItem(name: "Rice", grams: 150, kcalPer100g: 130, preparation: "Cooked")
        model.draft = Meal(items: [food])
        var completed = false
        model.update(food, correction: .catalog(id: record.id, grams: 150)) { completed = true }
        try await settle(model)
        XCTAssertTrue(completed)
        XCTAssertEqual(model.draft?.items.count, 1)
        XCTAssertEqual(model.draft?.items.first?.id, food.id)
        XCTAssertEqual(model.draft?.items.first?.calories, 133.5)
        XCTAssertEqual(model.draft?.items.first?.catalogID, record.id)
        let calls = await estimator.calls
        XCTAssertEqual(calls, 0)
    }

    @MainActor func testGramsOnlyNeverCallsModelOrDropsCatalogBasis() async throws {
        let estimator = CorrectionEstimator()
        let catalog = try NutritionCatalog(records: [], version: "v1")
        let model = makeModel(estimator: estimator, catalog: catalog)
        let food = FoodItem(name: "Rice", grams: 100, kcalPer100g: 130, preparation: "Cooked",
                            energyBasis: .database, catalogID: "rice", catalogVersion: "old")
        model.draft = Meal(items: [food])
        model.modelAvailability = .appleIntelligenceNotEnabled
        model.update(food, correction: .portion(grams: 200)) {}
        XCTAssertEqual(model.draft?.items.first?.calories, 260)
        XCTAssertEqual(model.draft?.items.first?.catalogVersion, "old")
        XCTAssertEqual(model.draft?.items.first?.identityConfirmed, false)
        let calls = await estimator.calls
        XCTAssertEqual(calls, 0)
    }

    @MainActor func testFoodCorrectionWithNoMatchUsesFreshModelEnergy() async throws {
        let estimator = CorrectionEstimator()
        let model = makeModel(estimator: estimator, catalog: try NutritionCatalog(records: [], version: "v1"))
        let food = FoodItem(name: "Rice", grams: 100, kcalPer100g: 130, preparation: "Cooked",
                            energyBasis: .database, catalogID: "rice", catalogVersion: "old")
        model.draft = Meal(items: [food])
        model.update(food, correction: .description(name: "Duck rice", preparation: "Baked", grams: 200)) {}
        try await settle(model)
        let updated = try XCTUnwrap(model.draft?.items.first)
        XCTAssertEqual(updated.id, food.id)
        XCTAssertEqual(updated.name, "Duck rice")
        XCTAssertEqual(updated.calories, 400)
        XCTAssertEqual(updated.energyBasis, .estimated)
        XCTAssertNil(updated.catalogID)
        XCTAssertNil(updated.catalogVersion)
        let calls = await estimator.calls
        XCTAssertEqual(calls, 1)
    }

    @MainActor func testFailedCorrectionKeepsPreviousSnapshot() async throws {
        let estimator = CorrectionEstimator(fails: true)
        let model = makeModel(estimator: estimator, catalog: try NutritionCatalog(records: [], version: "v1"))
        let food = FoodItem(name: "Rice", grams: 100, kcalPer100g: 130, preparation: "Cooked")
        let original = Meal(items: [food])
        model.draft = original
        model.update(food, correction: .description(name: "Unknown", preparation: "", grams: 100)) {}
        try await settle(model)
        XCTAssertEqual(model.draft, original)
        XCTAssertNotNil(model.error)
    }

    @MainActor func testCancelledCorrectionCannotOverwriteNewMeal() async throws {
        let estimator = DeferredCorrectionEstimator()
        let model = makeModel(estimator: estimator, catalog: try NutritionCatalog(records: [], version: "v1"))
        let food = FoodItem(name: "Rice", grams: 100, kcalPer100g: 130, preparation: "Cooked")
        model.draft = Meal(items: [food])
        model.update(food, correction: .description(name: "Old correction", preparation: "", grams: 100)) {}
        let deadline = Date().addingTimeInterval(3)
        while !(await estimator.waiting), Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        let waiting = await estimator.waiting
        XCTAssertTrue(waiting)
        model.reset()
        let next = Meal(items: [FoodItem(name: "New meal", grams: 100, kcalPer100g: 10, preparation: "")])
        model.draft = next
        await estimator.finish()
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(model.draft, next)
        XCTAssertFalse(model.busy)
    }

    @MainActor private func makeModel(estimator: any FoodEstimating, catalog: NutritionCatalog) -> AppModel {
        AppModel(estimator: estimator,
                 store: MealStore(directory: URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
                 catalog: catalog)
    }

    @MainActor private func settle(_ model: AppModel) async throws {
        let deadline = Date().addingTimeInterval(3)
        while model.busy, Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(model.busy)
    }
}

private actor CorrectionEstimator: FoodEstimating {
    private let fails: Bool
    var calls = 0
    init(fails: Bool = false) { self.fails = fails }
    func availability() async -> AnalysisAvailabilityState { .ready }
    func analyze(_ image: Data) async throws -> [FoodItem] { [] }
    func estimate(name: String, preparation: String) async throws -> FoodItem {
        calls += 1
        if fails { throw EstimateError.refused }
        return FoodItem(name: name, grams: 100, kcalPer100g: 200, preparation: preparation)
    }
}

private actor DeferredCorrectionEstimator: FoodEstimating {
    private var pending: CheckedContinuation<FoodItem, any Error>?
    var waiting: Bool { pending != nil }
    func availability() async -> AnalysisAvailabilityState { .ready }
    func analyze(_ image: Data) async throws -> [FoodItem] { [] }
    func estimate(name: String, preparation: String) async throws -> FoodItem {
        try await withCheckedThrowingContinuation { pending = $0 }
    }
    func finish() {
        pending?.resume(returning: FoodItem(name: "Old correction", grams: 100, kcalPer100g: 200, preparation: ""))
        pending = nil
    }
}
