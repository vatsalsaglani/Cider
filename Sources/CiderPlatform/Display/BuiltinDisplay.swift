import AppKit
import CiderDomain

@MainActor
enum BuiltinDisplay {
    static func resolve() -> (NSScreen, DisplaySnapshot)? {
        guard let screen = NSScreen.screens.first(where: { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(number.uint32Value) != 0
        }) else { return nil }
        let cameraWidth: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            cameraWidth = max(0, right.minX - left.maxX)
        } else { cameraWidth = 0 }
        return (screen, DisplaySnapshot(frame: screen.frame, visibleFrame: screen.visibleFrame,
                                       scale: screen.backingScaleFactor, cameraWidth: cameraWidth,
                                       cameraHeight: cameraWidth > 0 ? screen.safeAreaInsets.top : 0))
    }
}
