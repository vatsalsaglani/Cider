import Foundation
import CoreGraphics

public enum NotchEdge: String, Codable, CaseIterable, Sendable {
    case top, left, right, bottom
    public var title: String { rawValue.capitalized }
}

public struct DisplaySnapshot: Sendable, Equatable {
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let scale: CGFloat
    public let cameraWidth: CGFloat
    public let cameraHeight: CGFloat
    public init(frame: CGRect, visibleFrame: CGRect, scale: CGFloat, cameraWidth: CGFloat = 0, cameraHeight: CGFloat = 0) {
        self.frame = frame; self.visibleFrame = visibleFrame; self.scale = scale
        self.cameraWidth = cameraWidth; self.cameraHeight = cameraHeight
    }
}

public enum NotchGeometry {
    public static func frame(display: DisplaySnapshot, edge: NotchEdge, expanded: Bool, position: Double = 0.5) -> CGRect {
        let d = display, bounds = edge == .top ? d.frame : d.visibleFrame
        let vertical = edge == .left || edge == .right
        let compactWidth = vertical ? 58.0 : max(260, d.cameraWidth + 160)
        let size = CGSize(width: min(bounds.width, expanded ? 440 : compactWidth),
                          height: min(bounds.height, expanded ? 350 + d.cameraHeight : (vertical ? 160 : max(32, d.cameraHeight))))
        let t = CGFloat(min(1, max(0, position)))
        let x: CGFloat, y: CGFloat
        switch edge {
        case .top:
            x = bounds.minX + (bounds.width - size.width) * (d.cameraWidth > 0 ? 0.5 : t)
            y = bounds.maxY - size.height
        case .bottom:
            x = bounds.minX + (bounds.width - size.width) * t; y = bounds.minY
        case .left:
            x = bounds.minX; y = bounds.minY + (bounds.height - size.height) * t
        case .right:
            x = bounds.maxX - size.width; y = bounds.minY + (bounds.height - size.height) * t
        }
        let scale = max(1, d.scale)
        func pixel(_ value: CGFloat) -> CGFloat { (value * scale).rounded() / scale }
        return CGRect(x: pixel(x), y: pixel(y), width: pixel(size.width), height: pixel(size.height))
    }
}
