import Foundation
import CiderDomain

/// Bounded, saved-data context for an explicit TODO. It never reads editor drafts
/// and uses only the roots/note references stored on the task itself.
public struct TodoContextOptions: Sendable, Equatable {
    public var afterSequence: Int64?
    public var includeNotes: Bool
    public var noteByteLimit: Int
    public var totalByteLimit: Int

    public init(
        afterSequence: Int64? = nil,
        includeNotes: Bool = false,
        noteByteLimit: Int = WorkLimits.noteBytes,
        totalByteLimit: Int = WorkLimits.contextBytes
    ) {
        self.afterSequence = afterSequence
        self.includeNotes = includeNotes
        self.noteByteLimit = noteByteLimit
        self.totalByteLimit = totalByteLimit
    }
}

public struct TodoContextNote: Codable, Sendable, Equatable, Identifiable {
    public var reference: NoteReference
    public var content: String?
    public var sha256: String?
    public var modifiedAt: Date?
    public var truncated: Bool
    public var unavailable: Bool

    public var id: UUID { reference.id }
    public init(reference: NoteReference, content: String? = nil, sha256: String? = nil, modifiedAt: Date? = nil, truncated: Bool = false, unavailable: Bool = false) {
        self.reference = reference
        self.content = content
        self.sha256 = sha256
        self.modifiedAt = modifiedAt
        self.truncated = truncated
        self.unavailable = unavailable
    }
}

public struct TodoContextBundle: Codable, Sendable {
    public var detail: TaskDetail
    public var activity: WorkPage<JournalEntry>
    public var notes: [TodoContextNote]
    public var throughSequence: Int64?
    public var storeRevision: Int64
    public var truncated: Bool

    public init(detail: TaskDetail, activity: WorkPage<JournalEntry>, notes: [TodoContextNote], throughSequence: Int64?, storeRevision: Int64, truncated: Bool) {
        self.detail = detail
        self.activity = activity
        self.notes = notes
        self.throughSequence = throughSequence
        self.storeRevision = storeRevision
        self.truncated = truncated
    }
}

/// Reads a coherent snapshot through the app's existing read interfaces. A changed
/// revision is surfaced as a retryable conflict rather than mixing database states.
public struct TodoContextReader: Sendable {
    private let repository: any WorkReading
    private let noteAccess: any LinkedNoteAccess

    public init(repository: any WorkReading, noteAccess: any LinkedNoteAccess) {
        self.repository = repository
        self.noteAccess = noteAccess
    }

    public func context(taskID: UUID, options: TodoContextOptions = TodoContextOptions()) async throws -> TodoContextBundle {
        guard (1...WorkLimits.noteBytes).contains(options.noteByteLimit),
              (1...WorkLimits.contextBytes).contains(options.totalByteLimit) else { throw WorkStoreError.invalidInput }
        let before = try await repository.info()
        let detail = try await repository.detail(taskID)
        let activity = try await repository.journal(JournalQuery(taskID: taskID, afterSequence: options.afterSequence, limit: WorkLimits.list))
        guard detail.revision == before.revision, activity.revision == before.revision else { throw WorkStoreError.conflict }
        let roots = Dictionary(uniqueKeysWithValues: try await repository.folders().map { ($0.id, $0) })
        var remaining = options.totalByteLimit
        var notes: [TodoContextNote] = []
        var truncated = detail.truncated || activity.nextCursor != nil

        for note in detail.notes.prefix(20) {
            guard options.includeNotes else {
                notes.append(TodoContextNote(reference: note, modifiedAt: note.modifiedAt, unavailable: !note.available))
                continue
            }
            guard let root = roots[note.rootID], root.available, note.available else {
                notes.append(TodoContextNote(reference: note, modifiedAt: note.modifiedAt, unavailable: true))
                continue
            }
            guard remaining > 0 else {
                notes.append(TodoContextNote(reference: note, modifiedAt: note.modifiedAt, truncated: true))
                truncated = true
                continue
            }
            do {
                let limit = min(options.noteByteLimit, remaining)
                let snapshot = try await noteAccess.read(note, root: root, maxBytes: limit)
                let count = snapshot.markdown.utf8.count
                remaining -= count
                let wasTruncated = snapshot.truncated || count == limit
                truncated = truncated || wasTruncated
                notes.append(TodoContextNote(reference: note, content: snapshot.markdown, sha256: snapshot.sha256, modifiedAt: snapshot.modifiedAt, truncated: wasTruncated, unavailable: false))
            } catch let error as WorkStoreError where error == .notFound || error == .unavailable || error == .outsideRoot || error == .fileChanged {
                notes.append(TodoContextNote(reference: note, modifiedAt: note.modifiedAt, unavailable: true))
            }
        }
        if detail.notes.count > 20 { truncated = true }
        // The context limit covers saved task metadata and activity as well as note
        // bytes. Reserve envelope space before selecting each chronological entry.
        var selected: [JournalEntry] = []
        let reservedEnvelopeBytes = 1_024
        while try encodedSize(TodoContextBundle(
            detail: detail,
            activity: WorkPage(items: [], revision: activity.revision),
            notes: notes,
            throughSequence: options.afterSequence,
            storeRevision: before.revision,
            truncated: true
        )) + reservedEnvelopeBytes > options.totalByteLimit {
            guard let index = notes.lastIndex(where: { $0.content != nil }) else { throw WorkStoreError.outputLimit }
            notes[index].content = nil
            notes[index].truncated = true
            truncated = true
        }
        for entry in activity.items {
            let candidate = TodoContextBundle(
                detail: detail,
                activity: WorkPage(items: selected + [entry], nextCursor: activity.nextCursor, revision: activity.revision),
                notes: notes,
                throughSequence: entry.sequence,
                storeRevision: before.revision,
                truncated: true
            )
            guard try encodedSize(candidate) + reservedEnvelopeBytes <= options.totalByteLimit else {
                truncated = true
                break
            }
            selected.append(entry)
        }
        if selected.count < activity.items.count { truncated = true }
        let selectedActivity = WorkPage(items: selected, nextCursor: selected.count < activity.items.count ? "bounded" : activity.nextCursor, revision: activity.revision)
        let candidate = TodoContextBundle(detail: detail, activity: selectedActivity, notes: notes, throughSequence: selected.last?.sequence ?? options.afterSequence, storeRevision: before.revision, truncated: truncated)
        guard try encodedSize(candidate) + reservedEnvelopeBytes <= options.totalByteLimit else { throw WorkStoreError.outputLimit }
        let after = try await repository.info()
        guard after.revision == before.revision else { throw WorkStoreError.conflict }
        return candidate
    }

    private func encodedSize<T: Encodable>(_ value: T) throws -> Int {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value).count
    }
}
