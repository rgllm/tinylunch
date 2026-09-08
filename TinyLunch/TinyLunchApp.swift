import SwiftUI

@main
struct NoshApp: App {
    @State private var model: AppModel
    init() {
        var estimator: any FoodEstimating = AppleEstimator()
        var directory = URL.applicationSupportDirectory.appendingPathComponent("Nosh", isDirectory: true)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            directory = URL.temporaryDirectory.appendingPathComponent("NoshUITests", isDirectory: true)
            if ProcessInfo.processInfo.arguments.contains("--reset-history") { try? FileManager.default.removeItem(at: directory) }
        }
        if ProcessInfo.processInfo.arguments.contains("--example-meal") { estimator = FixtureEstimator() }
        #endif
        let model = AppModel(estimator: estimator, store: MealStore(directory: directory))
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--example-meal") { model.loadExample() }
        #endif
        _model = State(initialValue: model)
    }
    var body: some Scene {
        WindowGroup { RootView(model: model) }
    }
}
