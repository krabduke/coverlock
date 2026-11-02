import AppKit

struct Track: Equatable {
    var id: String
    var title: String
    var artist: String
    var album: String
    /// Seconds.
    var duration: Double
}

/// What's playing in Spotify or Music. Driven by the notifications both apps broadcast on
/// every play, pause, skip and track change, so nothing polls while the Mac is unlocked.
final class NowPlaying: ObservableObject {
    @Published private(set) var app: PlayerApp?
    @Published private(set) var track: Track?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var isPlaying = false

    private var anchorPosition: Double = 0
    private var anchorDate = Date()

    func position(at date: Date = Date()) -> Double {
        isPlaying ? anchorPosition + date.timeIntervalSince(anchorDate) : anchorPosition
    }

    func start() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(spotifyChanged(_:)),
                           name: .init("com.spotify.client.PlaybackStateChanged"), object: nil)
        center.addObserver(self, selector: #selector(musicChanged(_:)),
                           name: .init("com.apple.Music.playerInfo"), object: nil)
        refresh(.spotify)
        if track == nil { refresh(.music) }
    }

    // MARK: Controls

    func playPause() { send("playpause") }
    func next() { send("next track") }
    func previous() { send("previous track") }

    private func send(_ command: String) {
        guard let app else { return }
        Script.tell(app, command)
    }

    /// Re-reads the playhead, which the notifications don't always include (e.g. after a seek).
    func syncPosition() {
        guard let app, let position = Script.tell(app, "player position")?.doubleValue else { return }
        anchorPosition = position
        anchorDate = Date()
    }

    // MARK: Notifications

    @objc private func spotifyChanged(_ note: Notification) {
        let info = note.userInfo ?? [:]
        let state = info["Player State"] as? String
        guard state != "Stopped", let id = info["Track ID"] as? String else {
            clear(.spotify)
            return
        }
        let track = Track(
            id: id,
            title: info["Name"] as? String ?? "",
            artist: info["Artist"] as? String ?? "",
            album: info["Album"] as? String ?? "",
            duration: ((info["Duration"] as? NSNumber)?.doubleValue ?? 0) / 1000
        )
        update(.spotify, track: track, playing: state == "Playing",
               position: (info["Playback Position"] as? NSNumber)?.doubleValue)
    }

    @objc private func musicChanged(_ note: Notification) {
        let info = note.userInfo ?? [:]
        let state = info["Player State"] as? String
        guard state != "Stopped", let title = info["Name"] as? String else {
            clear(.music)
            return
        }
        let artist = info["Artist"] as? String ?? ""
        let track = Track(
            id: (info["PersistentID"] as? NSNumber)?.stringValue ?? "\(title)|\(artist)",
            title: title,
            artist: artist,
            album: info["Album"] as? String ?? "",
            duration: ((info["Total Time"] as? NSNumber)?.doubleValue ?? 0) / 1000
        )
        update(.music, track: track, playing: state == "Playing", position: nil)
    }

    /// Reads the current state directly, for when Coverlock starts after the music did.
    private func refresh(_ source: PlayerApp) {
        let idProperty = source == .spotify ? "id" : "persistent ID"
        let script = """
        if player state is stopped then return {}
        set t to current track
        return {\(idProperty) of t, name of t, artist of t, album of t, duration of t, player position, player state as text}
        """
        guard let result = Script.tell(source, script), result.numberOfItems == 7 else { return }
        let duration = result.item(5)?.doubleValue ?? 0
        let track = Track(
            id: result.item(1)?.stringValue ?? "",
            title: result.item(2)?.stringValue ?? "",
            artist: result.item(3)?.stringValue ?? "",
            album: result.item(4)?.stringValue ?? "",
            // Spotify reports milliseconds, Music reports seconds.
            duration: source == .spotify ? duration / 1000 : duration
        )
        update(source, track: track, playing: result.item(7)?.stringValue == "playing",
               position: result.item(6)?.doubleValue)
    }

    private func update(_ source: PlayerApp, track new: Track, playing: Bool, position: Double?) {
        // A pause from one app shouldn't take over while the other one is playing.
        if let app, app != source, isPlaying, !playing { return }

        let changed = new.id != track?.id || source != app
        anchorPosition = position ?? (changed ? 0 : self.position())
        anchorDate = Date()
        app = source
        isPlaying = playing
        if changed {
            artwork = nil
            track = new
            loadArtwork(source, trackID: new.id)
        }
        if position == nil { syncPosition() }
    }

    private func clear(_ source: PlayerApp) {
        guard app == source || app == nil else { return }
        app = nil
        track = nil
        artwork = nil
        isPlaying = false
    }

    // MARK: Artwork

    private func loadArtwork(_ source: PlayerApp, trackID: String) {
        switch source {
        case .spotify:
            guard let string = Script.tell(.spotify, "artwork url of current track")?.stringValue,
                  let url = URL(string: string) else { return }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async { self?.setArtwork(image, for: trackID) }
            }.resume()
        case .music:
            if let data = Script.tell(.music, "get data of artwork 1 of current track")?.data,
               let image = NSImage(data: data) {
                setArtwork(image, for: trackID)
            }
        }
    }

    private func setArtwork(_ image: NSImage, for trackID: String) {
        guard track?.id == trackID else { return }
        artwork = image
    }
}
