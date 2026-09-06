import SwiftUI
import AppKit
public struct AppMark: View {
    public init() {}
    public var body: some View {
        if let image = NSImage(contentsOf: Bundle.main.bundleURL.appending(path: "Contents/Resources/Cider_CiderPlatform.bundle/Resources").appending(path: "branding/cider.png")) { Image(nsImage: image).resizable().scaledToFit().frame(width: 26, height: 26).clipShape(RoundedRectangle(cornerRadius: 7)).accessibilityHidden(true) }
    }
}
