import SwiftUI
import AVFoundation
import AppKit

struct LibraryView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill").font(.title2).foregroundStyle(.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ambience").font(.title2.bold())
                        Text("A little world, on your desktop.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 16).padding(.top, 22)
                Button(action: model.importVideos) {
                    Label("Add Videos", systemImage: "plus").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(.mint).padding(.horizontal, 16)
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.state.clips) { clip in
                            Button { model.select(clip.id) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: clip.id == model.state.selectedID ? "play.circle.fill" : "film")
                                        .font(.title3).foregroundStyle(clip.id == model.state.selectedID ? Color.mint : Color.secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(clip.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
                                        Text("\(LoopTime.format(clip.end - clip.start)) loop").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }.padding(12).contentShape(Rectangle())
                                    .background(clip.id == model.state.selectedID ? Color.mint.opacity(0.12) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 10)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                    Toggle("Pause on battery", isOn: Binding(get: { model.state.pauseOnBattery }, set: model.setBatteryPause))
                    Toggle("Pause in Low Power Mode", isOn: Binding(get: { model.state.pauseOnLowPower }, set: model.setLowPowerPause))
                    Button("Show video folder", action: model.revealLibrary).buttonStyle(.link)
                }.font(.caption).toggleStyle(.checkbox).padding(16)
            }.frame(width: 265)
                .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            Group {
                if let clip = model.selected {
                    ClipEditor(model: model, clip: clip).id(clip.id)
                } else {
                    VStack(spacing: 18) {
                        Image(systemName: "play.rectangle.on.rectangle").font(.system(size: 52)).foregroundStyle(.mint)
                        Text("Your desktop, somewhere else.").font(.title.bold())
                        Text("Add a Terraria ambience video, or any MP4 you love.\nPick a section, turn up the ambience, and let it loop.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("Choose Your First Video", action: model.importVideos)
                            .buttonStyle(.borderedProminent).tint(.mint)
                        Link("Open your Terraria video ↗", destination: URL(string: "https://youtu.be/h5wBQzhqLYQ")!)
                            .font(.caption)
                        Text("Videos stay on your Mac. No account or subscription.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 890, minHeight: 680)
        .disabled(model.busy)
        .overlay(alignment: .bottom) {
            if model.busy {
                HStack { ProgressView().controlSize(.small); Text(model.status) }
                    .padding(14).background(.regularMaterial).cornerRadius(12).padding(20)
            }
        }
        .onAppear { model.refreshLogin() }
    }
}

struct FramingPreview: View {
    @ObservedObject var model: AppModel
    let clip: Clip
    let image: NSImage?
    @State private var dragOrigin: VideoFraming?
    @State private var guides = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                let framing = model.framing(for: clip)
                let rect = framing.viewport(in: geometry.size)
                ZStack {
                    Color.black
                    if let image = image {
                        Image(nsImage: image).resizable()
                            .aspectRatio(contentMode: framing.fill ? .fill : .fit)
                            .frame(width: rect.width, height: rect.height)
                            .clipped()
                            .position(x: rect.midX, y: rect.midY)
                    } else {
                        Text("Loading preview…").foregroundStyle(.secondary)
                    }
                    if guides {
                        Path { path in
                            for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
                                let x = geometry.size.width * fraction
                                let y = geometry.size.height * fraction
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                            }
                        }.stroke(Color.white.opacity(0.35), lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        guard geometry.size.width > 0, geometry.size.height > 0 else { return }
                        if dragOrigin == nil { dragOrigin = framing }
                        guard var moved = dragOrigin else { return }
                        moved.x += Double(value.translation.width / geometry.size.width)
                        moved.y += Double(value.translation.height / geometry.size.height)
                        model.setFraming(moved, for: clip.id, saveNow: false)
                    }
                    .onEnded { _ in dragOrigin = nil; model.saveFraming() })
            }
            .aspectRatio(model.desktopAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel("Drag to reposition video, or use the position sliders below")
            HStack {
                Text("Drag to reframe · still preview").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("Guides", isOn: $guides).toggleStyle(.checkbox).font(.caption)
            }
        }
    }
}

struct FramingControls: View {
    @ObservedObject var model: AppModel
    let clip: Clip
    private var framing: VideoFraming { model.framing(for: clip) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Frame your world").font(.headline)
                Spacer()
                Button("Fit") { model.setFraming(VideoFraming(), for: clip.id) }
                Button("Fill") { model.setFraming(VideoFraming(fill: true), for: clip.id) }
                Button("Center") {
                    var value = framing
                    value.x = 0
                    value.y = 0
                    model.setFraming(value, for: clip.id)
                }
            }.controlSize(.small)
            adjustment("Zoom", key: \.zoom, range: 0.5...3,
                       label: "\(Int((framing.zoom * 100).rounded()))%")
            adjustment("Left / Right", key: \.x, range: -0.5...0.5,
                       label: String(format: "%+.0f%%", framing.x * 100))
            adjustment("Up / Down", key: \.y, range: -0.5...0.5,
                       label: String(format: "%+.0f%%", framing.y * 100))
            Text("Changes appear on your desktop immediately and save for this video. Fit or Fill resets zoom and position; Center only resets position.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func adjustment(_ title: String, key: WritableKeyPath<VideoFraming, Double>,
                            range: ClosedRange<Double>, label: String) -> some View {
        HStack {
            Text(title).font(.caption).frame(width: 76, alignment: .leading)
            Slider(value: Binding(get: { framing[keyPath: key] }, set: { number in
                var value = framing
                value[keyPath: key] = number
                model.setFraming(value, for: clip.id, saveNow: false)
            }), in: range, onEditingChanged: { editing in if !editing { model.saveFraming() } })
                .tint(.mint).accessibilityLabel(title)
            Text(label).font(.caption).monospacedDigit().frame(width: 48, alignment: .trailing)
        }
    }
}

struct ClipEditor: View {
    @ObservedObject var model: AppModel
    let clip: Clip
    @State private var title = ""
    @State private var start = ""
    @State private var end = ""
    @State private var thumbnail: NSImage?
    private var hasChanges: Bool {
        title != clip.title || start != LoopTime.format(clip.start) || end != LoopTime.format(clip.end)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("NOW IN YOUR WORLD").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.secondary)
                        Text(clip.title).font(.title2.bold()).lineLimit(2)
                    }
                    Spacer()
                    Button(action: model.next) { Image(systemName: "forward.end.fill") }.help("Next video")
                    Button(action: model.togglePause) {
                        Label(model.state.paused ? "Resume" : "Pause", systemImage: model.state.paused ? "play.fill" : "pause.fill")
                    }.buttonStyle(.borderedProminent).tint(.mint)
                }
                FramingPreview(model: model, clip: clip, image: thumbnail)
                HStack(spacing: 8) {
                    Circle().fill(model.status.hasPrefix("Playing") ? Color.mint : Color.orange).frame(width: 6, height: 6)
                    Text(model.status).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("Original: \(LoopTime.format(clip.duration))").font(.caption).foregroundStyle(.secondary)
                }
                FramingControls(model: model, clip: clip)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Make it your loop").font(.headline)
                    TextField("Video name", text: $title).textFieldStyle(.roundedBorder)
                    HStack(alignment: .bottom, spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Start · m:ss").font(.caption).foregroundStyle(.secondary)
                            TextField("0:00", text: $start).textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text("End · m:ss").font(.caption).foregroundStyle(.secondary)
                            TextField("2:00", text: $end).textFieldStyle(.roundedBorder)
                        }
                        Button("Save & Apply") {
                            if model.updateClip(id: clip.id, title: title, start: start, end: end) { syncFields() }
                        }.buttonStyle(.borderedProminent).tint(.mint)
                    }
                    HStack {
                        Button("30 seconds") { preset(30) }
                        Button("2 minutes") { preset(120) }
                        Button("Whole video") { start = "0:00"; end = LoopTime.format(clip.duration) }
                    }.controlSize(.small)
                    Text("Loops keep the original audio. Choose matching endpoints for a smoother repeat.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(16).background(Color.primary.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 12))
                HStack {
                    Button { model.setMuted(!model.state.muted) } label: {
                        Image(systemName: model.state.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    }.help(model.state.muted ? "Unmute ambience" : "Mute ambience")
                    Slider(value: Binding(get: { model.state.volume }, set: model.setVolume), in: 0...1,
                           onEditingChanged: { editing in if !editing { model.saveVolume() } })
                        .tint(.mint).accessibilityLabel("Ambience volume")
                    Text("\(Int(model.state.volume * 100))%").monospacedDigit().font(.caption).frame(width: 38)
                }
                HStack {
                    Button("Export Saved Loop…", action: model.exportSelected).disabled(hasChanges)
                    Spacer()
                    Button("Remove Video…", role: .destructive, action: model.removeSelected)
                }.controlSize(.small)
                Text("Export trims the time range; desktop framing is not baked into the exported video.")
                    .font(.caption).foregroundStyle(.secondary)
                if let credit = clip.attribution {
                    Text(credit).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Text("Wallpaper plays behind your icons on the main display. Closing this window keeps it running; quit from the leaf in your menu bar.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(26)
        }
        .onAppear { syncFields() }
        .task(id: "\(clip.id)-\(clip.start)") {
            let url = model.url(for: clip)
            let time = clip.start
            let image = await Task.detached(priority: .utility) { () -> CGImage? in
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 1100, height: 620)
                return try? generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
            }.value
            if !Task.isCancelled { thumbnail = image.map { NSImage(cgImage: $0, size: .zero) } }
        }
    }

    private func syncFields() {
        let current = model.state.clips.first { $0.id == clip.id } ?? clip
        title = current.title
        start = LoopTime.format(current.start)
        end = LoopTime.format(current.end)
    }
    private func preset(_ length: Double) {
        let from = min(max(0, LoopTime.parse(start) ?? 0), max(0, clip.duration - 0.5))
        start = LoopTime.format(from)
        end = LoopTime.format(min(clip.duration, from + length))
    }
}
