import MediaAccessibility
import SwiftUI

public extension View {

    /// Renders *this view* as e-ink paper, using only SwiftUI modifiers.
    ///
    /// Use it for Xcode Previews or to paperize a single screen. To paperize the whole app,
    /// including UIKit screens, sheets, and alerts, use ``Paperize/enable(_:animated:)``
    /// or ``paperizeApp(_:configuration:)``.
    ///
    /// Toggling `isEnabled` keeps the view's identity, so `@State` inside is preserved.
    func paperize(
        _ isEnabled: Bool = true,
        configuration: PaperizeConfiguration = .default
    ) -> some View {
        modifier(PaperizeModifier(isEnabled: isEnabled, configuration: configuration))
    }

    /// Keeps the app-wide Paperize effect in sync with a value, for example a setting toggle.
    ///
    /// ```swift
    /// WindowGroup {
    ///     ContentView()
    ///         .paperizeApp(settings.paperMode, configuration: .newsprint)
    /// }
    /// ```
    func paperizeApp(
        _ isEnabled: Bool,
        configuration: PaperizeConfiguration = .default
    ) -> some View {
        modifier(PaperizeAppModifier(isEnabled: isEnabled, configuration: configuration))
    }

    /// Plays an e-ink refresh whenever `value` changes.
    ///
    /// When app-wide Paperize is enabled this triggers ``Paperize/refresh(_:)``. Otherwise
    /// the refresh flash is drawn over this view only, which works with ``paperize(_:configuration:)``
    /// and in Xcode Previews.
    func paperizeRefresh<Value: Equatable>(
        on value: Value,
        kind: RefreshKind = .automatic,
        configuration: RefreshConfiguration = .default
    ) -> some View {
        modifier(PaperizeRefreshModifier(value: value, kind: kind, configuration: configuration))
    }
}

// MARK: - Scoped paper effect

struct PaperizeModifier: ViewModifier {
    let isEnabled: Bool
    let configuration: PaperizeConfiguration

    func body(content: Content) -> some View {
        content
            .grayscale(isEnabled && configuration.isGrayscale ? 1 : 0)
            .overlay {
                if isEnabled {
                    PaperLayers(configuration: configuration)
                }
            }
            .compositingGroup()
            .environment(\.isInsidePaperize, isEnabled)
    }
}

private struct InsidePaperizeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// `true` inside `.paperize()`. A refresh flash drawn there is processed by the paper
    /// layers above it, so it must draw plain white instead of the paper color.
    var isInsidePaperize: Bool {
        get { self[InsidePaperizeKey.self] }
        set { self[InsidePaperizeKey.self] = newValue }
    }
}

/// The SwiftUI counterpart of `PaperOverlayView`'s blend stack (minus grayscale, which uses
/// the native `.grayscale` modifier).
struct PaperLayers: View {
    let configuration: PaperizeConfiguration

    var body: some View {
        ZStack {
            Color(uiColor: configuration.inkColor)
                .blendMode(.lighten)
            Color(uiColor: configuration.paperColor)
                .blendMode(.multiply)
            Color.black
                .opacity(Double(configuration.dimming.clamped01))
            Image(uiImage: GrainTexture.image)
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(Double(configuration.grain.clamped01))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - App-wide toggle

struct PaperizeAppModifier: ViewModifier {
    let isEnabled: Bool
    let configuration: PaperizeConfiguration

    func body(content: Content) -> some View {
        content
            .onAppear { sync() }
            .onChange(of: isEnabled) { _ in sync() }
            .onChange(of: configuration) { _ in sync() }
    }

    @MainActor
    private func sync() {
        if isEnabled {
            if Paperize.isEnabled {
                Paperize.configuration = configuration
            } else {
                Paperize.enable(configuration)
            }
        } else if Paperize.isEnabled {
            Paperize.disable()
        }
    }
}

// MARK: - Refresh on change

struct PaperizeRefreshModifier<Value: Equatable>: ViewModifier {
    let value: Value
    let kind: RefreshKind
    let configuration: RefreshConfiguration

    @State private var step: WaveformStep = .idle
    @State private var counter = RefreshCounter()
    @State private var generation = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isInsidePaperize) private var isInsidePaperize

    func body(content: Content) -> some View {
        content
            .overlay {
                FlashLayer(
                    step: step,
                    paperColor: isInsidePaperize ? .white : Color(uiColor: PaperizeConfiguration.default.paperColor)
                )
            }
            .onChange(of: value) { _ in trigger() }
    }

    @MainActor
    private func trigger() {
        if Paperize.isEnabled {
            // `onChange` runs before the new frame is on screen, so the snapshot taken here
            // is the outgoing content. It becomes the ghost.
            Paperize.performWithRefresh(kind) {}
            return
        }
        guard configuration.mode != .off else { return }

        let resolved = counter.resolve(kind, fullRefreshInterval: configuration.fullRefreshInterval)
        let reducesFlashing = configuration.respectsAccessibilitySettings
            && (reduceMotion || MADimFlashingLightsEnabled())
        let steps = Waveform.steps(for: resolved, configuration: configuration, reducesFlashing: reducesFlashing)

        generation += 1
        let current = generation
        Task { @MainActor in
            for next in steps {
                guard current == generation else { return }
                step = next
                if next.duration > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(next.duration * 1_000_000_000))
                }
            }
        }
    }
}

/// Draws one waveform step over a SwiftUI view. There's no screen snapshot to ghost here,
/// so the ghost phase is drawn as a fading paper wash.
struct FlashLayer: View {
    let step: WaveformStep
    let paperColor: Color

    var body: some View {
        ZStack {
            paperColor.opacity(Double(step.ghostAlpha.clamped01))
            switch step.flash {
            case .clear:
                Color.clear
            case .invert:
                Color.white.blendMode(.difference)
            case .black:
                Color.black
            case .paper:
                paperColor
            case .dim(let alpha):
                Color.black.opacity(Double(alpha))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
