import FoundationModels
import UIKit
import XCTest
@testable import TinyLunch

final class AnalysisAvailabilityTests: XCTestCase {
    func testDeviceNotEligibleKeepsHistoryAndDoesNotSendPeopleToSettings() {
        let state = AnalysisAvailabilityMapping.state(
            availability: .unavailable(.deviceNotEligible),
            supportsVision: true
        )
        XCTAssertEqual(state, .deviceNotEligible)
        XCTAssertEqual(state.status, .deviceNotEligible)
        XCTAssertEqual(state.primaryAction, .openHistory)
        XCTAssertEqual(state.primaryAction?.title, "Open History")
        XCTAssertNil(state.secondaryAction)
        XCTAssertFalse(state.allowsPhotoAnalysis)
        XCTAssertFalse(state.allowsTextEstimate)
        XCTAssertTrue(state.allowsHistory)
        XCTAssertTrue(state.title.localizedStandardContains("iPhone"))
        XCTAssertTrue(state.explanation.localizedStandardContains("device"))
        XCTAssertTrue(state.explanation.localizedStandardContains("History"))
        XCTAssertFalse(state.explanation.localizedStandardContains("Settings"))
        XCTAssertFalse(state.symbol.isEmpty)
    }

    func testAppleIntelligenceOffGuidesPeopleToSettings() {
        let state = AnalysisAvailabilityMapping.state(
            availability: .unavailable(.appleIntelligenceNotEnabled),
            supportsVision: false
        )
        XCTAssertEqual(state, .appleIntelligenceNotEnabled)
        XCTAssertEqual(state.primaryAction, .openSettings)
        XCTAssertEqual(state.primaryAction?.title, "Open Settings")
        XCTAssertEqual(state.secondaryAction, .retry)
        XCTAssertFalse(state.allowsPhotoAnalysis)
        XCTAssertFalse(state.allowsTextEstimate)
        XCTAssertTrue(state.allowsHistory)
        XCTAssertTrue(state.title.localizedStandardContains("Apple Intelligence"))
        XCTAssertTrue(state.explanation.localizedStandardContains("Settings"))
        XCTAssertTrue(state.explanation.localizedStandardContains("Apple Intelligence"))
        XCTAssertTrue(state.explanation.localizedStandardContains("History"))
    }

    func testModelNotReadyOffersRetryWhileHistoryStaysOpen() {
        let state = AnalysisAvailabilityMapping.state(
            availability: .unavailable(.modelNotReady),
            supportsVision: false
        )
        XCTAssertEqual(state, .modelNotReady)
        XCTAssertEqual(state.primaryAction, .retry)
        XCTAssertEqual(state.primaryAction?.title, "Try again")
        XCTAssertEqual(state.secondaryAction, .openHistory)
        XCTAssertFalse(state.allowsPhotoAnalysis)
        XCTAssertFalse(state.allowsTextEstimate)
        XCTAssertTrue(state.allowsHistory)
        XCTAssertTrue(state.explanation.lowercased().contains("download"))
        XCTAssertTrue(state.explanation.localizedStandardContains("History"))
        XCTAssertNotEqual(state.primaryAction, .openSettings)
    }

    func testReadyAndMissingVisionStaySeparateFromUnavailableReasons() {
        let ready = AnalysisAvailabilityMapping.state(availability: .available, supportsVision: true)
        XCTAssertEqual(ready, .ready)
        XCTAssertTrue(ready.allowsPhotoAnalysis)
        XCTAssertTrue(ready.allowsTextEstimate)
        XCTAssertTrue(ready.allowsHistory)
        XCTAssertNil(ready.primaryAction)
        XCTAssertNil(ready.secondaryAction)

        let vision = AnalysisAvailabilityMapping.state(availability: .available, supportsVision: false)
        XCTAssertEqual(vision, .visionUnavailable)
        XCTAssertFalse(vision.allowsPhotoAnalysis)
        XCTAssertTrue(vision.allowsTextEstimate)
        XCTAssertTrue(vision.allowsHistory)
        XCTAssertEqual(vision.primaryAction, .openHistory)
        XCTAssertEqual(vision.secondaryAction, .retry)
        XCTAssertTrue(vision.explanation.localizedStandardContains("History"))
    }

    func testEachUnavailableCaseHasItsOwnExplanationAndAWayForward() {
        let device = AnalysisAvailabilityMapping.state(availability: .unavailable(.deviceNotEligible), supportsVision: false)
        let turnedOff = AnalysisAvailabilityMapping.state(availability: .unavailable(.appleIntelligenceNotEnabled), supportsVision: true)
        let notReady = AnalysisAvailabilityMapping.state(availability: .unavailable(.modelNotReady), supportsVision: true)
        let states = [device, turnedOff, notReady]

        XCTAssertEqual(Set(states.map(\.status)).count, states.count)
        XCTAssertEqual(Set(states.map(\.title)).count, states.count)
        XCTAssertEqual(Set(states.map(\.explanation)).count, states.count)
        XCTAssertEqual(Set(states.map(\.symbol)).count, states.count)
        XCTAssertEqual(Set(states.map(\.primaryAction)).count, states.count)
        for state in states {
            XCTAssertFalse(state.allowsPhotoAnalysis)
            XCTAssertTrue(state.allowsHistory)
            XCTAssertNotNil(state.primaryAction)
            XCTAssertFalse(state.title.isEmpty)
            XCTAssertFalse(state.explanation.isEmpty)
            XCTAssertNotEqual(state.primaryAction, state.secondaryAction)
        }
    }

    func testUnknownAvailabilityStillOffersRetryAndHistory() {
        let state = AnalysisAvailabilityState.unavailable
        XCTAssertEqual(state.status, .unavailable)
        XCTAssertEqual(state.primaryAction, .retry)
        XCTAssertEqual(state.secondaryAction, .openHistory)
        XCTAssertFalse(state.allowsPhotoAnalysis)
        XCTAssertFalse(state.allowsTextEstimate)
        XCTAssertTrue(state.allowsHistory)
        XCTAssertTrue(state.explanation.localizedStandardContains("History"))
        XCTAssertEqual(AnalysisAvailabilityState.Action.openSettings.title, "Open Settings")
        XCTAssertEqual(AnalysisAvailabilityState.Action.retry.title, "Try again")
        XCTAssertEqual(AnalysisAvailabilityState.Action.openHistory.title, "Open History")
    }

    @MainActor
    func testHistoryStaysReadableAndAnalysisDoesNotStartWhenTheDeviceIsNotEligible() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MealStore(directory: directory)
        let meal = Meal(items: [FoodItem(name: "Rice", grams: 100, kcalPer100g: 130, preparation: "Cooked")])
        _ = try await store.save(meal)

        let model = AppModel(estimator: ScriptedEstimator(modelAvailability: .deviceNotEligible), store: store)
        await model.refresh()

        XCTAssertEqual(model.modelAvailability, .deviceNotEligible)
        XCTAssertFalse(model.modelAvailability.allowsPhotoAnalysis)
        XCTAssertTrue(model.modelAvailability.allowsHistory)
        XCTAssertTrue(model.historyLoaded)
        XCTAssertEqual(model.meals, [meal])

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        model.image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        XCTAssertNotNil(model.image?.jpegData(compressionQuality: 0.85))
        model.analyze()
        XCTAssertFalse(model.busy)
        XCTAssertNil(model.draft)
        XCTAssertNil(model.error)
        XCTAssertEqual(model.meals, [meal])
    }

    @MainActor
    func testPortionEditsStillApplyWhenTheModelIsNotReady() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(
            estimator: ScriptedEstimator(modelAvailability: .modelNotReady),
            store: MealStore(directory: directory)
        )
        let rice = FoodItem(name: "Rice", grams: 150, kcalPer100g: 130, preparation: "Cooked")
        model.draft = Meal(items: [rice])

        var applied = false
        model.update(rice, name: rice.name, preparation: rice.preparation, grams: 300) { applied = true }
        XCTAssertTrue(applied)
        XCTAssertEqual(model.draft?.items.first?.grams, 300)
        XCTAssertEqual(model.draft?.items.first?.calories, 390)
        XCTAssertFalse(model.busy)
        XCTAssertNil(model.error)

        applied = false
        model.update(rice, name: "Bread", preparation: rice.preparation, grams: 80) { applied = true }
        XCTAssertFalse(applied)
        XCTAssertEqual(model.draft?.items.first?.name, "Rice")
        XCTAssertEqual(model.draft?.items.first?.grams, 300)
        XCTAssertEqual(model.error, AnalysisAvailabilityState.modelNotReady.explanation)
        XCTAssertFalse(model.busy)
    }
}

private struct ScriptedEstimator: FoodEstimating {
    var modelAvailability: AnalysisAvailabilityState
    func availability() async -> AnalysisAvailabilityState { modelAvailability }
    func analyze(_ image: Data) async throws -> [FoodItem] { [] }
    func estimate(name: String, preparation: String) async throws -> FoodItem {
        FoodItem(name: name, grams: 100, kcalPer100g: 100, preparation: preparation)
    }
}
