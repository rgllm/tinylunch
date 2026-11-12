import SwiftUI
import PhotosUI
import ImageIO

@MainActor @Observable
final class AppModel {
    var meals: [Meal] = []
    var draft: Meal?
    var image: UIImage?
    var modelAvailability = AnalysisAvailabilityState.ready
    var issue: PresentationIssue?
    var error: String? { issue?.message }
    var savedMeal: Meal?
    var busy = false
    var saving = false
    var importing = false
    var historyLoaded = false
    var savedNotice = false
    private let estimator: any FoodEstimating
    let catalog: NutritionCatalog
    private let store: MealStore
    private var operation: Task<Void, Never>?
    private var requestID = UUID()

    init(estimator: any FoodEstimating, store: MealStore, catalog: NutritionCatalog = NutritionCatalog()) {
        self.estimator = estimator
        self.store = store
        self.catalog = catalog
    }

    func refresh() async {
        if issue?.cause == .history { issue = nil }
        modelAvailability = await estimator.availability()
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--marketing-history") {
                let existing = try await store.load()
                if existing.isEmpty {
                    await seedMarketingHistory()
                    return
                }
            }
            #endif
            meals = try await store.load()
            historyLoaded = true
        } catch {
            self.issue = PresentationIssue(cause: .history, message: String(localized: "Saved meals could not be read. Your existing history has not been replaced. Try again after unlocking your iPhone."), recovery: .refresh)
        }
    }

    func cancel() {
        requestID = UUID()
        operation?.cancel()
        operation = nil
        busy = false
        importing = false
    }

    func reset() {
        cancel()
        image = nil
        draft = nil
        savedNotice = false
        savedMeal = nil
        issue = nil
    }

    func importPhoto(_ item: PhotosPickerItem) {
        cancel()
        issue = nil
        importing = true
        let id = requestID
        operation = Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw ImportError.invalid }
                let decoded = try await Task.detached { try Self.decode(data) }.value
                guard id == requestID, !Task.isCancelled else { return }
                image = decoded
                draft = nil
                savedNotice = false
            } catch {
                guard id == requestID, !Task.isCancelled else { return }
                self.issue = PresentationIssue(cause: .photoImport, message: String(localized: "This photo could not be imported. An iCloud photo may need a connection. Try another photo or take one with the camera."))
            }
            if id == requestID { importing = false }
        }
    }

    nonisolated private static func decode(_ data: Data) throws -> UIImage {
        guard data.count <= 50_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary) else { throw ImportError.invalid }
        return UIImage(cgImage: cg)
    }

    func receiveCapture(_ captured: UIImage) {
        cancel()
        issue = nil
        let maxDimension = max(captured.size.width, captured.size.height)
        let scale = min(1, 2048 / maxDimension)
        let size = CGSize(width: captured.size.width * scale, height: captured.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            captured.draw(in: CGRect(origin: .zero, size: size))
        }
        draft = nil
        savedNotice = false
    }

    func analyze() {
        guard !busy, !importing, modelAvailability.allowsPhotoAnalysis,
              let data = image?.jpegData(compressionQuality: 0.85) else { return }
        cancel()
        issue = nil
        busy = true
        let id = requestID
        operation = Task {
            do {
                let recognized = try await estimator.analyze(data)
                var items: [FoodItem] = []
                for item in recognized {
                    try Task.checkCancellation()
                    items.append((try? await catalog.resolve(item)) ?? item)
                }
                guard id == requestID, !Task.isCancelled else { return }
                if items.isEmpty {
                    issue = PresentationIssue(cause: .noFood, message: String(localized: "No food was identified. Try a clearer photo with the meal in view."))
                } else {
                    image = nil
                    draft = Meal(items: items, estimatorVersion: MealEstimateMapping.promptVersion)
                }
            } catch is CancellationError {
            } catch {
                guard id == requestID, !Task.isCancelled else { return }
                self.issue = PresentationIssue(cause: .analysis, message: (error as? LocalizedError)?.errorDescription
                    ?? String(localized: "The meal could not be estimated. Your photo is still here so you can retry."), recovery: error is EstimateError ? nil : .analyze)
            }
            if id == requestID { busy = false }
        }
    }

    func update(_ item: FoodItem, correction: FoodCorrection, onSuccess: @escaping @MainActor () -> Void) {
        guard !busy, !saving, var meal = draft else { return }
        issue = nil
        if case .portion(let grams) = correction {
            guard let index = meal.items.firstIndex(where: { $0.id == item.id }) else { return }
            meal.items[index].grams = grams
            meal.items[index].portionConfirmed = grams != nil
            draft = meal
            onSuccess()
            return
        }
        cancel()
        busy = true
        let id = requestID
        operation = Task {
            do {
                var updated: FoodItem
                switch correction {
                case .portion:
                    return
                case .catalog(let catalogID, let grams):
                    let selection = try await catalog.record(id: catalogID)
                    updated = item.usingCatalog(selection.record, version: selection.version)
                    updated.grams = grams
                    updated.portionConfirmed = grams != nil
                case .description(let name, let preparation, let grams):
                    let invalidated = item.changingDescription(name: name, preparation: preparation, grams: grams)
                    updated = (try? await catalog.resolve(invalidated)) ?? invalidated
                    if updated.energyBasis != .database {
                        guard modelAvailability.allowsTextEstimate else {
                            throw EstimateError.unavailable(modelAvailability.explanation)
                        }
                        updated = try await estimator.estimate(name: name, preparation: preparation)
                        updated.identityConfirmed = true
                        if let grams { updated.grams = grams; updated.portionConfirmed = true }
                        updated = (try? await catalog.resolve(updated)) ?? updated
                    }
                }
                guard id == requestID, !Task.isCancelled else { return }
                updated.id = item.id
                if let index = meal.items.firstIndex(where: { $0.id == item.id }) {
                    meal.items[index] = updated
                } else { meal.items.append(updated) }
                draft = meal
                onSuccess()
            } catch {
                guard id == requestID, !Task.isCancelled else { return }
                let reason = (error as? LocalizedError)?.errorDescription ?? String(localized: "This correction could not be estimated.")
                self.issue = PresentationIssue(cause: .correction, message: String(localized: "\(reason) The previous draft is unchanged. Your entries are still here. Choose a local catalog match or update the food to try again."))
            }
            if id == requestID { busy = false }
        }
    }

    func save() async {
        guard !saving, !busy, historyLoaded, var meal = draft, !meal.items.isEmpty else { return }
        issue = nil
        saving = true
        defer { saving = false }
        meal.savedAt = Date()
        do {
            meals = try await store.save(meal)
            draft = nil
            image = nil
            savedMeal = meals.first(where: { $0.id == meal.id }) ?? meal
            savedNotice = true
        } catch { self.issue = PresentationIssue(cause: .save, message: String(localized: "The meal could not be saved. Your draft is still here. Please retry."), recovery: .save) }
    }

    func delete(_ meal: Meal) async {
        guard !saving else { return }
        issue = nil
        saving = true
        defer { saving = false }
        do {
            meals = try await store.delete(meal.id)
            if savedMeal?.id == meal.id { savedMeal = nil; savedNotice = false }
        }
        catch { self.issue = PresentationIssue(cause: .delete, message: String(localized: "The meal could not be deleted. It is still in History."), recovery: .delete(meal)) }
    }

    func recoverIssue(_ recovery: PresentationIssue.Recovery? = nil) async {
        let recovery = recovery ?? issue?.recovery
        issue = nil
        switch recovery {
        case .refresh: await refresh()
        case .analyze: analyze()
        case .save: await save()
        case .delete(let meal): await delete(meal)
        case nil: break
        }
    }

    #if DEBUG
    func loadExample() {
        draft = Meal(items: [FoodItem(name: "Rice", grams: 150, kcalPer100g: 130, preparation: "Cooked; example data", alternativeNames: ["Couscous", "Orzo"]),
                             FoodItem(name: "Unidentified sauce", grams: nil, kcalPer100g: nil, preparation: "Unknown; example data")], estimatorVersion: "ui-test-fixture")
    }

    func loadMarketingDraft() {
        draft = Meal(items: Self.marketingLunchItems, estimatorVersion: MealEstimateMapping.promptVersion)
    }

    func seedMarketingHistory() async {
        for meal in Self.marketingSavedMeals {
            _ = try? await store.save(meal)
        }
        meals = (try? await store.load()) ?? []
        historyLoaded = true
    }

    private static let marketingLunchItems = [
        FoodItem(name: "Grilled salmon", grams: 180, kcalPer100g: 180, preparation: "Grilled; skin off; visual portion", portionConfirmed: true),
        FoodItem(name: "Jasmine rice", grams: 150, kcalPer100g: 130, preparation: "Cooked; packed cup", portionConfirmed: true),
        FoodItem(name: "Broccoli", grams: 80, kcalPer100g: 35, preparation: "Steamed", portionConfirmed: true)
    ]

    private static var marketingSavedMeals: [Meal] {
        [
            Meal(
                savedAt: Date().addingTimeInterval(-3600),
                items: marketingLunchItems,
                estimatorVersion: MealEstimateMapping.promptVersion
            ),
            Meal(
                savedAt: Date().addingTimeInterval(-86400),
                items: [
                    FoodItem(name: "Overnight oats", grams: 250, kcalPer100g: 90, preparation: "Rolled oats with milk", portionConfirmed: true),
                    FoodItem(name: "Banana", grams: 120, kcalPer100g: 89, preparation: "Fresh", portionConfirmed: true)
                ],
                estimatorVersion: MealEstimateMapping.promptVersion
            )
        ]
    }
    #endif
    private enum ImportError: Error { case invalid }
}

struct PresentationIssue {
    enum Cause {
        case history, photoImport, camera, noFood, analysis, correction, save, delete

        var title: String {
            switch self {
            case .history: String(localized: "History could not be loaded")
            case .photoImport: String(localized: "Photo could not be imported")
            case .camera: String(localized: "Camera unavailable")
            case .noFood: String(localized: "No food identified")
            case .analysis: String(localized: "Meal could not be estimated")
            case .correction: String(localized: "Food could not be updated")
            case .save: String(localized: "Meal could not be saved")
            case .delete: String(localized: "Meal could not be deleted")
            }
        }

        var dismissal: String {
            switch self {
            case .history: String(localized: "Close message")
            case .delete: String(localized: "Keep meal")
            case .photoImport, .camera: String(localized: "Back to photo options")
            case .noFood, .analysis: String(localized: "Review photo")
            case .correction: String(localized: "Keep editing")
            case .save: String(localized: "Keep reviewing")
            }
        }
    }

    enum Recovery {
        case refresh, analyze, save, delete(Meal)

        var title: String {
            switch self {
            case .refresh: String(localized: "Reload History")
            case .analyze: String(localized: "Retry estimate")
            case .save: String(localized: "Retry save")
            case .delete: String(localized: "Retry delete")
            }
        }
    }

    var cause: Cause
    var message: String
    var recovery: Recovery? = nil
}
