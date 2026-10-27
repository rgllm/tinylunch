import Foundation
import FoundationModels

/// What the capture and review screens should do with the on-device model.
/// History stays reachable for every status. Photo analysis is offered only when the model is available and can see images.
struct AnalysisAvailabilityState: Equatable, Sendable {
    enum Status: Equatable, Hashable, Sendable {
        case ready
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
        case visionUnavailable
        case unavailable
    }

    enum Action: Equatable, Hashable, Sendable {
        case openSettings
        case retry
        case openHistory

        var title: String {
            switch self {
            case .openSettings: String(localized: "Open Settings")
            case .retry: String(localized: "Try again")
            case .openHistory: String(localized: "Open History")
            }
        }

        var symbol: String {
            switch self {
            case .openSettings: "gearshape"
            case .retry: "arrow.clockwise"
            case .openHistory: "clock"
            }
        }

        var accessibilityIdentifier: String {
            switch self {
            case .openSettings: "openAnalysisSettings"
            case .retry: "retryAnalysis"
            case .openHistory: "openHistoryFromAnalysis"
            }
        }

        var accessibilityHint: String {
            switch self {
            case .openSettings: String(localized: "Opens Settings so you can turn on Apple Intelligence.")
            case .retry: String(localized: "Checks whether on-device estimates are available.")
            case .openHistory: String(localized: "Shows saved meals.")
            }
        }
    }

    let status: Status
    let title: String
    let explanation: String
    let symbol: String
    let primaryAction: Action?
    let secondaryAction: Action?

    var allowsPhotoAnalysis: Bool { status == .ready }
    var allowsTextEstimate: Bool {
        switch status {
        case .ready, .visionUnavailable: true
        case .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unavailable: false
        }
    }
    var allowsHistory: Bool { true }

    static let ready = AnalysisAvailabilityState(
        status: .ready,
        title: "",
        explanation: "",
        symbol: "sparkles",
        primaryAction: nil,
        secondaryAction: nil
    )

    static let deviceNotEligible = AnalysisAvailabilityState(
        status: .deviceNotEligible,
        title: String(localized: "This iPhone can’t estimate meals"),
        explanation: String(localized: "Apple Intelligence isn’t available on this device, so photo analysis stays off. Open History to view or delete saved meals."),
        symbol: "iphone.slash",
        primaryAction: .openHistory,
        secondaryAction: nil
    )

    static let appleIntelligenceNotEnabled = AnalysisAvailabilityState(
        status: .appleIntelligenceNotEnabled,
        title: String(localized: "Apple Intelligence is turned off"),
        explanation: String(localized: "Turn it on in Settings, under Apple Intelligence & Siri, then return to TinyLunch. Estimates stay on this iPhone. History stays available while it’s off."),
        symbol: "gearshape",
        primaryAction: .openSettings,
        secondaryAction: .retry
    )

    static let modelNotReady = AnalysisAvailabilityState(
        status: .modelNotReady,
        title: String(localized: "The on-device model isn’t ready"),
        explanation: String(localized: "Apple is still downloading or preparing Apple Intelligence. That download is handled by the system. Try again when it finishes. History stays available."),
        symbol: "arrow.down.circle",
        primaryAction: .retry,
        secondaryAction: .openHistory
    )

    static let visionUnavailable = AnalysisAvailabilityState(
        status: .visionUnavailable,
        title: String(localized: "Photo analysis isn’t available"),
        explanation: String(localized: "This on-device model can’t look at photos. Saved meals in History can still be opened and deleted."),
        symbol: "photo",
        primaryAction: .openHistory,
        secondaryAction: .retry
    )

    static let unavailable = AnalysisAvailabilityState(
        status: .unavailable,
        title: String(localized: "Photo analysis unavailable"),
        explanation: String(localized: "The on-device model is unavailable right now. Try again in a moment, or open History. Saved meals stay on this iPhone."),
        symbol: "info.circle",
        primaryAction: .retry,
        secondaryAction: .openHistory
    )

    private init(
        status: Status,
        title: String,
        explanation: String,
        symbol: String,
        primaryAction: Action?,
        secondaryAction: Action?
    ) {
        self.status = status
        self.title = title
        self.explanation = explanation
        self.symbol = symbol
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
}

enum AnalysisAvailabilityMapping {
    /// Maps `SystemLanguageModel.availability` into UI state. A missing vision capability is separate from an unavailable model.
    static func state(
        availability: SystemLanguageModel.Availability,
        supportsVision: Bool
    ) -> AnalysisAvailabilityState {
        switch availability {
        case .available:
            return supportsVision ? .ready : .visionUnavailable
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        @unknown default:
            return .unavailable
        }
    }
}
