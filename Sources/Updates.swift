import AppKit
import Combine
import Sparkle

@MainActor
final class AppUpdates: ObservableObject {
    @Published private(set) var ready = false
    @Published private(set) var canCheck = false
    @Published var automaticChecks = false
    private var controller: SPUStandardUpdaterController?
    private var subscriptions = Set<AnyCancellable>()

    init() {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller = updater
        ready = true
        automaticChecks = updater.updater.automaticallyChecksForUpdates
        updater.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.canCheck = value }
            .store(in: &subscriptions)
        updater.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main)
            .sink { [weak self] value in self?.automaticChecks = value }
            .store(in: &subscriptions)
    }

    func check() { controller?.checkForUpdates(nil) }
    func setAutomaticChecks(_ enabled: Bool) { controller?.updater.automaticallyChecksForUpdates = enabled }
}
