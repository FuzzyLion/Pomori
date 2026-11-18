import SwiftUI

enum FocusControlColors {
    static func statusTitleColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? VibePalette.warmBackground.opacity(0.92)
            : VibePalette.labelPrimary.opacity(0.84)
    }

    /// Icons on the round glass controls: warm white in dark mode, restrained dark gray in light mode.
    static func controlIconColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? VibePalette.warmBackground.opacity(0.86)
            : VibePalette.labelPrimary.opacity(0.78)
    }

    /// Secondary text on the page, such as a finished session's breakdown. At least 4.5:1 on
    /// the page in both appearances.
    static func captionColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? VibePalette.warmBackground.opacity(0.64)
            : VibePalette.labelPrimary.opacity(0.80)
    }

    /// Label color on tinted capsule buttons in light mode, dark enough for 4.5:1 on the tint.
    static var lightProminentButtonForeground: Color {
        VibePalette.labelPrimary.opacity(0.92)
    }
}

struct FocusStatusTitle: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let text: String
    /// While a step is paused, Paused follows the phase: a still countdown and a running one look
    /// alike at a glance.
    let isPaused: Bool
    let phase: SessionPhase

    var body: some View {
        // The phase and Paused share a line between the top controls. At accessibility sizes a long
        // phase name and Paused no longer fit there, and Paused moves under the phase.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                statusLight

                HStack(spacing: 0) {
                    Text(text)
                    pausedSuffix
                }
            }
            .fixedSize()

            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    statusLight
                    Text(text)
                }

                if isPaused {
                    Text("Paused")
                        .transition(.opacity)
                }
            }
            .fixedSize()
        }
        .focusFont(.statusTitle)
        .tracking(-0.2)
        .lineLimit(1)
        .foregroundStyle(FocusControlColors.statusTitleColor(for: colorScheme))
        .frame(minHeight: FocusScreenLayout.topActionButtonVisualSize)
        .animation(
            reduceMotion ? FocusCompletionMotion.reducedMotionFade : FocusScreenLayout.pausedStatusAnimation,
            value: isPaused
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPaused ? "\(text), paused" : text)
        .zIndex(4)
    }

    private var statusLight: some View {
        Circle()
            .fill(phase.tintColor)
            .frame(width: 6.5, height: 6.5)
            .shadow(color: phase.shadowColor.opacity(colorScheme == .dark ? 0.20 : 0.14), radius: 3)
    }

    /// Paused unfolds from the end of the phase name while the line re-centers around it, so the two
    /// words never cross. Running, it takes no width.
    private var pausedSuffix: some View {
        Text(" · Paused")
            .fixedSize()
            .modifier(FocusSoftLeadingReveal(progress: isPaused ? 1 : 0))
            .frame(width: isPaused ? nil : 0, alignment: .leading)
            .opacity(isPaused ? 1 : 0)
    }
}

/// Shows its content from the leading edge as `progress` goes from 0 to 1. The moving edge is a short
/// fade rather than a cut, so a letter appears gradually instead of being sliced; at 1 the fade lies
/// past the end and the content is whole.
private struct FocusSoftLeadingReveal: ViewModifier, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let fadeWidth: CGFloat = 14

    func body(content: Content) -> some View {
        content.mask(alignment: .leading) {
            GeometryReader { proxy in
                let edge = max(0, CGFloat(progress) * (proxy.size.width + Self.fadeWidth))
                let solidShare = edge > 0 ? max(0, edge - Self.fadeWidth) / edge : 0

                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: solidShare),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: edge)
            }
        }
    }
}

enum SessionProgressNodeState: Equatable {
    case inactive
    /// The focus block that is running now.
    case half
    /// A focus block that reached its full planned duration.
    case filled
    /// A focus block that was skipped or ended before its full duration.
    case skipped
}

struct SessionProgressDots: View {
    let phase: SessionPhase
    let nodeStates: [SessionProgressNodeState]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(nodeStates.enumerated()), id: \.offset) { _, state in
                SessionProgressNode(phase: phase, state: state)
            }
        }
        .frame(minHeight: 12)
        .zIndex(4)
    }
}

private struct SessionProgressNode: View {
    @Environment(\.colorScheme) private var colorScheme

    let phase: SessionPhase
    let state: SessionProgressNodeState

    private let dotDiameter: CGFloat = 8.5

    var body: some View {
        Circle()
            .fill(inactiveFill)
            .overlay {
                if state == .half || state == .filled {
                    Circle()
                        .fill(activeFill)
                        .mask(alignment: .leading) {
                            Rectangle()
                                .frame(width: state == .half ? dotDiameter / 2 : dotDiameter)
                        }
                }
            }
            .overlay {
                if state == .skipped {
                    Circle()
                        .strokeBorder(phase.shadowColor.opacity(colorScheme == .dark ? 0.85 : 0.75), lineWidth: 1.2)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.28), lineWidth: 0.45)
                }
            }
            .frame(width: dotDiameter, height: dotDiameter)
            .shadow(
                color: state == .half || state == .filled
                    ? phase.shadowColor.opacity(colorScheme == .dark ? 0.22 : 0.13)
                    : .clear,
                radius: 2.5,
                y: 0.5
            )
    }

    private var inactiveFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.14)
            : VibePalette.labelSecondary.opacity(0.16)
    }

    private var activeFill: LinearGradient {
        LinearGradient(
            colors: [phase.tintColor, phase.shadowColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// A round glass control with a single SF Symbol, used in the top row and beside the primary button.
struct FocusIconButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemImage: String
    let diameter: CGFloat
    let symbolSize: CGFloat
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(FocusControlColors.controlIconColor(for: colorScheme))
                // At accessibility text sizes the glass style drew the symbol at about three quarters
                // of its size inside the unchanged circle.
                .imageScale(.medium)
                .frame(width: diameter, height: diameter)
        }
        .buttonStyle(.glass(.regular.tint(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12))))
        .buttonBorderShape(.circle)
        .accessibilityLabel(accessibilityLabel)
        // The circle keeps its size at every text size; at accessibility sizes a long press shows the
        // symbol and its name enlarged.
        .accessibilityShowsLargeContentViewer {
            Label(accessibilityLabel, systemImage: systemImage)
        }
        .zIndex(4)
    }
}

struct FocusPrimaryControlButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let action: FocusPrimaryAction
    let phase: SessionPhase
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 9) {
                // When the label changes inside an animation, as Pause becomes Done at a session's
                // end, the symbol and the title change over together.
                Image(systemName: action.systemImage)
                    .focusFont(.primarySymbol)
                    .contentTransition(.symbolEffect(.replace))

                Text(action.title)
                    .focusFont(.primaryLabel)
                    .tracking(-0.18)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .contentTransition(.opacity)
            }
            .foregroundStyle(colorScheme == .light ? FocusControlColors.lightProminentButtonForeground : .primary)
            .frame(
                minWidth: FocusScreenLayout.bottomPrimaryButtonMinWidth,
                maxWidth: .infinity,
                minHeight: FocusScreenLayout.bottomPrimaryButtonHeight,
                maxHeight: FocusScreenLayout.bottomPrimaryButtonHeight
            )
        }
        .buttonStyle(.glassProminent)
        .tint(tint)
        .buttonBorderShape(.capsule)
        .accessibilityLabel(action.title)
        // The label stops growing at the page's largest text size; beyond it a long press shows it enlarged.
        .accessibilityShowsLargeContentViewer {
            Label(action.title, systemImage: action.systemImage)
        }
        .zIndex(4)
    }

    /// Pause stays neutral so the bubble remains the strongest color while a step runs.
    /// Start, Resume, and Done carry a light wash of the current phase color.
    private var tint: Color {
        if action == .pause {
            return Color.white.opacity(colorScheme == .dark ? 0.10 : 0.70)
        }

        return phase.tintColor.opacity(colorScheme == .dark ? 0.34 : 0.42)
    }
}
