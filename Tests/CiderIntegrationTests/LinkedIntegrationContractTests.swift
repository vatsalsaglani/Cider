import Testing
@testable import CiderApp

@Suite struct LinkedIntegrationContractTests {
    @Test func appTypesImportWithoutLaunch() {
        // Metatypes prove linkage without constructing App, State, scenes, windows or services.
        _ = CiderApp.self
        _ = AppModel.self
        _ = WorkspaceView.self
    }
}
