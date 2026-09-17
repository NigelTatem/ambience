import AppKit
import AVFoundation
import QuartzCore

final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class VideoSurface: NSView {
    let videoLayer = AVPlayerLayer()
    var framing = VideoFraming() {
        didSet { updateVideoFrame() }
    }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        videoLayer.videoGravity = .resizeAspect
        videoLayer.masksToBounds = true
        layer?.addSublayer(videoLayer)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override func layout() {
        super.layout()
        updateVideoFrame()
    }
    private func updateVideoFrame() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.videoGravity = framing.fill ? .resizeAspectFill : .resizeAspect
        videoLayer.frame = framing.layerFrame(in: bounds.size)
        CATransaction.commit()
    }
}

@MainActor
final class WallpaperEngine {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var window: DesktopWindow?
    private var observation: NSKeyValueObservation?
    private var generation = UUID()
    private var framing = VideoFraming()
    var onFailure: ((String) -> Void)?

    init() {
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.automaticallyWaitsToMinimizeStalling = true
    }

    func load(url: URL, start: Double, end: Double) {
        stop()
        let item = AVPlayerItem(url: url)
        let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                duration: CMTime(seconds: end - start, preferredTimescale: 600))
        looper = AVPlayerLooper(player: player, templateItem: item, timeRange: range)
        let token = generation
        observation = looper?.observe(\.status, options: [.new]) { [weak self] loop, _ in
            if loop.status == .failed {
                let message = loop.error?.localizedDescription ?? "This video could not be looped. Try an H.264 MP4."
                Task { @MainActor [weak self] in
                    guard let self = self, self.generation == token else { return }
                    self.onFailure?(message)
                }
            }
        }
        placeWindow()
    }

    func placeWindow() {
        // The first screen contains the menu bar; do not follow the focused app to another display.
        guard looper != nil, let screen = NSScreen.screens.first else { return }
        if window == nil {
            let desktop = DesktopWindow(contentRect: screen.frame, styleMask: .borderless,
                                        backing: .buffered, defer: false)
            desktop.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            desktop.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            desktop.ignoresMouseEvents = true
            desktop.isReleasedWhenClosed = false
            desktop.hasShadow = false
            desktop.backgroundColor = .black
            desktop.isOpaque = true
            let surface = VideoSurface(frame: NSRect(origin: .zero, size: screen.frame.size))
            surface.framing = framing
            surface.videoLayer.player = player
            desktop.contentView = surface
            window = desktop
        }
        window?.setFrame(screen.frame, display: true)
        window?.orderFrontRegardless()
    }

    func setPlaying(_ playing: Bool) {
        if playing { player.play() } else { player.pause() }
    }

    func setFraming(_ value: VideoFraming) {
        framing = value.normalized
        guard let surface = window?.contentView as? VideoSurface else { return }
        surface.framing = framing
    }

    func stop() {
        generation = UUID()
        player.pause()
        observation = nil
        looper?.disableLooping()
        looper = nil
        player.removeAllItems()
        window?.close()
        window = nil
    }
}
