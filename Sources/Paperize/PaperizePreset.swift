/// Built-in starting points shown by the configuration editor.
public enum PaperizePreset: String, CaseIterable, Identifiable, Sendable {
    case standard, ereader, newsprint, unlit, tinted

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard: return "Default"
        case .ereader: return "E-reader"
        case .newsprint: return "Newsprint"
        case .unlit: return "Unlit"
        case .tinted: return "Tinted"
        }
    }

    public var configuration: PaperizeConfiguration {
        switch self {
        case .standard: return .default
        case .ereader: return .ereader
        case .newsprint: return .newsprint
        case .unlit: return .unlit
        case .tinted: return .tintedPaper
        }
    }

    /// Returns `nil` for a configuration customized beyond any built-in preset.
    public static func matching(_ configuration: PaperizeConfiguration) -> Self? {
        let normalized = SavedPaperizeConfiguration.normalize(configuration, fallback: .default)
        return allCases.first {
            SavedPaperizeConfiguration.normalize($0.configuration, fallback: .default) == normalized
        }
    }
}
