import Foundation

struct PlayerSnapshot: Sendable {
    let title: String
    let artist: String
    let playing: Bool
}

enum PlayerReadResult: Sendable {
    case snapshot(PlayerSnapshot)
    case unavailable
    case permissionDenied
}

/// Apple events are confined to this serial utility queue, with a bounded reply timeout.
/// Only the two fixed player dictionaries are queried; document text cannot become a script.
enum PlayerSnapshotReader {
    private static let queue = DispatchQueue(label: "app.cider.player-snapshot", qos: .utility)
    static func read(_ bundleID: String) async -> PlayerReadResult {
        guard ["com.apple.Music", "com.spotify.client"].contains(bundleID) else { return .unavailable }
        return await withCheckedContinuation { continuation in
            queue.async {
                let script = """
                if application id "\(bundleID)" is not running then return {"", "", "stopped"}
                with timeout of 3 seconds
                    tell application id "\(bundleID)"
                        if player state is stopped then return {"", "", "stopped"}
                        return {name of current track, artist of current track, player state as text}
                    end tell
                end timeout
                """
                var error: NSDictionary?
                let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
                guard error == nil, let result, result.numberOfItems == 3 else {
                    continuation.resume(returning: (error?[NSAppleScript.errorNumber] as? Int) == -1743 ? .permissionDenied : .unavailable); return
                }
                continuation.resume(returning: .snapshot(PlayerSnapshot(
                    title: result.atIndex(1)?.stringValue ?? "",
                    artist: result.atIndex(2)?.stringValue ?? "",
                    playing: result.atIndex(3)?.stringValue == "playing")))
            }
        }
    }
}
