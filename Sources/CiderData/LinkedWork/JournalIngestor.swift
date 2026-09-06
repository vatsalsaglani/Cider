import Foundation
import CiderDomain

/// Durable bridge between the metadata-only observer and linked-work storage.
/// It retries a revision race by re-reading attribution; the caller retains the
/// spool batch until this method returns successfully.
public struct JournalIngestor: WorkJournalIngesting, Sendable {
    private let repository: any WorkRepository
    private let planner: JournalAttributionPlanner

    public init(repository: any WorkRepository) {
        self.repository = repository
        self.planner = JournalAttributionPlanner()
    }

    public func ingest(events: [AgentEvent], hostID: UUID, receivedAt: Date) async throws -> JournalReceipt {
        guard events.count <= WorkLimits.eventBatch else { throw WorkStoreError.outputLimit }
        let chats = Array(Set(events.map { ChatIdentity(hostID: hostID, provider: $0.provider, sessionID: $0.session) }))
            .sorted { lhs, rhs in
                let left = lhs.hostID.uuidString + lhs.provider.rawValue + lhs.sessionID
                let right = rhs.hostID.uuidString + rhs.provider.rawValue + rhs.sessionID
                return left < right
            }
        for attempt in 0..<3 {
            let snapshot = try await repository.attribution(chats: chats, eventIDs: events.map(\.id))
            let replies = Set(events.flatMap { event in
                (event.answeredQuestionIDs ?? []).map { journalQuestionKey(chat: ChatIdentity(hostID: hostID, provider: event.provider, sessionID: event.session), questionID: $0) }
            })
            let questions = replies.isEmpty ? [:] : try await knownQuestions(for: snapshot.links, wanted: replies)
            let batch = try planner.batch(events: events, hostID: hostID, receivedAt: receivedAt, snapshot: snapshot, questions: questions)
            do {
                return try await repository.appendJournal(batch)
            } catch WorkStoreError.conflict where attempt < 2 {
                continue
            }
        }
        throw WorkStoreError.conflict
    }

    /// The frozen repository API has no question-ID index. Read only bounded
    /// journal metadata/text previews already selected for the task, then keep
    /// the original link as resolution provenance across a restart.
    private func knownQuestions(for links: [TaskChatLink], wanted: Set<String>) async throws -> [String: [JournalQuestionOrigin]] {
        let taskIDs = Set(links.map(\.taskID))
        var result: [String: [JournalQuestionOrigin]] = [:]
        for taskID in taskIDs {
            var required = Set<String>()
            for link in links where link.taskID == taskID {
                let prefix = link.chat.hostID.uuidString.lowercased() + ":" + link.chat.provider.rawValue + ":" + link.chat.sessionID + ":"
                for key in wanted where key.hasPrefix(prefix) { required.insert(key) }
            }
            guard !required.isEmpty else { continue }
            var cursor: String?
            var read = 0
            repeat {
                let page = try await repository.journal(JournalQuery(taskID: taskID, cursor: cursor, limit: WorkLimits.list))
                read += page.items.count
                guard read <= WorkLimits.attributionRows else { throw WorkStoreError.outputLimit }
                for entry in page.items where entry.kind == .question {
                    guard let questionID = entry.questionID, let linkID = entry.linkID else { continue }
                    guard let chat = entry.chat,
                          links.contains(where: { $0.id == linkID && $0.taskID == taskID && $0.chat == chat }) else { continue }
                    let key = journalQuestionKey(chat: chat, questionID: questionID)
                    guard wanted.contains(key) else { continue }
                    result[key, default: []].append(JournalQuestionOrigin(
                        linkID: linkID, turnID: entry.sourceTurnID, attribution: entry.attribution
                    ))
                }
                cursor = page.nextCursor
                if required.allSatisfy({ result[$0]?.contains(where: { origin in
                    links.contains(where: { $0.id == origin.linkID && $0.taskID == taskID })
                }) == true }) { break }
            } while cursor != nil
        }
        return result
    }
}
