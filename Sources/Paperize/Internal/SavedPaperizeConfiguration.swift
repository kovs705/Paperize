import UIKit

/// Versioned disk representation; UIKit colors are stored in resolved light-appearance RGBA.
struct SavedPaperizeConfiguration: Codable {
    let version: Int
    let paperColor: RGBAColor
    let inkColor: RGBAColor
    let isGrayscale: Bool
    let dimming: CGFloat
    let grain: CGFloat
    let prefersLightAppearance: Bool
    let refreshMode: String
    let fullRefreshInterval: Int
    let showsGhosting: Bool
    let ghostingIntensity: CGFloat
    let speed: Double
    let respectsAccessibilitySettings: Bool

    init(_ configuration: PaperizeConfiguration) {
        version = 1
        paperColor = RGBAColor(configuration.paperColor) ?? RGBAColor(red: 1, green: 1, blue: 1)
        inkColor = RGBAColor(configuration.inkColor) ?? RGBAColor(red: 0, green: 0, blue: 0)
        isGrayscale = configuration.isGrayscale
        dimming = configuration.dimming
        grain = configuration.grain
        prefersLightAppearance = configuration.prefersLightAppearance
        switch configuration.refresh.mode {
        case .off: refreshMode = "off"
        case .manual: refreshMode = "manual"
        case .automatic: refreshMode = "automatic"
        }
        fullRefreshInterval = configuration.refresh.fullRefreshInterval
        showsGhosting = configuration.refresh.showsGhosting
        ghostingIntensity = configuration.refresh.ghostingIntensity
        speed = configuration.refresh.speed
        respectsAccessibilitySettings = configuration.refresh.respectsAccessibilitySettings
    }

    var configuration: PaperizeConfiguration? {
        guard version == 1, paperColor.isValid, inkColor.isValid,
              dimming.isFinite, grain.isFinite, ghostingIntensity.isFinite, speed.isFinite else { return nil }
        let mode: RefreshConfiguration.Mode
        switch refreshMode {
        case "off": mode = .off
        case "manual": mode = .manual
        case "automatic": mode = .automatic
        default: return nil
        }
        return PaperizeConfiguration(
            paperColor: paperColor.uiColor, inkColor: inkColor.uiColor,
            isGrayscale: isGrayscale, dimming: dimming, grain: grain,
            prefersLightAppearance: prefersLightAppearance,
            refresh: RefreshConfiguration(
                mode: mode, fullRefreshInterval: fullRefreshInterval, showsGhosting: showsGhosting,
                ghostingIntensity: ghostingIntensity, speed: speed,
                respectsAccessibilitySettings: respectsAccessibilitySettings
            )
        )
    }

    static func normalize(_ input: PaperizeConfiguration, fallback: PaperizeConfiguration) -> PaperizeConfiguration {
        var result = input
        result.paperColor = (RGBAColor(input.paperColor) ?? RGBAColor(fallback.paperColor))?.uiColor ?? .white
        result.inkColor = (RGBAColor(input.inkColor) ?? RGBAColor(fallback.inkColor))?.uiColor ?? .black
        result.dimming = input.dimming.isFinite ? input.dimming.clamped01 : fallback.dimming
        result.grain = input.grain.isFinite ? input.grain.clamped01 : fallback.grain
        result.refresh.ghostingIntensity = input.refresh.ghostingIntensity.isFinite
            ? input.refresh.ghostingIntensity.clamped01 : fallback.refresh.ghostingIntensity
        result.refresh.speed = input.refresh.speed.isFinite ? min(max(input.refresh.speed, 0.1), 5) : fallback.refresh.speed
        result.refresh.fullRefreshInterval = min(max(input.refresh.fullRefreshInterval, 0), 100)
        return result
    }
}
