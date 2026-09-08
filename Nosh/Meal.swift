import Foundation

struct FoodItem: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var grams: Double?
    var kcalPer100g: Double?
    var preparation: String
    var portionConfirmed = false

    // Bounds are input sanity checks, not confidence in model accuracy.
    var calories: Double? {
        guard let grams, let kcalPer100g,
              grams.isFinite, grams > 0, grams <= 10_000,
              kcalPer100g.isFinite, kcalPer100g >= 0, kcalPer100g <= 1_000,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return grams * kcalPer100g / 100
    }
}

struct Meal: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var savedAt = Date()
    var items: [FoodItem]
    var estimatorVersion = "apple-on-device-prompt-v1"
    var isIncomplete: Bool { items.isEmpty || items.contains { $0.calories == nil } }
    var calories: Double? {
        let values = items.compactMap(\.calories)
        return values.isEmpty ? nil : values.reduce(0, +)
    }
    var title: String { items.prefix(3).map(\.name).joined(separator: ", ") }
    var calorieLabel: String {
        calories.map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "No estimate"
    }
}

actor MealStore {
    private struct Archive: Codable {
        var schemaVersion = 1
        var meals: [Meal]
    }
    private let directory: URL
    private var file: URL { directory.appendingPathComponent("meals.json") }
    init(directory: URL) { self.directory = directory }

    func load() throws -> [Meal] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file))
        guard archive.schemaVersion == 1 else { throw StoreError.unsupportedVersion }
        return archive.meals.sorted { $0.savedAt > $1.savedAt }
    }

    func save(_ meal: Meal) throws -> [Meal] {
        var meals = try load() // Never overwrite unreadable history.
        guard !meals.contains(where: { $0.id == meal.id }) else { return meals }
        meals.insert(meal, at: 0)
        try write(meals)
        return meals
    }

    func delete(_ id: UUID) throws -> [Meal] {
        let meals = try load().filter { $0.id != id }
        try write(meals)
        return meals
    }

    private func write(_ meals: [Meal]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.protectionKey: FileProtectionType.complete])
        var excludedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try excludedDirectory.setResourceValues(values)
        try JSONEncoder().encode(Archive(meals: meals)).write(to: file, options: [.atomic, .completeFileProtection])
    }

    enum StoreError: Error { case unsupportedVersion }
}
