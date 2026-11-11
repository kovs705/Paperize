import CoreGraphics
import Foundation

/// What the flash layer shows during one waveform step.
enum FlashPhase: Equatable {
    case clear
    /// Inverts everything on screen (difference blend with white).
    case invert
    /// Solid black.
    case black
    /// Solid paper.
    case paper
    /// Black at the given opacity, like a quick partial-update darkening.
    case dim(CGFloat)
}

/// One discrete frame of an e-ink refresh waveform.
struct WaveformStep: Equatable {
    var flash: FlashPhase
    /// Opacity of the previous-screen ghost during this step.
    var ghostAlpha: CGFloat
    /// How long the step stays on screen, in seconds.
    var duration: TimeInterval

    static let idle = WaveformStep(flash: .clear, ghostAlpha: 0, duration: 0)
}

/// Builds the step lists that imitate e-paper refresh waveforms.
///
/// Real e-ink panels don't animate smoothly. They step through a few discrete drive phases,
/// so the steps here are deliberately coarse, with no easing.
enum Waveform {

    static func steps(
        for kind: RefreshKind,
        configuration: RefreshConfiguration,
        reducesFlashing: Bool
    ) -> [WaveformStep] {
        let speed = max(configuration.speed, 0.1)
        let ghost = configuration.showsGhosting ? configuration.ghostingIntensity.clamped01 : 0

        var steps: [WaveformStep]
        switch kind {
        case .full where !reducesFlashing:
            steps = [
                WaveformStep(flash: .invert, ghostAlpha: 0, duration: 0.10),
                WaveformStep(flash: .black, ghostAlpha: 0, duration: 0.07),
                WaveformStep(flash: .paper, ghostAlpha: 0, duration: 0.08)
            ]
        case .full:
            // Without flashing, a "full" refresh is a slower, cleaner ghost fade.
            steps = [
                WaveformStep(flash: .clear, ghostAlpha: max(ghost, 0.2), duration: 0.12),
                WaveformStep(flash: .clear, ghostAlpha: max(ghost, 0.2) * 0.5, duration: 0.12)
            ]
        case .partial, .automatic:
            steps = [
                WaveformStep(flash: reducesFlashing ? .clear : .dim(0.10), ghostAlpha: ghost, duration: 0.05),
                WaveformStep(flash: .clear, ghostAlpha: ghost * 0.6, duration: 0.08),
                WaveformStep(flash: .clear, ghostAlpha: ghost * 0.3, duration: 0.08)
            ]
        }

        steps = steps.map { step in
            var step = step
            step.duration /= speed
            return step
        }
        steps.append(.idle)
        return steps
    }
}

/// Decides when an automatic refresh should be a full one, like e-readers that do a full
/// flash every few page turns to clear accumulated ghosting.
struct RefreshCounter: Equatable {
    private(set) var partialsSinceFull = 0

    mutating func resolve(_ requested: RefreshKind, fullRefreshInterval: Int) -> RefreshKind {
        switch requested {
        case .full:
            partialsSinceFull = 0
            return .full
        case .partial:
            partialsSinceFull += 1
            return .partial
        case .automatic:
            if fullRefreshInterval > 0, partialsSinceFull + 1 >= fullRefreshInterval {
                partialsSinceFull = 0
                return .full
            }
            partialsSinceFull += 1
            return .partial
        }
    }

    mutating func reset() {
        partialsSinceFull = 0
    }
}
