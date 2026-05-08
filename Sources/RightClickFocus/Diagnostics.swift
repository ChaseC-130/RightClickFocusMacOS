import AppKit
import ApplicationServices
import Foundation
import Security

enum Diagnostics {
    static func run() {
        let bundle = Bundle.main
        let executableURL = bundle.executableURL
        let bundleURL = bundle.bundleURL

        print("RightClickFocus Diagnostics")
        print("===========================")
        print("Bundle identifier: \(bundle.bundleIdentifier ?? "missing")")
        print("Bundle path: \(bundleURL.path)")
        print("Executable path: \(executableURL?.path ?? "missing")")
        print("Process path: \(CommandLine.arguments.first ?? "missing")")
        print("Code signature: \(codeSignatureStatus(bundleURL: bundleURL))")
        print("Accessibility trusted: \(AXIsProcessTrusted() ? "yes" : "no")")
        print("Input Monitoring preflight: \(CGPreflightListenEventAccess() ? "yes" : "no")")
        print("Right-click event tap creatable: \(canCreateRightClickEventTap() ? "yes" : "no")")
        print("Frontmost app: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown")")
    }

    private static func codeSignatureStatus(bundleURL: URL) -> String {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode)

        guard createStatus == errSecSuccess, let staticCode else {
            return "could not inspect (\(createStatus))"
        }

        let checkStatus = SecStaticCodeCheckValidity(staticCode, [], nil)
        guard checkStatus == errSecSuccess else {
            return "invalid (\(checkStatus))"
        }

        return "valid"
    }

    private static func canCreateRightClickEventTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: diagnosticEventTapCallback,
            userInfo: nil
        ) else {
            return false
        }

        CFMachPortInvalidate(tap)
        return true
    }
}

private let diagnosticEventTapCallback: CGEventTapCallBack = { _, _, event, _ in
    Unmanaged.passUnretained(event)
}
