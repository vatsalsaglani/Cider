import Foundation

/// Copies the former bundle's preferences once, before any model reads defaults.
/// Keep the old domain intact for rollback; never overwrite newer Cider settings.
public enum LegacyAppPreferences {
    public static func migrate(defaults: UserDefaults = .standard,
                               legacyDomain: String = "app.cinder.desktop",
                               destinationDomain: String = "app.cider.desktop") {
        let marker = "migratedCinderPreferencesV1"
        var current = defaults.persistentDomain(forName: destinationDomain) ?? [:]
        guard current[marker] as? Bool != true else { return }
        let legacy = defaults.persistentDomain(forName: legacyDomain) ?? [:]
        for (key, value) in legacy where current[key] == nil { current[key] = value }
        current[marker] = true
        defaults.setPersistentDomain(current, forName: destinationDomain)
    }
}
