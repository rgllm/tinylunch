import SwiftUI
import UIKit

/// Shared colors follow appearance; the interface still uses native navigation and controls.

enum VoiceOverAnnouncement {
    /// Status that is easy to miss when the control VoiceOver was on disappears.
    @MainActor static func post(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
enum TinyLunchStyle {
    static let paper = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.08, green: 0.085, blue: 0.075, alpha: 1)
        : UIColor(red: 0.975, green: 0.961, blue: 0.935, alpha: 1) })
    static let card = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.13, green: 0.14, blue: 0.12, alpha: 1) : .white })
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 1, green: 0.68, blue: 0.48, alpha: 1)
        : UIColor(red: 0.45, green: 0.16, blue: 0.06, alpha: 1) })
    /// Body and caption copy. Dark enough for small text on paper, cards, and the soft fill.
    static let ink = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.93, green: 0.90, blue: 0.85, alpha: 1)
        : UIColor(red: 0.24, green: 0.16, blue: 0.11, alpha: 1) })
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
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 26).padding(.vertical, 16).padding(.horizontal, 20)
            .foregroundStyle(enabled ? .white : TinyLunchStyle.ink)
            .background(enabled ? TinyLunchStyle.button : TinyLunchStyle.card, in: RoundedRectangle(cornerRadius: 22))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Icon and title that stack at accessibility sizes so the title wraps instead of truncating.
struct AccessibleActionLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 6) {
                Image(systemName: systemImage).accessibilityHidden(true)
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: systemImage).accessibilityHidden(true)
                Text(title).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MedicalDisclaimer: View {
    var prominent = true
    @Environment(\.dynamicTypeSize) private var typeSize
    private var message: some View {
        let icon = Image(systemName: "cross.case")
            .font(.subheadline)
            .foregroundStyle(TinyLunchStyle.accent)
            .accessibilityHidden(true)
        let copy = Text("TinyLunch is not a medical device. These are estimates only, not medical or dietary advice. Consult a qualified professional for guidance about your health.")
            .font(.headline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { icon; copy }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) { icon; copy }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("medicalDisclaimer")
    }
    var body: some View {
        if prominent {
            message
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TinyLunchStyle.card, in: RoundedRectangle(cornerRadius: 20))
        } else {
            message.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ScaledTextButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
    }
}

/// Icon and wrapping title. Stacks at accessibility sizes so the title is not clipped beside the symbol.
struct IconLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { icon; titleText }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) { icon; titleText }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var icon: some View {
        Image(systemName: systemImage).accessibilityHidden(true)
    }

    private var titleText: some View {
        Text(title)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        Text(emoji)
            .font(.title2)
            .frame(minWidth: size, minHeight: size)
            .background(TinyLunchStyle.soft, in: RoundedRectangle(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
            .accessibilityIdentifier("decorativeGlyph")
    }
}

struct EmojiPlate: View {
    @State private var taps = 0
    @State private var chef = false
    @AccessibilityFocusState private var plateFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let foods = ["🥑", "🍋", "🥐", "🍓", "🍳"]
    var body: some View {
        Button {
            taps += 1
            if taps.isMultiple(of: 5) { chef = true }
        } label: {
            ZStack {
                Ellipse().fill(TinyLunchStyle.soft).frame(width: 220, height: 108).offset(y: 18)
                Circle().fill(TinyLunchStyle.card).frame(width: 188, height: 188)
                    .shadow(color: .black.opacity(0.055), radius: 12, x: 0, y: 12)
                Circle().strokeBorder(TinyLunchStyle.soft, lineWidth: 2).frame(width: 158, height: 158)
                Circle().fill(TinyLunchStyle.paper.opacity(0.6)).frame(width: 136, height: 136)
                Text(foods[taps % foods.count])
                    .font(.system(size: 72))
                    .padding(32)
                    .rotationEffect(.degrees(taps.isMultiple(of: 2) ? -8 : 6))
                    .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.35), value: taps)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("decorativeGlyph")
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .clipped()
            .overlay(alignment: .topTrailing) {
                Text("🍅").font(.title).padding(.top, 12).padding(.trailing, 28)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("decorativeGlyph")
            }
            .overlay(alignment: .bottomLeading) {
                Text("🌿").font(.title).padding(.leading, 24).padding(.bottom, 16)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("decorativeGlyph")
            }
            .overlay(alignment: .topLeading) {
                Image(systemName: "sparkle").font(.body).foregroundStyle(TinyLunchStyle.accent)
                    .padding(.leading, 36).padding(.top, 28)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("The TinyLunch plate")
        .accessibilityHint("Tap to change the food on the plate.")
        .accessibilityIdentifier("emojiPlate")
        .accessibilityFocused($plateFocused)
        .accessibilityAction(named: "Discover the chef’s table") { chef = true }
        .sensoryFeedback(.selection, trigger: taps)
        .sheet(isPresented: $chef, onDismiss: {
            Task { @MainActor in plateFocused = true }
        }) { SurpriseSheet(kind: .chef) }
    }
}

struct SurpriseSheet: View {
    enum Kind { case chef, toast }
    let kind: Kind
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var titleFocused: Bool
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
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($titleFocused)
                    Text(kind == .chef ? (served ? "One imaginary pancake. No need to log this one." : "You found our tiny kitchen. There’s always a seat for the curious.") : "To good food, good company, and remembering to eat before it gets cold.")
                        .foregroundStyle(TinyLunchStyle.ink).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if kind == .chef {
                        Button(served ? "Compliments to the chef" : "Surprise me") {
                            if served { dismiss() }
                            else { withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) { served = true } }
                        }.buttonStyle(PrimaryAction()).padding(.top, 8)
                    }
                }.padding(28)
            }
            .background(TinyLunchStyle.paper)
        }
        .tint(TinyLunchStyle.accent)
        .safeAreaInset(edge: .bottom) {
            Button("Done") { dismiss() }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(TinyLunchStyle.paper)
                .accessibilityHint("Closes this screen.")
        }
        .onAppear { Task { @MainActor in titleFocused = true } }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.selection, trigger: served)
    }
}

struct PrivacySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @AccessibilityFocusState private var noticeFocused: Bool
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Not a medical device")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($noticeFocused)
                    MedicalDisclaimer(prominent: false)
                    privacyHeading
                    Text("TinyLunch is built for on-device estimates. Your food photos and meal details aren’t sent to a server.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    sectionHeader("What stays")
                    wrappingLabel("Only meals you choose to save", systemImage: "checkmark.circle")
                    wrappingLabel("Foods, portions, and estimates", systemImage: "list.bullet")
                    wrappingLabel("No saved photos", systemImage: "photo.badge.checkmark")
                    Text("History stays on this iPhone and is excluded from backups. Deleting the app removes it. You can delete individual meals in History.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Apple may need to download its model first. Choosing an iCloud photo may also need a connection.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    sectionHeader("Photo analysis")
                    Text("Estimating from a photo uses Apple Intelligence on this iPhone. If that on-device model isn’t available, History stays usable and new estimates wait until it is.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Adjust portions and preparation before saving. Unknown foods stay unknown instead of becoming zero.")
                        .font(.body)
                        .foregroundStyle(TinyLunchStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(TinyLunchStyle.paper)
            .navigationTitle("Made to stay local").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityHint("Closes About privacy.")
                }
            }
        }
        .onAppear { Task { @MainActor in noticeFocused = true } }
        .presentationDragIndicator(.visible)
    }

    private var privacyHeading: some View {
        let icon = Image(systemName: "lock.iphone")
            .font(.title2)
            .accessibilityHidden(true)
        let title = Text("Your plate. Your business.")
            .font(.title2.weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { icon; title }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 10) { icon; title }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(TinyLunchStyle.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private func wrappingLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        IconLabel(title: title, systemImage: systemImage)
            .font(.body)
            .foregroundStyle(.primary)
    }
}
