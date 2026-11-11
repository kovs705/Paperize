import Foundation
@testable import Paperize
import UIKit
import XCTest

@MainActor
final class SettingsTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "PaperizeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    func testPrivacyManifestShipsInTheLibraryResourceBundle() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        let accesses = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = try XCTUnwrap(accesses.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        })
        let reasons = try XCTUnwrap(defaults["NSPrivacyAccessedAPITypeReasons"] as? [String])
        XCTAssertTrue(reasons.contains("CA92.1"))
        XCTAssertTrue(reasons.contains("1C8F.1"))
    }

    func testMutationsRestoreEveryConfigurationField() throws {
        try withDefaults { defaults in
            let settings = PaperizeSettings(defaults: defaults)
            var config = PaperizeConfiguration(
                paperColor: UIColor(red: 0.8, green: 0.7, blue: 0.6, alpha: 0.9),
                inkColor: UIColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.8),
                isGrayscale: false, dimming: 0.4, grain: 0.6, prefersLightAppearance: false,
                refresh: RefreshConfiguration(mode: .manual, fullRefreshInterval: 9, showsGhosting: false,
                                              ghostingIntensity: 0.35, speed: 1.5, respectsAccessibilitySettings: false)
            )
            settings.configuration = config
            let restored = PaperizeSettings(defaultConfiguration: .ereader, defaults: defaults)
            XCTAssertEqual(restored.configuration, config)
            config.grain = 0.75
            settings.configuration.grain = 0.75
            XCTAssertEqual(PaperizeSettings(defaults: defaults).configuration, config)
        }
    }

    func testStorageKeysAndAppDomainsRemainIndependent() throws {
        try withDefaults { firstApp in
            try withDefaults { secondApp in
                let settings = PaperizeSettings(defaults: firstApp, storageKey: "first")
                settings.configuration.dimming = 0.65
                XCTAssertEqual(PaperizeSettings(defaults: firstApp, storageKey: "first").configuration.dimming, 0.65)
                XCTAssertEqual(PaperizeSettings(defaults: firstApp, storageKey: "second").configuration.dimming, 0)
                XCTAssertEqual(PaperizeSettings(defaults: secondApp, storageKey: "first").configuration.dimming, 0)
            }
        }
    }

    func testResetPersistsTheAppsInitialConfiguration() throws {
        try withDefaults { defaults in
            let settings = PaperizeSettings(defaultConfiguration: .newsprint, defaults: defaults)
            settings.configuration.dimming = 0.7
            settings.configuration.refresh.mode = .off
            settings.reset()
            let restored = PaperizeSettings(defaultConfiguration: .ereader, defaults: defaults)
            XCTAssertEqual(restored.configuration.dimming, 0.04)
            XCTAssertEqual(restored.configuration.grain, 0.45)
            XCTAssertEqual(restored.configuration.refresh.mode, .automatic)
        }
    }

    func testCorruptAndFutureDataFallBackWithoutEnablingPaperize() throws {
        Paperize.disable(animated: false)
        try withDefaults { defaults in
            for data in [Data("broken".utf8), Data("{\"version\":999}".utf8)] {
                defaults.set(data, forKey: "Paperize.configuration")
                let settings = PaperizeSettings(defaultConfiguration: .newsprint, defaults: defaults)
                XCTAssertEqual(settings.configuration.grain, 0.45)
                XCTAssertFalse(Paperize.isEnabled)
            }
        }
    }

    func testACompleteFutureSchemaIsNotLoadedAsCurrentData() throws {
        try withDefaults { defaults in
            let settings = PaperizeSettings(defaults: defaults)
            settings.configuration.dimming = 0.6
            let data = try XCTUnwrap(defaults.data(forKey: "Paperize.configuration"))
            var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            payload["version"] = 999
            defaults.set(try JSONSerialization.data(withJSONObject: payload), forKey: "Paperize.configuration")
            XCTAssertEqual(PaperizeSettings(defaultConfiguration: .unlit, defaults: defaults).configuration.dimming, 0.32)
        }
    }

    func testUnknownModeAndInvalidColorFallBackToInitialConfiguration() throws {
        try withDefaults { defaults in
            let settings = PaperizeSettings(defaults: defaults)
            settings.configuration.dimming = 0.5
            let saved = try XCTUnwrap(defaults.data(forKey: "Paperize.configuration"))
            var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
            payload["refreshMode"] = "future-mode"
            defaults.set(try JSONSerialization.data(withJSONObject: payload), forKey: "Paperize.configuration")
            XCTAssertEqual(PaperizeSettings(defaultConfiguration: .unlit, defaults: defaults).configuration.dimming, 0.32)

            payload = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
            payload["paperColor"] = ["red": 2, "green": 0, "blue": 0, "alpha": 1]
            defaults.set(try JSONSerialization.data(withJSONObject: payload), forKey: "Paperize.configuration")
            XCTAssertEqual(PaperizeSettings(defaultConfiguration: .unlit, defaults: defaults).configuration.dimming, 0.32)
        }
    }

    func testNumericEditsAreNormalizedBeforeApplyingAndSaving() throws {
        try withDefaults { defaults in
            let settings = PaperizeSettings(defaultConfiguration: .newsprint, defaults: defaults)
            settings.configuration.dimming = .nan
            settings.configuration.grain = 2
            settings.configuration.refresh.ghostingIntensity = -1
            settings.configuration.refresh.speed = .infinity
            settings.configuration.refresh.fullRefreshInterval = -9
            XCTAssertEqual(settings.configuration.dimming, 0.04)
            XCTAssertEqual(settings.configuration.grain, 1)
            XCTAssertEqual(settings.configuration.refresh.ghostingIntensity, 0)
            XCTAssertEqual(settings.configuration.refresh.speed, 1)
            XCTAssertEqual(settings.configuration.refresh.fullRefreshInterval, 0)
            settings.configuration.refresh.speed = 100
            settings.configuration.refresh.fullRefreshInterval = 1000
            let restored = PaperizeSettings(defaults: defaults)
            XCTAssertEqual(restored.configuration.refresh.speed, 5)
            XCTAssertEqual(restored.configuration.refresh.fullRefreshInterval, 100)
        }
    }

    func testPresetMatchingSurvivesSavingAndShowsCustomAfterEdits() throws {
        try withDefaults { defaults in
            for preset in PaperizePreset.allCases {
                let settings = PaperizeSettings(defaults: defaults)
                settings.configuration = preset.configuration
                let restored = PaperizeSettings(defaults: defaults)
                XCTAssertEqual(PaperizePreset.matching(restored.configuration), preset)
                restored.configuration.grain = 0.99
                XCTAssertNil(PaperizePreset.matching(restored.configuration))
            }
        }
    }

    func testDynamicColorsAreSavedUsingLightAppearance() throws {
        try withDefaults { defaults in
            let settings = PaperizeSettings(defaults: defaults)
            settings.configuration.paperColor = UIColor { traits in
                traits.userInterfaceStyle == .dark ? .black : .white
            }
            let restored = PaperizeSettings(defaults: defaults)
            var red: CGFloat = 0
            restored.configuration.paperColor.getRed(&red, green: nil, blue: nil, alpha: nil)
            XCTAssertEqual(red, 1)
        }
    }
}
