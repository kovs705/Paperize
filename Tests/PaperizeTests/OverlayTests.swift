@testable import Paperize
import UIKit
import XCTest

@MainActor
final class OverlayTests: XCTestCase {

    func testOverlayIsTransparentToTouchesAndAccessibility() {
        let overlay = PaperOverlayView(configuration: .default)
        overlay.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertNil(overlay.hitTest(CGPoint(x: 50, y: 50), with: nil))
        XCTAssertFalse(overlay.isUserInteractionEnabled)
        XCTAssertTrue(overlay.accessibilityElementsHidden)
        XCTAssertEqual(overlay.layer.zPosition, PaperOverlayView.zPosition)
    }

    func testBlendLayersUseExpectedFilters() {
        let overlay = PaperOverlayView(configuration: .default)
        XCTAssertEqual(overlay.grayscaleView.layer.compositingFilter as? String, BlendMode.saturation)
        XCTAssertEqual(overlay.inkView.layer.compositingFilter as? String, BlendMode.lighten)
        XCTAssertEqual(overlay.paperView.layer.compositingFilter as? String, BlendMode.multiply)
        XCTAssertEqual(overlay.grainView.layer.compositingFilter as? String, BlendMode.multiply)
    }

    func testApplyReflectsConfiguration() {
        let overlay = PaperOverlayView(configuration: .default)
        var config = PaperizeConfiguration.tintedPaper
        config.dimming = 0.4
        config.grain = 0
        overlay.apply(config)

        XCTAssertTrue(overlay.grayscaleView.isHidden)
        XCTAssertFalse(overlay.dimView.isHidden)
        XCTAssertEqual(overlay.dimView.alpha, 0.4, accuracy: 0.001)
        XCTAssertTrue(overlay.grainView.isHidden)
        XCTAssertEqual(overlay.paperView.backgroundColor, config.paperColor)
        XCTAssertEqual(overlay.inkView.backgroundColor, config.inkColor)
    }

    func testRenderFlashPhases() {
        let overlay = PaperOverlayView(configuration: .default)

        overlay.render(WaveformStep(flash: .invert, ghostAlpha: 0, duration: 0))
        XCTAssertFalse(overlay.flashView.isHidden)
        XCTAssertEqual(overlay.flashView.layer.compositingFilter as? String, BlendMode.difference)

        overlay.render(WaveformStep(flash: .black, ghostAlpha: 0.3, duration: 0))
        XCTAssertNil(overlay.flashView.layer.compositingFilter)
        XCTAssertEqual(overlay.flashView.backgroundColor, .black)
        XCTAssertEqual(overlay.ghostContainer.alpha, 0.3, accuracy: 0.001)

        overlay.render(.idle)
        XCTAssertTrue(overlay.flashView.isHidden)
        XCTAssertEqual(overlay.ghostContainer.alpha, 0)
    }

    func testPlaybackEndsAtRestAndDropsGhost() async throws {
        let overlay = PaperOverlayView(configuration: .default)
        let steps = Waveform.steps(for: .partial, configuration: .default, reducesFlashing: false)
        overlay.play(steps, ghost: UIView())
        XCTAssertEqual(overlay.ghostContainer.subviews.count, 1)

        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertTrue(overlay.flashView.isHidden)
        XCTAssertTrue(overlay.ghostContainer.subviews.isEmpty)
        XCTAssertFalse(overlay.isPlaying)
    }

    func testGhostSitsAbovePaperStackButBelowFlash() {
        let overlay = PaperOverlayView(configuration: .default)
        let order = overlay.subviews
        let ghost = try? XCTUnwrap(order.firstIndex(of: overlay.ghostContainer))
        XCTAssertGreaterThan(ghost ?? -1, order.firstIndex(of: overlay.grainView) ?? .max)
        XCTAssertLessThan(ghost ?? .max, order.firstIndex(of: overlay.flashView) ?? -1)
    }
}

@MainActor
final class ControllerTests: XCTestCase {

    private var controller: PaperizeController { .shared }

    func testAttachIsIdempotentAndDetachRestoresAppearance() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.overrideUserInterfaceStyle = .dark

        controller.attach(to: window)
        controller.attach(to: window)
        XCTAssertEqual(window.subviews.filter { $0 is PaperOverlayView }.count, 1)
        XCTAssertEqual(window.overrideUserInterfaceStyle, .light)

        controller.detach(from: window)
        XCTAssertNil(controller.overlay(in: window))
        XCTAssertEqual(window.overrideUserInterfaceStyle, .dark)
    }

    func testOverlayStaysAboveLaterSubviews() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let overlay = controller.attach(to: window)
        let modal = UIView()
        window.addSubview(modal)
        XCTAssertGreaterThan(overlay.layer.zPosition, modal.layer.zPosition)
        controller.detach(from: window)
    }

    func testExcludedWindowsAreNotDecorated() {
        let window = UIWindow(frame: .zero)
        XCTAssertTrue(controller.shouldDecorate(window))
        window.isPaperizeExcluded = true
        XCTAssertFalse(controller.shouldDecorate(window))
        window.isPaperizeExcluded = false
        XCTAssertTrue(controller.shouldDecorate(window))
    }

    func testOnlyUIKitInputControllersAreTreatedAsSystemInput() {
        final class KeyboardSettingsViewController: UIViewController {}
        XCTAssertFalse(PaperizeController.isSystemInputController(UINavigationController()))
        XCTAssertFalse(PaperizeController.isSystemInputController(KeyboardSettingsViewController()))
    }

    func testAppWindowSubclassesAreNotTreatedAsSystemWindows() {
        final class AppWindow: UIWindow {}
        XCTAssertFalse(PaperizeController.isSystemWindow(UIWindow(frame: .zero)))
        XCTAssertFalse(PaperizeController.isSystemWindow(AppWindow(frame: .zero)))
    }
}
