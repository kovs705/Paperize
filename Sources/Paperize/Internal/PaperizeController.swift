import MediaAccessibility
import UIKit

/// Owns the global state: which windows are paperized, refresh scheduling, and ghosts.
@MainActor
final class PaperizeController: NSObject {

    static let shared = PaperizeController()

    private(set) var isEnabled = false
    private(set) var configuration: PaperizeConfiguration = .default

    private var counter = RefreshCounter()
    private var isAutomaticRefreshScheduled = false
    private var ghosts: [ObjectIdentifier: UIView] = [:]
    private var ghostsCapturedAt: Date?
    /// While a full refresh is on screen, other refreshes are dropped so they don't cut it short.
    private var fullRefreshEndsAt: Date?
    private let excludedWindows = NSHashTable<UIWindow>.weakObjects()

    /// Ghosts older than this are considered stale, for example after a cancelled interactive pop.
    private let ghostLifetime: TimeInterval = 1.5

    /// Overrides the system accessibility checks. Tests use this.
    var reducesFlashingOverride: Bool?

    // MARK: Enable / disable

    func enable(_ configuration: PaperizeConfiguration, animated: Bool) {
        let wasEnabled = isEnabled
        self.configuration = configuration
        isEnabled = true

        if configuration.refresh.mode == .automatic {
            ViewControllerHooks.install()
        }

        guard !wasEnabled else {
            for window in decoratableWindows { attach(to: window) }
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeVisible(_:)),
            name: UIWindow.didBecomeVisibleNotification,
            object: nil
        )

        let windows = decoratableWindows
        // The "switch on" transition is a full e-ink flash, unless refreshes are off or the
        // user asked for less flashing. Then it's a crossfade.
        let shouldFlash = animated && configuration.refresh.mode != .off && !reducesFlashing
        if animated && !shouldFlash { crossfade(windows) }
        for window in windows { attach(to: window) }
        counter.reset()
        if shouldFlash { refresh(.full) }
    }

    func disable(animated: Bool) {
        guard isEnabled else { return }
        isEnabled = false

        NotificationCenter.default.removeObserver(self, name: UIWindow.didBecomeVisibleNotification, object: nil)

        let windows = allWindows
        if animated { crossfade(windows.filter { overlay(in: $0) != nil }) }
        for window in windows { detach(from: window) }
        ghosts.removeAll()
        ghostsCapturedAt = nil
        fullRefreshEndsAt = nil
    }

    func update(_ configuration: PaperizeConfiguration) {
        self.configuration = configuration
        guard isEnabled else { return }
        if configuration.refresh.mode == .automatic {
            ViewControllerHooks.install()
        }
        for window in allWindows {
            if let overlay = overlay(in: window) {
                overlay.apply(configuration)
                applyAppearance(to: window, overlay: overlay)
            }
        }
    }

    // MARK: Windows

    var allWindows: [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
    }

    private var decoratableWindows: [UIWindow] {
        allWindows.filter { shouldDecorate($0) }
    }

    func shouldDecorate(_ window: UIWindow) -> Bool {
        !excludedWindows.contains(window) && !Self.isSystemWindow(window)
    }

    /// UIKit's own helper windows (keyboard, text effects, and so on). Their content is often
    /// rendered out of process, and adding subviews to them isn't supported.
    static func isSystemWindow(_ window: UIWindow) -> Bool {
        let type = Swift.type(of: window)
        guard type != UIWindow.self else { return false }
        let name = NSStringFromClass(type)
        return name.hasPrefix("UI") || name.hasPrefix("_UI")
    }

    func overlay(in window: UIWindow) -> PaperOverlayView? {
        window.subviews.lazy.compactMap { $0 as? PaperOverlayView }.first
    }

    @discardableResult
    func attach(to window: UIWindow) -> PaperOverlayView {
        if let existing = overlay(in: window) {
            existing.apply(configuration)
            applyAppearance(to: window, overlay: existing)
            return existing
        }
        let overlay = PaperOverlayView(configuration: configuration)
        overlay.frame = window.bounds
        window.addSubview(overlay)
        applyAppearance(to: window, overlay: overlay)
        return overlay
    }

    func detach(from window: UIWindow) {
        guard let overlay = overlay(in: window) else { return }
        overlay.stopPlayback()
        if let saved = overlay.savedInterfaceStyle {
            window.overrideUserInterfaceStyle = saved
        }
        overlay.removeFromSuperview()
    }

    private func applyAppearance(to window: UIWindow, overlay: PaperOverlayView) {
        if configuration.prefersLightAppearance {
            if overlay.savedInterfaceStyle == nil {
                overlay.savedInterfaceStyle = window.overrideUserInterfaceStyle
            }
            window.overrideUserInterfaceStyle = .light
        } else if let saved = overlay.savedInterfaceStyle {
            window.overrideUserInterfaceStyle = saved
            overlay.savedInterfaceStyle = nil
        }
    }

    func setExcluded(_ excluded: Bool, window: UIWindow) {
        if excluded {
            excludedWindows.add(window)
            detach(from: window)
        } else {
            excludedWindows.remove(window)
            if isEnabled, shouldDecorate(window) { attach(to: window) }
        }
    }

    func isExcluded(_ window: UIWindow) -> Bool {
        excludedWindows.contains(window)
    }

    @objc private func windowDidBecomeVisible(_ notification: Notification) {
        guard isEnabled, let window = notification.object as? UIWindow, shouldDecorate(window) else { return }
        attach(to: window)
    }

    // MARK: Refresh

    var reducesFlashing: Bool {
        if let reducesFlashingOverride { return reducesFlashingOverride }
        guard configuration.refresh.respectsAccessibilitySettings else { return false }
        return UIAccessibility.isReduceMotionEnabled || MADimFlashingLightsEnabled()
    }

    func refresh(_ requested: RefreshKind) {
        guard isEnabled, configuration.refresh.mode != .off else { return }

        if requested != .full, let endsAt = fullRefreshEndsAt, Date() < endsAt {
            // The full refresh in progress already shows the new content cleanly.
            ghosts.removeAll()
            ghostsCapturedAt = nil
            return
        }

        let kind = counter.resolve(requested, fullRefreshInterval: configuration.refresh.fullRefreshInterval)
        let steps = Waveform.steps(for: kind, configuration: configuration.refresh, reducesFlashing: reducesFlashing)
        let freshGhosts = takeGhosts()
        fullRefreshEndsAt = kind == .full
            ? Date().addingTimeInterval(steps.reduce(0) { $0 + $1.duration })
            : nil

        for window in allWindows {
            guard let overlay = overlay(in: window) else { continue }
            // A full refresh exists to clear ghosting, so it never shows a ghost
            // (unless flashing is reduced, in which case the ghost fade replaces the flash).
            let wantsGhost = kind == .partial || reducesFlashing
            let ghost = wantsGhost ? freshGhosts[ObjectIdentifier(window)] : nil
            overlay.play(steps, ghost: ghost)
        }
    }

    /// Snapshots each paperized window as it looks now, so the next refresh can ghost it.
    func captureGhosts() {
        guard isEnabled, configuration.refresh.mode != .off else { return }
        // With reduced flashing, the ghost fade *is* the refresh, so it's needed even if ghosting is off.
        guard configuration.refresh.showsGhosting || reducesFlashing else { return }
        // Several view controllers appear at once during one transition. Only capture once.
        if let capturedAt = ghostsCapturedAt, Date().timeIntervalSince(capturedAt) < 0.1 { return }

        ghosts.removeAll()
        for window in allWindows where !window.isHidden {
            // Skip windows mid-refresh: the snapshot would capture the flash, not the content.
            guard let overlay = overlay(in: window), !overlay.isPlaying else { continue }
            if let snapshot = window.snapshotView(afterScreenUpdates: false) {
                ghosts[ObjectIdentifier(window)] = snapshot
            }
        }
        let capturedAt = Date()
        ghostsCapturedAt = capturedAt

        // Don't hold full-screen snapshots if no refresh follows (for example, a cancelled interactive pop).
        let lifetime = ghostLifetime
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(lifetime * 1_000_000_000))
            guard let self, self.ghostsCapturedAt == capturedAt else { return }
            self.ghosts.removeAll()
            self.ghostsCapturedAt = nil
        }
    }

    private func takeGhosts() -> [ObjectIdentifier: UIView] {
        defer {
            ghosts.removeAll()
            ghostsCapturedAt = nil
        }
        guard let capturedAt = ghostsCapturedAt, Date().timeIntervalSince(capturedAt) <= ghostLifetime else {
            return [:]
        }
        return ghosts
    }

    /// Coalesces the many appearance callbacks from one transition into a single refresh.
    func scheduleAutomaticRefresh() {
        guard isEnabled, configuration.refresh.mode == .automatic, !isAutomaticRefreshScheduled else { return }
        isAutomaticRefreshScheduled = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isAutomaticRefreshScheduled = false
            self.refresh(.automatic)
        }
    }

    // MARK: View controller hooks

    func viewControllerWillAppear(_ viewController: UIViewController) {
        guard isEnabled, configuration.refresh.mode == .automatic else { return }
        guard !Self.isSystemInputController(viewController) else { return }
        if let window = viewController.viewIfLoaded?.window, overlay(in: window) == nil { return }
        captureGhosts()
    }

    /// UIKit's keyboard and input-accessory controllers. Their appearance isn't a "page change".
    static func isSystemInputController(_ viewController: UIViewController) -> Bool {
        let name = NSStringFromClass(Swift.type(of: viewController))
        guard name.hasPrefix("UI") || name.hasPrefix("_UI") else { return false }
        return name.contains("Input") || name.contains("Keyboard")
    }

    func viewControllerDidAppear(_ viewController: UIViewController) {
        guard isEnabled, configuration.refresh.mode == .automatic else { return }
        // Keyboard and other system windows shouldn't make the page flash.
        guard let window = viewController.viewIfLoaded?.window, overlay(in: window) != nil else { return }
        scheduleAutomaticRefresh()
    }

    // MARK: Transitions

    /// Fades from the current on-screen image to whatever is drawn next.
    private func crossfade(_ windows: [UIWindow], duration: TimeInterval = 0.35) {
        for window in windows {
            guard let snapshot = window.snapshotView(afterScreenUpdates: false) else { continue }
            snapshot.frame = window.bounds
            snapshot.isUserInteractionEnabled = false
            snapshot.layer.zPosition = PaperOverlayView.zPosition + 1
            window.addSubview(snapshot)
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: { snapshot.alpha = 0 },
                completion: { _ in snapshot.removeFromSuperview() }
            )
        }
    }
}
