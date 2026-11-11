import ObjectiveC
import UIKit

/// Opt-in appearance hooks that drive automatic refreshes. They're only installed when a
/// configuration uses `RefreshConfiguration.Mode.automatic`, and they're never removed.
/// Once Paperize is disabled the hooks do nothing.
@MainActor
enum ViewControllerHooks {

    private(set) static var isInstalled = false

    static func install() {
        guard !isInstalled else { return }
        isInstalled = true
        exchange(
            #selector(UIViewController.viewWillAppear(_:)),
            with: #selector(UIViewController.paperize_viewWillAppear(_:))
        )
        exchange(
            #selector(UIViewController.viewDidAppear(_:)),
            with: #selector(UIViewController.paperize_viewDidAppear(_:))
        )
    }

    private static func exchange(_ original: Selector, with replacement: Selector) {
        guard
            let originalMethod = class_getInstanceMethod(UIViewController.self, original),
            let replacementMethod = class_getInstanceMethod(UIViewController.self, replacement)
        else {
            assertionFailure("Paperize: could not hook \(original)")
            return
        }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }
}

extension UIViewController {

    // After the exchange, calling `paperize_*` from inside runs UIKit's original implementation.

    @objc fileprivate dynamic func paperize_viewWillAppear(_ animated: Bool) {
        paperize_viewWillAppear(animated)
        PaperizeController.shared.viewControllerWillAppear(self)
    }

    @objc fileprivate dynamic func paperize_viewDidAppear(_ animated: Bool) {
        paperize_viewDidAppear(animated)
        PaperizeController.shared.viewControllerDidAppear(self)
    }
}
