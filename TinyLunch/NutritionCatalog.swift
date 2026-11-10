import Foundation

struct CatalogRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let preparation: String
    let kcalPer100g: Double
}

struct CatalogSearch: Sendable {
    let version: String
    let candidates: [CatalogRecord]
    let automaticMatch: CatalogRecord?
}

actor NutritionCatalog {
    static let bundledVersion = "usda-sr-2018-04-foundation-2026-10-29-v1"
    private struct Archive: Decodable {
        let schemaVersion: Int
        let version: String
        let records: [CatalogRecord]
    }
    private struct Entry {
        let record: CatalogRecord
        let words: Set<String>
    }
    private let resource: URL?
    private var version: String
    private var entries: [Entry]?

    init(resource: URL? = Bundle.main.url(forResource: "catalog", withExtension: "json",
        subdirectory: "NutritionCatalog/\(NutritionCatalog.bundledVersion)")) {
        self.resource = resource
        version = Self.bundledVersion
    }

    init(records: [CatalogRecord], version: String) throws {
        resource = nil
        self.version = version
        entries = try Self.index(records)
    }

    func search(name: String, preparation: String = "") throws -> CatalogSearch {
        try load()
        let words = Self.words(name)
        guard !words.isEmpty else { return CatalogSearch(version: version, candidates: [], automaticMatch: nil) }
        let states = Self.states(name + " " + preparation)
        let matches = (entries ?? []).filter {
            words.isSubset(of: $0.words) && Self.compatible(states, Self.states($0.record.name))
        }.sorted {
            if $0.words.count != $1.words.count { return $0.words.count < $1.words.count }
            return $0.record.id < $1.record.id
        }
        let exactWords = words.union(Self.states(preparation))
        let exact = matches.filter { $0.words == exactWords }
        let ambiguousPreparation = preparation.range(
            of: #"\b(not|no|without|unknown|uncertain|possibly|maybe|or)\b"#,
            options: [.regularExpression, .caseInsensitive]) != nil
        let portionNotes: Set<String> = ["visual", "portion", "edible", "estimated", "suggested", "assumed", "assumption", "weight", "grams", "g"]
        let unexplainedPreparation = Self.words(preparation).subtracting(Self.states(preparation)).subtracting(portionNotes)
        let automatic = exact.count == 1 && !ambiguousPreparation && unexplainedPreparation.isEmpty ? exact.first?.record : nil
        return CatalogSearch(version: version, candidates: Array(matches.prefix(5).map(\.record)), automaticMatch: automatic)
    }

    func record(id: String) throws -> (record: CatalogRecord, version: String) {
        try load()
        guard let record = entries?.first(where: { $0.record.id == id })?.record else { throw CatalogError.missingRecord }
        return (record, version)
    }

    func resolve(_ item: FoodItem) throws -> FoodItem {
        guard item.alternativeNames.isEmpty || item.identityConfirmed else { return item }
        let result = try search(name: item.name, preparation: item.preparation)
        guard let match = result.automaticMatch else { return item }
        return item.usingCatalog(match, version: result.version, replacingIdentity: false)
    }

    private func load() throws {
        guard entries == nil else { return }
        guard let resource, resource.isFileURL else { throw CatalogError.unavailable }
        let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: resource))
        guard archive.schemaVersion == 1, !archive.version.isEmpty else { throw CatalogError.invalidResource }
        entries = try Self.index(archive.records)
        version = archive.version
    }

    private static func index(_ records: [CatalogRecord]) throws -> [Entry] {
        var identifiers = Set<String>()
        return try records.map { record in
            guard !record.id.isEmpty, identifiers.insert(record.id).inserted,
                  !record.name.isEmpty, record.kcalPer100g.isFinite,
                  (0...1_000).contains(record.kcalPer100g) else { throw CatalogError.invalidResource }
            return Entry(record: record, words: words(record.name))
        }
    }

    private static func words(_ text: String) -> Set<String> {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let singular = ["bananas": "banana", "potatoes": "potato", "tomatoes": "tomato", "eggs": "egg",
                        "sardines": "sardine", "beans": "bean", "peas": "pea", "carrots": "carrot"]
        let ignored: Set<String> = ["and", "or", "with", "the", "a", "an", "of"]
        return Set(normalized.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map {
            singular[String($0)] ?? String($0)
        }.filter { !ignored.contains($0) })
    }

    private static func states(_ text: String) -> Set<String> {
        let known: Set<String> = ["raw", "uncooked", "cooked", "grilled", "broiled", "roasted", "baked", "boiled",
                                  "steamed", "stewed", "fried", "breaded", "battered", "dried", "dehydrated", "canned", "smoked"]
        return words(text).intersection(known)
    }

    private static func compatible(_ requested: Set<String>, _ row: Set<String>) -> Bool {
        let raw: Set<String> = ["raw", "uncooked"]
        let cooking: Set<String> = ["cooked", "grilled", "broiled", "roasted", "baked", "boiled", "steamed", "stewed", "fried"]
        if !requested.isDisjoint(with: raw), !row.isDisjoint(with: cooking) { return false }
        if !requested.isDisjoint(with: cooking), !row.isDisjoint(with: raw) { return false }
        let specific = requested.subtracting(["cooked"])
        guard specific.isSubset(of: row) else { return false }
        if requested.contains("cooked"), row.isDisjoint(with: cooking) { return false }
        if requested.isDisjoint(with: ["breaded", "battered"]),
           !requested.isDisjoint(with: cooking), !row.isDisjoint(with: ["breaded", "battered"]) { return false }
        return true
    }

    enum CatalogError: LocalizedError {
        case unavailable, invalidResource, missingRecord
        var errorDescription: String? {
            "The bundled food catalog could not be read. Model estimates are still available when Apple Intelligence is ready."
        }
    }
}

enum FoodCorrection: Sendable {
    case portion(grams: Double?)
    case description(name: String, preparation: String, grams: Double?)
    case catalog(id: String, grams: Double?)
}

extension FoodItem {
    func changingDescription(name: String, preparation: String, grams: Double?) -> FoodItem {
        var item = self
        item.name = name
        item.preparation = preparation
        item.grams = grams
        item.kcalPer100g = nil
        item.energyBasis = .estimated
        item.catalogID = nil
        item.catalogVersion = nil
        item.alternativeNames = []
        item.identityConfirmed = true
        item.portionConfirmed = grams != nil
        return item
    }

    func usingCatalog(_ record: CatalogRecord, version: String, replacingIdentity: Bool = true) -> FoodItem {
        var item = self
        if replacingIdentity {
            item.name = String(record.name.prefix(200))
            item.preparation = record.preparation
            item.alternativeNames = []
            item.identityConfirmed = true
        }
        item.kcalPer100g = record.kcalPer100g
        item.energyBasis = .database
        item.catalogID = record.id
        item.catalogVersion = version
        return item
    }
}
