@testable import Paperize
import XCTest

final class WaveformTests: XCTestCase {

    func testEveryRefreshKindOnlyFadesThePreviousScreen() {
        var configuration = RefreshConfiguration.default
        configuration.respectsAccessibilitySettings = false
        for kind: RefreshKind in [.full, .partial, .automatic] {
            let steps = Waveform.steps(for: kind, configuration: configuration, reducesMotion: false)
            XCTAssertEqual(steps.map(\.ghostAlpha), [0.22, 0.132, 0.066, 0])
            XCTAssertEqual(steps.last, .idle)
        }
    }

    func testReduceMotionDisablesRefreshAnimation() {
        for kind: RefreshKind in [.full, .partial, .automatic] {
            XCTAssertEqual(Waveform.steps(for: kind, configuration: .default, reducesMotion: true), [.idle])
        }
    }

    func testGhostingCanBeDisabled() {
        var config = RefreshConfiguration.default
        config.showsGhosting = false
        let steps = Waveform.steps(for: .partial, configuration: config, reducesMotion: false)
        XCTAssertEqual(steps, [.idle])
    }

    func testSpeedScalesDurations() {
        var fast = RefreshConfiguration.default
        fast.speed = 2
        let normal = Waveform.steps(for: .full, configuration: .default, reducesMotion: false)
        let doubled = Waveform.steps(for: .full, configuration: fast, reducesMotion: false)
        for (normalStep, fastStep) in zip(normal, doubled) {
            XCTAssertEqual(normalStep.duration / 2, fastStep.duration, accuracy: 0.0001)
        }
    }

    func testNonPositiveSpeedDoesNotProduceInfiniteDurations() {
        var config = RefreshConfiguration.default
        config.speed = 0
        let steps = Waveform.steps(for: .full, configuration: config, reducesMotion: false)
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
