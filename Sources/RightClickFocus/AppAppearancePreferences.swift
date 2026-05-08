import Foundation

final class AppAppearancePreferences {
    private enum Key {
        static let showInDock = "showInDock"
        static let showInMenuBar = "showInMenuBar"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.showInDock: true,
            Key.showInMenuBar: true
        ])
        ensureVisibleControlSurface()
    }

    var showInDock: Bool {
        get { defaults.bool(forKey: Key.showInDock) }
        set {
            defaults.set(newValue, forKey: Key.showInDock)
            ensureVisibleControlSurface()
        }
    }

    var showInMenuBar: Bool {
        get { defaults.bool(forKey: Key.showInMenuBar) }
        set {
            defaults.set(newValue, forKey: Key.showInMenuBar)
            ensureVisibleControlSurface()
        }
    }

    func ensureVisibleControlSurface() {
        if !defaults.bool(forKey: Key.showInDock), !defaults.bool(forKey: Key.showInMenuBar) {
            defaults.set(true, forKey: Key.showInDock)
        }
    }
}
