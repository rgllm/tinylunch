import SwiftUI

struct HistoryView: View {
    @Bindable var model: AppModel
    var startMeal: () -> Void
    @State private var pendingDelete: Meal?
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        NavigationStack {
            Group {
                if model.meals.isEmpty {
                    ScrollView {
                        VStack(spacing: 22) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 28).fill(TinyLunchStyle.soft)
                                    .frame(width: 154, height: 174).rotationEffect(.degrees(-10)).offset(x: -12, y: 3)
                                VStack(spacing: 16) {
                                    Text("🥡").font(.system(size: 60))
                                    Capsule().fill(TinyLunchStyle.soft).frame(width: 70, height: 6)
                                    Capsule().fill(TinyLunchStyle.soft.opacity(0.65)).frame(width: 44, height: 6)
                                }.frame(width: 154, height: 174).background(TinyLunchStyle.card, in: RoundedRectangle(cornerRadius: 28))
                                    .rotationEffect(.degrees(6)).offset(x: 12)
                            }.frame(height: 214).accessibilityHidden(true)
                            Text(model.historyLoaded ? "No saved meals" : "History unavailable")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            if model.historyLoaded && !model.modelAvailability.allowsPhotoAnalysis {
                                availabilityCard
                            }
                            Text(emptyHistoryMessage)
                                .foregroundStyle(TinyLunchStyle.ink).multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            if model.historyLoaded {
                                Button { startMeal() } label: {
                                    AccessibleActionLabel(title: "Start a meal", systemImage: "plus")
                                }
                                .buttonStyle(PrimaryAction())
                                .accessibilityLabel("Start a meal")
                                .accessibilityHint("Returns to the new meal screen.")
                            } else {
                                Button { Task { await model.refresh() } } label: {
                                    AccessibleActionLabel(title: "Retry", systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(PrimaryAction())
                                .accessibilityLabel("Retry")
                                .accessibilityHint("Loads saved meals again.")
                            }
                            Label {
                                Text("Just meal details. No photos.")
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "lock").accessibilityHidden(true)
                            }
                            .font(.footnote).foregroundStyle(TinyLunchStyle.ink)
                        }.padding(.horizontal, 32).padding(.top, 52).padding(.bottom, 32)
                    }
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Good food,\nremembered.")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityAddTraits(.isHeader)
                                Text("Your saved meals, just as you left them.")
                                    .font(.subheadline).foregroundStyle(TinyLunchStyle.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !model.modelAvailability.allowsPhotoAnalysis {
                                    availabilityCard.buttonStyle(.borderless).padding(.top, 8)
                                }
                            }.padding(.vertical, 12)
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                        Section {
                            ForEach(model.meals) { meal in
                                NavigationLink { SavedMealView(meal: meal) { pendingDelete = meal } } label: {
                                    HStack(alignment: .top, spacing: 14) {
                                        if !typeSize.isAccessibilitySize {
                                            FoodBadge(name: meal.items.first?.name ?? "", size: 52)
                                        }
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(meal.title).font(.headline)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(meal.calorieLabel).font(.subheadline.weight(.medium)).foregroundStyle(TinyLunchStyle.accent)
                                                .fixedSize(horizontal: false, vertical: true)
                                            if meal.isIncomplete { Text("Incomplete estimate").font(.caption).foregroundStyle(TinyLunchStyle.ink) }
                                            Text(meal.savedAt, format: .dateTime.day().month().hour().minute())
                                                .font(.caption).foregroundStyle(TinyLunchStyle.ink)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 5)
                                    }
                                }
                                .accessibilityHint("Shows this saved meal. Use the Delete meal action to remove it.")
                                .swipeActions { Button("Delete", role: .destructive) { pendingDelete = meal }.disabled(model.saving) }
                                .contextMenu { Button("Delete meal", systemImage: "trash", role: .destructive) { pendingDelete = meal }.disabled(model.saving) }
                                .accessibilityAction(named: "Delete meal") { pendingDelete = meal }
                                .listRowBackground(TinyLunchStyle.card)
                            }
                        }
                        Section {
                            Text("Saved on this iPhone. Choose Delete meal to remove one.")
                                .font(.body)
                                .foregroundStyle(TinyLunchStyle.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.listRowBackground(Color.clear)
                    }.scrollContentBackground(.hidden)
                }
            }
            .background(TinyLunchStyle.paper)
            .navigationTitle("History")
            .confirmationDialog("Delete this meal?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Delete meal", role: .destructive) {
                    if let meal = pendingDelete { Task { await model.delete(meal) } }
                    pendingDelete = nil
                }
            }
        }
    }

    private var availabilityCard: some View {
        AnalysisAvailabilityCard(
            state: model.modelAvailability,
            showsHistoryAction: false,
            retry: { Task { await model.refresh() } },
            openSettings: openSystemSettings,
            openHistory: {}
        )
    }

    private var emptyHistoryMessage: String {
        if !model.historyLoaded {
            return String(localized: "Your meals are still on this iPhone. Try loading them again.")
        }
        if !model.modelAvailability.allowsPhotoAnalysis {
            return String(localized: "Meals you save stay in this list, where you can open or delete them.")
        }
        return String(localized: "A place for meals worth remembering.\nTap Save after an estimate to keep it here.")
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct SavedMealView: View {
    let meal: Meal
    var delete: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(meal.title).font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(meal.savedAt, format: .dateTime.day().month(.wide).year().hour().minute())
                        .foregroundStyle(TinyLunchStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                MealSummary(meal: meal)
                MedicalDisclaimer()
                Text("On your plate").font(.system(.title3, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 18) {
                    ForEach(meal.items) { item in
                        FoodRow(item: item)
                            .accessibilityHint("Saved food. This record cannot be edited.")
                        if item.id != meal.items.last?.id { Divider() }
                    }
                }.tinyLunchCard()
                Label {
                    Text("Saved as estimated. Your original details stay unchanged.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock").accessibilityHidden(true)
                }
                .font(.footnote).foregroundStyle(TinyLunchStyle.ink)
                Button(role: .destructive) { delete() } label: {
                    AccessibleActionLabel(title: "Delete meal", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("deleteSavedMeal")
                .accessibilityLabel("Delete meal")
                .accessibilityHint("Asks you to confirm before deleting this meal.")
            }.padding(24).padding(.bottom, 24)
        }
        .background(TinyLunchStyle.paper)
        .navigationTitle("Saved meal").navigationBarTitleDisplayMode(.inline)
    }
}
