import AppKit
import Combine
import SwiftUI

/// Shows the player on every screen while the Mac is locked and something is loaded in
/// Spotify or Music, and hides it again on unlock.
final class LockScreenController {
    private let nowPlaying: NowPlaying
    private let lyrics: LyricsStore
    private var windows: [NSWindow] = []
    private var isLocked = false
    private var previewTimer: Timer?
    private var resyncTimer: Timer?
    private var subscriptions: Set<AnyCancellable> = []

    private var isActive: Bool { isLocked || previewTimer != nil }

    init(nowPlaying: NowPlaying, lyrics: LyricsStore) {
        self.nowPlaying = nowPlaying
        self.lyrics = lyrics
    }

    func start() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.locked()
        }
        center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.unlocked()
        }

        // @Published fires before the value changes; hop a run loop turn to read the new one.
        nowPlaying.$track.map { $0?.id }.removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.trackChanged() }
            .store(in: &subscriptions)
    }

    /// Shows the lock screen player over the desktop for a few seconds, without locking.
    func preview() {
        endPreview()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            self?.endPreview()
        }
        present(onLockScreen: false)
    }

    /// Renders the lock screen player for the main screen to a PNG, for checking the layout
    /// without needing screen recording permission.
    @MainActor
    func snapshot(to url: URL, backdrop: Backdrop) {
        guard let screen = NSScreen.main else { return }
        let renderer = ImageRenderer(content: LockScreenView(
            nowPlaying: nowPlaying, lyrics: lyrics, backdrop: backdrop,
            showLyrics: Settings.lyrics, size: screen.frame.size
        ))
        renderer.scale = screen.backingScaleFactor
        guard let image = renderer.cgImage else { return }
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
    }

    private func endPreview() {
        guard previewTimer != nil else { return }
        previewTimer?.invalidate()
        previewTimer = nil
        if !isLocked { dismiss() }
    }

    private func locked() {
        NSLog("Coverlock: screen locked, track=\(nowPlaying.track?.title ?? "none")")
        isLocked = true
        endPreview()
        present(onLockScreen: true)
        // The playhead can drift from seeks that don't post a notification; keep lyrics honest.
        resyncTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, self.nowPlaying.isPlaying else { return }
            self.nowPlaying.syncPosition()
        }
    }

    private func unlocked() {
        NSLog("Coverlock: screen unlocked")
        isLocked = false
        resyncTimer?.invalidate()
        resyncTimer = nil
        dismiss()
    }

    private func trackChanged() {
        guard isActive else { return }
        if nowPlaying.track == nil {
            dismiss()
        } else if windows.isEmpty {
            present(onLockScreen: isLocked)
        }
    }

    private func present(onLockScreen: Bool) {
        guard Settings.enabled, windows.isEmpty, nowPlaying.track != nil else { return }
        if onLockScreen && !SkyLight.shared.isAvailable { return }

        let backdrop = Settings.backdrop

        for screen in NSScreen.screens {
            let window = LockScreenWindow(screen: screen)
            window.contentView = FirstMouseHostingView(rootView: LockScreenView(
                nowPlaying: nowPlaying, lyrics: lyrics,
                backdrop: backdrop, showLyrics: Settings.lyrics, size: screen.frame.size
            ))
            window.alphaValue = 0
            window.orderFrontRegardless()
            if onLockScreen { SkyLight.shared.attach(window) }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.4
                window.animator().alphaValue = 1
            }
            windows.append(window)
        }
        NSLog("Coverlock: showing on \(windows.count) screen(s), lockScreen=\(onLockScreen), background=\(backdrop.rawValue)")
    }

    private func dismiss() {
        for window in windows {
            SkyLight.shared.detach(window)
            window.orderOut(nil)
            window.close()
        }
        windows = []
    }
}

/// Borderless, never key: keystrokes on the lock screen always go to the password field,
/// so Coverlock can never see what is typed there.
private final class LockScreenWindow: NSPanel {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        level = .screenSaver
        canBecomeVisibleWithoutLogin = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Lets the play/skip buttons respond to the first click on a window that is never key.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
