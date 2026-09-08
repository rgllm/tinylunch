import SwiftUI

struct MealSummary: View {
    let meal: Meal
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = 54
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(meal.isIncomplete ? "Known foods subtotal" : "Estimated meal total")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("🍽️").font(.title).accessibilityHidden(true)
            }.foregroundStyle(.secondary)
            Text(meal.calorieLabel)
                .font(.system(size: amountSize, weight: .semibold, design: .rounded))
                .tracking(-2).foregroundStyle(NoshStyle.accent)
                .contentTransition(.numericText()).animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: meal.calories)
                .minimumScaleFactor(0.65).accessibilityIdentifier("mealCalories")
            Divider()
            if meal.isIncomplete {
                Label("Incomplete estimate", systemImage: "circle.lefthalf.filled")
                    .font(.subheadline.weight(.semibold))
            }
            Text(meal.isIncomplete ? "Some food couldn’t be estimated and isn’t included in this subtotal." : "An estimate based on portions and preparation. Adjust either to make it more useful.")
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.noshCard()
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
                Text(item.calories.map { "\($0.formatted(.number.precision(.fractionLength(0)))) kcal" } ?? "Not estimated")
                    .font(.subheadline.weight(.medium)).foregroundStyle(NoshStyle.accent)
                if let grams = item.grams {
                    Text("\(grams.formatted()) g · \(item.portionConfirmed ? "Confirmed portion" : "Suggested portion")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !item.preparation.isEmpty {
                    Text(item.preparation).font(.caption).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.accessibilityElement(children: .combine)
    }
}

struct FoodEditor: View {
    let item: FoodItem
    let busy: Bool
    var cancel: () -> Void
    var commit: (String, String, Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var name: String
    @State private var preparation: String
    @State private var grams: Double?
    @FocusState private var portionFocused: Bool
    @State private var portionChange = 0
    init(item: FoodItem, busy: Bool, cancel: @escaping () -> Void, commit: @escaping (String, String, Double?) -> Void) {
        self.item = item
        self.busy = busy
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
                    HStack(spacing: 14) {
                        FoodBadge(name: name, size: 54)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Make it your portion").font(.headline)
                            Text("Small adjustments count.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }.listRowBackground(NoshStyle.card)
                Section("Food") {
                    TextField("Food name", text: $name).accessibilityIdentifier("foodName")
                    TextField("Preparation and assumptions", text: $preparation, axis: .vertical)
                }.listRowBackground(NoshStyle.card)
                Section {
                    HStack {
                        TextField("Grams", value: $grams, format: .number)
                            .keyboardType(.decimalPad).focused($portionFocused)
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .accessibilityLabel("Portion in grams").accessibilityIdentifier("portionGrams")
                        Text("g").font(.title2).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                    if let original = item.grams, original.isFinite, original > 0 {
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
                        layout {
                            portionButton("Half", multiplier: 0.5, original: original)
                            portionButton("Original", multiplier: 1, original: original)
                            portionButton("Double", multiplier: 2, original: original)
                        }.padding(.vertical, 4)
                    }
                } header: { Text("Portion") } footer: {
                    Text("Changing grams adjusts the current estimate. A different food or preparation needs a new estimate.")
                }.listRowBackground(NoshStyle.card)
                if busy {
                    Section { ProgressView("Updating estimate…") }
                }
            }
            .scrollContentBackground(.hidden).background(NoshStyle.paper)
            .disabled(busy)
            .navigationTitle("Correct food").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { commit(name.trimmingCharacters(in: .whitespacesAndNewlines), preparation, grams) }
                        .fontWeight(.semibold).disabled(!valid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { portionFocused = false }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: portionChange)
    }
    private func portionButton(_ title: LocalizedStringKey, multiplier: Double, original: Double) -> some View {
        Button(title) { grams = original * multiplier; portionChange += 1 }
            .font(.subheadline.weight(.medium)).buttonStyle(.bordered).buttonBorderShape(.capsule)
            .frame(maxWidth: .infinity).disabled(original * multiplier > 10_000)
    }
}
