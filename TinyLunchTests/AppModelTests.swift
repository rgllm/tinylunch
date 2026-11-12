import XCTest
@testable import TinyLunch

final class AppModelTests: XCTestCase {
    func testPortionInputConsumesTheWholeValueAndAllowsMissingPortions() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(PortionInput("", locale: locale), .missing)
        XCTAssertEqual(PortionInput("  ", locale: locale), .missing)
        XCTAssertEqual(PortionInput("150.5", locale: locale), .valid(150.5))
        XCTAssertEqual(PortionInput("10000", locale: locale), .valid(10000))
        for text in ["150abc", "150 g", "1.5.2", "NaN", "inf", "1,000"] {
            XCTAssertEqual(PortionInput(text, locale: locale), .malformed, text)
        }
        for text in ["0", "-1", "10001"] {
            XCTAssertEqual(PortionInput(text, locale: locale), .outOfRange, text)
        }
        XCTAssertEqual(PortionInput("150,5", locale: Locale(identifier: "pt_PT")), .valid(150.5))
        XCTAssertEqual(PortionInput("1.000", locale: Locale(identifier: "pt_PT")), .malformed)
        let original = 123.45678901234567
        let displayed = original.formatted(.number.locale(locale).grouping(.never))
        XCTAssertEqual(PortionInput(displayed, locale: locale, original: original), .valid(original))
        XCTAssertEqual(PortionInput("125", locale: locale, original: original), .valid(125))
        let half = original * 0.5
        let displayedHalf = half.formatted(.number.locale(locale).grouping(.never).precision(.significantDigits(1...17)))
        XCTAssertEqual(PortionInput(displayedHalf, locale: locale, original: original), .valid(half))
    }

    @MainActor func testSaveFailureKeepsDraftAndRetryConfirmsTheSavedSnapshot() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MealStore(directory: directory)
        let model = AppModel(estimator: CorrectionEstimator(), store: store)
        await model.refresh()
        let draft = Meal(items: [FoodItem(name: "Unknown sauce", grams: nil, kcalPer100g: nil, preparation: "")])
        model.draft = draft
        try Data("blocked".utf8).write(to: directory)
        await model.save()
        XCTAssertEqual(model.draft, draft)
        XCTAssertFalse(model.savedNotice)
        XCTAssertNil(model.savedMeal)
        XCTAssertEqual(model.issue?.cause, .save)
        try FileManager.default.removeItem(at: directory)
        await model.recoverIssue()
        XCTAssertNil(model.draft)
        XCTAssertTrue(model.savedNotice)
        XCTAssertEqual(model.savedMeal?.id, draft.id)
        XCTAssertEqual(model.savedMeal?.items, draft.items)
        XCTAssertTrue(model.savedMeal?.isIncomplete == true)
        let saved = try await store.load()
        XCTAssertEqual(model.savedMeal, saved.first)
        XCTAssertNil(model.issue)
    }

    @MainActor func testDeleteRecoveryTargetsOnlyTheMealThatFailed() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MealStore(directory: directory)
        let first = Meal(items: [FoodItem(name: "Rice", grams: 100, kcalPer100g: 130, preparation: "Cooked")])
        let second = Meal(items: [FoodItem(name: "Tea", grams: 200, kcalPer100g: 0, preparation: "Plain")])
        _ = try await store.save(first)
        _ = try await store.save(second)
        let model = AppModel(estimator: CorrectionEstimator(), store: store)
        await model.refresh()
        let file = directory.appendingPathComponent("meals.json")
        let archive = try Data(contentsOf: file)
        try Data("unreadable".utf8).write(to: file)
        await model.delete(first)
        XCTAssertEqual(model.meals.count, 2)
        XCTAssertEqual(model.issue?.cause, .delete)
        guard case .delete(let target) = model.issue?.recovery else { return XCTFail("Missing targeted recovery") }
        XCTAssertEqual(target.id, first.id)
        try archive.write(to: file)
        model.issue = nil
        await model.recoverIssue(.delete(target))
        XCTAssertEqual(model.meals.map(\.id), [second.id])
        let remaining = try await store.load()
        XCTAssertEqual(remaining.map(\.id), [second.id])
    }

    @MainActor func testSavedConfirmationDoesNotFollowHistorySortOrder() async throws {
        let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MealStore(directory: directory)
        let future = Meal(savedAt: .distantFuture, items: [FoodItem(name: "Later meal", grams: 100, kcalPer100g: 50, preparation: "")])
        _ = try await store.save(future)
        let model = AppModel(estimator: CorrectionEstimator(), store: store)
        await model.refresh()
        let draft = Meal(items: [FoodItem(name: "Tea", grams: 200, kcalPer100g: 0, preparation: "Plain")])
        model.draft = draft
        await model.save()
        await model.refresh()
        XCTAssertEqual(model.meals.first?.id, future.id)
        XCTAssertEqual(model.savedMeal?.id, draft.id)
        XCTAssertEqual(model.savedMeal?.calories, 0)
    }

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
        XCTAssertEqual(model.issue?.cause, .correction)
        XCTAssertNil(model.issue?.recovery)
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
