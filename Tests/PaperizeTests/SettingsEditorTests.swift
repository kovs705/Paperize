import Foundation
@testable import Paperize
import SwiftUI
import XCTest

@MainActor
final class SettingsEditorTests: XCTestCase {
    private func hostedWindow() throws -> UIWindow {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            throw XCTSkip("Window lifecycle verification requires an application-hosted test")
        }
        return UIWindow(windowScene: scene)
    }

    private struct Root: View {
        let settings: PaperizeSettings
        var body: some View {
            Text("Live settings")
                .paperizeApp(true, configuration: settings.configuration)
        }
    }

    func testSavedSettingsDriveTheAppModifierLive() async throws {
        let suite = "PaperizeEditorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = PaperizeSettings(defaults: defaults)
        settings.configuration.refresh.mode = .off
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = UIHostingController(rootView: Root(settings: settings))
        window.makeKeyAndVisible()
        defer {
            Paperize.disable(animated: false)
            window.isHidden = true
            defaults.removePersistentDomain(forName: suite)
        }
        try await Task.sleep(for: .milliseconds(100))
        settings.configuration.grain = 0.6
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(Paperize.isEnabled)
        XCTAssertEqual(Paperize.configuration.grain, 0.6)
        XCTAssertEqual(PaperizeSettings(defaults: defaults).configuration.grain, 0.6)
    }

    func testEditorKeepsItsWindowReadableAndRestoresTheEffectOnDismissal() async throws {
        let suite = "PaperizeEditorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = PaperizeSettings(defaults: defaults)
        Paperize.enable(animated: false)
        let window = try hostedWindow()
        window.rootViewController = UIHostingController(rootView: PaperizeSettingsView(settings: settings))
        window.makeKeyAndVisible()
        defer {
            Paperize.disable(animated: false)
            window.isHidden = true
            defaults.removePersistentDomain(forName: suite)
        }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(Paperize.isEnabled)
        XCTAssertFalse(PaperizeController.shared.shouldDecorate(window), "The editor must remain readable at any ink/paper settings")
        XCTAssertNil(PaperizeController.shared.overlay(in: window))
        window.rootViewController = UIHostingController(rootView: Text("App content"))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(window.isPaperizeExcluded)
        XCTAssertNotNil(PaperizeController.shared.overlay(in: window))
    }

    func testDarkHostPreviewRespondsToLightAppearancePreference() throws {
        var config = PaperizeConfiguration.ereader
        config.prefersLightAppearance = false
        let darkPreview = ImageRenderer(content: PaperizeSettingsPreview(configuration: config)
            .environment(\.colorScheme, .dark).frame(width: 320, height: 180))
        let darkImage = try XCTUnwrap(darkPreview.uiImage?.pngData())
        config.prefersLightAppearance = true
        let lightPreview = ImageRenderer(content: PaperizeSettingsPreview(configuration: config)
            .environment(\.colorScheme, .dark).frame(width: 320, height: 180))
        XCTAssertNotEqual(darkImage, try XCTUnwrap(lightPreview.uiImage?.pngData()))
    }

    func testHostWindowExclusionChangesSurviveEditorDismissal() async throws {
        let suite = "PaperizeEditorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = PaperizeSettings(defaults: defaults)
        let window = try hostedWindow()
        window.rootViewController = UIHostingController(rootView: PaperizeSettingsView(settings: settings))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            defaults.removePersistentDomain(forName: suite)
        }
        try await Task.sleep(for: .milliseconds(100))
        window.isPaperizeExcluded = false
        XCTAssertFalse(PaperizeController.shared.shouldDecorate(window), "A host cannot revoke a temporary editor lease")
        window.isPaperizeExcluded = true
        window.rootViewController = UIHostingController(rootView: Text("App content"))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(window.isPaperizeExcluded, "The host's explicit exclusion must survive editor dismissal")
    }

    func testUnreadableSavedConfigurationLeavesAVisibleRecoveryPath() async throws {
        Paperize.disable(animated: false)
        let suite = "PaperizeEditorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let saved = PaperizeSettings(defaults: defaults)
        saved.configuration.dimming = 1
        let restored = PaperizeSettings(defaults: defaults)
        restored.configuration.refresh.mode = .off
        let window = try hostedWindow()
        window.rootViewController = UIHostingController(rootView: Root(settings: restored))
        window.makeKeyAndVisible()
        defer {
            Paperize.disable(animated: false)
            window.isHidden = true
            defaults.removePersistentDomain(forName: suite)
        }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(Paperize.isEnabled)
        XCTAssertEqual(restored.configuration.dimming, 1, "Keep the user's saved value")
        XCTAssertNil(PaperizeController.shared.overlay(in: window), "Unreadable settings must leave the app usable after relaunch")
        restored.configuration.dimming = 0
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNotNil(PaperizeController.shared.overlay(in: window), "Readable edits restore the effect automatically")
        restored.configuration.paperColor = .black
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(PaperizeController.shared.overlay(in: window))
    }

    func testOpeningEditorWhileDisabledKeepsPaperizeDisabled() async throws {
        Paperize.disable(animated: false)
        let suite = "PaperizeEditorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = PaperizeSettings(defaultConfiguration: .ereader, defaults: defaults)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = UIHostingController(rootView: PaperizeSettingsView(settings: settings))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            defaults.removePersistentDomain(forName: suite)
        }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(Paperize.isEnabled)
        settings.configuration.grain = 0.4
        XCTAssertEqual(PaperizeSettings(defaults: defaults).configuration.grain, 0.4)
        XCTAssertFalse(Paperize.isEnabled)
    }
}
