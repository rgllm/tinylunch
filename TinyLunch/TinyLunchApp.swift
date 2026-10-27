import SwiftUI

@main
struct TinyLunchApp: App {
    @State private var model: AppModel
    init() {
        var estimator: any FoodEstimating = AppleEstimator()
        var directory = URL.applicationSupportDirectory.appendingPathComponent("TinyLunch", isDirectory: true)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--ui-testing") {
            directory = URL.temporaryDirectory.appendingPathComponent("TinyLunchUITests", isDirectory: true)
            if args.contains("--reset-history") { try? FileManager.default.removeItem(at: directory) }
        }
        if args.contains("--analysis-unavailable") {
            estimator = UnavailableEstimator()
        } else if args.contains("--example-meal") || args.contains("--marketing-screenshots") {
            estimator = FixtureEstimator()
        }
        #endif
        let model = AppModel(estimator: estimator, store: MealStore(directory: directory))
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--example-meal") { model.loadExample() }
        if ProcessInfo.processInfo.arguments.contains("--marketing-review") { model.loadMarketingDraft() }
        #endif
        _model = State(initialValue: model)
    }
    var body: some Scene {
        WindowGroup { RootView(model: model) }
    }
}
