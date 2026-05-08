import Foundation

enum Preferences {
    static let changedNotification = Notification.Name("com.chasecargill.RightClickFocus.preferencesChanged")

    private enum Key {
        static let showMenuBarIcon = "ShowMenuBarIcon"
    }

    static var showMenuBarIcon: Bool {
        get {
            guard UserDefaults.standard.object(forKey: Key.showMenuBarIcon) != nil else {
                return true
            }

            return UserDefaults.standard.bool(forKey: Key.showMenuBarIcon)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.showMenuBarIcon)
        }
    }

    static func notifyChanged() {
        DistributedNotificationCenter.default().post(name: changedNotification, object: nil)
    }
}
