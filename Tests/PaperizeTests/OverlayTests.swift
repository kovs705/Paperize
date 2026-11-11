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

    func testRenderOnlyChangesGhostOpacity() {
        let overlay = PaperOverlayView(configuration: .default)
        overlay.render(WaveformStep(ghostAlpha: 0.3, duration: 0))
        XCTAssertEqual(overlay.ghostContainer.alpha, 0.3, accuracy: 0.001)
        overlay.render(.idle)
        XCTAssertEqual(overlay.ghostContainer.alpha, 0)
    }

    func testPlaybackEndsAtRestAndDropsGhost() async throws {
        let overlay = PaperOverlayView(configuration: .default)
        let steps = Waveform.steps(for: .partial, configuration: .default, reducesMotion: false)
        overlay.play(steps, ghost: UIView())
        XCTAssertEqual(overlay.ghostContainer.subviews.count, 1)

        try await Task.sleep(for: .milliseconds(600))

        XCTAssertTrue(overlay.ghostContainer.subviews.isEmpty)
        XCTAssertFalse(overlay.isPlaying)
    }

    func testGhostSitsAbovePaperStack() {
        let overlay = PaperOverlayView(configuration: .default)
        let order = overlay.subviews
        let ghost = try? XCTUnwrap(order.firstIndex(of: overlay.ghostContainer))
        XCTAssertGreaterThan(ghost ?? -1, order.firstIndex(of: overlay.grainView) ?? .max)
    }

    func testPaperOverlayPreservesVisibleContentContrast() async throws {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw XCTSkip("Rendering requires an application-hosted test with a window scene")
        }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let content = UIViewController()
        content.view.backgroundColor = .white
        let black = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 100))
        black.backgroundColor = .black
        content.view.addSubview(black)
        window.rootViewController = content
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        var configuration = PaperizeConfiguration.ereader
        configuration.grain = 0
        let overlay = PaperOverlayView(configuration: configuration)
        overlay.frame = window.bounds
        window.addSubview(overlay)
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixels = [UInt8](repeating: 0, count: 100 * 100 * 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixels, width: 100, height: 100, bitsPerComponent: 8,
            bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        let ink = Int(pixels[(50 * 100 + 25) * 4])
        let paper = Int(pixels[(50 * 100 + 75) * 4])
        XCTAssertGreaterThan(paper - ink, 100, "Paperize must preserve content, not render a flat overlay (ink: \(ink), paper: \(paper))")
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
