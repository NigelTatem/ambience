import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSMenuItemValidation {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private var libraryWindow: NSWindow?
    private var updates: AppUpdates!

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        model = AppModel()
        updates = AppUpdates()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Ambience")
        statusItem.button?.toolTip = "Ambience wallpapers"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        model.start()
        if model.selected == nil || model.message != nil { showLibrary() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLibrary()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model?.busy == true {
            let alert = NSAlert()
            alert.messageText = "A video operation is still running"
            alert.informativeText = "Let it finish before quitting to keep the import or export intact."
            alert.addButton(withTitle: "Keep Running")
            alert.runModal()
            return .terminateCancel
        }
        return .terminateNow
    }

    private func installMainMenu() {
        let menu = NSMenu()
        let appRoot = NSMenuItem()
        menu.addItem(appRoot)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Ambience", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appRoot.submenu = appMenu
        let editRoot = NSMenuItem()
        menu.addItem(editRoot)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editRoot.submenu = edit
        NSApp.mainMenu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let heading = NSMenuItem(title: model.status, action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())
        add("Open Video Collection…", to: menu, action: #selector(showLibrary))
        add(model.state.paused ? "Resume" : "Pause", to: menu, action: #selector(togglePause))
        add(model.state.muted ? "Unmute Ambience" : "Mute Ambience", to: menu, action: #selector(toggleMute))
        add("Next Video", to: menu, action: #selector(next))
        if !model.state.clips.isEmpty {
            let root = NSMenuItem(title: "Choose Video", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for clip in model.state.clips {
                let item = NSMenuItem(title: clip.title, action: #selector(choose(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = clip.id.uuidString
                item.state = clip.id == model.state.selectedID ? .on : .off
                submenu.addItem(item)
            }
            root.submenu = submenu
            menu.addItem(root)
        }
        menu.addItem(.separator())
        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: "")
        update.target = self
        update.isEnabled = updates.canCheck && !model.busy
        menu.addItem(update)
        add("Quit Ambience", to: menu, action: #selector(quit))
    }

    private func add(_ title: String, to menu: NSMenu, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkUpdates) { return updates.canCheck && !model.busy }
        return true
    }
    @objc func showLibrary() {
        guard model != nil else { return }
        model.refreshLogin()
        if libraryWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 970, height: 790),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Ambience"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: AppTabs(model: model, updates: updates))
            window.minSize = NSSize(width: 890, height: 710)
            window.center()
            libraryWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        libraryWindow?.makeKeyAndOrderFront(nil)
    }
    @objc private func togglePause() { model.togglePause() }
    @objc private func toggleMute() { model.setMuted(!model.state.muted) }
    @objc private func next() { model.next() }
    @objc private func choose(_ sender: NSMenuItem) {
        if let string = sender.representedObject as? String, let id = UUID(uuidString: string) { model.select(id) }
    }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func checkUpdates() { if !model.busy { updates.check() } }
}

@main
struct AmbienceMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        // Reopening a running copy should show its controls, not create competing wallpaper players.
        if let bundleID = Bundle.main.bundleIdentifier,
           let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            running.activate(options: [.activateIgnoringOtherApps])
            return
        }
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
