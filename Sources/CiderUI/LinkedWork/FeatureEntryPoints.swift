import Foundation
import SwiftUI
import CiderDomain

@MainActor public protocol LinkedTaskDetailFeature: View {
    init(taskID: UUID, model: LinkedWorkModel, navigate: @escaping (LinkedRoute) -> Void)
}
@MainActor public protocol LinkedNoteConnectionsFeature: View {
    init(noteID: UUID, model: LinkedWorkModel, navigate: @escaping (LinkedRoute) -> Void)
}
@MainActor public protocol LinkedGraphFeature: View {
    init(model: LinkedWorkModel, focus: LinkedEntityID?, navigate: @escaping (LinkedRoute) -> Void)
}
@MainActor public protocol LinkedAgentAccessFeature: View { init() }
