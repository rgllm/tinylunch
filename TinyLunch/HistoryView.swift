import SwiftUI

struct HistoryView: View {
    @Bindable var model: AppModel
    var startMeal: () -> Void
    @State private var pendingDelete: Meal?
    var body: some View {
        NavigationStack {
            Group {
                if model.meals.isEmpty {
                    ScrollView {
                        VStack(spacing: 22) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 28).fill(NoshStyle.soft)
                                    .frame(width: 154, height: 174).rotationEffect(.degrees(-10)).offset(x: -12, y: 3)
                                VStack(spacing: 16) {
                                    Text("🥡").font(.system(size: 60))
                                    Capsule().fill(NoshStyle.soft).frame(width: 70, height: 6)
                                    Capsule().fill(NoshStyle.soft.opacity(0.65)).frame(width: 44, height: 6)
                                }.frame(width: 154, height: 174).background(NoshStyle.card, in: RoundedRectangle(cornerRadius: 28))
                                    .rotationEffect(.degrees(6)).offset(x: 12)
                            }.frame(height: 214).accessibilityHidden(true)
                            Text(model.historyLoaded ? "No saved meals" : "History unavailable")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
                            Text(model.historyLoaded ? "A place for meals worth remembering.\nTap Save after an estimate to keep it here." : "Your meals are still on this iPhone. Try loading them again.")
                                .foregroundStyle(.secondary).multilineTextAlignment(.center)
                            if model.historyLoaded {
                                Button("Start a meal", systemImage: "plus") { startMeal() }.buttonStyle(PrimaryAction())
                            } else {
                                Button("Retry", systemImage: "arrow.clockwise") { Task { await model.refresh() } }.buttonStyle(PrimaryAction())
                            }
                            Label("Just meal details. No photos.", systemImage: "lock")
                                .font(.footnote).foregroundStyle(.secondary)
                        }.padding(.horizontal, 32).padding(.top, 52).padding(.bottom, 32)
                    }
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Good food,\nremembered.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                                Text("Your saved meals, just as you left them.").font(.subheadline).foregroundStyle(.secondary)
                            }.padding(.vertical, 12)
                        }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
                        Section {
                            ForEach(model.meals) { meal in
                                NavigationLink { SavedMealView(meal: meal) } label: {
                                    HStack(alignment: .top, spacing: 14) {
                                        FoodBadge(name: meal.items.first?.name ?? "", size: 52)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(meal.title).font(.headline)
                                            Text(meal.calorieLabel).font(.subheadline.weight(.medium)).foregroundStyle(NoshStyle.accent)
                                            if meal.isIncomplete { Text("Incomplete estimate").font(.caption).foregroundStyle(.secondary) }
                                            Text(meal.savedAt, format: .dateTime.day().month().hour().minute())
                                                .font(.caption).foregroundStyle(.secondary)
                                        }.padding(.vertical, 5)
                                    }
                                }
                                .swipeActions { Button("Delete", role: .destructive) { pendingDelete = meal }.disabled(model.saving) }
                                .contextMenu { Button("Delete meal", systemImage: "trash", role: .destructive) { pendingDelete = meal }.disabled(model.saving) }
                                .accessibilityAction(named: "Delete meal") { pendingDelete = meal }
                                .listRowBackground(NoshStyle.card)
                            }
                        } footer: { Text("Saved on this iPhone. Swipe left to delete a meal.") }
                    }.scrollContentBackground(.hidden)
                }
            }
            .background(NoshStyle.paper)
            .navigationTitle("History")
            .confirmationDialog("Delete this meal?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Delete meal", role: .destructive) {
                    if let meal = pendingDelete { Task { await model.delete(meal) } }
                    pendingDelete = nil
                }
            }
        }
    }
}

private struct SavedMealView: View {
    let meal: Meal
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(meal.title).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(meal.savedAt, format: .dateTime.day().month(.wide).year().hour().minute())
                        .foregroundStyle(.secondary)
                }
                MealSummary(meal: meal)
                Text("On your plate").font(.system(.title3, design: .rounded, weight: .bold))
                VStack(spacing: 18) {
                    ForEach(meal.items) { item in
                        FoodRow(item: item)
                        if item.id != meal.items.last?.id { Divider() }
                    }
                }.noshCard()
                Label("Saved as estimated. Your original details stay unchanged.", systemImage: "lock")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(24)
        }
        .background(NoshStyle.paper)
        .navigationTitle("Saved meal").navigationBarTitleDisplayMode(.inline)
    }
}
