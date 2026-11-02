import AppKit

enum PlayerApp: String {
    case spotify = "com.spotify.client"
    case music = "com.apple.Music"

    var name: String {
        switch self {
        case .spotify: "Spotify"
        case .music: "Music"
        }
    }

    /// AppleScript would launch the app if it isn't running, so every script checks this first.
    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: rawValue).isEmpty
    }
}

enum Script {
    @discardableResult
    static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("Coverlock: AppleScript failed: \(error)")
            return nil
        }
        return result
    }

    @discardableResult
    static func tell(_ app: PlayerApp, _ body: String) -> NSAppleEventDescriptor? {
        guard app.isRunning else { return nil }
        return run("tell application \"\(app.name)\"\n\(body)\nend tell")
    }
}

extension NSAppleEventDescriptor {
    /// AppleScript lists are 1-indexed.
    func item(_ index: Int) -> NSAppleEventDescriptor? {
        index <= numberOfItems ? atIndex(index) : nil
    }
}
