import UIKit

/// Describes how the "paper" looks and how the simulated e-ink display refreshes.
///
/// Start from a preset and tweak it:
///
/// ```swift
/// var config = PaperizeConfiguration.newsprint
/// config.dimming = 0.2
/// Paperize.enable(config)
/// ```
public struct PaperizeConfiguration: Equatable {

    /// The color of the paper. It is *multiplied* over the app: pure white becomes this color,
    /// and every other color is tinted toward it.
    public var paperColor: UIColor

    /// The darkest "ink" the display can show. Pure black is lifted to this color
    /// (lighten blend), giving the low-contrast look of e-paper.
    public var inkColor: UIColor

    /// Removes all color from the app when `true`.
    public var isGrayscale: Bool

    /// Extra darkening, from `0` (none) to `1` (black), like an e-reader with its front light off.
    public var dimming: CGFloat

    /// Strength of the paper grain texture, from `0` (smooth) to `1` (rough).
    public var grain: CGFloat

    /// Forces the light appearance on paperized windows while Paperize is enabled. E-paper
    /// is reflective, so dark mode looks wrong on it.
    public var prefersLightAppearance: Bool

    /// How screen updates are visualized.
    public var refresh: RefreshConfiguration

    public init(
        paperColor: UIColor = PaperizeConfiguration.default.paperColor,
        inkColor: UIColor = PaperizeConfiguration.default.inkColor,
        isGrayscale: Bool = true,
        dimming: CGFloat = 0,
        grain: CGFloat = 0,
        prefersLightAppearance: Bool = true,
        refresh: RefreshConfiguration = .default
    ) {
        self.paperColor = paperColor
        self.inkColor = inkColor
        self.isGrayscale = isGrayscale
        self.dimming = dimming.clamped01
        self.grain = grain.clamped01
        self.prefersLightAppearance = prefersLightAppearance
        self.refresh = refresh
    }
}

// MARK: - Presets

public extension PaperizeConfiguration {

    /// Soft gray paper with slightly lifted blacks. A good all-round e-ink look.
    static let `default` = PaperizeConfiguration(
        paperColor: UIColor(white: 0.90, alpha: 1),
        inkColor: UIColor(white: 0.13, alpha: 1),
        isGrayscale: true,
        dimming: 0,
        grain: 0.15,
        prefersLightAppearance: true,
        refresh: .default
    )

    /// Bright, crisp, slightly warm paper, like a modern e-reader with the front light on.
    static let ereader = PaperizeConfiguration(
        paperColor: UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1),
        inkColor: UIColor(white: 0.08, alpha: 1),
        isGrayscale: true,
        dimming: 0,
        grain: 0.05,
        prefersLightAppearance: true,
        refresh: .default
    )

    /// Warm, grainy, low-contrast newsprint.
    static let newsprint = PaperizeConfiguration(
        paperColor: UIColor(red: 0.91, green: 0.88, blue: 0.80, alpha: 1),
        inkColor: UIColor(red: 0.22, green: 0.21, blue: 0.20, alpha: 1),
        isGrayscale: true,
        dimming: 0.04,
        grain: 0.45,
        prefersLightAppearance: true,
        refresh: .default
    )

    /// A dim, unlit e-ink panel, like reading in a dark room. Easy on the eyes at night.
    static let unlit = PaperizeConfiguration(
        paperColor: UIColor(white: 0.84, alpha: 1),
        inkColor: UIColor(white: 0.18, alpha: 1),
        isGrayscale: true,
        dimming: 0.32,
        grain: 0.2,
        prefersLightAppearance: true,
        refresh: .default
    )

    /// Keeps the app's colors but puts them on paper: tinted, flattened, and textured.
    static let tintedPaper = PaperizeConfiguration(
        paperColor: UIColor(red: 0.95, green: 0.93, blue: 0.87, alpha: 1),
        inkColor: UIColor(white: 0.12, alpha: 1),
        isGrayscale: false,
        dimming: 0,
        grain: 0.25,
        prefersLightAppearance: false,
        refresh: .off
    )
}

// MARK: - Refresh

/// How the simulated e-ink panel visualizes screen changes.
public struct RefreshConfiguration: Equatable, Sendable {

    /// When refreshes happen.
    public enum Mode: Equatable, Sendable {
        /// Never refresh. The screen updates instantly, like an LCD.
        case off
        /// Refresh only when you call ``Paperize/refresh(_:)`` or use `.paperizeRefresh(on:)`.
        case manual
        /// Also refresh every time a view controller appears (push, pop, present, tab switch).
        ///
        /// This installs `viewWillAppear(_:)` and `viewDidAppear(_:)` hooks on `UIViewController`.
        case automatic
    }

    public var mode: Mode

    /// Every N-th automatic refresh uses a longer ghost fade. `0` keeps every fade short.
    public var fullRefreshInterval: Int

    /// Shows a faint image of the previous screen that fades out after a partial refresh.
    public var showsGhosting: Bool

    /// Opacity of the ghost image at the start of a partial refresh, from `0` to `1`.
    public var ghostingIntensity: CGFloat

    /// Playback speed multiplier. `2` plays refreshes twice as fast.
    public var speed: Double

    /// When `true`, Reduce Motion disables ghost animations.
    public var respectsAccessibilitySettings: Bool

    public init(
        mode: Mode = .automatic,
        fullRefreshInterval: Int = 6,
        showsGhosting: Bool = true,
        ghostingIntensity: CGFloat = 0.22,
        speed: Double = 1,
        respectsAccessibilitySettings: Bool = true
    ) {
        self.mode = mode
        self.fullRefreshInterval = max(0, fullRefreshInterval)
        self.showsGhosting = showsGhosting
        self.ghostingIntensity = ghostingIntensity.clamped01
        self.speed = speed
        self.respectsAccessibilitySettings = respectsAccessibilitySettings
    }

    /// Automatic ghost fades, with a longer fade every 6th time.
    public static let `default` = RefreshConfiguration()

    /// Refreshes only when you ask for them.
    public static let manual = RefreshConfiguration(mode: .manual)

    /// No refresh effects.
    public static let off = RefreshConfiguration(mode: .off)
}

/// The kind of e-ink refresh to play.
public enum RefreshKind: Equatable, Sendable {
    /// Let Paperize decide: a partial refresh, with a full one every
    /// ``RefreshConfiguration/fullRefreshInterval`` times.
    case automatic
    /// A quick, subtle update that leaves a fading ghost of the previous screen.
    case partial
    /// A longer fade of the previous screen.
    case full
}

// `UIColor` is immutable and thread-safe, but older SDKs don't mark it `Sendable`.
extension PaperizeConfiguration: @unchecked Sendable {}

extension CGFloat {
    var clamped01: CGFloat { Swift.min(Swift.max(self, 0), 1) }
}
