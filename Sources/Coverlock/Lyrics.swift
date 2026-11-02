import Combine
import Foundation

struct LyricLine: Equatable {
    /// Seconds from the start of the track.
    let time: Double
    let text: String
}

/// Time-synced lyrics from LRCLIB (https://lrclib.net), a free public lyrics database.
/// Only the title, artist, album and duration of the track are sent.
final class LyricsStore: ObservableObject {
    @Published private(set) var lines: [LyricLine] = []

    private let nowPlaying: NowPlaying
    private var cache: [String: [LyricLine]] = [:]
    private var currentID: String?
    private var subscription: AnyCancellable?

    init(nowPlaying: NowPlaying) {
        self.nowPlaying = nowPlaying
    }

    func start() {
        subscription = nowPlaying.$track
            .removeDuplicates()
            .sink { [weak self] in self?.load($0) }
    }

    /// The line being sung at `position`, or nil before the first one.
    static func index(in lines: [LyricLine], at position: Double) -> Int? {
        lines.lastIndex { $0.time <= position + 0.2 }
    }

    private func load(_ track: Track?) {
        lines = []
        currentID = track?.id
        guard let track, Settings.lyrics else { return }
        if let cached = cache[track.id] {
            lines = cached
            return
        }
        Task {
            let fetched = await Self.fetch(track)
            await MainActor.run {
                self.cache[track.id] = fetched
                if self.currentID == track.id { self.lines = fetched }
            }
        }
    }

    private static func fetch(_ track: Track) async -> [LyricLine] {
        var exact = URLComponents(string: "https://lrclib.net/api/get")!
        exact.queryItems = [
            .init(name: "track_name", value: track.title),
            .init(name: "artist_name", value: track.artist),
            .init(name: "album_name", value: track.album),
            .init(name: "duration", value: String(Int(track.duration.rounded()))),
        ]
        if let match = await request(exact.url!) as? [String: Any],
           let synced = match["syncedLyrics"] as? String {
            return parse(synced)
        }

        // The exact lookup is strict about album and duration; fall back to a search.
        var search = URLComponents(string: "https://lrclib.net/api/search")!
        search.queryItems = [
            .init(name: "track_name", value: track.title),
            .init(name: "artist_name", value: track.artist),
        ]
        let results = await request(search.url!) as? [[String: Any]] ?? []
        let synced = results.filter { $0["syncedLyrics"] is String }
        let best = synced.first {
            abs((($0["duration"] as? NSNumber)?.doubleValue ?? 0) - track.duration) < 3
        } ?? synced.first
        return (best?["syncedLyrics"] as? String).map(parse) ?? []
    }

    private static func request(_ url: URL) async -> Any? {
        var request = URLRequest(url: url)
        request.setValue("Coverlock (https://github.com/krabduke/coverlock)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    /// Parses LRC: `[mm:ss.xx] text`, where one line may carry several timestamps.
    static func parse(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for raw in lrc.split(whereSeparator: \.isNewline) {
            var rest = Substring(raw)
            var times: [Double] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let parts = rest[rest.index(after: rest.startIndex)..<close].split(separator: ":")
                if parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) {
                    times.append(minutes * 60 + seconds)
                }
                rest = rest[rest.index(after: close)...]
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            lines += times.map { LyricLine(time: $0, text: text) }
        }
        return lines.sorted { $0.time < $1.time }
    }
}
