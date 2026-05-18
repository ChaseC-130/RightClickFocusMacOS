import AppKit
import ApplicationServices
import CarbonActivationShim
import OSLog

final class RightClickFocusController {
    var isEnabled = true
    private(set) var isEventTapRunning = false
    private(set) var lastError: String?
    private(set) var lastFocusSummary = "None"

    private let logger = Logger(subsystem: "com.chasecargill.RightClickFocus", category: "focus")
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let systemWideElement = AXUIElementCreateSystemWide()

    var hasInputMonitoringAccess: Bool {
        CGPreflightListenEventAccess()
    }

    func requestInputMonitoringAccess() -> Bool {
        let didGrantAccess = CGRequestListenEventAccess()

        if didGrantAccess {
            lastError = nil
        } else {
            lastError = "Grant Input Monitoring permission, then relaunch or choose Permissions again."
        }

        return didGrantAccess
    }

    func setLastError(_ message: String) {
        lastError = message
    }

    func clearLastError() {
        lastError = nil
    }

    func start() -> Bool {
        guard isEnabled else { return false }

        if isEventTapRunning {
            return true
        }

        guard AXIsProcessTrusted() else {
            lastError = "Grant Accessibility permission, then relaunch or choose Permissions again."
            return false
        }

        guard hasInputMonitoringAccess else {
            lastError = "Grant Input Monitoring permission, then relaunch or choose Permissions again."
            return false
        }

        let mask = CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "The event tap could not start. Grant Input Monitoring permission, then relaunch."
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            lastError = "The event tap run loop source could not be created."
            return false
        }

        eventTap = tap
        runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isEventTapRunning = true
        lastError = nil
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isEventTapRunning = false
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        guard isEnabled, type == .rightMouseDown else { return }

        let point = event.location
        guard let target = targetWindow(at: point) else {
            lastFocusSummary = "No window at \(Int(point.x)), \(Int(point.y))"
            logger.debug("Right-click at x=\(point.x) y=\(point.y) did not match an onscreen window.")
            return
        }

        focus(target: target)
    }

    private func targetWindow(at point: CGPoint) -> TargetWindow? {
        switch graphicsWindowHit(at: point) {
        case .target(var target):
            target.axWindow = accessibilityWindow(matching: target, at: point)
            return target

        case .covered(let ownerName, let layer):
            logger.debug(
                """
                Right-click at x=\(point.x) y=\(point.y) is covered by \
                \(ownerName ?? "an unfocusable surface", privacy: .public) \
                on layer \(layer).
                """
            )
            return nil

        case .none:
            guard let target = accessibilityWindow(at: point) else {
                return nil
            }

            guard !frontmostApplicationCovers(point, excluding: target.pid) else {
                logger.debug("Right-click at x=\(point.x) y=\(point.y) is covered by the frontmost app.")
                return nil
            }

            return target
        }
    }

    private func accessibilityWindow(at point: CGPoint) -> TargetWindow? {
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &element
        )

        guard result == .success, let element else { return nil }
        guard let window = nearestWindow(startingAt: element) else { return nil }

        var pid = pid_t()
        guard AXUIElementGetPid(window, &pid) == .success else { return nil }
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }

        return TargetWindow(
            pid: pid,
            axWindow: window,
            cgWindowID: nil,
            ownerName: applicationName(pid: pid),
            windowName: windowTitle(window),
            bounds: nil
        )
    }

    private func accessibilityWindow(matching target: TargetWindow, at point: CGPoint) -> AXUIElement? {
        if
            let window = accessibilityWindow(at: point)?.axWindow,
            pid(for: window) == target.pid
        {
            return window
        }

        let appElement = AXUIElementCreateApplication(target.pid)
        guard let windows = axElementArrayAttribute(kAXWindowsAttribute, from: appElement) else {
            return nil
        }

        let windowsContainingPoint = windows.filter { window in
            guard let frame = frame(of: window) else { return false }
            return frame.contains(point)
        }

        let candidates = windowsContainingPoint.isEmpty ? windows : windowsContainingPoint

        return candidates.min { left, right in
            frameDistance(from: target.bounds, to: frame(of: left)) <
                frameDistance(from: target.bounds, to: frame(of: right))
        }
    }

    private func nearestWindow(startingAt element: AXUIElement) -> AXUIElement? {
        if isWindow(element) {
            return element
        }

        if let window = axElementAttribute(kAXWindowAttribute, from: element) {
            return window
        }

        var current = element
        for _ in 0..<12 {
            guard let parent = axElementAttribute(kAXParentAttribute, from: current) else {
                break
            }

            if isWindow(parent) {
                return parent
            }

            current = parent
        }

        return nil
    }

    private func isWindow(_ element: AXUIElement) -> Bool {
        guard let role = attribute(kAXRoleAttribute, from: element) as? String else {
            return false
        }

        return role == (kAXWindowRole as String)
    }

    private func focus(target: TargetWindow) {
        guard let app = NSRunningApplication(processIdentifier: target.pid) else { return }

        let appElement = AXUIElementCreateApplication(target.pid)
        app.unhide()

        if let axWindow = target.axWindow {
            focus(axWindow: axWindow, appElement: appElement)
        }

        let axFrontmostResult = AXUIElementSetAttributeValue(
            appElement,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )
        let carbonActivationResult = activateAsUserInitiated(pid: target.pid)
        let appActivationResult = app.activate(options: [.activateAllWindows])

        if let axWindow = target.axWindow {
            focus(axWindow: axWindow, appElement: appElement)
        }

        logger.debug(
            """
            Right-click focus target app=\(target.ownerName ?? "unknown", privacy: .public) \
            title=\(target.windowName ?? "untitled", privacy: .public) \
            pid=\(target.pid) windowID=\(target.cgWindowID ?? 0) \
            axWindow=\(target.axWindow == nil ? "no" : "yes", privacy: .public) \
            axFrontmost=\(axFrontmostResult.rawValue) \
            carbonActivate=\(carbonActivationResult ?? Int32.min) \
            appActivate=\(appActivationResult)
            """
        )

        let targetName = target.ownerName ?? "unknown app"
        lastFocusSummary = targetName
    }

    private func activateAsUserInitiated(pid: pid_t) -> OSStatus? {
        RightClickFocusActivateProcessForPID(pid)
    }

    private func focus(axWindow: AXUIElement, appElement: AXUIElement) {
        AXUIElementSetAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            axWindow
        )
        AXUIElementSetAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            axWindow
        )
        AXUIElementSetAttributeValue(
            axWindow,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )
        AXUIElementSetAttributeValue(
            axWindow,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
    }

    private func attribute(_ name: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard result == .success else { return nil }
        return value
    }

    private func axElementAttribute(_ name: String, from element: AXUIElement) -> AXUIElement? {
        guard let value = attribute(name, from: element) else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func axElementArrayAttribute(_ name: String, from element: AXUIElement) -> [AXUIElement]? {
        guard let value = attribute(name, from: element) else { return nil }
        guard CFGetTypeID(value) == CFArrayGetTypeID() else { return nil }
        return value as? [AXUIElement]
    }

    private func graphicsWindowHit(at point: CGPoint) -> GraphicsWindowHit {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return .none
        }

        for windowInfo in windowInfoList {
            if let alpha = numericValue(kCGWindowAlpha, in: windowInfo), alpha.doubleValue <= 0.05 {
                continue
            }

            guard
                let boundsDictionary = windowInfo[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else {
                continue
            }

            guard bounds.contains(point) else {
                continue
            }

            let layer = numericValue(kCGWindowLayer, in: windowInfo)?.intValue ?? Int.max
            let ownerName = windowInfo[kCGWindowOwnerName as String] as? String

            guard let ownerPID = numericValue(kCGWindowOwnerPID, in: windowInfo)?.int32Value else {
                return .covered(ownerName: ownerName, layer: layer)
            }

            if ownerPID == ProcessInfo.processInfo.processIdentifier {
                return .covered(ownerName: ownerName, layer: layer)
            }

            guard layer == 0 else {
                return .covered(ownerName: ownerName, layer: layer)
            }

            guard let windowID = numericValue(kCGWindowNumber, in: windowInfo)?.uint32Value else {
                return .covered(ownerName: ownerName, layer: layer)
            }

            return .target(TargetWindow(
                pid: ownerPID,
                axWindow: nil,
                cgWindowID: windowID,
                ownerName: ownerName,
                windowName: windowInfo[kCGWindowName as String] as? String,
                bounds: bounds
            ))
        }

        return .none
    }

    private func frontmostApplicationCovers(_ point: CGPoint, excluding targetPID: pid_t) -> Bool {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        let frontmostPID = frontmostApplication.processIdentifier
        guard
            frontmostPID != targetPID,
            frontmostPID != ProcessInfo.processInfo.processIdentifier
        else {
            return false
        }

        let appElement = AXUIElementCreateApplication(frontmostPID)
        guard let windows = axElementArrayAttribute(kAXWindowsAttribute, from: appElement) else {
            return false
        }

        return windows.contains { window in
            !isMinimized(window) && frame(of: window)?.contains(point) == true
        }
    }

    private func numericValue(_ key: CFString, in windowInfo: [String: Any]) -> NSNumber? {
        windowInfo[key as String] as? NSNumber
    }

    private func pid(for element: AXUIElement) -> pid_t? {
        var pid = pid_t()
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard
            let positionValue = attribute(kAXPositionAttribute, from: window),
            let sizeValue = attribute(kAXSizeAttribute, from: window),
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        let didReadPosition = AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        let didReadSize = AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        guard didReadPosition, didReadSize else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func isMinimized(_ window: AXUIElement) -> Bool {
        attribute(kAXMinimizedAttribute, from: window) as? Bool ?? false
    }

    private func frameDistance(from expected: CGRect?, to candidate: CGRect?) -> CGFloat {
        guard let expected, let candidate else { return .greatestFiniteMagnitude }

        return abs(expected.minX - candidate.minX)
            + abs(expected.minY - candidate.minY)
            + abs(expected.width - candidate.width)
            + abs(expected.height - candidate.height)
    }

    private func applicationName(pid: pid_t) -> String? {
        NSRunningApplication(processIdentifier: pid)?.localizedName
    }

    private func windowTitle(_ window: AXUIElement) -> String? {
        attribute(kAXTitleAttribute, from: window) as? String
    }
}

private struct TargetWindow {
    let pid: pid_t
    var axWindow: AXUIElement?
    let cgWindowID: CGWindowID?
    let ownerName: String?
    let windowName: String?
    let bounds: CGRect?
}

private enum GraphicsWindowHit {
    case target(TargetWindow)
    case covered(ownerName: String?, layer: Int)
    case none
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<RightClickFocusController>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    controller.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}
