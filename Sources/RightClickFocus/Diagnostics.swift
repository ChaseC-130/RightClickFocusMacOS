import AppKit
import ApplicationServices
import Foundation
import Security

enum Diagnostics {
    static func run(outputPath: String? = nil) {
        let report = makeReport() + "\n"

        if let outputPath {
            do {
                try report.write(
                    to: URL(fileURLWithPath: outputPath),
                    atomically: true,
                    encoding: .utf8
                )
            } catch {
                print(report)
                print("Could not write diagnostic report: \(error)")
            }
        } else {
            print(report)
        }
    }

    private static func makeReport() -> String {
        let bundle = Bundle.main
        let executableURL = bundle.executableURL
        let bundleURL = bundle.bundleURL

        return [
            "RightClickFocus Diagnostics",
            "===========================",
            "Launch mode: LaunchServices app bundle",
            "Bundle identifier: \(bundle.bundleIdentifier ?? "missing")",
            "Bundle path: \(bundleURL.path)",
            "Executable path: \(executableURL?.path ?? "missing")",
            "Process path: \(CommandLine.arguments.first ?? "missing")",
            "Code signature: \(codeSignatureStatus(bundleURL: bundleURL))",
            "Accessibility trusted: \(AXIsProcessTrusted() ? "yes" : "no")",
            "Input Monitoring preflight: \(CGPreflightListenEventAccess() ? "yes" : "no")",
            "Right-click event tap creatable: \(canCreateRightClickEventTap() ? "yes" : "no")",
            "Launch at Login: \(LaunchAtLoginController.statusDescription)",
            "Menu bar icon preference: \(Preferences.showMenuBarIcon ? "shown" : "hidden")",
            "Frontmost app: \(NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown")"
        ].joined(separator: "\n")
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
