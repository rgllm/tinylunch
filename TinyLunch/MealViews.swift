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
                    Text("🍽️").font(.title).frame(width: 44, height: 44).accessibilityHidden(true)
                }
            }.foregroundStyle(TinyLunchStyle.ink)
            Text(meal.calorieLabel)
                .font(.system(size: amountSize, weight: .semibold, design: .rounded))
                .tracking(typeSize.isAccessibilitySize ? 0 : -2)
                .foregroundStyle(TinyLunchStyle.accent)
                .contentTransition(.numericText()).animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: meal.calories)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("mealCalories")
                .accessibilityHint(meal.isIncomplete ? "Known foods subtotal. This is an estimate, not a measurement." : "Estimated meal total. This is an estimate, not a measurement.")
            Divider()
            if meal.isIncomplete {
                Label {
                    Text("Incomplete estimate").fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "circle.lefthalf.filled").accessibilityHidden(true)
                }
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
                if item.energyBasis == .estimated {
                    Text("Estimated")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TinyLunchStyle.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TinyLunchStyle.soft, in: Capsule())
                        .fixedSize(horizontal: true, vertical: true)
                }
                Text(item.calories.map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "Not estimated")
                    .font(.subheadline.weight(.medium)).foregroundStyle(TinyLunchStyle.accent)
                    .fixedSize(horizontal: false, vertical: true)
                if let grams = item.grams {
                    Text("\(grams.formatted()) g · \(item.portionConfirmed ? "Confirmed portion" : "Suggested portion")")
                        .font(.caption).foregroundStyle(TinyLunchStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !item.preparation.isEmpty {
                    Text(item.preparation).font(.caption).foregroundStyle(TinyLunchStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityDescription)
    }
}

extension FoodItem {
    var accessibilityDescription: String {
        var parts = [name]
        if energyBasis == .estimated { parts.append("Estimated") }
        if let calories {
            parts.append("\(calories.formatted(.number.precision(.fractionLength(0)))) kilocalories")
        } else {
            parts.append("Not estimated")
        }
        if let grams {
            let status = portionConfirmed ? "Confirmed portion" : "Suggested portion"
            parts.append("\(grams.formatted()) grams, \(status)")
        }
        if !preparation.isEmpty { parts.append(preparation) }
        return parts.joined(separator: ", ")
    }
}

struct FoodEditor: View {
    let item: FoodItem
    let busy: Bool
    let allowsIdentityEdit: Bool
    var cancel: () -> Void
    var commit: (String, String, Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var name: String
    @State private var preparation: String
    @State private var grams: Double?
    @FocusState private var portionFocused: Bool
    @State private var portionChange = 0
    init(item: FoodItem, busy: Bool, allowsIdentityEdit: Bool = true, cancel: @escaping () -> Void, commit: @escaping (String, String, Double?) -> Void) {
        self.item = item
        self.busy = busy
        self.allowsIdentityEdit = allowsIdentityEdit
        self.cancel = cancel
        self.commit = commit
        _name = State(initialValue: item.name)
        _preparation = State(initialValue: item.preparation)
        _grams = State(initialValue: item.grams)
    }
    private var valid: Bool {
        let food = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let validPortion = grams.map { $0.isFinite && $0 > 0 && $0 <= 10_000 } ?? true
        return !busy && !food.isEmpty && name.count <= 200 && preparation.count <= 400 && validPortion
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            FoodBadge(name: name, size: 54)
                            editorIntro
                        }.padding(.vertical, 6)
                    } else {
                        HStack(spacing: 14) {
                            FoodBadge(name: name, size: 54)
                            editorIntro
                        }.padding(.vertical, 6)
                    }
                }.listRowBackground(TinyLunchStyle.card)
                Section {
                    TextField("Food name", text: $name)
                        .accessibilityIdentifier("foodName")
                        .disabled(!allowsIdentityEdit)
                        .accessibilityHint(allowsIdentityEdit ? "The food to estimate." : "Changing the food or preparation waits until on-device estimates are available again.")
                    TextField("Preparation and assumptions", text: $preparation, axis: .vertical)
                        .accessibilityIdentifier("foodPreparation")
                        .disabled(!allowsIdentityEdit)
                        .accessibilityHint(allowsIdentityEdit ? "How the food was prepared. Changing this needs a new estimate." : "Changing the food or preparation waits until on-device estimates are available again.")
                } header: {
                    editorHeader("Food")
                }.listRowBackground(TinyLunchStyle.card)
                Section {
                    let portionStyle: Font.TextStyle = typeSize.isAccessibilitySize ? .title2 : .largeTitle
                    let unitStyle: Font.TextStyle = typeSize.isAccessibilitySize ? .title3 : .title2
                    HStack(alignment: .firstTextBaseline) {
                        TextField("Grams", value: $grams, format: .number)
                            .keyboardType(.decimalPad).focused($portionFocused)
                            .font(.system(portionStyle, design: .rounded, weight: .semibold))
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Portion in grams")
                            .accessibilityHint("Enter a weight in grams. Changing only the grams updates the estimate on this iPhone.")
                            .accessibilityIdentifier("portionGrams")
                        Text("g")
                            .font(.system(unitStyle))
                            .foregroundStyle(TinyLunchStyle.ink)
                            .accessibilityHidden(true)
                    }.padding(.vertical, 6)
                    if let original = item.grams, original.isFinite, original > 0 {
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                        layout {
                            portionButton("Half", multiplier: 0.5, original: original, hint: "Sets the portion to half the original weight.")
                            portionButton("Original", multiplier: 1, original: original, hint: "Restores the original portion.")
                            portionButton("Double", multiplier: 2, original: original, hint: "Sets the portion to double the original weight.")
                        }.padding(.vertical, 4)
                    }
                } header: {
                    editorHeader("Portion")
                } footer: {
                    Group {
                        if allowsIdentityEdit {
                            Text("Changing grams adjusts the current estimate. A different food or preparation needs a new estimate.")
                        } else {
                            Text("Portion changes still apply. Changing the food or preparation waits until on-device estimates are available again.")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(TinyLunchStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                }.listRowBackground(TinyLunchStyle.card)
                if busy {
                    Section { ProgressView("Updating estimate…") }
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
                        .accessibilityHint("Dismisses the keyboard.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button("Apply") { apply() }
                        .buttonStyle(PrimaryAction())
                        .disabled(!valid)
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
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: portionChange)
    }

    private func editorHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(TinyLunchStyle.ink)
            .textCase(nil)
    }

    private var editorIntro: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Make it your portion").font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Small adjustments count.").font(.subheadline).foregroundStyle(TinyLunchStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func apply() {
        commit(name.trimmingCharacters(in: .whitespacesAndNewlines), preparation, grams)
    }

    private func portionButton(_ title: LocalizedStringKey, multiplier: Double, original: Double, hint: LocalizedStringKey) -> some View {
        Button(title) { grams = original * multiplier; portionChange += 1 }
            .font(.subheadline.weight(.medium)).buttonStyle(.bordered).buttonBorderShape(.capsule)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(original * multiplier > 10_000)
            .accessibilityHint(hint)
    }
}
