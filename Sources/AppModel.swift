import AppKit
import AVFoundation
import Combine
import IOKit.ps
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state = LibraryState()
    @Published private(set) var busy = false
    @Published private(set) var status = "Add a video to begin"
    @Published private(set) var loginEnabled = false
    @Published private(set) var desktopAspectRatio: CGFloat = 1.6
    @Published var message: String?
    let engine = WallpaperEngine()
    let root: URL
    private let stateURL: URL
    private var observers: [NSObjectProtocol] = []
    private var powerTimer: Timer?
    private var sleeping = false
    private var displaySleeping = false
    private var sessionInactive = false
    private var storageAvailable = true
    private var failedPlayback = false
    var selected: Clip? { state.clips.first { $0.id == state.selectedID } }

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        root = support.appendingPathComponent("Ambience", isDirectory: true)
        stateURL = root.appendingPathComponent("library.json")
        do {
            try FileManager.default.createDirectory(at: root.appendingPathComponent("Videos"), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: stateURL.path) {
                state = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: stateURL))
                guard state.clips.allSatisfy({
                    $0.filename == URL(fileURLWithPath: $0.filename).lastPathComponent &&
                    LoopTime.valid(start: $0.start, end: $0.end, duration: $0.duration)
                }) else { throw CocoaError(.fileReadCorruptFile) }
                state.volume = min(1, max(0, state.volume))
            }
        } catch {
            storageAvailable = false
            state = LibraryState()
            status = "Collection could not be opened"
            message = "Could not open the video collection. Your saved files have been left intact.\n\(error.localizedDescription)\n\(root.path)"
        }
        engine.onFailure = { [weak self] error in
            self?.failedPlayback = true
            self?.engine.stop()
            self?.status = "Playback failed"
            self?.message = error
        }
        refreshLogin()
        refreshDisplaySize()
        watchWorkspace(NSWorkspace.willSleepNotification) { $0.sleeping = true; $0.updatePlayback() }
        watchWorkspace(NSWorkspace.didWakeNotification) { $0.sleeping = false; $0.updatePlayback() }
        watchWorkspace(NSWorkspace.screensDidSleepNotification) { $0.displaySleeping = true; $0.updatePlayback() }
        watchWorkspace(NSWorkspace.screensDidWakeNotification) { $0.displaySleeping = false; $0.updatePlayback() }
        watchWorkspace(NSWorkspace.sessionDidResignActiveNotification) { $0.sessionInactive = true; $0.updatePlayback() }
        watchWorkspace(NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionInactive = false; $0.updatePlayback() }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDisplaySize()
                if self?.selected != nil { self?.engine.placeWindow() }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updatePlayback() }
        })
        // A slow, coalescible check only monitors power policy; video looping uses AVPlayerLooper.
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.state.pauseOnBattery else { return }
                self.updatePlayback()
            }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        powerTimer = timer
    }

    func start() { if storageAvailable, selected != nil { loadSelected() } }

    private func watchWorkspace(_ name: Notification.Name, action: @escaping (AppModel) -> Void) {
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in if let self = self { action(self) } }
        })
    }

    func url(for clip: Clip) -> URL { root.appendingPathComponent("Videos").appendingPathComponent(clip.filename) }

    @discardableResult
    private func save() -> Bool {
        guard storageAvailable else { return false }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: stateURL, options: .atomic)
            return true
        } catch {
            message = "Your latest changes could not be saved: \(error.localizedDescription)"
            return false
        }
    }

    func importVideos() {
        guard !busy, storageAvailable else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = "Add Videos"
        guard panel.runModal() == .OK else { return }
        addVideoURLs(panel.urls)
    }

    func addDownloadedVideo(_ url: URL, title: String, credit: String) -> Bool {
        guard !busy, storageAvailable else { return false }
        addVideoURLs([url], downloadedTitle: title, credit: credit)
        return true
    }

    private func addVideoURLs(_ urls: [URL], downloadedTitle: String? = nil, credit: String? = nil) {
        busy = true
        engine.setPlaying(false)
        status = "Adding videos…"
        Task { @MainActor in
            var failures: [String] = []
            for source in urls {
                do {
                    let asset = AVURLAsset(url: source)
                    let duration = try await asset.load(.duration).seconds
                    let playable = try await asset.load(.isPlayable)
                    let tracks = try await asset.loadTracks(withMediaType: .video)
                    guard playable, !tracks.isEmpty, duration.isFinite, duration >= 0.5 else {
                        throw NSError(domain: "Ambience", code: 1, userInfo: [NSLocalizedDescriptionKey: "Use a playable video at least half a second long."])
                    }
                    let id = UUID()
                    let filename = id.uuidString + "." + source.pathExtension.lowercased()
                    let destination = root.appendingPathComponent("Videos").appendingPathComponent(filename)
                    try await Task.detached(priority: .utility) {
                        try FileManager.default.copyItem(at: source, to: destination)
                    }.value
                    let clip = Clip(id: id, title: downloadedTitle ?? source.deletingPathExtension().lastPathComponent,
                                    filename: filename, duration: duration, start: 0, end: min(120, duration), attribution: credit)
                    state.clips.append(clip)
                    if state.selectedID == nil || downloadedTitle != nil { state.selectedID = id }
                    save()
                } catch { failures.append("\(source.lastPathComponent): \(error.localizedDescription)") }
                if downloadedTitle != nil { try? FileManager.default.removeItem(at: source) }
            }
            busy = false
            if selected != nil { loadSelected() } else { status = "Add a video to begin" }
            if !failures.isEmpty { message = failures.joined(separator: "\n\n") }
        }
    }

    func select(_ id: UUID) {
        guard !busy, state.clips.contains(where: { $0.id == id }) else { return }
        state.selectedID = id
        save()
        loadSelected()
    }

    func next() {
        guard !busy, !state.clips.isEmpty else { return }
        let index = state.clips.firstIndex(where: { $0.id == state.selectedID }) ?? -1
        select(state.clips[(index + 1) % state.clips.count].id)
    }

    private func loadSelected() {
        guard let clip = selected else { engine.stop(); status = "Add a video to begin"; return }
        guard FileManager.default.fileExists(atPath: url(for: clip).path) else {
            failedPlayback = true
            engine.stop()
            status = "Video file missing"
            message = "The imported copy of \(clip.title) is missing. Remove its entry and add the video again."
            return
        }
        failedPlayback = false
        engine.setFraming(framing(for: clip))
        engine.load(url: url(for: clip), start: clip.start, end: clip.end)
        updatePlayback()
    }

    func setVolume(_ volume: Double) {
        state.volume = min(1, max(0, volume))
        engine.player.volume = Float(state.volume)
    }
    func saveVolume() { save() }
    func framing(for clip: Clip) -> VideoFraming {
        (clip.framing ?? VideoFraming(fill: state.fillScreen ?? false)).normalized
    }
    func setFraming(_ value: VideoFraming, for id: UUID, saveNow: Bool = true) {
        guard let index = state.clips.firstIndex(where: { $0.id == id }) else { return }
        let framing = value.normalized
        state.clips[index].framing = framing
        if state.selectedID == id { engine.setFraming(framing) }
        if saveNow { save() }
    }
    func saveFraming() { save() }
    private func refreshDisplaySize() {
        if let size = NSScreen.screens.first?.frame.size, size.height > 0 {
            desktopAspectRatio = size.width / size.height
        }
    }
    func setMuted(_ muted: Bool) { state.muted = muted; save(); updatePlayback() }
    func togglePause() {
        state.paused.toggle()
        save()
        if failedPlayback, !state.paused { loadSelected() } else { updatePlayback() }
    }
    func setBatteryPause(_ enabled: Bool) { state.pauseOnBattery = enabled; save(); updatePlayback() }
    func setLowPowerPause(_ enabled: Bool) { state.pauseOnLowPower = enabled; save(); updatePlayback() }

    private func onBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (type as String) == kIOPSBatteryPowerValue
    }

    func updatePlayback() {
        guard selected != nil, !failedPlayback, !busy else { return }
        let reason: String?
        if state.paused { reason = "Paused" }
        else if sleeping || displaySleeping || sessionInactive { reason = "Paused while your Mac is inactive" }
        else if state.pauseOnLowPower && ProcessInfo.processInfo.isLowPowerModeEnabled { reason = "Paused for Low Power Mode" }
        else if state.pauseOnBattery && onBattery() { reason = "Paused on battery" }
        else { reason = nil }
        engine.player.volume = Float(state.volume)
        engine.player.isMuted = state.muted
        engine.setPlaying(reason == nil)
        status = reason ?? "Playing on your main desktop"
    }

    func updateClip(id: UUID, title: String, start: String, end: String) -> Bool {
        guard let index = state.clips.firstIndex(where: { $0.id == id }),
              let startValue = LoopTime.parse(start), let endValue = LoopTime.parse(end),
              LoopTime.valid(start: startValue, end: endValue, duration: state.clips[index].duration) else {
            message = "Enter seconds or m:ss. The end must be after the start by at least 0.5 seconds and within the video."
            return false
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanTitle.isEmpty { state.clips[index].title = cleanTitle }
        state.clips[index].start = startValue
        state.clips[index].end = min(endValue, state.clips[index].duration)
        let saved = save()
        if id == state.selectedID { loadSelected() }
        return saved
    }

    func removeSelected() {
        guard !busy, let clip = selected else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \(clip.title)?"
        alert.informativeText = "This removes the copy in Ambience. Your original video is kept."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        engine.stop()
        state.clips.removeAll { $0.id == clip.id }
        state.selectedID = state.clips.first?.id
        if save() { try? FileManager.default.removeItem(at: url(for: clip)) }
        loadSelected()
    }

    func exportSelected() {
        guard !busy, let clip = selected else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = clip.title.replacingOccurrences(of: "/", with: "-") + "-loop.mp4"
        guard panel.runModal() == .OK, let output = panel.url else { return }
        guard output.standardizedFileURL != url(for: clip).standardizedFileURL else {
            message = "Choose a location outside the imported video file."
            return
        }
        busy = true
        engine.setPlaying(false)
        status = "Exporting loop…"
        Task { @MainActor in
            let temporary = output.deletingLastPathComponent().appendingPathComponent(".ambience-\(UUID().uuidString).mp4")
            defer {
                try? FileManager.default.removeItem(at: temporary)
                busy = false
                updatePlayback()
            }
            let asset = AVURLAsset(url: url(for: clip))
            guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) else {
                message = "This video cannot be exported. Its saved loop can still play."
                return
            }
            exporter.outputURL = temporary
            exporter.outputFileType = .mp4
            exporter.timeRange = CMTimeRange(start: CMTime(seconds: clip.start, preferredTimescale: 600),
                                            duration: CMTime(seconds: clip.end - clip.start, preferredTimescale: 600))
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                exporter.exportAsynchronously { continuation.resume() }
            }
            guard exporter.status == .completed else {
                message = exporter.error?.localizedDescription ?? "The export did not finish."
                return
            }
            do {
                if FileManager.default.fileExists(atPath: output.path) {
                    _ = try FileManager.default.replaceItemAt(output, withItemAt: temporary)
                } else { try FileManager.default.moveItem(at: temporary, to: output) }
                NSWorkspace.shared.activateFileViewerSelecting([output])
            } catch { message = "Could not save the exported loop: \(error.localizedDescription)" }
        }
    }

    func refreshLogin() { loginEnabled = SMAppService.mainApp.status == .enabled }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLogin()
            if SMAppService.mainApp.status == .requiresApproval {
                message = "macOS needs your approval. Enable Ambience under System Settings → General → Login Items."
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            refreshLogin()
            message = "Could not change launch at login: \(error.localizedDescription)\nYou can also add Ambience in System Settings → General → Login Items."
        }
    }

    func revealLibrary() { NSWorkspace.shared.open(root) }
    func shutdown() { save(); engine.stop(); powerTimer?.invalidate() }
}
