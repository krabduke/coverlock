import AppKit
import CoreImage

/// Temporarily replaces the desktop wallpaper (which macOS also shows on the lock screen)
/// with a blurred version of the album cover, and puts the original back afterwards.
///
/// `NSWorkspace.setDesktopImageURL` only changes the current Space, and rewrites a single
/// "all desktops" wallpaper into one entry per Space as a side effect, so it can't be used
/// to undo itself. Instead the wallpaper agent's whole store is snapshotted before the
/// first swap and written back byte for byte afterwards. The snapshot lives on disk, so if
/// Coverlock quits or crashes while locked it is restored on the next launch.
final class Wallpaper {
    static let shared = Wallpaper()

    private let store = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    private let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Coverlock", isDirectory: true)
    private var snapshot: URL { folder.appendingPathComponent("wallpaper-store-snapshot.plist") }
    private let context = CIContext()
    private var generation = 0

    func apply(_ artwork: NSImage) {
        guard let cover = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: snapshot.path) {
            do {
                try FileManager.default.copyItem(at: store, to: snapshot)
            } catch {
                // Without a snapshot there is no safe way back, so leave the wallpaper alone.
                NSLog("Coverlock: could not snapshot wallpaper settings, not changing wallpaper: \(error)")
                return
            }
        }

        // A new file name every time: macOS caches wallpapers by URL.
        generation += 1
        for screen in NSScreen.screens {
            let size = CGSize(width: screen.frame.width * screen.backingScaleFactor,
                              height: screen.frame.height * screen.backingScaleFactor)
            guard let data = render(cover, size: size) else { continue }
            let url = folder.appendingPathComponent("cover-\(generation)-\(screen.id).jpg")
            do {
                try data.write(to: url)
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [
                    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true,
                ])
            } catch {
                NSLog("Coverlock: could not set wallpaper: \(error)")
            }
        }
        removeCovers(keeping: generation)
    }

    func restore() {
        guard FileManager.default.fileExists(atPath: snapshot.path) else { return }
        do {
            _ = try FileManager.default.replaceItemAt(store, withItemAt: snapshot)
        } catch {
            NSLog("Coverlock: could not restore wallpaper settings (snapshot kept at \(snapshot.path)): \(error)")
            return
        }
        // The agent only reads its store at launch; launchd restarts it straight away.
        let agent = Process()
        agent.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        agent.arguments = ["WallpaperAgent"]
        try? agent.run()
        // Give the agent a moment to switch away before deleting the cover files.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.removeCovers(keeping: nil) }
    }

    /// The cover scaled to fill the screen, heavily blurred and slightly darkened so white
    /// text stays readable on bright covers.
    private func render(_ cover: CGImage, size: CGSize) -> Data? {
        let image = CIImage(cgImage: cover)
        let scale = max(size.width / image.extent.width, size.height / image.extent.height)
        let scaled = image.transformed(by: .init(scaleX: scale, y: scale))
        let crop = CGRect(x: (scaled.extent.width - size.width) / 2,
                          y: (scaled.extent.height - size.height) / 2,
                          width: size.width, height: size.height)
        let output = scaled
            .clampedToExtent()
            .applyingGaussianBlur(sigma: size.width / 36)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.25,
                kCIInputBrightnessKey: -0.1,
            ])
            .cropped(to: crop)
            .transformed(by: .init(translationX: -crop.minX, y: -crop.minY))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return context.jpegRepresentation(of: output, colorSpace: colorSpace, options: [
            CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): 0.9,
        ])
    }

    private func removeCovers(keeping generation: Int?) {
        let keep = generation.map { "cover-\($0)-" }
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("cover-") {
            if let keep, file.lastPathComponent.hasPrefix(keep) { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}

extension NSScreen {
    var id: String {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? localizedName
    }
}
