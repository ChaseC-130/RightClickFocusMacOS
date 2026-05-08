import AppKit
import ApplicationServices

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum SettingsURL {
        static let accessibility = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        static let inputMonitoring = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
    }

    private let focusController = RightClickFocusController()
    private var statusItem: NSStatusItem?
    private var enabledItem: NSMenuItem?
    private var permissionsItem: NSMenuItem?
    private var lastClickItem: NSMenuItem?

    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            Diagnostics.run()
            Foundation.exit(0)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenuBar()
        requestAccessibilityIfNeeded()
        requestInputMonitoringIfNeeded()
        startFocusController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusController.stop()
    }

    private func configureMenuBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "cursorarrow.click.2",
                accessibilityDescription: "Right Click Focus"
            ) ?? NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: "Right Click Focus")
            button.toolTip = "Right Click Focus"
        }

        let menu = NSMenu()
        menu.delegate = self

        let enabledItem = NSMenuItem(
            title: "Focus on Right-Click",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = .on
        self.enabledItem = enabledItem
        menu.addItem(enabledItem)

        let permissionsItem = NSMenuItem(
            title: "Permissions: Checking...",
            action: #selector(requestPermissions),
            keyEquivalent: ""
        )
        permissionsItem.target = self
        self.permissionsItem = permissionsItem
        menu.addItem(permissionsItem)

        let lastClickItem = NSMenuItem(title: "Last Target: None", action: nil, keyEquivalent: "")
        lastClickItem.isEnabled = false
        self.lastClickItem = lastClickItem
        menu.addItem(lastClickItem)

        menu.addItem(.separator())

        let accessibilityItem = NSMenuItem(
            title: "Open Accessibility Settings",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        let inputMonitoringItem = NSMenuItem(
            title: "Open Input Monitoring Settings",
            action: #selector(openInputMonitoringSettings),
            keyEquivalent: ""
        )
        inputMonitoringItem.target = self
        menu.addItem(inputMonitoringItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
    }

    private func startFocusController() {
        if focusController.start() {
            updateMenu()
            return
        }

        updateMenu()
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func requestInputMonitoringIfNeeded() {
        guard !focusController.hasInputMonitoringAccess else { return }
        _ = focusController.requestInputMonitoringAccess()
    }

    private func updateMenu() {
        enabledItem?.state = focusController.isEnabled ? .on : .off

        if !AXIsProcessTrusted(), !focusController.hasInputMonitoringAccess {
            permissionsItem?.title = "Permissions: Needs Accessibility + Input Monitoring"
        } else if !AXIsProcessTrusted() {
            permissionsItem?.title = "Permissions: Needs Accessibility"
        } else if !focusController.hasInputMonitoringAccess {
            permissionsItem?.title = "Permissions: Needs Input Monitoring"
        } else if focusController.isEventTapRunning {
            permissionsItem?.title = "Permissions: Ready"
        } else {
            permissionsItem?.title = "Permissions: Event Tap Stopped"
        }

        if let message = focusController.lastError {
            permissionsItem?.toolTip = message
        } else {
            permissionsItem?.toolTip = nil
        }

        lastClickItem?.title = "Last Target: \(focusController.lastFocusSummary)"
    }

    @objc private func toggleEnabled() {
        focusController.isEnabled.toggle()

        if focusController.isEnabled {
            _ = focusController.start()
        } else {
            focusController.stop()
        }

        updateMenu()
    }

    @objc private func requestPermissions() {
        requestAccessibilityIfNeeded()
        requestInputMonitoringIfNeeded()
        _ = focusController.start()
        updateMenu()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(SettingsURL.accessibility)
    }

    @objc private func openInputMonitoringSettings() {
        NSWorkspace.shared.open(SettingsURL.inputMonitoring)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
