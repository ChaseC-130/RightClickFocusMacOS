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
    }

    var showInDock: Bool {
        get { defaults.bool(forKey: Key.showInDock) }
        set {
            defaults.set(newValue, forKey: Key.showInDock)
        }
    }

    var showInMenuBar: Bool {
        get { defaults.bool(forKey: Key.showInMenuBar) }
        set {
            defaults.set(newValue, forKey: Key.showInMenuBar)
        }
    }
}
