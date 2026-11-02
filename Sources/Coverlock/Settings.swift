import Foundation

/// Coverlock never touches the desktop wallpaper: everything it shows lives in its own
/// lock-screen window, so the desktop is the same before and after locking. (v0.1 swapped the
/// real wallpaper while locked; a saved "wallpaper" setting now falls back to `.overlay`.)
enum Backdrop: String, CaseIterable {
    /// Draw the blurred cover in our own lock-screen window. Covers the system clock, so we
    /// draw our own, and fades out at the bottom so the password field stays visible.
    case overlay
    /// Leave the lock-screen background alone and only show the player.
    case off

    var title: String {
        switch self {
        case .overlay: "Album art overlay"
        case .off: "Keep my wallpaper"
        }
    }
}

enum Settings {
    private static let defaults = UserDefaults.standard

    static func register() {
        defaults.register(defaults: [
            "enabled": true,
            "backdrop": Backdrop.overlay.rawValue,
            "lyrics": true,
        ])
    }

    static var enabled: Bool {
        get { defaults.bool(forKey: "enabled") }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    static var backdrop: Backdrop {
        get { Backdrop(rawValue: defaults.string(forKey: "backdrop") ?? "") ?? .overlay }
        set { defaults.set(newValue.rawValue, forKey: "backdrop") }
    }

    static var lyrics: Bool {
        get { defaults.bool(forKey: "lyrics") }
        set { defaults.set(newValue, forKey: "lyrics") }
    }
}
