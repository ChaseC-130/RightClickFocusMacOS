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
    private let mainWindowController = MainWindowController()
    private var refreshTimer: Timer?
    private var statusItem: NSStatusItem?
    private var showWindowItem: NSMenuItem?
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
        mainWindowController.delegate = self
        configureMenuBar()
        startFocusController()
        mainWindowController.showWindow(nil)
        startRefreshTimer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        focusController.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
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

        let showWindowItem = NSMenuItem(
            title: "Open RightClickFocus",
            action: #selector(showMainWindow),
            keyEquivalent: ""
        )
        showWindowItem.target = self
        self.showWindowItem = showWindowItem
        menu.addItem(showWindowItem)

        menu.addItem(.separator())

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
        updateInterface()
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateInterface()
    }

    private func startFocusController() {
        if focusController.start() {
            updateInterface()
            return
        }

        updateInterface()
    }

    private func startRefreshTimer() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshStatus() {
        if
            focusController.isEnabled,
            !focusController.isEventTapRunning,
            hasAccessibilityAccess,
            focusController.hasInputMonitoringAccess
        {
            _ = focusController.start()
        }

        updateInterface()
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

    private func updateInterface() {
        updateMenu()
        mainWindowController.update(state: currentWindowState())
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

    private func currentWindowState() -> MainWindowState {
        MainWindowState(
            focusOnRightClick: focusController.isEnabled,
            launchAtLogin: LaunchAtLoginController.isEnabled,
            accessibilityGranted: hasAccessibilityAccess,
            inputMonitoringGranted: focusController.hasInputMonitoringAccess,
            eventTapRunning: focusController.isEventTapRunning,
            lastTarget: focusController.lastFocusSummary,
            lastError: focusController.lastError,
            needsApplicationsFolderPrompt: !isRunningFromApplicationsFolder
        )
    }

    private func updateLaunchAtLoginMenuItem() {
        launchAtLoginItem?.state = LaunchAtLoginController.isEnabled ? .on : .off
        launchAtLoginItem?.title = "Launch at Login"
    }

    private var isRunningFromApplicationsFolder: Bool {
        let bundleParent = Bundle.main.bundleURL
            .standardizedFileURL
            .deletingLastPathComponent()
            .path
        let userApplicationsPath = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
            .standardizedFileURL
            .path

        return bundleParent == "/Applications" || bundleParent == userApplicationsPath
    }

    @objc private func toggleEnabled() {
        setFocusOnRightClick(!focusController.isEnabled)
    }

    private func setFocusOnRightClick(_ enabled: Bool) {
        focusController.isEnabled = enabled

        if enabled {
            _ = focusController.start()
        } else {
            focusController.stop()
        }

        updateInterface()
    }

    @objc private func toggleLaunchAtLogin() {
        setLaunchAtLogin(!LaunchAtLoginController.isEnabled)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(enabled)
            focusController.clearLastError()
        } catch {
            focusController.setLastError("Launch at Login could not be updated: \(error.localizedDescription)")
        }

        updateInterface()
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

        updateInterface()
    }

    @objc private func openAccessibilitySettings() {
        requestAccessibilityIfNeeded()
        NSWorkspace.shared.open(SettingsURL.accessibility)
        updateInterface()
    }

    @objc private func openInputMonitoringSettings() {
        if !focusController.hasInputMonitoringAccess {
            _ = focusController.requestInputMonitoringAccess()
        }

        NSWorkspace.shared.open(SettingsURL.inputMonitoring)
        updateInterface()
    }

    @objc private func showMainWindow() {
        mainWindowController.showWindow(nil)
        updateInterface()
    }

    private func showCurrentAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    private func openApplicationsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
    }

    private func resetPrivacyPermissions() {
        do {
            try resetPrivacyPermissions(for: Bundle.main.bundleIdentifier ?? "com.chasecargill.RightClickFocus")
            try resetPrivacyPermissions(for: "local.codex.RightClickFocus")
            focusController.stop()
            focusController.setLastError("Permissions reset. Quit and reopen RightClickFocus, then grant Accessibility and Input Monitoring again.")
            NSWorkspace.shared.open(SettingsURL.accessibility)
        } catch {
            focusController.setLastError("Permissions could not be reset: \(error.localizedDescription)")
        }

        updateInterface()
    }

    private func resetPrivacyPermissions(for bundleID: String) throws {
        try runTCCUtil(arguments: ["reset", "Accessibility", bundleID])
        try runTCCUtil(arguments: ["reset", "ListenEvent", bundleID])
    }

    private func runTCCUtil(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: MainWindowControllerDelegate {
    func mainWindowController(_ controller: MainWindowController, setFocusOnRightClick enabled: Bool) {
        setFocusOnRightClick(enabled)
    }

    func mainWindowController(_ controller: MainWindowController, setLaunchAtLogin enabled: Bool) {
        setLaunchAtLogin(enabled)
    }

    func mainWindowControllerDidRequestPermissions(_ controller: MainWindowController) {
        requestPermissions()
    }

    func mainWindowControllerDidOpenAccessibilitySettings(_ controller: MainWindowController) {
        openAccessibilitySettings()
    }

    func mainWindowControllerDidOpenInputMonitoringSettings(_ controller: MainWindowController) {
        openInputMonitoringSettings()
    }

    func mainWindowControllerDidShowCurrentAppInFinder(_ controller: MainWindowController) {
        showCurrentAppInFinder()
    }

    func mainWindowControllerDidOpenApplicationsFolder(_ controller: MainWindowController) {
        openApplicationsFolder()
    }

    func mainWindowControllerDidResetPermissions(_ controller: MainWindowController) {
        resetPrivacyPermissions()
    }

    func mainWindowControllerDidQuit(_ controller: MainWindowController) {
        quit()
    }
}
