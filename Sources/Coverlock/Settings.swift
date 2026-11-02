import Foundation

enum Backdrop: String, CaseIterable {
    /// Swap the real wallpaper for the blurred cover while locked, so the system clock and
    /// password field draw on top of it natively.
    case wallpaper
    /// Draw the blurred cover in our own lock-screen window. Covers the system clock, so we
    /// draw our own, and fades out at the bottom so the password field stays visible.
    case overlay
    /// Leave the lock-screen background alone and only show the player.
    case off

    var title: String {
        switch self {
        case .wallpaper: "Album art as wallpaper"
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
            "backdrop": Backdrop.wallpaper.rawValue,
            "lyrics": true,
        ])
    }

    static var enabled: Bool {
        get { defaults.bool(forKey: "enabled") }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    static var backdrop: Backdrop {
        get { Backdrop(rawValue: defaults.string(forKey: "backdrop") ?? "") ?? .wallpaper }
        set { defaults.set(newValue.rawValue, forKey: "backdrop") }
    }

    static var lyrics: Bool {
        get { defaults.bool(forKey: "lyrics") }
        set { defaults.set(newValue, forKey: "lyrics") }
    }
}
