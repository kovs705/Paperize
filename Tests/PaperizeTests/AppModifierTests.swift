import Observation
@testable import Paperize
import SwiftUI
import XCTest

@MainActor
final class AppModifierTests: XCTestCase {
    @Observable
    final class Settings {
        var isEnabled = false
        var configuration = PaperizeConfiguration.default
    }

    private struct Content: View {
        let settings: Settings

        var body: some View {
            Text("Paperize content")
                .paperizeApp(settings.isEnabled, configuration: settings.configuration)
        }
    }

    func testToggleAppliesTheNewStateImmediately() async throws {
        Paperize.disable(animated: false)
        let settings = Settings()
        settings.configuration.refresh.mode = .off
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = UIHostingController(rootView: Content(settings: settings))
        window.makeKeyAndVisible()
        defer {
            Paperize.disable(animated: false)
            window.isHidden = true
        }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(Paperize.isEnabled)

        settings.isEnabled = true
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(Paperize.isEnabled, "The first on transition must enable Paperize")

        settings.isEnabled = false
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(Paperize.isEnabled, "Off must disable Paperize, rather than replay the previous on value")
    }

    func testConfigurationChangesApplyTheNewConfiguration() async throws {
        Paperize.disable(animated: false)
        let settings = Settings()
        settings.isEnabled = true
        settings.configuration.refresh.mode = .off
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.rootViewController = UIHostingController(rootView: Content(settings: settings))
        window.makeKeyAndVisible()
        defer {
            Paperize.disable(animated: false)
            window.isHidden = true
        }
        try await Task.sleep(for: .milliseconds(100))

        settings.configuration.dimming = 0.47
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(Paperize.configuration.dimming, 0.47, accuracy: 0.001)
    }
}
