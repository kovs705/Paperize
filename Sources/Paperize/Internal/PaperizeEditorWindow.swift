import SwiftUI

/// Temporarily exempts the editor's window without changing the host's exclusion policy.
struct PaperizeEditorWindow: UIViewRepresentable {
    func makeUIView(context: Context) -> Reader { Reader() }
    func updateUIView(_ uiView: Reader, context: Context) {}
    static func dismantleUIView(_ uiView: Reader, coordinator: Void) { uiView.releaseWindow() }

    final class Reader: UIView {
        private weak var excludedWindow: UIWindow?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window !== excludedWindow else { return }
            releaseWindow()
            guard let window else { return }
            excludedWindow = window
            PaperizeController.shared.beginEditing(in: window)
        }

        func releaseWindow() {
            if let window = excludedWindow { PaperizeController.shared.endEditing(in: window) }
            excludedWindow = nil
        }
    }
}
