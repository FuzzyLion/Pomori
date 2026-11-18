import SwiftUI

struct FocusScreenLayout {
    static let bubbleDiameter: CGFloat = 280
    static let horizontalPadding: CGFloat = 24
    static let topChromeHorizontalPadding: CGFloat = 18
    static let topChromeInnerSpacing: CGFloat = 16
    static let topActionButtonHitSize: CGFloat = 40
    static let topActionButtonVisualSize: CGFloat = 36
    static let progressDotsHeight: CGFloat = 12
    static let bottomControlRowWidth: CGFloat = 324
    static let bottomControlSpacing: CGFloat = 14
    static let bottomGlassMergeSpacing: CGFloat = 0
    static let bottomSecondaryButtonHitSize: CGFloat = 58
    static let bottomSecondaryButtonSize: CGFloat = 50
    static let bottomPrimaryButtonHeight: CGFloat = 52
    static let bottomPrimaryButtonMinWidth: CGFloat = 176
    /// The chrome's text grows with Dynamic Type up to this size. Above it the layout around the vessel
    /// would run out of room, so the controls offer the large content viewer instead.
    static let largestTextSize: DynamicTypeSize = .accessibility1
    static let layoutSettlingEpsilon: CGFloat = 1
    static let immersiveLayoutRestoreFallbackDelay: Duration = .milliseconds(450)
    static let immersiveVisualFadeAnimation = Animation.easeOut(duration: 0.18)
    static let phaseMorphAnimation = Animation.easeInOut(duration: 0.34)
    /// Paused unfolding after the phase, close to the primary button's own change from Pause to Resume.
    static let pausedStatusAnimation = Animation.easeInOut(duration: 0.32)
    static let phaseChromeBreathInAnimation = Animation.easeOut(duration: 0.18)
    static let phaseChromeBreathOutAnimation = Animation.easeInOut(duration: 0.24)
    static let phaseChromeBreathHoldDuration: UInt64 = 90_000_000

    let size: CGSize
    let safeAreaInsets: EdgeInsets
    /// The container frame in global coordinates, used to keep the bubble in place
    /// while immersive mode changes the safe area.
    let containerFrame: CGRect

    init(proxy: GeometryProxy) {
        size = proxy.size
        safeAreaInsets = proxy.safeAreaInsets
        containerFrame = proxy.frame(in: .global)
    }

    var isCompact: Bool {
        size.height < 760
    }

    var topChromePadding: CGFloat {
        max(6, safeAreaInsets.top - 50)
    }

    /// Room for the status between the top controls, keeping the inner spacing on both sides.
    var statusTitleMaxWidth: CGFloat {
        max(0, size.width - 2 * (Self.topChromeHorizontalPadding + Self.topActionButtonHitSize + Self.topChromeInnerSpacing))
    }

    /// Global y of the bubble center in the regular layout.
    var defaultBubbleGlobalY: CGFloat {
        containerFrame.minY + size.height / 2
    }

    /// The bubble sits in the middle of the page unless it is pinned to a global position.
    func bubbleCenter(pinnedGlobalY: CGFloat?) -> CGPoint {
        let y = pinnedGlobalY.map { $0 - containerFrame.minY } ?? size.height / 2
        return CGPoint(x: size.width / 2, y: y)
    }

    func progressDotsTop(bubbleCenterY: CGFloat) -> CGFloat {
        bubbleCenterY + Self.bubbleDiameter / 2 + (isCompact ? 16 : 20)
    }

    /// The breakdown of a finished session, just under the round markers.
    func summaryCaptionTop(bubbleCenterY: CGFloat) -> CGFloat {
        progressDotsTop(bubbleCenterY: bubbleCenterY) + Self.progressDotsHeight + (isCompact ? 11 : 14)
    }

    func bottomChromeTop(bubbleCenterY: CGFloat) -> CGFloat {
        bubbleCenterY
            + Self.bubbleDiameter / 2
            + (isCompact ? 40 : 56)
            + Self.progressDotsHeight
            + (isCompact ? 18 : 22)
    }

    static func bubbleFrame(center: CGPoint) -> CGRect {
        CGRect(
            x: center.x - bubbleDiameter / 2,
            y: center.y - bubbleDiameter / 2,
            width: bubbleDiameter,
            height: bubbleDiameter
        )
    }
}
