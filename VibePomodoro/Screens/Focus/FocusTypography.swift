import SwiftUI

/// The Focus page's type scale around the vessel. Each role keeps its size at the default text size and
/// grows with Dynamic Type along the system text style closest to it, up to
/// `FocusScreenLayout.largestTextSize`. The countdown and the FOCUSED label belong to the vessel and keep
/// their size.
enum FocusTextRole {
    /// Ready, the current phase, or the session's end, at the top of the page.
    case statusTitle
    /// The note under the status after an early finish.
    case statusDetail
    /// A finished session's breakdown under the round markers.
    case summaryCaption
    /// Start, Pause, Resume, or Done.
    case primaryLabel
    /// The symbol beside the primary label.
    case primarySymbol

    var size: CGFloat {
        switch self {
        case .statusTitle: 18
        case .primaryLabel: 17
        case .primarySymbol: 15
        case .statusDetail: 14
        case .summaryCaption: 13
        }
    }

    var weight: Font.Weight {
        switch self {
        case .statusTitle, .primaryLabel, .primarySymbol: .semibold
        case .statusDetail, .summaryCaption: .medium
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .statusTitle: .headline
        case .primaryLabel, .primarySymbol: .body
        case .statusDetail: .subheadline
        case .summaryCaption: .footnote
        }
    }
}

private struct FocusScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(_ role: FocusTextRole) {
        _size = ScaledMetric(wrappedValue: role.size, relativeTo: role.textStyle)
        weight = role.weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    func focusFont(_ role: FocusTextRole) -> some View {
        modifier(FocusScaledFont(role))
    }
}
