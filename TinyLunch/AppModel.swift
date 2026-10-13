import SwiftUI
import PhotosUI
import ImageIO

@MainActor @Observable
final class AppModel {
    var meals: [Meal] = []
    var draft: Meal?
    var image: UIImage?
    var modelAvailability = AnalysisAvailabilityState.ready
    var error: String?
    var busy = false
    var saving = false
    var importing = false
    var historyLoaded = false
    var savedNotice = false
    private let estimator: any FoodEstimating
    private let store: MealStore
    private var operation: Task<Void, Never>?
    private var requestID = UUID()

    init(estimator: any FoodEstimating, store: MealStore) {
        self.estimator = estimator
        self.store = store
    }

    func refresh() async {
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
            self.error = "Saved meals could not be read. Your existing history has not been replaced. Try again after unlocking your iPhone."
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
    }

    func importPhoto(_ item: PhotosPickerItem) {
        cancel()
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
                self.error = "This photo could not be imported. An iCloud photo may need a connection. Try another photo or take one with the camera."
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
        busy = true
        let id = requestID
        operation = Task {
            do {
                let items = try await estimator.analyze(data)
                guard id == requestID, !Task.isCancelled else { return }
                if items.isEmpty {
                    error = "No food was identified. Try a clearer photo with the meal in view."
                } else {
                    image = nil
                    draft = Meal(items: items, estimatorVersion: MealEstimateMapping.promptVersion)
                }
            } catch is CancellationError {
            } catch {
                guard id == requestID, !Task.isCancelled else { return }
                self.error = (error as? LocalizedError)?.errorDescription
                    ?? "The meal could not be estimated. Your photo is still here so you can retry."
            }
            if id == requestID { busy = false }
        }
    }

    func update(_ item: FoodItem, name: String, preparation: String, grams: Double?, onSuccess: @escaping @MainActor () -> Void) {
        guard !busy, !saving, var meal = draft else { return }
        if item.name == name && item.preparation == preparation,
           let index = meal.items.firstIndex(where: { $0.id == item.id }) {
            meal.items[index].grams = grams
            meal.items[index].portionConfirmed = true
            draft = meal
            onSuccess()
            return
        }
        guard modelAvailability.allowsTextEstimate else {
            error = modelAvailability.explanation
            return
        }
        cancel()
        busy = true
        let id = requestID
        operation = Task {
            do {
                var updated = try await estimator.estimate(name: name, preparation: preparation)
                guard id == requestID, !Task.isCancelled else { return }
                updated.id = item.id
                if let grams { updated.grams = grams; updated.portionConfirmed = true }
                if let index = meal.items.firstIndex(where: { $0.id == item.id }) {
                    meal.items[index] = updated
                } else { meal.items.append(updated) }
                draft = meal
                onSuccess()
            } catch {
                guard id == requestID, !Task.isCancelled else { return }
                self.error = "This correction could not be estimated. The previous draft is unchanged. Retry the correction when the model is available."
            }
            if id == requestID { busy = false }
        }
    }

    func save() async {
        guard !saving, !busy, historyLoaded, var meal = draft, !meal.items.isEmpty else { return }
        saving = true
        defer { saving = false }
        meal.savedAt = Date()
        do {
            meals = try await store.save(meal)
            draft = nil
            image = nil
            savedNotice = true
        } catch { self.error = "The meal could not be saved. Your draft is still here. Please retry." }
    }

    func delete(_ meal: Meal) async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do { meals = try await store.delete(meal.id) }
        catch { self.error = "The meal could not be deleted. Please retry." }
    }

    #if DEBUG
    func loadExample() {
        draft = Meal(items: [FoodItem(name: "Rice", grams: 150, kcalPer100g: 130, preparation: "Cooked; example data"),
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
