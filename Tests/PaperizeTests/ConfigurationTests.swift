@testable import Paperize
import XCTest

final class ConfigurationTests: XCTestCase {

    func testInitializerClampsUnitValues() {
        let config = PaperizeConfiguration(dimming: 4, grain: -1)
        XCTAssertEqual(config.dimming, 1)
        XCTAssertEqual(config.grain, 0)

        let refresh = RefreshConfiguration(fullRefreshInterval: -3, ghostingIntensity: 2)
        XCTAssertEqual(refresh.fullRefreshInterval, 0)
        XCTAssertEqual(refresh.ghostingIntensity, 1)
    }

    func testPresetsAreDistinct() {
        let presets: [PaperizeConfiguration] = [.default, .ereader, .newsprint, .unlit, .tintedPaper]
        for (i, a) in presets.enumerated() {
            for b in presets[(i + 1)...] {
                XCTAssertNotEqual(a, b)
            }
        }
    }

    func testTintedPaperKeepsColor() {
        XCTAssertFalse(PaperizeConfiguration.tintedPaper.isGrayscale)
        XCTAssertTrue(PaperizeConfiguration.default.isGrayscale)
    }

    func testGrainTextureIsDeterministicAndLight() {
        let a = GrainTexture.make(size: 16)
        let b = GrainTexture.make(size: 16)
        XCTAssertEqual(a.pngData(), b.pngData())
        XCTAssertEqual(a.size, CGSize(width: 8, height: 8), "Rendered at scale 2")
    }
}
