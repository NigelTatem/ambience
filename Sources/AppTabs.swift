import SwiftUI

@MainActor
struct AppTabs: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates: AppUpdates
    @StateObject private var catalog = WallpaperCatalog()
    private var version: String { (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "" }

    var body: some View {
        TabView {
            LibraryView(model: model)
                .tabItem { Label("My Wallpapers", systemImage: "rectangle.stack") }
            DiscoverView(catalog: catalog, model: model)
                .tabItem { Label("Discover", systemImage: "sparkles") }
            settings.tabItem { Label("Settings", systemImage: "gearshape") }
        }.padding(8).frame(minWidth: 910, minHeight: 730)
        .alert("Ambience", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("OK") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Make yourself at home").font(.largeTitle.bold())
            GroupBox("Playback & startup") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                    Toggle("Pause on battery", isOn: Binding(get: { model.state.pauseOnBattery }, set: { model.setBatteryPause($0) }))
                    Toggle("Pause in Low Power Mode", isOn: Binding(get: { model.state.pauseOnLowPower }, set: { model.setLowPowerPause($0) }))
                    Text("Power-saving pauses stop both video and audio.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            GroupBox("Updates") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ambience \(version)")
                    Toggle("Check for updates automatically", isOn: Binding(get: { updates.automaticChecks }, set: { updates.setAutomaticChecks($0) }))
                        .disabled(!updates.ready)
                    Button("Check for Updates…", action: updates.check).disabled(!updates.canCheck || model.busy)
                    Text(updates.ready ? "Updates keep your videos, framing, and preferences. You can review an update before installing it." : "This development build has no update signing key. Run the publisher setup to enable updates.")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            Button("Show downloaded videos", action: model.revealLibrary)
            Link("Project & downloads ↗", destination: URL(string: "https://github.com/NigelTatem/ambience")!)
            Text("Free to use. No account needed in Ambience.").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }.padding(36).frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
            .toggleStyle(.checkbox).onAppear { model.refreshLogin() }
    }
}
