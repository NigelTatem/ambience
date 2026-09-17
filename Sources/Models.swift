import Foundation
import CoreGraphics

enum InterfaceTheme: String, Codable, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AccentTheme: String, Codable, CaseIterable, Identifiable {
    case moss, twilight, ember
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct Clip: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var filename: String
    var duration: Double
    var start: Double
    var end: Double
    var framing: VideoFraming? = nil
    var attribution: String? = nil
}

struct VideoFraming: Codable, Equatable {
    var fill = false
    var zoom: Double = 1
    // Fractions of the screen: positive x moves right; positive y moves down.
    var x: Double = 0
    var y: Double = 0

    var normalized: VideoFraming {
        VideoFraming(fill: fill,
                     zoom: zoom.isFinite ? min(3, max(0.5, zoom)) : 1,
                     x: x.isFinite ? min(0.5, max(-0.5, x)) : 0,
                     y: y.isFinite ? min(0.5, max(-0.5, y)) : 0)
    }

    // Coordinates here start at the top left, matching the framing preview.
    func viewport(in size: CGSize) -> CGRect {
        let value = normalized
        let width = size.width * CGFloat(value.zoom)
        let height = size.height * CGFloat(value.zoom)
        return CGRect(x: (size.width - width) / 2 + size.width * CGFloat(value.x),
                      y: (size.height - height) / 2 + size.height * CGFloat(value.y),
                      width: width, height: height)
    }

    func layerFrame(in size: CGSize) -> CGRect {
        let rect = viewport(in: size)
        return CGRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height)
    }
}

struct LibraryState: Codable {
    var clips: [Clip] = []
    var selectedID: UUID? = nil
    var volume: Double = 0.15
    var muted = false
    var paused = false
    var pauseOnBattery = false
    var pauseOnLowPower = true
    // Optional so collections saved before 1.0.1 still decode without a migration.
    var fillScreen: Bool? = nil
    // Optional so collections made before themes continue to open unchanged.
    var interfaceTheme: InterfaceTheme? = nil
    var accentTheme: AccentTheme? = nil
}

enum LoopTime {
    static func parse(_ text: String) -> Double? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        let numbers = parts.compactMap { Double($0) }
        guard numbers.count == parts.count, numbers.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        if numbers.count > 1 && numbers.dropFirst().contains(where: { $0 >= 60 }) { return nil }
        return numbers.reduce(0) { $0 * 60 + $1 }
    }

    static func format(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int((seconds * 100).rounded())
        let whole = total / 100
        let fraction = total % 100
        let base = String(format: "%d:%02d", whole / 60, whole % 60)
        return fraction == 0 ? base : base + String(format: ".%02d", fraction)
    }

    static func valid(start: Double, end: Double, duration: Double) -> Bool {
        start.isFinite && end.isFinite && duration.isFinite && start >= 0 &&
        end <= duration + 0.02 && end - start >= 0.5
    }
}
