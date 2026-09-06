import SwiftUI
import Testing
@testable import CiderPlatform

@Test @MainActor func responsePeekDoesNotExpandOrPinHUD() {
    let controller = NotchController(content: { _, _, _, _ in AnyView(EmptyView()) }, captureContent: { _ in AnyView(EmptyView()) })
    controller.peek(title: "Response", message: "Preview")
    #expect(controller.presentation.peekTitle == "Response")
    #expect(!controller.presentation.expanded)
    #expect(!controller.presentation.pinned)
    controller.toggle()
    #expect(controller.presentation.peekTitle == nil)
    #expect(controller.presentation.expanded)
    controller.peek(title: "Another response", message: "Preview")
    #expect(controller.presentation.peekTitle == nil)
    controller.stop()
}

@Test @MainActor func peekActionAndSourceDismissal() {
    let controller = NotchController(content: { _, _, _, _ in AnyView(EmptyView()) }, captureContent: { _ in AnyView(EmptyView()) })
    var opened = false
    controller.peek(title: "Response", message: "Preview", action: { opened = true })
    controller.presentation.activatePeek?()
    #expect(opened)
    controller.presentation.pinned = true
    controller.dismissAfterSourceOpen()
    #expect(!controller.presentation.expanded)
    #expect(!controller.presentation.pinned)
    #expect(controller.presentation.activatePeek == nil)
    #expect(controller.presentation.peekTitle == nil)
    controller.stop()
}

@Test @MainActor func questionPeekTakesPriorityWithoutOpeningHUD() {
    let controller = NotchController(content: { _, _, _, _ in AnyView(EmptyView()) }, captureContent: { _ in AnyView(EmptyView()) })
    controller.peek(title: "Needs input", message: "Which folder?", requiresInput: true)
    controller.peek(title: "Finished responding", message: "Another agent is done")
    #expect(controller.presentation.peekTitle == "Needs input")
    #expect(controller.presentation.peekMessage == "Which folder?")
    #expect(!controller.presentation.expanded)
    controller.dismissAfterSourceOpen()
    controller.peek(title: "Finished responding", message: "Later response")
    #expect(controller.presentation.peekTitle == "Finished responding")
    controller.stop()
}
