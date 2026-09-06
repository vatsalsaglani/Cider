import SwiftUI

public struct WorkspaceBackdrop: View {
    public init() {}
    public var body: some View {
        ZStack(alignment: .topLeading) {
            CiderColor.background
            RadialGradient(colors: [CiderColor.backdropEmber.opacity(0.48), .clear], center: .topLeading, startRadius: 0, endRadius: 720)
        }.ignoresSafeArea()
    }
}
