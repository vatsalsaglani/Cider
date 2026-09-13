import Foundation
import Testing
import CiderData

struct LegacyAppPreferencesTests {
    @Test func copiesFoldersAndDraftsWithoutOverwritingOrDeletingLegacyPreferences() throws {
        let defaults = UserDefaults.standard
        let legacy = "test.cinder." + UUID().uuidString
        let destination = "test.cider." + UUID().uuidString
        defer { defaults.removePersistentDomain(forName: legacy); defaults.removePersistentDomain(forName: destination) }
        defaults.setPersistentDomain(["workspaceFolders": ["/fixture/notes"], "noteDraft:/fixture/notes/a.md": "Unsaved", "sidebarCollapsed": false], forName: legacy)
        defaults.setPersistentDomain(["sidebarCollapsed": true], forName: destination)
        LegacyAppPreferences.migrate(defaults: defaults, legacyDomain: legacy, destinationDomain: destination)
        let migrated = try #require(defaults.persistentDomain(forName: destination))
        #expect(migrated["workspaceFolders"] as? [String] == ["/fixture/notes"])
        #expect(migrated["noteDraft:/fixture/notes/a.md"] as? String == "Unsaved")
        #expect(migrated["sidebarCollapsed"] as? Bool == true)
        #expect(defaults.persistentDomain(forName: legacy) != nil)
        var updated = migrated; updated.removeValue(forKey: "workspaceFolders")
        defaults.setPersistentDomain(updated, forName: destination)
        LegacyAppPreferences.migrate(defaults: defaults, legacyDomain: legacy, destinationDomain: destination)
        #expect(defaults.persistentDomain(forName: destination)?["workspaceFolders"] == nil)
    }
}
