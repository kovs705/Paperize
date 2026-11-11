import UIKit

/// Makes the whole app look like it's on an e-ink display: grayscale, paper-toned, slightly
/// dimmed, with optional previous-screen ghosting.
///
/// ```swift
/// Paperize.enable()                       // default look
/// Paperize.enable(.newsprint)             // or a preset
/// Paperize.configuration.dimming = 0.3    // tweak live
/// Paperize.refresh(.full)                 // gently fade the previous screen
/// Paperize.disable()
/// ```
///
/// Paperize puts a touch-transparent overlay on every window of the app. Your views and
/// layout are never modified.
@MainActor
public enum Paperize {

    /// Whether the paper effect is currently on.
    public static var isEnabled: Bool {
        PaperizeController.shared.isEnabled
    }

    /// The active configuration. Changes take effect immediately if Paperize is enabled,
    /// and are used the next time it's enabled otherwise.
    public static var configuration: PaperizeConfiguration {
        get { PaperizeController.shared.configuration }
        set { PaperizeController.shared.update(newValue) }
    }

    /// Turns the paper effect on for every window of the app, including windows created later.
    ///
    /// - Parameters:
    ///   - configuration: The look to use. Pass `nil` to keep the current ``configuration``.
    ///   - animated: Crossfades from the current appearance to the paper effect.
    public static func enable(_ configuration: PaperizeConfiguration? = nil, animated: Bool = true) {
        PaperizeController.shared.enable(configuration ?? self.configuration, animated: animated)
    }

    /// Turns the paper effect off and restores every window.
    public static func disable(animated: Bool = true) {
        PaperizeController.shared.disable(animated: animated)
    }

    /// Turns the effect on if it's off, and off if it's on.
    public static func toggle(animated: Bool = true) {
        if isEnabled {
            disable(animated: animated)
        } else {
            enable(animated: animated)
        }
    }

    /// Plays a gentle ghost fade now. Does nothing if Paperize is disabled or
    /// ``RefreshConfiguration/mode`` is `.off`.
    ///
    /// For a ghost of the *previous* screen, use ``performWithRefresh(_:_:)`` instead, which
    /// snapshots the screen before your changes.
    public static func refresh(_ kind: RefreshKind = .automatic) {
        PaperizeController.shared.refresh(kind)
    }

    /// Snapshots the screen, runs `changes`, and then plays a refresh that ghosts the old content.
    ///
    /// ```swift
    /// Paperize.performWithRefresh {
    ///     pageView.page += 1
    /// }
    /// ```
    public static func performWithRefresh(_ kind: RefreshKind = .automatic, _ changes: () -> Void) {
        let controller = PaperizeController.shared
        controller.captureGhosts()
        changes()
        controller.refresh(kind)
    }
}

public extension UIWindow {

    /// Set to `true` to keep this window in full color while Paperize is enabled, for
    /// example a debug overlay or a camera preview window.
    @MainActor
    var isPaperizeExcluded: Bool {
        get { PaperizeController.shared.isExcluded(self) }
        set { PaperizeController.shared.setExcluded(newValue, window: self) }
    }
}
