import SwiftUI

/// Everything drawn on the lock screen. The system clock sits in roughly the top quarter
/// and the profile picture and password field in the bottom fifth, so the player lives in
/// the band between them.
struct LockScreenView: View {
    @ObservedObject var nowPlaying: NowPlaying
    @ObservedObject var lyrics: LyricsStore
    let backdrop: Backdrop
    let showLyrics: Bool
    /// The screen size, passed in rather than read from a GeometryReader so the layout is
    /// identical in the lock screen window and in `ImageRenderer` snapshots.
    let size: CGSize

    var body: some View {
        ZStack {
            if backdrop == .overlay {
                CoverBackdrop(artwork: nowPlaying.artwork)
                    // A square cover filling a wide screen is taller than it; pin it to the
                    // screen so it doesn't stretch the stack and push everything up.
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    // Fade out over the password field so it stays visible and clickable.
                    .mask(LinearGradient(stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.72),
                        .init(color: .clear, location: 0.84),
                    ], startPoint: .top, endPoint: .bottom))
                // The overlay hides the system clock, so draw one in its place.
                LockClock(height: size.height)
                    .position(x: size.width / 2, y: size.height * 0.15)
            }
            if let track = nowPlaying.track {
                Player(track: track, nowPlaying: nowPlaying, lyrics: lyrics,
                       showLyrics: showLyrics, coverSize: min(size.height * 0.3, 380))
                    .frame(maxWidth: min(size.width * 0.8, 1040))
                    .position(x: size.width / 2, y: size.height * 0.5)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.easeInOut(duration: 0.5), value: nowPlaying.track?.id)
        .ignoresSafeArea()
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

private struct CoverBackdrop: View {
    let artwork: NSImage?

    var body: some View {
        ZStack {
            Color.black
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    // Oversized so the blur's soft edges fall outside the screen.
                    .scaleEffect(1.3)
                    .blur(radius: 90, opaque: true)
                    .saturation(1.25)
                    .transition(.opacity)
            }
            Color.black.opacity(0.28)
        }
        .clipped()
    }
}

private struct LockClock: View {
    let height: CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 0) {
                Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: height * 0.022, weight: .semibold, design: .rounded))
                    .opacity(0.85)
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: height * 0.11, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}

private struct Player: View {
    let track: Track
    @ObservedObject var nowPlaying: NowPlaying
    @ObservedObject var lyrics: LyricsStore
    let showLyrics: Bool
    let coverSize: CGFloat

    var body: some View {
        if showLyrics && !lyrics.lines.isEmpty {
            withLyrics
        } else {
            centered
        }
    }

    /// No lyrics: one centred column, cover on top and the song name underneath.
    private var centered: some View {
        // A touch smaller than with lyrics, so the taller column clears the clock above
        // and the password field below.
        let coverSize = coverSize * 0.9
        return VStack(spacing: 0) {
            Cover(image: nowPlaying.artwork, size: coverSize)
            VStack(spacing: 6) {
                Text(track.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .opacity(0.7)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)
            .frame(width: coverSize * 1.6)
            .padding(.top, 30)
            Progress(nowPlaying: nowPlaying, duration: track.duration)
                .frame(width: coverSize)
                .padding(.top, 22)
            Controls(nowPlaying: nowPlaying)
                .padding(.top, 10)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 2)
    }

    /// Lyrics on: cover and controls on the left, song name and lyrics on the right.
    private var withLyrics: some View {
        HStack(alignment: .center, spacing: coverSize * 0.18) {
            VStack(spacing: 20) {
                Cover(image: nowPlaying.artwork, size: coverSize)
                Progress(nowPlaying: nowPlaying, duration: track.duration)
                    .frame(width: coverSize)
                Controls(nowPlaying: nowPlaying)
            }
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .opacity(0.7)
                        .lineLimit(1)
                }
                if showLyrics && !lyrics.lines.isEmpty {
                    LyricsView(lines: lyrics.lines, nowPlaying: nowPlaying)
                        .frame(height: coverSize * 0.95, alignment: .top)
                        .clipped()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .shadow(color: .black.opacity(0.25), radius: 10, y: 2)
    }
}

private struct Cover: View {
    let image: NSImage?
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                .fill(.white.opacity(0.12))
            Image(systemName: "music.note")
                .font(.system(size: size * 0.28))
                .opacity(0.5)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.04, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 32, y: 18)
        .animation(.easeInOut(duration: 0.4), value: image)
    }
}

private struct Progress: View {
    @ObservedObject var nowPlaying: NowPlaying
    let duration: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let position = min(max(nowPlaying.position(at: context.date), 0), max(duration, 0))
            let fraction = duration > 0 ? position / duration : 0
            VStack(spacing: 7) {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        GeometryReader { bar in
                            Capsule().fill(.white).frame(width: bar.size.width * fraction)
                        }
                    }
                HStack {
                    Text(Self.format(position))
                    Spacer()
                    Text("-" + Self.format(duration - position))
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .opacity(0.6)
            }
        }
    }

    private static func format(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct Controls: View {
    @ObservedObject var nowPlaying: NowPlaying

    var body: some View {
        HStack(spacing: 40) {
            button("backward.fill", size: 24, action: nowPlaying.previous)
            button(nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 38, action: nowPlaying.playPause)
            button("forward.fill", size: 24, action: nowPlaying.next)
        }
    }

    private func button(_ symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct LyricsView: View {
    let lines: [LyricLine]
    @ObservedObject var nowPlaying: NowPlaying

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let current = LyricsStore.index(in: lines, at: nowPlaying.position(at: context.date))
            let first = max((current ?? 0) - 1, 0)
            let visible = first..<min(first + 5, lines.count)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(visible, id: \.self) { index in
                    let isCurrent = index == current
                    Text(lines[index].text.isEmpty ? "♪" : lines[index].text)
                        .font(.system(size: isCurrent ? 36 : 24, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .opacity(isCurrent ? 1 : (current.map { index < $0 } ?? false) ? 0.3 : 0.5)
                }
            }
            .animation(.spring(duration: 0.5), value: current)
        }
    }
}
