import Foundation
import Observation

/// A saved paper configuration, owned and shared by the host app.
///
/// Creating or editing settings never enables Paperize. Pass ``configuration`` to
/// `.paperizeApp(_:configuration:)` to apply changes live while Paper mode is on.
@MainActor
@Observable
public final class PaperizeSettings {
    public let defaultConfiguration: PaperizeConfiguration

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String
    private var value: PaperizeConfiguration

    /// Edits are normalized and saved immediately in this app's defaults domain.
    public var configuration: PaperizeConfiguration {
        get { value }
        set {
            value = SavedPaperizeConfiguration.normalize(newValue, fallback: defaultConfiguration)
            if let data = try? JSONEncoder().encode(SavedPaperizeConfiguration(value)) {
                defaults.set(data, forKey: storageKey)
            }
        }
    }

    public init(
        defaultConfiguration: PaperizeConfiguration = .default,
        defaults: UserDefaults = .standard,
        storageKey: String = "Paperize.configuration"
    ) {
        let initial = SavedPaperizeConfiguration.normalize(defaultConfiguration, fallback: .default)
        self.defaultConfiguration = initial
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SavedPaperizeConfiguration.self, from: data),
           let restored = saved.configuration {
            value = SavedPaperizeConfiguration.normalize(restored, fallback: initial)
        } else {
            value = initial
        }
    }

    /// Restores and saves the initial configuration chosen by this app.
    public func reset() {
        configuration = defaultConfiguration
    }
}
