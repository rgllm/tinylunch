import SwiftUI

/// Shared colors follow appearance; the interface still uses native navigation and controls.
enum TinyLunchStyle {
    static let paper = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.08, green: 0.085, blue: 0.075, alpha: 1)
        : UIColor(red: 0.975, green: 0.961, blue: 0.935, alpha: 1) })
    static let card = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.13, green: 0.14, blue: 0.12, alpha: 1) : .white })
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1, green: 0.68, blue: 0.48, alpha: 1)
        : UIColor(red: 0.64, green: 0.23, blue: 0.10, alpha: 1) })
    static let button = Color(red: 0.65, green: 0.24, blue: 0.11)
    static let soft = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.21, green: 0.17, blue: 0.12, alpha: 1)
        : UIColor(red: 0.95, green: 0.90, blue: 0.82, alpha: 1) })
}

struct TinyLunchCard: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(TinyLunchStyle.card, in: RoundedRectangle(cornerRadius: 28))
    }
}

extension View {
    func tinyLunchCard() -> some View { modifier(TinyLunchCard()) }
}

struct PrimaryAction: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline)
            .frame(maxWidth: .infinity, minHeight: 26).padding(.vertical, 16).padding(.horizontal, 20)
            .foregroundStyle(enabled ? .white : Color.secondary)
            .background(enabled ? TinyLunchStyle.button : TinyLunchStyle.soft, in: RoundedRectangle(cornerRadius: 22))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct FoodBadge: View {
    let name: String
    var size: CGFloat = 46
    private var emoji: String {
        let lower = name.lowercased()
        // Decoration only; this mapping never establishes a food identity or calorie value.
        let symbols: [(String, String)] = [("rice", "🍚"), ("avocado", "🥑"), ("salad", "🥗"),
            ("egg", "🥚"), ("pizza", "🍕"), ("pasta", "🍝"), ("bread", "🍞"),
            ("chicken", "🍗"), ("apple", "🍎"), ("banana", "🍌"), ("coffee", "☕️")]
        return symbols.first { lower.contains($0.0) }?.1 ?? "🍽️"
    }
    var body: some View {
        Text(emoji).font(.system(size: size * 0.56)).frame(width: size, height: size)
            .background(TinyLunchStyle.soft.opacity(0.65), in: RoundedRectangle(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

struct EmojiPlate: View {
    @State private var taps = 0
    @State private var chef = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let foods = ["🥑", "🍋", "🥐", "🍓", "🍳"]
    var body: some View {
        Button {
            taps += 1
            if taps.isMultiple(of: 5) { chef = true }
        } label: {
            ZStack {
                Ellipse().fill(TinyLunchStyle.soft).frame(width: 254, height: 130).offset(y: 24)
                Circle().fill(TinyLunchStyle.card).frame(width: 208, height: 208)
                    .shadow(color: .black.opacity(0.055), radius: 12, x: 0, y: 12)
                Circle().strokeBorder(TinyLunchStyle.soft, lineWidth: 2).frame(width: 176, height: 176)
                Circle().fill(TinyLunchStyle.paper.opacity(0.6)).frame(width: 154, height: 154)
                Text(foods[taps % foods.count]).font(.system(size: 88))
                    .rotationEffect(.degrees(taps.isMultiple(of: 2) ? -12 : 9))
                    .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.35), value: taps)
                Text("🍅").font(.system(size: 32)).rotationEffect(.degrees(18)).offset(x: 104, y: -64)
                Text("🌿").font(.system(size: 33)).rotationEffect(.degrees(-20)).offset(x: -109, y: 64)
                Image(systemName: "sparkle").font(.system(size: 17)).foregroundStyle(TinyLunchStyle.accent).offset(x: -115, y: -58)
            }.frame(maxWidth: .infinity).frame(height: 230).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("The TinyLunch plate")
        .accessibilityHint("Tap to change the food on the plate.")
        .accessibilityIdentifier("emojiPlate")
        .accessibilityAction(named: "Discover the chef’s table") { chef = true }
        .sensoryFeedback(.selection, trigger: taps)
        .sheet(isPresented: $chef) { SurpriseSheet(kind: .chef) }
    }
}

struct SurpriseSheet: View {
    enum Kind { case chef, toast }
    let kind: Kind
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var served = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(kind == .chef ? (served ? "🥞" : "🧑‍🍳") : "🍞")
                        .font(.system(size: 86)).padding(.top, 26)
                        .rotationEffect(.degrees(served && !reduceMotion ? -8 : 0))
                        .accessibilityHidden(true)
                    Text(kind == .chef ? (served ? "On the house." : "The chef’s table") : "A little toast.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
                    Text(kind == .chef ? (served ? "One imaginary pancake. No need to log this one." : "You found our tiny kitchen. There’s always a seat for the curious.") : "To good food, good company, and remembering to eat before it gets cold.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if kind == .chef {
                        Button(served ? "Compliments to the chef" : "Surprise me") {
                            if served { dismiss() }
                            else { withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) { served = true } }
                        }.buttonStyle(PrimaryAction()).padding(.top, 8)
                    }
                }.padding(28)
            }
            .background(TinyLunchStyle.paper)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(TinyLunchStyle.accent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: served)
    }
}

struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Your plate. Your business.", systemImage: "lock.iphone").font(.system(.title2, design: .rounded, weight: .bold))
                    Text("TinyLunch is built for on-device estimates. Your food photos and meal details aren’t sent to a server.")
                }
                Section("What stays") {
                    Label("Only meals you choose to save", systemImage: "checkmark.circle")
                    Label("Foods, portions, and estimates", systemImage: "list.bullet")
                    Label("No saved photos", systemImage: "photo.badge.checkmark")
                }
                Section {
                    Text("History stays on this iPhone and is excluded from backups. Deleting the app removes it. You can delete individual meals in History.")
                    Text("Apple may need to download its model first. Choosing an iCloud photo may also need a connection.")
                }
                Section("Estimates, not advice") {
                    Text("Calories are model estimates, not lab measurements or medical advice. TinyLunch is not a medical device and does not diagnose, treat, or replace professional nutrition guidance.")
                }
                Section {
                    Text("Estimating from a photo uses Apple Intelligence on this iPhone. If that on-device model isn’t available, History stays usable and new estimates wait until it is.")
                } header: {
                    Text("Photo analysis")
                } footer: {
                    Text("Adjust portions and preparation before saving. Unknown foods stay unknown instead of becoming zero.")
                }
            }
            .scrollContentBackground(.hidden).background(TinyLunchStyle.paper)
            .navigationTitle("Made to stay local").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDragIndicator(.visible)
    }
}
