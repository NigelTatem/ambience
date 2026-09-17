import Foundation
import CoreGraphics

@main
struct LoopTimeTests {
    static func main() {
        func check(_ value: @autoclosure () -> Bool, _ label: String) {
            guard value() else { fatalError("Loop-time check failed: \(label)") }
        }
        check(LoopTime.parse("90") == 90, "seconds")
        check(LoopTime.parse("1:30") == 90, "minutes")
        check(LoopTime.parse("1:02:03.5") == 3723.5, "hours and fractions")
        check(LoopTime.parse(" 2:00 ") == 120, "whitespace")
        for bad in ["", "1:", ":30", "1:60", "-3", "NaN", "inf", "1:2:3:4"] {
            check(LoopTime.parse(bad) == nil, "invalid input \(bad)")
        }
        check(!LoopTime.valid(start: 10, end: 2, duration: 60), "reversed range")
        check(!LoopTime.valid(start: 0, end: 61, duration: 60), "end beyond duration")
        check(!LoopTime.valid(start: 0, end: 0.1, duration: 60), "too-short range")
        check(LoopTime.valid(start: 0, end: 60, duration: 60), "whole video")
        check(LoopTime.valid(start: 10, end: 12, duration: 60), "section")
        check(LoopTime.format(59.999) == "1:00", "rounding carry")
        check(LoopTime.format(0.5) == "0:00.50", "fractional duration")
        let original = LibraryState(clips: [Clip(id: UUID(), title: "Rain", filename: "rain.mp4", duration: 3600, start: 60, end: 180)])
        let data = try! JSONEncoder().encode(original)
        let restored = try! JSONDecoder().decode(LibraryState.self, from: data)
        check(restored.clips == original.clips, "collection round trip")
        // Version 1.0 saved no fillScreen key. Upgrading must retain clips and power settings.
        var legacy = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        legacy.removeValue(forKey: "fillScreen")
        legacy["pauseOnLowPower"] = false
        let oldData = try! JSONSerialization.data(withJSONObject: legacy)
        var upgraded = try! JSONDecoder().decode(LibraryState.self, from: oldData)
        check(upgraded.clips == original.clips, "upgrade preserves videos")
        check(!upgraded.pauseOnLowPower, "upgrade preserves low power choice")
        check(!(upgraded.fillScreen ?? false), "old collections default to fit")
        upgraded.fillScreen = true
        let updated = try! JSONDecoder().decode(LibraryState.self, from: JSONEncoder().encode(upgraded))
        check(updated.fillScreen == true, "framing setting persists")
        check(upgraded.clips[0].framing == nil, "old clips retain legacy framing fallback")
        let custom = VideoFraming(fill: true, zoom: 1.5, x: 0.1, y: 0.2)
        upgraded.clips[0].framing = custom
        upgraded.clips.append(Clip(id: UUID(), title: "Forest", filename: "forest.mp4", duration: 120, start: 0, end: 120))
        let framed = try! JSONDecoder().decode(LibraryState.self, from: JSONEncoder().encode(upgraded))
        check(framed.clips[0].framing == custom, "per-video framing persists")
        check(framed.clips[1].framing == nil, "editing one video's framing does not affect another")
        let screen = CGSize(width: 1000, height: 625)
        check(VideoFraming().viewport(in: screen) == CGRect(origin: .zero, size: screen), "fit viewport")
        let preview = custom.viewport(in: screen)
        let layer = custom.layerFrame(in: screen)
        check(preview.width == 1500 && preview.height == 937.5, "uniform zoom")
        check(preview.minX == -150 && preview.minY == -31.25, "drag translates by screen fraction")
        check(layer.minX == preview.minX && layer.maxY == screen.height - preview.minY, "AppKit vertical direction matches preview")
        let small = custom.viewport(in: CGSize(width: 400, height: 250))
        check(abs(small.minX / 400 - preview.minX / 1000) < 0.000001, "preview scales with screen")
        check(VideoFraming(zoom: 100, x: -5, y: 5).normalized == VideoFraming(zoom: 3, x: -0.5, y: 0.5), "controls stay in supported range")
        print("Loop-time and collection checks passed.")
    }
}
