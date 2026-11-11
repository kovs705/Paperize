import CoreGraphics
import Foundation

/// One step in the fade of a previous-screen snapshot.
struct WaveformStep: Equatable {
    var ghostAlpha: CGFloat
    var duration: TimeInterval

    static let idle = WaveformStep(ghostAlpha: 0, duration: 0)
}

/// Refreshes only fade previous content; they never replace or invert the screen.
enum Waveform {
    static func steps(
        for kind: RefreshKind,
        configuration: RefreshConfiguration,
        reducesMotion: Bool
    ) -> [WaveformStep] {
        guard configuration.showsGhosting, !reducesMotion else { return [.idle] }
        let speed = max(configuration.speed, 0.1)
        let ghost = configuration.ghostingIntensity.clamped01
        let duration: TimeInterval = kind == .full ? 0.12 : 0.08
        return [
            WaveformStep(ghostAlpha: ghost, duration: duration / speed),
            WaveformStep(ghostAlpha: ghost * 0.6, duration: duration / speed),
            WaveformStep(ghostAlpha: ghost * 0.3, duration: duration / speed),
            .idle
        ]
    }
}

/// Decides when an automatic refresh uses the longer ghost fade.
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
