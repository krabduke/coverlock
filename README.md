# Coverlock

A lock-screen music player for macOS. While Spotify or Apple Music is playing, Coverlock
puts the album cover across your lock screen with the track, a progress bar,
⏮ ⏯ ⏭ controls and, if you want them, time-synced lyrics. It only changes the lock screen:
your desktop wallpaper is never touched.

![Coverlock on the lock screen](docs/screenshot.jpg)

## Install

On a new Mac, paste this into Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/krabduke/coverlock/main/install.sh | zsh
```

It installs **Coverlock**, **[Faders](https://github.com/krabduke/faders)** (per-app volume
from the menu bar) and **[Boring Notch](https://github.com/TheBoredTeam/boring.notch)** (a free
Dynamic Island for the notch), and opens them. Add `-s -- --coverlock-only` after `zsh` to
install just Coverlock.

Then:

1. **Turn on login items**, or the apps won't come back after a restart: tick
   **Open at login** in Coverlock's ♪ menu and at the bottom of the Faders panel, and
   **Launch at login** in Boring Notch's settings (⭐ menu).
2. **Allow the permission prompts.** Coverlock asks to control Spotify / Music. Faders asks
   for "Screen & System Audio Recording" the first time you change an app's volume. Boring
   Notch asks for Accessibility, which macOS 27 calls "Device Control and Data Access".

The prebuilt download runs on Apple Silicon Macs with macOS 14 or later. On an Intel Mac,
build it from source (below).

## Using it

Everything lives in the ♪ menu-bar icon:

| Menu item | What it does |
|---|---|
| Show on lock screen | Turns the lock-screen player on or off |
| Show lyrics | Time-synced lyrics from [LRCLIB](https://lrclib.net) beside the cover. Off, the cover sits centred with the song name underneath |
| Background | **Album art overlay** (the blurred cover fills the lock screen, fading out above the password field) or **Keep my wallpaper** (only the player is shown). Neither changes your desktop |
| Preview for 10 seconds | Shows the player over your desktop without locking |
| Open at login | Starts Coverlock automatically |

Lyrics lookups send only the song title, artist, album and length to LRCLIB.

## Build from source

Needs the Xcode command line tools (`xcode-select --install`).

```sh
git clone https://github.com/krabduke/coverlock.git
cd coverlock
./build.sh --install    # builds, copies to /Applications, launches
```

`scripts/release.sh vX.Y.Z` builds the app and publishes it as a GitHub release, which
is what the installer downloads.

## How it works

- **Now playing:** Spotify and Music broadcast a notification on every play, pause and
  track change. Coverlock listens for those rather than polling, and uses AppleScript for
  the controls.
- **Drawing on the lock screen:** windows are moved into a private SkyLight space that
  sits above the lock screen. This is the technique from
  [Lakr233/SkyLightWindow](https://github.com/Lakr233/SkyLightWindow) (MIT), which Boring
  Notch also uses. It relies on private macOS API, so a macOS update can break it.

## License

MIT
