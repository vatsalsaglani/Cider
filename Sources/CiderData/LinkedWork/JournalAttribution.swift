import Foundation
import CiderDomain

struct JournalQuestionOrigin: Sendable {
    let linkID: UUID
    let turnID: String?
    let attribution: CiderDomain.JournalAttribution
}

func journalQuestionKey(chat: ChatIdentity, questionID: String) -> String {
    chat.hostID.uuidString.lowercased() + ":" + chat.provider.rawValue + ":" + chat.sessionID + ":" + questionID
}

/// Converts an observer batch into conservative, assignment-scoped journal
/// work.  Directory and display metadata are intentionally never considered
/// attribution evidence.
struct JournalAttributionPlanner: Sendable {
    func batch(
        events: [AgentEvent],
        hostID: UUID,
        receivedAt: Date,
        snapshot: AttributionSnapshot,
        questions: [String: [JournalQuestionOrigin]]
    ) throws -> JournalBatch {
        guard events.count <= WorkLimits.eventBatch else { throw WorkStoreError.outputLimit }
        let processed = Set(snapshot.processedEventIDs)
        let ordered = events.sorted { lhs, rhs in
            lhs.time == rhs.time ? lhs.id.uuidString < rhs.id.uuidString : lhs.time < rhs.time
        }
        var knownEpisodes = snapshot.episodes
        var changedEpisodes: [AssignmentEpisode] = []
        var entries: [JournalDraft] = []
        var processedIDs: [UUID] = []
        var questionOrigins = questions

        for event in ordered where !processed.contains(event.id) {
            processedIDs.append(event.id)
            let identity = ChatIdentity(hostID: hostID, provider: event.provider, sessionID: event.session)
            let links = snapshot.links.filter { $0.chat == identity }
            guard !links.isEmpty else { continue }

            if event.name == "UserPromptSubmit" {
                // A structured answer can arrive with the next prompt. Resolve
                // it before opening that new episode, never against new work.
                for questionID in event.answeredQuestionIDs ?? [] {
                    for match in resolutionMatches(questionID: questionID, chat: identity, links: links, origins: questionOrigins) {
                        entries.append(draft(
                            taskID: match.link.taskID, link: match.link, event: event, identity: identity,
                            questionID: questionID, kind: .questionResolved, text: "Question resolved",
                            attribution: match.attribution, receivedAt: receivedAt
                        ))
                    }
                }
                for link in links.filter({ contains($0, event.time) }) {
                    let episode = AssignmentEpisode(
                        linkID: link.id,
                        sourceStartID: event.id,
                        turnID: event.turn,
                        startedAt: event.time
                    )
                    upsert(episode, into: &knownEpisodes)
                    changedEpisodes.append(episode)
                }
                continue
            }

            let matches = matches(for: event, links: links, episodes: knownEpisodes)
            switch event.name {
            case "Stop", "SubagentStop", "AgentResponse":
                guard let preview = event.lastMessage, !preview.isEmpty else { continue }
                for match in matches {
                    entries.append(draft(
                        taskID: match.link.taskID, link: match.link, event: event, identity: identity,
                        questionID: nil, kind: .response, text: preview,
                        attribution: match.attribution, receivedAt: receivedAt
                    ))
                    if event.child == nil, let episode = match.episode, episode.endedAt == nil {
                        var closed = episode
                        closed.endedAt = event.time
                        upsert(closed, into: &knownEpisodes)
                        changedEpisodes.append(closed)
                    }
                }
            case "PreToolUse":
                for question in event.questions ?? [] {
                    for match in matches {
                        entries.append(draft(
                            taskID: match.link.taskID, link: match.link, event: event, identity: identity,
                            questionID: question.id, kind: .question, text: question.text,
                            attribution: match.attribution, receivedAt: receivedAt
                        ))
                        questionOrigins[journalQuestionKey(chat: identity, questionID: question.id), default: []].append(JournalQuestionOrigin(
                            linkID: match.link.id, turnID: event.turn, attribution: match.attribution
                        ))
                    }
                }
            default:
                break
            }
        }
        return JournalBatch(
            expectedRevision: snapshot.revision,
            entries: entries,
            episodes: uniqueEpisodes(changedEpisodes),
            processedEventIDs: processedIDs
        )
    }

    private func contains(_ link: TaskChatLink, _ time: Date) -> Bool {
        time >= link.startedAt && (link.endedAt.map { time <= $0 } ?? true)
    }

    private struct Match {
        let link: TaskChatLink
        let episode: AssignmentEpisode?
        let attribution: CiderDomain.JournalAttribution
    }

    private func matches(
        for event: AgentEvent,
        links: [TaskChatLink],
        episodes: [AssignmentEpisode]
    ) -> [Match] {
        links.compactMap { link in
            // An identified turn remains attributable after the link closes;
            // the close must not turn a delayed Stop into a new attachment.
            let allEpisodes = episodes.filter { $0.linkID == link.id && event.time >= $0.startedAt }
            if let turn = event.turn {
                if let episode = allEpisodes.first(where: { $0.turnID == turn }) {
                    return Match(link: link, episode: episode, attribution: episode.turnID == link.initialTurnID ? .identifiedTurn : .observedEpisode)
                }
                // Initial-turn inclusion is explicit; it never lets a delayed
                // terminal event fall through to a newer link by directory.
                if link.initialTurnID == turn {
                    return Match(link: link, episode: nil, attribution: .identifiedTurn)
                }
                return nil
            }
            // Without a provider turn ID, only one open observed episode is
            // usable.  Multiple candidates remain unassigned rather than guessed.
            guard contains(link, event.time) else { return nil }
            let candidates = allEpisodes.filter { $0.endedAt == nil }
            guard candidates.count == 1, let episode = candidates.first else { return nil }
            return Match(link: link, episode: episode, attribution: .observedEpisode)
        }
    }

    private func resolutionMatches(
        questionID: String,
        chat: ChatIdentity,
        links: [TaskChatLink],
        origins: [String: [JournalQuestionOrigin]]
    ) -> [Match] {
        let validLinks = Dictionary(uniqueKeysWithValues: links.map { ($0.id, $0) })
        // The question ID alone is provider-local. Include immutable chat
        // identity so a same-named request in another chat cannot resolve here.
        return (origins[journalQuestionKey(chat: chat, questionID: questionID)] ?? []).compactMap { origin in
            guard let link = validLinks[origin.linkID] else { return nil }
            return Match(link: link, episode: nil, attribution: origin.attribution)
        }
    }

    private func draft(
        taskID: UUID,
        link: TaskChatLink,
        event: AgentEvent,
        identity: ChatIdentity,
        questionID: String?,
        kind: JournalKind,
        text: String,
        attribution: CiderDomain.JournalAttribution,
        receivedAt: Date
    ) -> JournalDraft {
        let suffix = questionID ?? event.child ?? "event"
        return JournalDraft(
            taskID: taskID,
            linkID: link.id,
            chat: identity,
            sourceEventID: event.id,
            sourceTurnID: event.turn,
            questionID: questionID,
            sourceKey: "event:\(event.id.uuidString.lowercased()):\(kind.rawValue):\(suffix)",
            occurredAt: event.time,
            receivedAt: receivedAt,
            kind: kind,
            text: text,
            previewOnly: true,
            attribution: attribution
        )
    }

    private func uniqueEpisodes(_ episodes: [AssignmentEpisode]) -> [AssignmentEpisode] {
        var latest: [String: AssignmentEpisode] = [:]
        for episode in episodes { latest[episode.linkID.uuidString + episode.sourceStartID.uuidString] = episode }
        return latest.values.sorted { lhs, rhs in
            lhs.startedAt == rhs.startedAt ? lhs.id.uuidString < rhs.id.uuidString : lhs.startedAt < rhs.startedAt
        }
    }

    private func upsert(_ episode: AssignmentEpisode, into episodes: inout [AssignmentEpisode]) {
        if let index = episodes.firstIndex(where: { $0.linkID == episode.linkID && $0.sourceStartID == episode.sourceStartID }) {
            episodes[index] = episode
        } else {
            episodes.append(episode)
        }
    }
}
