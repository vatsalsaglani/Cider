import CoreGraphics

/// Top-edge outline, including concave shoulders. Other edges rotate this same geometry.
public enum NotchOutline {
    public static func path(in rect: CGRect, edge: NotchEdge) -> CGPath {
        let vertical = edge == .left || edge == .right
        let w = vertical ? rect.height : rect.width, h = vertical ? rect.width : rect.height
        let shoulder = min(12.0, h / 3), radius = min(22.0, h / 2)
        let p = CGMutablePath()
        p.move(to: .zero); p.addLine(to: CGPoint(x: w, y: 0))
        p.addQuadCurve(to: CGPoint(x: w - shoulder, y: shoulder), control: CGPoint(x: w - shoulder, y: 0))
        p.addLine(to: CGPoint(x: w - shoulder, y: h - radius))
        p.addQuadCurve(to: CGPoint(x: w - shoulder - radius, y: h), control: CGPoint(x: w - shoulder, y: h))
        p.addLine(to: CGPoint(x: shoulder + radius, y: h))
        p.addQuadCurve(to: CGPoint(x: shoulder, y: h - radius), control: CGPoint(x: shoulder, y: h))
        p.addLine(to: CGPoint(x: shoulder, y: shoulder))
        p.addQuadCurve(to: .zero, control: CGPoint(x: shoulder, y: 0)); p.closeSubpath()
        var transform: CGAffineTransform
        switch edge {
        case .top: transform = .identity
        case .bottom: transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)
        case .left: transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        case .right: transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: h, ty: 0)
        }
        transform.tx += rect.minX; transform.ty += rect.minY
        return p.copy(using: &transform)!
    }
}
