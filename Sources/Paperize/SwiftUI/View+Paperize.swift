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

    /// Presents the shared, automatically saved configuration editor.
    /// Opening this sheet does not change whether Paperize is enabled.
    @MainActor
    func paperizeSettingsSheet(
        isPresented: Binding<Bool>,
        settings: PaperizeSettings
    ) -> some View {
        sheet(isPresented: isPresented) {
            PaperizeSettingsView(settings: settings)
        }
    }

    /// Plays an e-ink refresh whenever `value` changes.
    ///
    /// When app-wide Paperize is enabled this fades a snapshot of the previous screen.
    /// Otherwise it has no visual effect. The configuration argument is retained for
    /// source compatibility; app-wide refreshes use ``Paperize/configuration``.
    func paperizeRefresh<Value: Equatable>(
        on value: Value,
        kind: RefreshKind = .automatic,
        configuration: RefreshConfiguration = .default
    ) -> some View {
        modifier(PaperizeRefreshModifier(value: value, kind: kind))
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
            .onChange(of: isEnabled) { sync() }
            .onChange(of: configuration) { sync() }
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

    func body(content: Content) -> some View {
        content.onChange(of: value) {
            if Paperize.isEnabled {
                Paperize.performWithRefresh(kind) {}
            }
        }
    }
}
