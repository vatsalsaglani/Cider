import SwiftUI
import AppKit
public struct BrandImage: View {
    let name: String
    let size: CGFloat
    public init(_ name: String, size: CGFloat = 28) { self.name = name; self.size = size }
    public var body: some View {
        if let image = NSImage(contentsOf: Bundle.main.bundleURL.appending(path: "Contents/Resources/Cider_CiderPlatform.bundle/Resources").appending(path: "brands/\(name).svg")) { Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size) }
    }
}
