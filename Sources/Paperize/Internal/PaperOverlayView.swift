import UIKit

/// Core Animation compositing-filter names. They're kept in one place because the blend
/// strings aren't formally documented for iOS (see docs/adr/0001-rendering-approach.md).
enum BlendMode {
    static let saturation = "saturationBlendMode"
    static let lighten = "lightenBlendMode"
    static let multiply = "multiplyBlendMode"
    static let difference = "differenceBlendMode"
}

/// The full-window stack of blend layers that turns whatever is drawn below it into "paper".
///
/// It ignores touches and accessibility, and it sits above every sibling view through a large
/// `zPosition`, so views added to the window later (modal containers, for example) stay below it.
final class PaperOverlayView: UIView {

    /// Larger than anything a sane app would use, so the overlay always renders on top.
    static let zPosition: CGFloat = 1_000_000

    // Bottom to top. Order matters: each layer blends with everything rendered below it.
    let grayscaleView = UIView()
    let inkView = UIView()
    let paperView = UIView()
    let dimView = UIView()
    let grainView = UIView()
    /// Holds a snapshot of the previous screen. The snapshot already went through the paper
    /// stack when it was captured, so it sits *above* the stack to avoid being processed twice.
    let ghostContainer = UIView()
    let flashView = UIView()

    private(set) var configuration: PaperizeConfiguration
    private var playback: Task<Void, Never>?

    /// `true` while a refresh waveform is on screen. Snapshots taken now would capture the flash.
    private(set) var isPlaying = false

    /// The window's own `overrideUserInterfaceStyle` before Paperize forced light mode.
    var savedInterfaceStyle: UIUserInterfaceStyle?

    init(configuration: PaperizeConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        isOpaque = false
        layer.zPosition = Self.zPosition
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        for view in [grayscaleView, inkView, paperView, dimView, grainView, ghostContainer, flashView] {
            view.frame = bounds
            view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.isUserInteractionEnabled = false
            addSubview(view)
        }

        ghostContainer.alpha = 0
        ghostContainer.clipsToBounds = true

        grayscaleView.backgroundColor = .black
        grayscaleView.layer.compositingFilter = BlendMode.saturation

        inkView.layer.compositingFilter = BlendMode.lighten
        paperView.layer.compositingFilter = BlendMode.multiply

        dimView.backgroundColor = .black

        grainView.backgroundColor = UIColor(patternImage: GrainTexture.image)
        grainView.layer.compositingFilter = BlendMode.multiply

        flashView.isHidden = true

        apply(configuration)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }

    // MARK: Configuration

    func apply(_ configuration: PaperizeConfiguration) {
        self.configuration = configuration

        grayscaleView.isHidden = !configuration.isGrayscale

        inkView.backgroundColor = configuration.inkColor

        paperView.backgroundColor = configuration.paperColor

        let dimming = configuration.dimming.clamped01
        dimView.alpha = dimming
        dimView.isHidden = dimming == 0

        let grain = configuration.grain.clamped01
        grainView.alpha = grain
        grainView.isHidden = grain == 0
    }

    // MARK: Refresh playback

    /// Plays a refresh waveform. Starting a new one cancels the one in progress.
    /// - Parameter ghost: a snapshot of the previous screen to fade out, if there is one.
    func play(_ steps: [WaveformStep], ghost: UIView?) {
        playback?.cancel()
        setGhost(ghost)
        isPlaying = true

        playback = Task { @MainActor [weak self] in
            for step in steps {
                guard let self, !Task.isCancelled else { return }
                self.render(step)
                if step.duration > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(step.duration * 1_000_000_000))
                }
            }
            guard let self, !Task.isCancelled else { return }
            self.render(.idle)
            self.setGhost(nil)
            self.isPlaying = false
        }
    }

    /// Stops any playback and returns to the resting state.
    func stopPlayback() {
        playback?.cancel()
        playback = nil
        isPlaying = false
        render(.idle)
        setGhost(nil)
    }

    func render(_ step: WaveformStep) {
        ghostContainer.alpha = step.ghostAlpha.clamped01

        switch step.flash {
        case .clear:
            flashView.isHidden = true
        case .invert:
            show(flash: .white, alpha: 1, filter: BlendMode.difference)
        case .black:
            show(flash: .black, alpha: 1, filter: nil)
        case .paper:
            show(flash: configuration.paperColor, alpha: 1, filter: nil)
        case .dim(let alpha):
            show(flash: .black, alpha: alpha.clamped01, filter: nil)
        }
    }

    private func show(flash color: UIColor, alpha: CGFloat, filter: String?) {
        flashView.backgroundColor = color
        flashView.alpha = alpha
        flashView.layer.compositingFilter = filter
        flashView.isHidden = false
    }

    private func setGhost(_ ghost: UIView?) {
        ghostContainer.subviews.forEach { $0.removeFromSuperview() }
        guard let ghost else {
            ghostContainer.alpha = 0
            return
        }
        ghost.frame = ghostContainer.bounds
        ghost.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        ghost.isUserInteractionEnabled = false
        ghostContainer.addSubview(ghost)
    }
}
