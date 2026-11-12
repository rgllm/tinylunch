import SwiftUI

struct MealSummary: View {
    enum Context { case draft, saved }
    let meal: Meal
    var context = Context.draft
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
                .monospacedDigit()
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
            Text(meal.isIncomplete ? "Some food couldn’t be estimated and isn’t included in this subtotal." : context == .draft ? "An estimate based on portions and preparation. Adjust either to make it more useful." : "Saved as estimated, using the portions and preparation shown below.")
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
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
                layout {
                    Text(item.name).font(.headline).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.calories.map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "Not estimated")
                        .font(.headline).monospacedDigit().foregroundStyle(TinyLunchStyle.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(item.identityConfirmed ? "Confirmed food" : "Suggested food")
                    .font(.caption).foregroundStyle(.secondary)
                if !item.alternativeNames.isEmpty && !item.identityConfirmed {
                    Text("Other possible matches: \(item.alternativeNames.joined(separator: ", "))")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                if item.energyBasis == .database {
                    Text("USDA catalog estimate")
                        .font(.caption).foregroundStyle(.secondary)
                    if let catalogID = item.catalogID, let version = item.catalogVersion {
                        Text("\(catalogID) · \(version)")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if item.showsEstimatedBadge {
                    Text("Model estimate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let grams = item.grams {
                    Text("\(grams.formatted()) g · \(item.portionConfirmed ? "Confirmed portion" : "Suggested portion")")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !item.preparation.isEmpty {
                    Text(item.preparation).font(.subheadline).foregroundStyle(.secondary)
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
    let issue: PresentationIssue?
    var dismissIssue: () -> Void
    var recoverIssue: (PresentationIssue.Recovery) -> Void
    var cancel: () -> Void
    let catalog: NutritionCatalog
    var commit: (FoodCorrection) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @AccessibilityFocusState private var introFocused: Bool
    @AccessibilityFocusState private var updatingFocused: Bool
    @State private var name: String
    @State private var preparation: String
    @State private var gramsText: String
    @State private var portionWasEdited = false
    @FocusState private var portionFocused: Bool
    @State private var portionChange = 0
    @State private var catalogQuery: String
    @State private var catalogResults: [CatalogRecord] = []
    @State private var selectedCatalog: CatalogRecord?
    @State private var chosenAlternative: String?
    @State private var catalogSearching = false
    @State private var catalogMessage: String?

    init(item: FoodItem, busy: Bool, allowsIdentityEdit: Bool = true, catalog: NutritionCatalog, issue: PresentationIssue? = nil, dismissIssue: @escaping () -> Void = {}, recoverIssue: @escaping (PresentationIssue.Recovery) -> Void = { _ in }, cancel: @escaping () -> Void, commit: @escaping (FoodCorrection) -> Void) {
        self.item = item
        self.busy = busy
        self.allowsIdentityEdit = allowsIdentityEdit
        self.catalog = catalog
        self.issue = issue
        self.dismissIssue = dismissIssue
        self.recoverIssue = recoverIssue
        self.cancel = cancel
        self.commit = commit
        _name = State(initialValue: item.name)
        _preparation = State(initialValue: item.preparation)
        _gramsText = State(initialValue: item.grams.map { $0.formatted(.number.grouping(.never)) } ?? "")
        _catalogQuery = State(initialValue: item.name)
    }
    private var portion: PortionInput { PortionInput(gramsText, original: item.grams) }
    private var grams: Double? { if case .valid(let value) = portion { value } else { nil } }
    private var valid: Bool {
        let food = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !busy && !food.isEmpty && name.count <= 200 && preparation.count <= 400 && portion.error == nil
    }
    private var previewCalories: Double? {
        guard valid, name == item.name, preparation == item.preparation, chosenAlternative != name else { return nil }
        var preview = item
        preview.grams = grams
        return preview.calories
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            ScrollViewReader { proxy in
            Form {
                if let issue, issue.cause == .correction {
                    Section {
                        PresentationIssueCard(issue: issue, dismiss: dismissIssue)
                    }.listRowBackground(TinyLunchStyle.card).id("correctionIssue")
                }
                Section {
                    editorBanner
                }.listRowBackground(TinyLunchStyle.card)
                Section {
                    editorHeader("Portion in grams")
                    let unitStyle: Font.TextStyle = typeSize.isAccessibilitySize ? .title3 : .title2
                    let portionLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 4))
                    portionLayout {
                        TextField("For example, 150", text: $gramsText)
                            .keyboardType(.decimalPad).focused($portionFocused)
                            .font(.title2).monospacedDigit()
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
                    if portionWasEdited, let error = portion.error {
                        Text(error).font(.subheadline).foregroundStyle(.red)
                            .accessibilityIdentifier("portionValidation")
                    }
                    if gramsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No portion entered. A new model estimate may suggest grams; otherwise this food stays incomplete.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("missingPortionHelp")
                    }
                    if let calories = previewCalories {
                        Text("Estimated \(calories.formatted(.number.precision(.fractionLength(0)))) kcal")
                            .font(.headline).monospacedDigit()
                            .accessibilityIdentifier("portionEstimatePreview")
                    }
                    if let original = item.grams, original.isFinite, original > 0 {
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                        layout {
                            portionButton("Half", multiplier: 0.5, original: original, hint: "Sets the portion to half the original weight.")
                            portionButton("Original", multiplier: 1, original: original, hint: "Restores the original portion.")
                            portionButton("Double", multiplier: 2, original: original, hint: "Sets the portion to double the original weight.")
                        }
                    }
                    Group {
                        if allowsIdentityEdit {
                            Text("Changing grams adjusts the current estimate. A different food or preparation needs a new catalog match or model estimate.")
                        } else {
                            Text("Portion changes and local catalog choices still work. Other corrections wait until Apple Intelligence is ready.")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }.listRowBackground(TinyLunchStyle.card)
                Section {
                    editorHeader("Food")
                    if !item.alternativeNames.isEmpty {
                        Text("Possible food matches")
                            .font(.headline)
                        Text("Choose the closest match or type a correction. These are suggestions for the same food.")
                        ForEach([item.name] + item.alternativeNames, id: \.self) { candidate in
                            Button {
                                if name != candidate { preparation = "" }
                                name = candidate
                                chosenAlternative = candidate
                                catalogQuery = candidate
                                selectedCatalog = nil
                            } label: {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(candidate).fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    if name == candidate { Image(systemName: "checkmark").accessibilityHidden(true) }
                                }.frame(minHeight: 44)
                            }
                            .accessibilityAddTraits(name == candidate ? .isSelected : [])
                            .accessibilityIdentifier("alternative-\(candidate)")
                        }
                    }
                    Text("Food name").font(.subheadline.weight(.semibold))
                    TextField("For example, cooked rice", text: $name)
                        .accessibilityIdentifier("foodName")
                        .accessibilityLabel("Food name")
                        .accessibilityHint(allowsIdentityEdit ? "The food to estimate." : "Choose a local catalog food while Apple Intelligence is unavailable.")
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Enter a food name to update this item.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("\(name.count) of 200 characters")
                        .font(.caption).foregroundStyle(name.count > 200 ? Color.red : Color.secondary)
                        .accessibilityIdentifier("foodNameValidation")
                    if name.count > 200 {
                        Text("Shorten the food name to 200 characters or fewer.").font(.subheadline).foregroundStyle(.red)
                    }
                    Text("Preparation and assumptions").font(.subheadline.weight(.semibold))
                    TextField("For example, cooked with oil", text: $preparation, axis: .vertical)
                        .accessibilityIdentifier("foodPreparation")
                        .accessibilityLabel("Preparation and assumptions")
                        .accessibilityHint(allowsIdentityEdit ? "How the food was prepared. Changing this needs a new estimate." : "Choose a local catalog food while Apple Intelligence is unavailable.")
                    Text("\(preparation.count) of 400 characters")
                        .font(.caption).foregroundStyle(preparation.count > 400 ? Color.red : Color.secondary)
                        .accessibilityIdentifier("preparationValidation")
                    if preparation.count > 400 {
                        Text("Shorten the preparation to 400 characters or fewer.").font(.subheadline).foregroundStyle(.red)
                    }
                }.listRowBackground(TinyLunchStyle.card)
                catalogSection
            }
            .onChange(of: issue?.cause) { _, cause in
                if cause == .correction {
                    portionFocused = false
                    proxy.scrollTo("correctionIssue", anchor: .top)
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
                    if busy {
                        ProgressView("Updating estimate…")
                            .accessibilityFocused($updatingFocused)
                    }
                    Button(item.name.isEmpty ? "Add food" : "Update food") { apply() }
                        .buttonStyle(PrimaryAction())
                        .disabled(!valid)
                        .accessibilityIdentifier("Apply")
                        .accessibilityHint("Applies the food, preparation, and portion.")
                    Button("Cancel") { if issue?.cause == .correction { dismissIssue() }; cancel(); dismiss() }
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
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert(issue?.cause.title ?? "", isPresented: Binding(get: { issue != nil && issue?.cause != .correction }, set: { if !$0 { dismissIssue() } })) {
            if let recovery = issue?.recovery {
                Button(recovery.title) { recoverIssue(recovery) }
            }
            Button(issue?.cause.dismissal ?? String(localized: "Keep editing"), role: .cancel, action: dismissIssue)
        } message: {
            Text(issue?.message ?? "")
        }
        .onAppear { Task { @MainActor in introFocused = true } }
        .task(id: catalogQuery) { await searchCatalog() }
        .onChange(of: portionFocused) { _, focused in if !focused { portionWasEdited = true } }
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
                catalogMessage = String(localized: "No local match. Try a simpler food name or another preparation. You can update the food using an on-device model estimate when Apple Intelligence is ready.")
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, query == catalogQuery else { return }
            catalogResults = []
            catalogMessage = String(localized: "The bundled catalog could not be read. You can still use a model estimate when Apple Intelligence is ready.")
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
        guard valid else { return }
        dismissIssue()
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
        Button(title) {
            gramsText = (original * multiplier).formatted(.number.grouping(.never).precision(.significantDigits(1...17)))
            portionWasEdited = true
            portionChange += 1
        }
            .buttonStyle(.plain)
            .font(.headline)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .disabled(original * multiplier > 10_000)
            .accessibilityHint(hint)
    }
}

enum PortionInput: Equatable {
    case missing
    case valid(Double)
    case malformed
    case outOfRange

    init(_ text: String, locale: Locale = .current, original: Double? = nil) {
        if let original, text == original.formatted(.number.locale(locale).grouping(.never)) {
            self = original.isFinite && original > 0 && original <= 10_000 ? .valid(original) : .outOfRange
            return
        }
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { self = .missing; return }
        let separator = locale.decimalSeparator ?? "."
        guard separator == "." || !text.contains(".") else { self = .malformed; return }
        let normalized = text.replacingOccurrences(of: separator, with: ".")
        var number = ""
        for character in normalized {
            if let digit = character.wholeNumberValue, (0...9).contains(digit) {
                number += String(digit)
            } else if character == "." || (number.isEmpty && (character == "-" || character == "+")) {
                number.append(character)
            } else {
                self = .malformed
                return
            }
        }
        guard let value = Double(number), value.isFinite else { self = .malformed; return }
        self = value > 0 && value <= 10_000 ? .valid(value) : .outOfRange
    }

    var error: String? {
        switch self {
        case .missing, .valid: nil
        case .malformed: String(localized: "Enter a number in grams, without units or grouping separators, or leave it blank.")
        case .outOfRange: String(localized: "Use more than 0 and up to 10,000 grams, or leave it blank.")
        }
    }
}
