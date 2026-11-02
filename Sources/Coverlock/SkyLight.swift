import AppKit

/// Moves windows into a private SkyLight space that sits above the lock screen.
///
/// This is the same technique as Lakr233/SkyLightWindow (MIT), which Boring Notch also uses.
/// It relies on private macOS API, so a system update can break it; every symbol is looked
/// up at runtime and the app keeps working (minus the lock screen) if one disappears.
final class SkyLight {
    static let shared = SkyLight()

    /// Above the lock screen (300); the level macOS uses for notifications on the lock screen.
    private static let aboveLockScreenLevel: Int32 = 400

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindowsToSpace = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32
    private typealias RemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32

    private let connection: Int32
    private let space: Int32
    private let addWindows: AddWindowsToSpace?
    private let removeWindows: RemoveWindowsFromSpaces?

    var isAvailable: Bool { addWindows != nil && space != 0 }

    private init() {
        let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW)
        func symbol<T>(_ name: String, as _: T.Type) -> T? {
            dlsym(handle, name).map { unsafeBitCast($0, to: T.self) }
        }

        addWindows = symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", as: AddWindowsToSpace.self)
        removeWindows = symbol("SLSRemoveWindowsFromSpaces", as: RemoveWindowsFromSpaces.self)

        guard let mainConnectionID = symbol("SLSMainConnectionID", as: MainConnectionID.self),
              let spaceCreate = symbol("SLSSpaceCreate", as: SpaceCreate.self),
              let setLevel = symbol("SLSSpaceSetAbsoluteLevel", as: SpaceSetAbsoluteLevel.self),
              let showSpaces = symbol("SLSShowSpaces", as: ShowSpaces.self) else {
            NSLog("Coverlock: SkyLight symbols missing; lock screen display unavailable")
            connection = 0
            space = 0
            return
        }

        connection = mainConnectionID()
        space = spaceCreate(connection, 1, 0)
        _ = setLevel(connection, space, Self.aboveLockScreenLevel)
        _ = showSpaces(connection, [space] as CFArray)
    }

    func attach(_ window: NSWindow) {
        guard isAvailable else { return }
        _ = addWindows?(connection, space, [window.windowNumber] as CFArray, 7)
    }

    func detach(_ window: NSWindow) {
        guard isAvailable else { return }
        _ = removeWindows?(connection, [window.windowNumber] as CFArray, [space] as CFArray)
    }
}
