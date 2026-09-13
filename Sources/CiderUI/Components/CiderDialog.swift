import SwiftUI

/// Shared shell for app-owned sheets. File pickers remain system panels.
public struct CiderDialogStyle: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    public func body(content: Content) -> some View {
        content
            .foregroundStyle(CiderColor.textPrimary)
            .tint(CiderColor.accentEnd)
            .buttonStyle(CiderDialogButtonStyle())
            .background {
                ZStack(alignment: .topLeading) {
                    CiderColor.background
                    RadialGradient(colors: [CiderColor.backdropEmber.opacity(0.34), .clear],
                                   center: .topLeading, startRadius: 0, endRadius: 460)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(CiderColor.controlBorder.opacity(contrast == .increased ? 1 : 0.55))
                    .allowsHitTesting(false)
            }
            .presentationBackground(.clear)
            .preferredColorScheme(.dark)
    }
}

public struct CiderDialogButtonStyle: ButtonStyle {
    let primary: Bool
    @Environment(\.isEnabled) private var enabled
    public init(primary: Bool = false) { self.primary = primary }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 18).padding(.vertical, 10)
            .foregroundStyle(primary ? CiderColor.textOnAccent : (configuration.role == .destructive ? CiderColor.failure : CiderColor.textPrimary))
            .background {
                if primary {
                    Capsule().fill(LinearGradient(colors: [CiderColor.accent, CiderColor.accentEnd], startPoint: .leading, endPoint: .trailing))
                } else {
                    Capsule().fill(LinearGradient(colors: [CiderColor.controlTop.opacity(0.65), CiderColor.controlBottom], startPoint: .top, endPoint: .bottom))
                }
            }
            .overlay(Capsule().strokeBorder(CiderColor.controlBorder.opacity(primary ? 0.2 : 0.5)))
            .contentShape(Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.65 : 1) : 0.4)
    }
}

public struct CiderDialogHeading: View {
    let title: String
    let symbol: String
    public init(_ title: String, symbol: String) { self.title = title; self.symbol = symbol }
    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium))
                .foregroundStyle(CiderColor.accentEnd).frame(width: 42, height: 42)
                .background(CiderColor.accentWash, in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            Text(title).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

public extension View {
    func ciderDialog() -> some View { modifier(CiderDialogStyle()) }
    func ciderNotice(_ title: String, message: String, isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            CiderPrompt(title: title, message: message, confirmTitle: "Got it", cancel: nil) { isPresented.wrappedValue = false }
                .onExitCommand { isPresented.wrappedValue = false }
        }
    }
    func ciderConfirmation(_ title: String, message: String, isPresented: Binding<Bool>, confirmTitle: String,
                           confirm: @escaping () -> Void) -> some View {
        sheet(isPresented: isPresented) {
            CiderPrompt(title: title, message: message, confirmTitle: confirmTitle,
                        cancel: { isPresented.wrappedValue = false }) {
                isPresented.wrappedValue = false; confirm()
            }.onExitCommand { isPresented.wrappedValue = false }
        }
    }
}

public struct CiderPrompt: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancel: (() -> Void)?
    let confirm: () -> Void
    public init(title: String, message: String, confirmTitle: String, cancel: (() -> Void)? = nil, confirm: @escaping () -> Void) {
        self.title = title; self.message = message; self.confirmTitle = confirmTitle; self.cancel = cancel; self.confirm = confirm
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CiderDialogHeading(title, symbol: cancel == nil ? "exclamationmark.bubble" : "trash")
            Text(message).font(.body).foregroundStyle(CiderColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            HStack {
                if let cancel { Button("Cancel", action: cancel).keyboardShortcut(.cancelAction) }
                Spacer()
                if cancel == nil {
                    Button(confirmTitle, action: confirm)
                        .buttonStyle(CiderDialogButtonStyle(primary: true)).keyboardShortcut(.defaultAction)
                } else {
                    // Destructive confirmation deliberately has no Return shortcut.
                    Button(confirmTitle, role: .destructive, action: confirm)
                }
            }.padding(.top, 4)
        }.padding(28).frame(width: 460).ciderDialog()
    }
}
