import Paperize
import SwiftUI

@main
struct PaperizeDemoApp: App {
    @StateObject private var settings = PaperSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                // App-wide: covers UIKit screens, sheets and alerts too.
                .paperizeApp(settings.isOn, configuration: settings.configuration)
        }
    }
}

final class PaperSettings: ObservableObject {
    enum Preset: String, CaseIterable, Identifiable {
        case standard = "Default", ereader = "E-reader", newsprint = "Newsprint", unlit = "Unlit", tinted = "Tinted"
        var id: String { rawValue }

        var configuration: PaperizeConfiguration {
            switch self {
            case .standard: return .default
            case .ereader: return .ereader
            case .newsprint: return .newsprint
            case .unlit: return .unlit
            case .tinted: return .tintedPaper
            }
        }
    }

    @Published var isOn = true
    @Published var preset: Preset = .standard { didSet { resetTweaks() } }
    @Published var dimming: Double = 0
    @Published var grain: Double = 0
    @Published var refreshMode: RefreshConfiguration.Mode = .automatic

    init() { resetTweaks() }

    var configuration: PaperizeConfiguration {
        var config = preset.configuration
        config.dimming = CGFloat(dimming)
        config.grain = CGFloat(grain)
        config.refresh.mode = refreshMode
        return config
    }

    private func resetTweaks() {
        dimming = Double(preset.configuration.dimming)
        grain = Double(preset.configuration.grain)
    }
}
