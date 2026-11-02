import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let nowPlaying = NowPlaying()
    private lazy var lyrics = LyricsStore(nowPlaying: nowPlaying)
    private lazy var lockScreen = LockScreenController(nowPlaying: nowPlaying, lyrics: lyrics)
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.register()
        nowPlaying.start()
        lyrics.start()
        lockScreen.start()

        // Lets `scripts/preview.sh` show the preview without clicking the menu.
        DistributedNotificationCenter.default().addObserver(
            forName: .init("com.krabduke.coverlock.preview"), object: nil, queue: .main
        ) { [weak self] _ in self?.lockScreen.preview() }
        // `scripts/snapshot.sh <path> [overlay|off]` renders the player to a PNG.
        DistributedNotificationCenter.default().addObserver(
            forName: .init("com.krabduke.coverlock.snapshot"), object: nil, queue: .main
        ) { [weak self] note in
            guard let path = note.object as? String else { return }
            let parts = path.split(separator: "|").map(String.init)
            let backdrop = parts.count > 1 ? Backdrop(rawValue: parts[1]) ?? .overlay : .overlay
            MainActor.assumeIsolated {
                self?.lockScreen.snapshot(to: URL(fileURLWithPath: parts[0]), backdrop: backdrop)
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Coverlock")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let playing = nowPlaying.track.map { "\($0.title) — \($0.artist)" } ?? "Nothing playing"
        menu.addItem(withTitle: playing, action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        menu.addItem(item("Show on lock screen", checked: Settings.enabled) { Settings.enabled.toggle() })
        menu.addItem(item("Show lyrics", checked: Settings.lyrics) { Settings.lyrics.toggle() })

        let background = NSMenuItem(title: "Background", action: nil, keyEquivalent: "")
        let backgrounds = NSMenu()
        for backdrop in Backdrop.allCases {
            backgrounds.addItem(item(backdrop.title, checked: Settings.backdrop == backdrop) {
                Settings.backdrop = backdrop
            })
        }
        background.submenu = backgrounds
        menu.addItem(background)

        let preview = item("Preview for 10 seconds", checked: false) { [weak self] in self?.lockScreen.preview() }
        preview.isEnabled = nowPlaying.track != nil
        menu.addItem(preview)
        menu.addItem(.separator())

        let loginItem = SMAppService.mainApp
        menu.addItem(item("Open at login", checked: loginItem.status == .enabled) {
            do {
                if loginItem.status == .enabled { try loginItem.unregister() } else { try loginItem.register() }
            } catch {
                NSLog("Coverlock: login item change failed: \(error)")
            }
        })
        menu.addItem(withTitle: "Quit Coverlock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func item(_ title: String, checked: Bool, action: @escaping () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, action: action)
        item.state = checked ? .on : .off
        return item
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}
