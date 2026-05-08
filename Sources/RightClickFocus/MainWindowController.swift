import AppKit

struct MainWindowState {
    let focusOnRightClick: Bool
    let launchAtLogin: Bool
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool
    let eventTapRunning: Bool
    let lastTarget: String
    let lastError: String?
    let showInDock: Bool
    let showInMenuBar: Bool
    let needsApplicationsFolderPrompt: Bool
}

@MainActor
protocol MainWindowControllerDelegate: AnyObject {
    func mainWindowController(_ controller: MainWindowController, setFocusOnRightClick enabled: Bool)
    func mainWindowController(_ controller: MainWindowController, setLaunchAtLogin enabled: Bool)
    func mainWindowController(_ controller: MainWindowController, setShowInDock enabled: Bool)
    func mainWindowController(_ controller: MainWindowController, setShowInMenuBar enabled: Bool)
    func mainWindowControllerDidRequestPermissions(_ controller: MainWindowController)
    func mainWindowControllerDidOpenAccessibilitySettings(_ controller: MainWindowController)
    func mainWindowControllerDidOpenInputMonitoringSettings(_ controller: MainWindowController)
    func mainWindowControllerDidShowCurrentAppInFinder(_ controller: MainWindowController)
    func mainWindowControllerDidOpenApplicationsFolder(_ controller: MainWindowController)
    func mainWindowControllerDidResetPermissions(_ controller: MainWindowController)
    func mainWindowControllerDidQuit(_ controller: MainWindowController)
}

@MainActor
final class MainWindowController: NSWindowController {
    weak var delegate: MainWindowControllerDelegate?

    private let contentStack = NSStackView()
    private let applicationsPromptView = NSView()
    private let focusCheckbox = NSButton(checkboxWithTitle: "Focus on Right-Click", target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: nil)
    private let showInDockCheckbox = NSButton(checkboxWithTitle: "Show in Dock", target: nil, action: nil)
    private let showInMenuBarCheckbox = NSButton(checkboxWithTitle: "Show in Menu Bar", target: nil, action: nil)
    private let accessibilityValue = NSTextField(labelWithString: "Checking...")
    private let inputMonitoringValue = NSTextField(labelWithString: "Checking...")
    private let eventTapValue = NSTextField(labelWithString: "Checking...")
    private let lastTargetValue = NSTextField(labelWithString: "None")
    private let errorLabel = NSTextField(labelWithString: "")
    private let permissionsButton = NSButton(title: "Request Permissions", target: nil, action: nil)
    private var lastApplicationsPromptVisibility: Bool?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RightClickFocus"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 440, height: 330)

        super.init(window: window)

        buildContent()
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(state: MainWindowState) {
        focusCheckbox.state = state.focusOnRightClick ? .on : .off
        launchAtLoginCheckbox.state = state.launchAtLogin ? .on : .off
        showInDockCheckbox.state = state.showInDock ? .on : .off
        showInMenuBarCheckbox.state = state.showInMenuBar ? .on : .off
        showInDockCheckbox.isEnabled = state.showInMenuBar || !state.showInDock
        showInMenuBarCheckbox.isEnabled = state.showInDock || !state.showInMenuBar

        setStatus(accessibilityValue, text: state.accessibilityGranted ? "Granted" : "Missing", isReady: state.accessibilityGranted)
        setStatus(inputMonitoringValue, text: state.inputMonitoringGranted ? "Granted" : "Missing", isReady: state.inputMonitoringGranted)
        setStatus(eventTapValue, text: state.eventTapRunning ? "Running" : "Stopped", isReady: state.eventTapRunning)

        lastTargetValue.stringValue = state.lastTarget
        lastTargetValue.toolTip = state.lastTarget

        applicationsPromptView.isHidden = !state.needsApplicationsFolderPrompt
        resizeIfNeeded(showingApplicationsPrompt: state.needsApplicationsFolderPrompt)

        if let lastError = state.lastError, !lastError.isEmpty {
            errorLabel.stringValue = lastError
            errorLabel.isHidden = false
        } else {
            errorLabel.stringValue = ""
            errorLabel.isHidden = true
        }

        permissionsButton.title = permissionsTitle(for: state)
        permissionsButton.isEnabled = !state.accessibilityGranted || !state.inputMonitoringGranted || !state.eventTapRunning
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let window else { return }

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        contentStack.detachesHiddenViews = true
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(contentStack)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])

        contentStack.addArrangedSubview(makeApplicationsPrompt())
        contentStack.addArrangedSubview(makeHeader())
        contentStack.addArrangedSubview(makeOptionsSection())
        contentStack.addArrangedSubview(makePermissionsSection())
        contentStack.addArrangedSubview(makeStatusSection())
        contentStack.addArrangedSubview(makeFooter())

        focusCheckbox.target = self
        focusCheckbox.action = #selector(toggleFocusOnRightClick)
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin)
        showInDockCheckbox.target = self
        showInDockCheckbox.action = #selector(toggleShowInDock)
        showInMenuBarCheckbox.target = self
        showInMenuBarCheckbox.action = #selector(toggleShowInMenuBar)
    }

    private func makeHeader() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "RightClickFocus")
        title.font = .systemFont(ofSize: 18, weight: .semibold)

        let subtitle = NSTextField(labelWithString: "Focus windows when you right-click them.")
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [title, subtitle])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let stack = NSStackView(views: [icon, textStack])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 44),
            icon.heightAnchor.constraint(equalToConstant: 44)
        ])

        let wrapper = NSStackView(views: [stack])
        wrapper.orientation = .vertical
        wrapper.alignment = .leading
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.widthAnchor.constraint(equalToConstant: 440).isActive = true
        return wrapper
    }

    private func makeApplicationsPrompt() -> NSView {
        applicationsPromptView.wantsLayer = true
        applicationsPromptView.translatesAutoresizingMaskIntoConstraints = false
        applicationsPromptView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        applicationsPromptView.layer?.borderColor = NSColor.separatorColor.cgColor
        applicationsPromptView.layer?.borderWidth = 1
        applicationsPromptView.layer?.cornerRadius = 8

        let icon = NSImageView(image: NSImage(
            systemSymbolName: "folder.badge.questionmark",
            accessibilityDescription: "Applications folder"
        ) ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Move to Applications")
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        let message = NSTextField(labelWithString: "This copy is not running from Applications. If you opened the disk image, drag RightClickFocus.app onto Applications there, then reopen it from Applications.")
        message.font = .systemFont(ofSize: 12)
        message.textColor = .secondaryLabelColor
        message.maximumNumberOfLines = 3

        let textStack = NSStackView(views: [title, message])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let showAppButton = makeButton(
            title: "Show App",
            symbolName: "magnifyingglass",
            action: #selector(showCurrentAppInFinder)
        )
        let applicationsButton = makeButton(
            title: "Open Applications",
            symbolName: "folder",
            action: #selector(openApplicationsFolder)
        )

        let buttonStack = NSStackView(views: [showAppButton, applicationsButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 8

        let rightStack = NSStackView(views: [textStack, buttonStack])
        rightStack.orientation = .vertical
        rightStack.alignment = .leading
        rightStack.spacing = 8

        let promptStack = NSStackView(views: [icon, rightStack])
        promptStack.orientation = .horizontal
        promptStack.alignment = .top
        promptStack.spacing = 10
        promptStack.translatesAutoresizingMaskIntoConstraints = false

        applicationsPromptView.addSubview(promptStack)

        NSLayoutConstraint.activate([
            applicationsPromptView.widthAnchor.constraint(equalToConstant: 440),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),
            promptStack.leadingAnchor.constraint(equalTo: applicationsPromptView.leadingAnchor, constant: 12),
            promptStack.trailingAnchor.constraint(equalTo: applicationsPromptView.trailingAnchor, constant: -12),
            promptStack.topAnchor.constraint(equalTo: applicationsPromptView.topAnchor, constant: 12),
            promptStack.bottomAnchor.constraint(equalTo: applicationsPromptView.bottomAnchor, constant: -12)
        ])

        return applicationsPromptView
    }

    private func makeOptionsSection() -> NSView {
        let label = sectionLabel("Options")
        let stack = NSStackView(views: [
            label,
            focusCheckbox,
            launchAtLoginCheckbox,
            showInDockCheckbox,
            showInMenuBarCheckbox
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 440).isActive = true
        return stack
    }

    private func makePermissionsSection() -> NSView {
        permissionsButton.target = self
        permissionsButton.action = #selector(requestPermissions)
        permissionsButton.bezelStyle = .rounded
        permissionsButton.image = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: "Request permissions")
        permissionsButton.imagePosition = .imageLeading

        let accessibilityButton = makeButton(
            title: "Accessibility",
            symbolName: "accessibility",
            action: #selector(openAccessibilitySettings)
        )
        let inputMonitoringButton = makeButton(
            title: "Input Monitoring",
            symbolName: "keyboard",
            action: #selector(openInputMonitoringSettings)
        )

        let revealAppButton = makeButton(
            title: "Reveal App",
            symbolName: "magnifyingglass",
            action: #selector(showCurrentAppInFinder)
        )

        let resetPermissionsButton = makeButton(
            title: "Reset Permissions",
            symbolName: "arrow.counterclockwise",
            action: #selector(resetPermissions)
        )

        let requestButtonStack = NSStackView(views: [permissionsButton])
        requestButtonStack.orientation = .horizontal
        requestButtonStack.alignment = .centerY

        let settingsButtonStack = NSStackView(views: [accessibilityButton, inputMonitoringButton, revealAppButton])
        settingsButtonStack.orientation = .horizontal
        settingsButtonStack.alignment = .centerY
        settingsButtonStack.spacing = 8

        let resetButtonStack = NSStackView(views: [resetPermissionsButton])
        resetButtonStack.orientation = .horizontal
        resetButtonStack.alignment = .centerY

        let stack = NSStackView(views: [
            sectionLabel("Permissions"),
            makeStatusRow(title: "Accessibility", value: accessibilityValue),
            makeStatusRow(title: "Input Monitoring", value: inputMonitoringValue),
            requestButtonStack,
            settingsButtonStack,
            resetButtonStack,
            errorLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 440).isActive = true

        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 12)
        errorLabel.maximumNumberOfLines = 2
        errorLabel.isHidden = true

        return stack
    }

    private func makeStatusSection() -> NSView {
        let stack = NSStackView(views: [
            sectionLabel("Status"),
            makeStatusRow(title: "Event Tap", value: eventTapValue),
            makeStatusRow(title: "Last Clicked", value: lastTargetValue)
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 440).isActive = true

        lastTargetValue.lineBreakMode = .byTruncatingTail
        lastTargetValue.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return stack
    }

    private func makeFooter() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let quitButton = makeButton(title: "Quit", symbolName: "power", action: #selector(quit))

        let stack = NSStackView(views: [spacer, quitButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 440).isActive = true
        return stack
    }

    private func makeStatusRow(title: String, value: NSTextField) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.widthAnchor.constraint(equalToConstant: 128).isActive = true

        value.font = .systemFont(ofSize: 13)

        let stack = NSStackView(views: [titleLabel, value])
        stack.orientation = .horizontal
        stack.alignment = .firstBaseline
        stack.spacing = 10
        return stack
    }

    private func makeButton(title: String, symbolName: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        return button
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func setStatus(_ label: NSTextField, text: String, isReady: Bool) {
        label.stringValue = text
        label.textColor = isReady ? .systemGreen : .systemOrange
    }

    private func resizeIfNeeded(showingApplicationsPrompt: Bool) {
        guard lastApplicationsPromptVisibility != showingApplicationsPrompt, let window else { return }
        lastApplicationsPromptVisibility = showingApplicationsPrompt

        let targetContentSize = NSSize(
            width: 480,
            height: showingApplicationsPrompt ? 644 : 524
        )
        let targetFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetContentSize)).size
        var frame = window.frame
        let topY = frame.maxY
        frame.size = targetFrameSize
        frame.origin.y = topY - targetFrameSize.height
        window.setFrame(frame, display: true)
    }

    private func permissionsTitle(for state: MainWindowState) -> String {
        if !state.accessibilityGranted, !state.inputMonitoringGranted {
            return "Request Permissions"
        }

        if !state.accessibilityGranted {
            return "Request Accessibility"
        }

        if !state.inputMonitoringGranted {
            return "Request Input Monitoring"
        }

        return state.eventTapRunning ? "Permissions Ready" : "Restart Listener"
    }

    @objc private func toggleFocusOnRightClick() {
        delegate?.mainWindowController(self, setFocusOnRightClick: focusCheckbox.state == .on)
    }

    @objc private func toggleLaunchAtLogin() {
        delegate?.mainWindowController(self, setLaunchAtLogin: launchAtLoginCheckbox.state == .on)
    }

    @objc private func toggleShowInDock() {
        delegate?.mainWindowController(self, setShowInDock: showInDockCheckbox.state == .on)
    }

    @objc private func toggleShowInMenuBar() {
        delegate?.mainWindowController(self, setShowInMenuBar: showInMenuBarCheckbox.state == .on)
    }

    @objc private func requestPermissions() {
        delegate?.mainWindowControllerDidRequestPermissions(self)
    }

    @objc private func openAccessibilitySettings() {
        delegate?.mainWindowControllerDidOpenAccessibilitySettings(self)
    }

    @objc private func openInputMonitoringSettings() {
        delegate?.mainWindowControllerDidOpenInputMonitoringSettings(self)
    }

    @objc private func showCurrentAppInFinder() {
        delegate?.mainWindowControllerDidShowCurrentAppInFinder(self)
    }

    @objc private func openApplicationsFolder() {
        delegate?.mainWindowControllerDidOpenApplicationsFolder(self)
    }

    @objc private func resetPermissions() {
        delegate?.mainWindowControllerDidResetPermissions(self)
    }

    @objc private func quit() {
        delegate?.mainWindowControllerDidQuit(self)
    }
}
