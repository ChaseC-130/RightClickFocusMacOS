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
    private var launchAtLoginItem: NSMenuItem?
    private var permissionsItem: NSMenuItem?
    private var accessibilityStatusItem: NSMenuItem?
    private var inputMonitoringStatusItem: NSMenuItem?
    private var eventTapStatusItem: NSMenuItem?
    private var lastClickItem: NSMenuItem?

    static func main() {
        if let diagnoseToIndex = CommandLine.arguments.firstIndex(of: "--diagnose-to") {
            let outputPath = CommandLine.arguments.dropFirst(diagnoseToIndex + 1).first
            Diagnostics.run(outputPath: outputPath)
            Foundation.exit(0)
        }

        if CommandLine.arguments.contains("--diagnose") {
            Diagnostics.run()
            Foundation.exit(0)
        }

        if CommandLine.arguments.contains("--enable-launch-at-login") {
            do {
                try LaunchAtLoginController.setEnabled(true)
                print("Launch at Login enabled.")
                Foundation.exit(0)
            } catch {
                fputs("Could not enable Launch at Login: \(error.localizedDescription)\n", stderr)
                Foundation.exit(1)
            }
        }

        if CommandLine.arguments.contains("--disable-launch-at-login") {
            do {
                try LaunchAtLoginController.setEnabled(false)
                print("Launch at Login disabled.")
                Foundation.exit(0)
            } catch {
                fputs("Could not disable Launch at Login: \(error.localizedDescription)\n", stderr)
                Foundation.exit(1)
            }
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenuBar()
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

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        self.launchAtLoginItem = launchAtLoginItem
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let permissionsItem = NSMenuItem(
            title: "Permissions: Checking...",
            action: #selector(requestPermissions),
            keyEquivalent: ""
        )
        permissionsItem.target = self
        self.permissionsItem = permissionsItem
        menu.addItem(permissionsItem)

        let accessibilityStatusItem = NSMenuItem(title: "Accessibility: Checking...", action: nil, keyEquivalent: "")
        accessibilityStatusItem.isEnabled = false
        self.accessibilityStatusItem = accessibilityStatusItem
        menu.addItem(accessibilityStatusItem)

        let inputMonitoringStatusItem = NSMenuItem(title: "Input Monitoring: Checking...", action: nil, keyEquivalent: "")
        inputMonitoringStatusItem.isEnabled = false
        self.inputMonitoringStatusItem = inputMonitoringStatusItem
        menu.addItem(inputMonitoringStatusItem)

        let eventTapStatusItem = NSMenuItem(title: "Event Tap: Checking...", action: nil, keyEquivalent: "")
        eventTapStatusItem.isEnabled = false
        self.eventTapStatusItem = eventTapStatusItem
        menu.addItem(eventTapStatusItem)

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
        guard !hasAccessibilityAccess else { return }

        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private var hasAccessibilityAccess: Bool {
        AXIsProcessTrusted()
    }

    private func updateMenu() {
        enabledItem?.state = focusController.isEnabled ? .on : .off
        updateLaunchAtLoginMenuItem()
        accessibilityStatusItem?.title = "Accessibility: \(hasAccessibilityAccess ? "Granted" : "Missing")"
        inputMonitoringStatusItem?.title = "Input Monitoring: \(focusController.hasInputMonitoringAccess ? "Granted" : "Missing")"
        eventTapStatusItem?.title = "Event Tap: \(focusController.isEventTapRunning ? "Running" : "Stopped")"

        if !hasAccessibilityAccess, !focusController.hasInputMonitoringAccess {
            permissionsItem?.title = "Request Permissions / Open Settings"
        } else if !hasAccessibilityAccess {
            permissionsItem?.title = "Request Accessibility / Open Settings"
        } else if !focusController.hasInputMonitoringAccess {
            permissionsItem?.title = "Request Input Monitoring / Open Settings"
        } else if focusController.isEventTapRunning {
            permissionsItem?.title = "Permissions: Ready"
        } else {
            permissionsItem?.title = "Restart Event Tap"
        }

        if let message = focusController.lastError {
            permissionsItem?.toolTip = message
        } else {
            permissionsItem?.toolTip = nil
        }

        lastClickItem?.title = "Last Target: \(focusController.lastFocusSummary)"
    }

    private func updateLaunchAtLoginMenuItem() {
        launchAtLoginItem?.state = LaunchAtLoginController.isEnabled ? .on : .off
        launchAtLoginItem?.title = "Launch at Login"
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

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLoginController.setEnabled(!LaunchAtLoginController.isEnabled)
            focusController.clearLastError()
        } catch {
            focusController.setLastError("Launch at Login could not be updated: \(error.localizedDescription)")
        }

        updateMenu()
    }

    @objc private func requestPermissions() {
        let needsAccessibility = !hasAccessibilityAccess
        let needsInputMonitoring = !focusController.hasInputMonitoringAccess

        if needsAccessibility {
            requestAccessibilityIfNeeded()
        }

        if needsInputMonitoring {
            _ = focusController.requestInputMonitoringAccess()
        }

        _ = focusController.start()

        if !focusController.hasInputMonitoringAccess {
            NSWorkspace.shared.open(SettingsURL.inputMonitoring)
        } else if !hasAccessibilityAccess {
            NSWorkspace.shared.open(SettingsURL.accessibility)
        }

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
