import Foundation

import Testing
@testable import CiderPlatform

@MainActor @Test func initialSongDoesNotNeedAPlayerNotification() async throws {
    let player = NowPlaying(readSnapshot: { _ in
        .snapshot(PlayerSnapshot(title: "Already playing", artist: "Artist", playing: true))
    }, runningPlayers: { ["com.apple.Music"] })
    player.refresh()
    while player.refreshing { await Task.yield() }
    #expect(player.title == "Already playing")
    #expect(player.source == "Music")
}

@MainActor @Test func pausedPlayerDoesNotReplaceAnotherPlayingTrack() {
    let player = NowPlaying()
    player.accept(PlayerSnapshot(title: "Active", artist: "", playing: true), from: "com.apple.Music")
    player.accept(PlayerSnapshot(title: "Paused", artist: "", playing: false), from: "com.spotify.client")
    #expect(player.title == "Active")
    player.accept(PlayerSnapshot(title: "Active", artist: "", playing: false), from: "com.apple.Music")
    player.accept(PlayerSnapshot(title: "Other", artist: "", playing: true), from: "com.spotify.client")
    #expect(player.title == "Other")
    #expect(player.source == "Spotify")
}

@MainActor @Test func notificationWinsOverSlowStartupSnapshot() async {
    let player = NowPlaying(readSnapshot: { _ in
        await Task.yield()
        return .snapshot(PlayerSnapshot(title: "Old", artist: "", playing: true))
    }, runningPlayers: { ["com.apple.Music"] })
    player.refresh()
    await Task.yield()
    player.accept(PlayerSnapshot(title: "New", artist: "", playing: true), from: "com.apple.Music")
    while player.refreshing { await Task.yield() }
    #expect(player.title == "New")
}

@MainActor @Test func closedPlayerClearsStaleSong() async {
    let player = NowPlaying(readSnapshot: { _ in .unavailable }, runningPlayers: { [] })
    player.accept(PlayerSnapshot(title: "Old", artist: "", playing: true), from: "com.apple.Music")
    player.refresh()
    while player.refreshing { await Task.yield() }
    #expect(player.title.isEmpty)
}

@Test @MainActor func systemMediaAcceptsBrowserArtworkAndClearsEndedSession() {
    let player = NowPlaying()
    player.acceptSystem(Data(#"{"type":"data","payload":{"title":"Synthetic video","artist":"Test channel","playing":true,"bundleIdentifier":"com.apple.Safari","artworkData":"YWJj"}}"#.utf8))
    #expect(player.title == "Synthetic video")
    #expect(player.playing && player.canControl)
    #expect(player.artwork == Data("abc".utf8))
    player.acceptSystem(Data(#"{"type":"data","payload":{}}"#.utf8))
    #expect(player.title.isEmpty && !player.playing && !player.canControl)
    #expect(player.artwork == nil)
}
