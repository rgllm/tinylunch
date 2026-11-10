import SwiftUI

struct MealSummary: View {
    let meal: Meal
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = 54
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(meal.isIncomplete ? "Known foods subtotal" : "Estimated meal total")
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize {
                    Text("🍽️").font(.title).frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("decorativeGlyph")
                }
            }.foregroundStyle(TinyLunchStyle.ink)
            Text(meal.calorieLabel)
                .font(.system(size: amountSize, weight: .semibold, design: .rounded))
                .foregroundStyle(TinyLunchStyle.accent)
                .contentTransition(.numericText()).animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: meal.calories)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("mealCalories")
                .accessibilityLabel(meal.spokenEnergy)
                .accessibilityHint(meal.isIncomplete ? "Known foods subtotal. This is an estimate, not a measurement." : "Estimated meal total. This is an estimate, not a measurement.")
            Divider()
            if meal.isIncomplete {
                IconLabel(title: "Incomplete estimate", systemImage: "circle.lefthalf.filled")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel("Incomplete estimate")
                    .accessibilityHint("Some food could not be estimated and is not included in this subtotal.")
            }
            Text(meal.isIncomplete ? "Some food couldn’t be estimated and isn’t included in this subtotal." : "An estimate based on portions and preparation. Adjust either to make it more useful.")
                .font(.subheadline).foregroundStyle(TinyLunchStyle.ink).fixedSize(horizontal: false, vertical: true)
        }.tinyLunchCard()
    }
}

struct FoodRow: View {
    let item: FoodItem
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if !typeSize.isAccessibilitySize { FoodBadge(name: item.name) }
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name).font(.headline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.identityConfirmed ? "Confirmed food" : "Suggested food")
                    .font(.subheadline).foregroundStyle(.primary)
                if !item.alternativeNames.isEmpty && !item.identityConfirmed {
                    Text("Other possible matches: \(item.alternativeNames.joined(separator: ", "))")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                if item.energyBasis == .database {
                    Text("USDA catalog estimate")
                        .font(.headline).foregroundStyle(.primary)
                    if let catalogID = item.catalogID, let version = item.catalogVersion {
                        Text("\(catalogID) · \(version)")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if item.showsEstimatedBadge {
                    Text("Model estimate")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(item.calories.map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "Not estimated")
                    .font(.headline).foregroundStyle(TinyLunchStyle.accent)
                    .fixedSize(horizontal: false, vertical: true)
                if let grams = item.grams {
                    Text("\(grams.formatted()) g · \(item.portionConfirmed ? "Confirmed portion" : "Suggested portion")")
                        .font(.headline).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !item.preparation.isEmpty {
                    Text(item.preparation).font(.headline).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .background(TinyLunchStyle.card)
        }
    }
}

struct FoodEditor: View {
    let item: FoodItem
    let busy: Bool
    let allowsIdentityEdit: Bool
    var cancel: () -> Void
    let catalog: NutritionCatalog
    var commit: (FoodCorrection) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @AccessibilityFocusState private var introFocused: Bool
    @AccessibilityFocusState private var updatingFocused: Bool
    @State private var name: String
    @State private var preparation: String
    @State private var grams: Double?
    @FocusState private var portionFocused: Bool
    @State private var portionChange = 0
    @State private var catalogQuery: String
    @State private var catalogResults: [CatalogRecord] = []
    @State private var selectedCatalog: CatalogRecord?
    @State private var chosenAlternative: String?
    @State private var catalogSearching = false
    @State private var catalogMessage: String?

    init(item: FoodItem, busy: Bool, allowsIdentityEdit: Bool = true, catalog: NutritionCatalog, cancel: @escaping () -> Void, commit: @escaping (FoodCorrection) -> Void) {
        self.item = item
        self.busy = busy
        self.allowsIdentityEdit = allowsIdentityEdit
        self.catalog = catalog
        self.cancel = cancel
        self.commit = commit
        _name = State(initialValue: item.name)
        _preparation = State(initialValue: item.preparation)
        _grams = State(initialValue: item.grams)
        _catalogQuery = State(initialValue: item.name)
    }
    private var valid: Bool {
        let food = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let validPortion = grams.map { $0.isFinite && $0 > 0 && $0 <= 10_000 } ?? true
        return !busy && !food.isEmpty && name.count <= 200 && preparation.count <= 400 && validPortion
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            Form {
                Section {
                    editorBanner
                    if let original = item.grams, original.isFinite, original > 0 {
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                        layout {
                            portionButton("Half", multiplier: 0.5, original: original, hint: "Sets the portion to half the original weight.")
                            portionButton("Original", multiplier: 1, original: original, hint: "Restores the original portion.")
                            portionButton("Double", multiplier: 2, original: original, hint: "Sets the portion to double the original weight.")
                        }
                    }
                }.listRowBackground(TinyLunchStyle.card)
                Section {
                    editorHeader("Food")
                    if !item.alternativeNames.isEmpty {
                        Text("Possible food matches")
                            .font(.headline)
                        Text("Choose the closest match or type a correction. These are suggestions for the same food.")
                        ForEach([item.name] + item.alternativeNames, id: \.self) { candidate in
                            Button(candidate) {
                                if name != candidate { preparation = "" }
                                name = candidate
                                chosenAlternative = candidate
                                catalogQuery = candidate
                                selectedCatalog = nil
                            }
                            .accessibilityIdentifier("alternative-\(candidate)")
                        }
                    }
                    TextField("Food name", text: $name)
                        .accessibilityIdentifier("foodName")
                        .accessibilityLabel("Food name")
                        .accessibilityHint(allowsIdentityEdit ? "The food to estimate." : "Choose a local catalog food while Apple Intelligence is unavailable.")
                    TextField("Preparation and assumptions", text: $preparation, axis: .vertical)
                        .accessibilityIdentifier("foodPreparation")
                        .accessibilityLabel("Preparation and assumptions")
                        .accessibilityHint(allowsIdentityEdit ? "How the food was prepared. Changing this needs a new estimate." : "Choose a local catalog food while Apple Intelligence is unavailable.")
                }.listRowBackground(TinyLunchStyle.card)
                catalogSection
                Section {
                    editorHeader("Portion")
                    let unitStyle: Font.TextStyle = typeSize.isAccessibilitySize ? .title3 : .title2
                    let portionLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 4))
                    portionLayout {
                        TextField("Grams", value: $grams, format: .number)
                            .keyboardType(.decimalPad).focused($portionFocused)
                            .font(.title2)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Portion in grams")
                            .accessibilityHint("Enter a weight in grams. Changing only the grams updates the estimate on this iPhone.")
                            .accessibilityIdentifier("portionGrams")
                        Text("g")
                            .font(.system(unitStyle))
                            .foregroundStyle(TinyLunchStyle.ink)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 6)
                    Group {
                        if allowsIdentityEdit {
                            Text("Changing grams adjusts the current estimate. A different food or preparation needs a new catalog match or model estimate.")
                        } else {
                            Text("Portion changes and local catalog choices still work. Other corrections wait until Apple Intelligence is ready.")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                }.listRowBackground(TinyLunchStyle.card)
                if busy {
                    Section {
                        ProgressView("Updating estimate…")
                            .accessibilityFocused($updatingFocused)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(TinyLunchStyle.paper)
            .disabled(busy)
            .navigationTitle("Correct food").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { portionFocused = false }
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityHint("Dismisses the keyboard.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button("Apply") { apply() }
                        .buttonStyle(PrimaryAction())
                        .disabled(!valid)
                        .accessibilityIdentifier("Apply")
                        .accessibilityHint("Applies the food, preparation, and portion.")
                    Button("Cancel") { cancel(); dismiss() }
                        .buttonStyle(.plain)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(TinyLunchStyle.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
                .background(TinyLunchStyle.paper)
            }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { Task { @MainActor in introFocused = true } }
        .task(id: catalogQuery) { await searchCatalog() }
        .onChange(of: name) { _, _ in invalidateCatalogSelection() }
        .onChange(of: preparation) { _, _ in invalidateCatalogSelection() }

        .onChange(of: busy) { _, isBusy in
            guard isBusy else { return }
            Task { @MainActor in updatingFocused = true }
        }
    }

    private func editorHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(TinyLunchStyle.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var editorBanner: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    FoodBadge(name: name, size: 54)
                    editorIntro
                }
            } else {
                HStack(spacing: 14) {
                    FoodBadge(name: name, size: 54)
                    editorIntro
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TinyLunchStyle.card)
    }

    private var editorIntro: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Make it your portion")
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($introFocused)
            Text("Small adjustments count.")
                .font(.body)
                .foregroundStyle(TinyLunchStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var catalogSection: some View {
        Section {
            editorHeader("Local nutrition catalog")
            TextField("Search bundled USDA foods", text: $catalogQuery)
                .accessibilityIdentifier("catalogSearch")
                .accessibilityHint("Searches foods stored on this iPhone. No internet connection is used.")
            Text("Choose a food with the right preparation. Catalog energy still depends on the food match and portion.")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if catalogSearching { ProgressView("Searching local foods…") }
            ForEach(catalogResults) { record in
                Button {
                    name = String(record.name.prefix(200))
                    preparation = record.preparation
                    selectedCatalog = record
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.name).font(.body)
                        Text("\(record.kcalPer100g.formatted()) kcal per 100 g · \(record.preparation)")
                            .font(.subheadline)
                        if selectedCatalog?.id == record.id { Text("Selected catalog food").font(.subheadline.weight(.semibold)) }
                    }
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("catalog-\(record.id)")
            }
            if let catalogMessage { Text(catalogMessage).font(.subheadline) }
        }.listRowBackground(TinyLunchStyle.card)
    }

    @MainActor private func searchCatalog() async {
        let query = catalogQuery
        catalogSearching = true
        catalogMessage = nil
        do {
            try await Task.sleep(for: .milliseconds(150))
            let result = try await catalog.search(name: query)
            guard !Task.isCancelled, query == catalogQuery else { return }
            catalogResults = result.candidates
            if result.candidates.isEmpty, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                catalogMessage = "No local match. A valid model estimate can still be used. Missing energy is never zero."
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, query == catalogQuery else { return }
            catalogResults = []
            catalogMessage = "The bundled catalog could not be read. You can still use a model estimate when Apple Intelligence is ready."
        }
        catalogSearching = false
    }

    private func invalidateCatalogSelection() {
        guard let selectedCatalog else { return }
        if name != String(selectedCatalog.name.prefix(200)) || preparation != selectedCatalog.preparation {
            self.selectedCatalog = nil
        }
    }

    private func apply() {
        let singleLine = name
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let food = singleLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selectedCatalog, food == String(selectedCatalog.name.prefix(200)), preparation == selectedCatalog.preparation {
            commit(.catalog(id: selectedCatalog.id, grams: grams))
        } else if food == item.name, preparation == item.preparation, chosenAlternative != food {
            commit(.portion(grams: grams))
        } else {
            commit(.description(name: food, preparation: preparation, grams: grams))
        }
    }

    private func portionButton(_ title: LocalizedStringKey, multiplier: Double, original: Double, hint: LocalizedStringKey) -> some View {
        Button(title) { grams = original * multiplier; portionChange += 1 }
            .buttonStyle(.plain)
            .font(.headline)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .disabled(original * multiplier > 10_000)
            .accessibilityHint(hint)
    }
}
