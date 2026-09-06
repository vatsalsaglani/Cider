import AppKit
import Observation

@MainActor @Observable
public final class NowPlaying {
    public private(set) var title = ""
    public private(set) var artist = ""
    public private(set) var playing = false
    public private(set) var source = ""
    public private(set) var unavailable = false
    public private(set) var needsPermission = false
    public private(set) var refreshing = false
    public private(set) var artwork: Data?
    public private(set) var canControl = false
    private var systemMedia: SystemMediaBridge?
    public func previous() { systemMedia?.send(5) }
    public func togglePlayback() { systemMedia?.send(2) }
    public func next() { systemMedia?.send(4) }
    func acceptSystem(_ data: Data) {
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let item = envelope["payload"] as? [String: Any] else { return }
        title = item["title"] as? String ?? ""
        artist = item["artist"] as? String ?? ""
        playing = item["playing"] as? Bool ?? false
        artwork = (item["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
        canControl = !title.isEmpty
        let id = item["parentApplicationBundleIdentifier"] as? String ?? item["bundleIdentifier"] as? String ?? ""
        source = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent ?? ""
        refreshing = false; unavailable = false
    }
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var tracks: [String: PlayerSnapshot] = [:]
    private var revisions: [String: Int] = [:]
    private var preferred = ""
    private var refreshTask: Task<Void, Never>?
    private let players = ["com.apple.Music", "com.spotify.client"]
    private let readSnapshot: @Sendable (String) async -> PlayerReadResult
    private let runningPlayers: @MainActor () -> Set<String>
    public init() {
        readSnapshot = PlayerSnapshotReader.read
        runningPlayers = { Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)) }
    }
    init(readSnapshot: @escaping @Sendable (String) async -> PlayerReadResult,
         runningPlayers: @escaping @MainActor () -> Set<String>) {
        self.readSnapshot = readSnapshot; self.runningPlayers = runningPlayers
    }

    public func start() {
        guard tokens.isEmpty, systemMedia == nil else { return }
        let bridge = SystemMediaBridge()
        if bridge.available {
            systemMedia = bridge
            bridge.receive = { [weak self] in self?.acceptSystem($0) }
            bridge.failed = { [weak self] in self?.unavailable = true; self?.canControl = false; self?.playing = false }
            let center = NotificationCenter.default
            tokens.append((center, center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.stop() }
            }))
            let workspace = NSWorkspace.shared.notificationCenter
            tokens.append((workspace, workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }))
            bridge.start()
            return
        }
        for name in ["com.apple.Music.playerInfo", "com.apple.iTunes.playerInfo", "com.spotify.client.PlaybackStateChanged"] {
            let center = DistributedNotificationCenter.default()
            let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] notification in
                let snapshot = PlayerSnapshot(title: notification.userInfo?["Name"] as? String ?? "",
                    artist: notification.userInfo?["Artist"] as? String ?? "",
                    playing: notification.userInfo?["Player State"] as? String == "Playing")
                let id = name.contains("spotify") ? "com.spotify.client" : "com.apple.Music"
                Task { @MainActor [weak self] in self?.accept(snapshot, from: id) }
            }
            tokens.append((center, token))
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didWakeNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            tokens.append((center, token))
        }
        refresh()
    }
    public func refresh() {
        if let systemMedia { systemMedia.start(); return }
        guard !refreshing else { return }
        let running = runningPlayers()
        tracks = tracks.filter { running.contains($0.key) }; project()
        refreshing = true; unavailable = false; needsPermission = false
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer { refreshing = false }
            for id in players where running.contains(id) {
                let revision = revisions[id, default: 0]
                let result = await readSnapshot(id)
                guard !Task.isCancelled else { return }
                guard revisions[id, default: 0] == revision else { continue }
                switch result {
                case .snapshot(let track): accept(track, from: id)
                case .unavailable: unavailable = true
                case .permissionDenied: needsPermission = true
                }
            }
        }
    }
    func accept(_ track: PlayerSnapshot, from id: String) {
        revisions[id, default: 0] += 1
        tracks[id] = track
        if track.playing { preferred = id }
        project()
    }
    private func project() {
        let order = [preferred] + players.filter { $0 != preferred }
        let id = order.first { tracks[$0]?.playing == true }
            ?? order.first { !(tracks[$0]?.title.isEmpty ?? true) }
        guard let id, let track = tracks[id] else { title = ""; artist = ""; playing = false; source = ""; return }
        title = track.title; artist = track.artist; playing = track.playing
        source = id == "com.spotify.client" ? "Spotify" : "Music"
    }
    public func stop() {
        systemMedia?.stop(); systemMedia = nil
        refreshTask?.cancel(); refreshTask = nil
        tokens.forEach { $0.0.removeObserver($0.1) }; tokens.removeAll()
    }
}
