@testable import Paperize
import XCTest

final class WaveformTests: XCTestCase {

    func testFullRefreshFlashesInvertBlackPaperThenRests() {
        let steps = Waveform.steps(for: .full, configuration: .default, reducesFlashing: false)
        XCTAssertEqual(steps.map(\.flash), [.invert, .black, .paper, .clear])
        XCTAssertTrue(steps.allSatisfy { $0.ghostAlpha == 0 }, "A full refresh clears ghosting")
        XCTAssertEqual(steps.last, .idle)
    }

    func testFullRefreshNeverFlashesWhenFlashingIsReduced() {
        let steps = Waveform.steps(for: .full, configuration: .default, reducesFlashing: true)
        XCTAssertTrue(steps.allSatisfy { $0.flash == .clear })
        XCTAssertGreaterThan(steps.first?.ghostAlpha ?? 0, 0, "Falls back to a ghost fade")
    }

    func testPartialRefreshFadesGhostMonotonically() {
        let steps = Waveform.steps(for: .partial, configuration: .default, reducesFlashing: false)
        let ghosts = steps.map(\.ghostAlpha)
        XCTAssertEqual(ghosts.first, RefreshConfiguration.default.ghostingIntensity)
        XCTAssertEqual(ghosts, ghosts.sorted(by: >))
        XCTAssertEqual(steps.first?.flash, .dim(0.10))
    }

    func testPartialRefreshWithoutFlashingHasNoDim() {
        let steps = Waveform.steps(for: .partial, configuration: .default, reducesFlashing: true)
        XCTAssertTrue(steps.allSatisfy { $0.flash == .clear })
    }

    func testGhostingCanBeDisabled() {
        var config = RefreshConfiguration.default
        config.showsGhosting = false
        let steps = Waveform.steps(for: .partial, configuration: config, reducesFlashing: false)
        XCTAssertTrue(steps.allSatisfy { $0.ghostAlpha == 0 })
    }

    func testSpeedScalesDurations() {
        var fast = RefreshConfiguration.default
        fast.speed = 2
        let normal = Waveform.steps(for: .full, configuration: .default, reducesFlashing: false)
        let doubled = Waveform.steps(for: .full, configuration: fast, reducesFlashing: false)
        for (a, b) in zip(normal, doubled) {
            XCTAssertEqual(a.duration / 2, b.duration, accuracy: 0.0001)
        }
    }

    func testNonPositiveSpeedDoesNotProduceInfiniteDurations() {
        var config = RefreshConfiguration.default
        config.speed = 0
        let steps = Waveform.steps(for: .full, configuration: config, reducesFlashing: false)
        XCTAssertTrue(steps.allSatisfy { $0.duration.isFinite })
    }
}

final class RefreshCounterTests: XCTestCase {

    func testEveryNthAutomaticRefreshIsFull() {
        var counter = RefreshCounter()
        let kinds = (0..<12).map { _ in counter.resolve(.automatic, fullRefreshInterval: 6) }
        XCTAssertEqual(kinds, [
            .partial, .partial, .partial, .partial, .partial, .full,
            .partial, .partial, .partial, .partial, .partial, .full
        ])
    }

    func testExplicitFullResetsTheCycle() {
        var counter = RefreshCounter()
        _ = counter.resolve(.automatic, fullRefreshInterval: 3)
        _ = counter.resolve(.automatic, fullRefreshInterval: 3)
        XCTAssertEqual(counter.resolve(.full, fullRefreshInterval: 3), .full)
        XCTAssertEqual(counter.resolve(.automatic, fullRefreshInterval: 3), .partial)
    }

    func testZeroIntervalNeverEscalates() {
        var counter = RefreshCounter()
        for _ in 0..<50 {
            XCTAssertEqual(counter.resolve(.automatic, fullRefreshInterval: 0), .partial)
        }
    }

    func testIntervalOfOneAlwaysFull() {
        var counter = RefreshCounter()
        for _ in 0..<5 {
            XCTAssertEqual(counter.resolve(.automatic, fullRefreshInterval: 1), .full)
        }
    }
}
