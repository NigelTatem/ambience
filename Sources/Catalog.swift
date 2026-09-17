import SwiftUI
import Foundation
import CryptoKit

struct CatalogManifest: Decodable {
    let schemaVersion: Int
    let wallpapers: [CatalogWallpaper]
}
struct CatalogWallpaper: Decodable, Identifiable {
    let id: String
    let title: String
    let creator: String
    let license: String
    let sourceURL: URL
    let thumbnailURL: URL
    let variants: [CatalogVariant]
}
struct CatalogVariant: Decodable, Identifiable {
    let id: String
    let label: String
    let width: Int
    let height: Int
    let bytes: Int64
    let sha256: String
    let url: URL
}

@MainActor
final class WallpaperCatalog: ObservableObject {
    @Published private(set) var wallpapers: [CatalogWallpaper] = []
    @Published private(set) var loading = false
    @Published private(set) var downloading: String?
    @Published var notice: String?
    private var downloadTask: Task<Void, Never>?

    init() {
        if let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
           let data = try? Data(contentsOf: url), let manifest = try? Self.decode(data) {
            wallpapers = manifest.wallpapers
        }
    }
    private static func decode(_ data: Data) throws -> CatalogManifest {
        guard data.count <= 2_000_000 else { throw CatalogError.invalidCatalog }
        let manifest = try JSONDecoder().decode(CatalogManifest.self, from: data)
        guard manifest.schemaVersion == 1, manifest.wallpapers.count <= 500,
              Set(manifest.wallpapers.map(\.id)).count == manifest.wallpapers.count else { throw CatalogError.invalidCatalog }
        for wallpaper in manifest.wallpapers {
            guard wallpaper.sourceURL.scheme == "https", wallpaper.thumbnailURL.scheme == "https",
                  !wallpaper.creator.isEmpty, !wallpaper.license.isEmpty, !wallpaper.variants.isEmpty,
                  Set(wallpaper.variants.map(\.id)).count == wallpaper.variants.count else { throw CatalogError.invalidCatalog }
            for variant in wallpaper.variants {
                guard variant.url.scheme == "https", variant.bytes > 0, variant.bytes < 2_147_483_648,
                      variant.width > 0, variant.height > 0,
                      variant.sha256.count == 64,
                      variant.sha256.allSatisfy({ $0.isHexDigit }) else { throw CatalogError.invalidCatalog }
            }
        }
        return manifest
    }
    func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        guard let address = Bundle.main.object(forInfoDictionaryKey: "AmbienceCatalogURL") as? String,
              let url = URL(string: address), url.scheme == "https" else { return }
        do {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CatalogError.unavailable }
            wallpapers = try Self.decode(data).wallpapers
            notice = nil
        } catch { notice = "The online collection isn't available yet. Your own wallpapers still work offline." }
    }
    func download(_ wallpaper: CatalogWallpaper, variant: CatalogVariant, model: AppModel) {
        guard downloading == nil else { return }
        downloading = wallpaper.id
        notice = nil
        downloadTask = Task { @MainActor in
            var staged: URL?
            defer {
                if let staged = staged { try? FileManager.default.removeItem(at: staged) }
                downloading = nil
                downloadTask = nil
            }
            do {
                let request = URLRequest(url: variant.url, timeoutInterval: 300)
                let (temporary, response) = try await URLSession.shared.download(for: request)
                staged = temporary
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                      response.url?.scheme == "https" else { throw CatalogError.downloadFailed }
                try Task.checkCancellation()
                try await Task.detached(priority: .utility) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: temporary.path)
                    guard (attributes[.size] as? NSNumber)?.int64Value == variant.bytes else { throw CatalogError.integrity }
                    let handle = try FileHandle(forReadingFrom: temporary)
                    defer { try? handle.close() }
                    var hash = SHA256()
                    while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty { hash.update(data: chunk) }
                    let actual = hash.finalize().map { String(format: "%02x", $0) }.joined()
                    guard actual == variant.sha256.lowercased() else { throw CatalogError.integrity }
                }.value
                try Task.checkCancellation()
                let movie = FileManager.default.temporaryDirectory.appendingPathComponent("Ambience-\(UUID().uuidString).mp4")
                try FileManager.default.moveItem(at: temporary, to: movie)
                staged = movie
                let credit = "\(wallpaper.creator) · \(wallpaper.license) · \(wallpaper.sourceURL.absoluteString)"
                guard model.addDownloadedVideo(movie, title: wallpaper.title, credit: credit) else { throw CatalogError.busy }
                staged = nil // Import takes ownership and deletes the staging copy after it finishes.
                notice = "Download verified. Adding it to My Wallpapers…"
            } catch {
                notice = Task.isCancelled ? "Download cancelled." : error.localizedDescription
            }
        }
    }
    func cancel() { downloadTask?.cancel() }
}

enum CatalogError: LocalizedError {
    case invalidCatalog, unavailable, downloadFailed, integrity, busy
    var errorDescription: String? {
        switch self {
        case .invalidCatalog: return "The wallpaper catalog has an unsupported format."
        case .unavailable: return "The wallpaper catalog is not published yet."
        case .downloadFailed: return "The wallpaper could not be downloaded. Please try again."
        case .integrity: return "The download did not match the published file. It was discarded; try downloading again."
        case .busy: return "Another import or export is running. Finish it, then try this download again."
        }
    }
}

struct DiscoverView: View {
    @ObservedObject var catalog: WallpaperCatalog
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Find your next world").font(.largeTitle.bold())
                        Text("Download once. Make it yours. Play offline.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh") { Task { await catalog.refresh() } }.disabled(catalog.loading)
                }
                if catalog.loading { ProgressView().controlSize(.small) }
                if let notice = catalog.notice { Text(notice).font(.callout).foregroundStyle(.secondary) }
                if catalog.wallpapers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles.rectangle.stack").font(.system(size: 44)).foregroundStyle(.mint)
                        Text("The collection is getting started").font(.title2.bold())
                        Text("No wallpapers have been published yet. You can add your own videos in My Wallpapers.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("Add Your Own Videos", action: model.importVideos).disabled(model.busy)
                    }.frame(maxWidth: .infinity).padding(.vertical, 75)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 20)], spacing: 20) {
                    ForEach(catalog.wallpapers) { wallpaper in
                        CatalogCard(wallpaper: wallpaper, catalog: catalog, model: model)
                    }
                }
            }.padding(32)
        }.task { await catalog.refresh() }
    }
}

struct CatalogCard: View {
    let wallpaper: CatalogWallpaper
    @ObservedObject var catalog: WallpaperCatalog
    @ObservedObject var model: AppModel
    @State private var selectedVariant = ""
    private var variant: CatalogVariant? { wallpaper.variants.first { $0.id == selectedVariant } ?? wallpaper.variants.first }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: wallpaper.thumbnailURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: { Color.gray.opacity(0.15) }
                .frame(height: 160).clipped().cornerRadius(10)
            Text(wallpaper.title).font(.headline)
            Link("\(wallpaper.creator) · \(wallpaper.license)", destination: wallpaper.sourceURL)
                .font(.caption)
            Picker("Quality", selection: $selectedVariant) {
                ForEach(wallpaper.variants) { item in
                    Text("\(item.label) · \(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file))").tag(item.id)
                }
            }.pickerStyle(.menu)
            if let variant = variant { Text("\(variant.width) × \(variant.height)").font(.caption).foregroundStyle(.secondary) }
            if catalog.downloading == wallpaper.id {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Downloading…").font(.caption)
                    Spacer()
                    Button("Cancel", action: catalog.cancel)
                }
            } else {
                Button("Download & Apply") {
                    if let variant = variant { catalog.download(wallpaper, variant: variant, model: model) }
                }.buttonStyle(.borderedProminent).tint(.mint)
                    .disabled(catalog.downloading != nil || model.busy)
            }
        }.padding(16).background(Color.primary.opacity(0.035)).cornerRadius(14)
            .onAppear { if selectedVariant.isEmpty { selectedVariant = wallpaper.variants.first?.id ?? "" } }
    }
}
