-- Schema v1. Apply once inside the writer's migration transaction.
-- Connections enable foreign_keys and bounded busy handling before transactions.
CREATE TABLE metadata (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    schema_version INTEGER NOT NULL CHECK (schema_version = 1),
    revision INTEGER NOT NULL CHECK (revision >= 0),
    host_id TEXT NOT NULL CHECK (length(host_id) = 36),
    migration_source_hash TEXT
) STRICT;
CREATE TABLE tasks (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL CHECK (length(trim(title)) > 0),
    description_markdown TEXT NOT NULL DEFAULT '' CHECK (length(CAST(description_markdown AS BLOB)) <= 65536),
    planned_day TEXT NOT NULL CHECK (planned_day GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
    due_at REAL,
    status TEXT NOT NULL CHECK (status IN ('planned','inProgress','blocked','readyForReview','done')),
    created_at REAL NOT NULL,
    sort_order INTEGER NOT NULL,
    revision INTEGER NOT NULL CHECK (revision >= 1)
) STRICT;
CREATE INDEX tasks_day_status ON tasks(planned_day,status,sort_order,id);
CREATE TABLE criteria (
    id TEXT PRIMARY KEY NOT NULL,
    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    position INTEGER NOT NULL CHECK (position >= 0 AND position < 200),
    text TEXT NOT NULL CHECK (length(text) > 0),
    checked INTEGER NOT NULL CHECK (checked IN (0,1)),
    updated_at REAL NOT NULL,
    UNIQUE(task_id,position)
) STRICT;
CREATE TABLE chats (
    host_id TEXT NOT NULL,
    provider TEXT NOT NULL CHECK (provider IN ('codex','claude')),
    session_id TEXT NOT NULL CHECK (length(session_id) > 0),
    title TEXT,
    directory TEXT NOT NULL,
    origin_json TEXT CHECK (origin_json IS NULL OR json_valid(origin_json)),
    observed_at REAL,
    current_turn_id TEXT,
    execution TEXT NOT NULL CHECK (execution IN ('Ready','Working','Finished responding','Interrupted','Ended','Unknown')),
    attention TEXT,
    PRIMARY KEY(host_id,provider,session_id)
) STRICT;
CREATE TABLE task_chat_links (
    id TEXT PRIMARY KEY NOT NULL,
    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    host_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    session_id TEXT NOT NULL,
    role TEXT,
    started_at REAL NOT NULL,
    ended_at REAL CHECK (ended_at IS NULL OR ended_at >= started_at),
    initial_turn_id TEXT,
    revision INTEGER NOT NULL CHECK (revision >= 1),
    FOREIGN KEY(host_id,provider,session_id) REFERENCES chats(host_id,provider,session_id) ON DELETE RESTRICT,
    UNIQUE(id,task_id)
) STRICT;
CREATE UNIQUE INDEX one_active_assignment ON task_chat_links(task_id,host_id,provider,session_id) WHERE ended_at IS NULL;
CREATE INDEX assignments_by_chat ON task_chat_links(host_id,provider,session_id,started_at,ended_at);
CREATE TABLE folder_roots (
    id TEXT PRIMARY KEY NOT NULL,
    path TEXT NOT NULL UNIQUE,
    available INTEGER NOT NULL CHECK (available IN (0,1))
) STRICT;
CREATE TABLE notes (
    id TEXT PRIMARY KEY NOT NULL,
    root_id TEXT NOT NULL REFERENCES folder_roots(id) ON DELETE RESTRICT,
    relative_path TEXT NOT NULL CHECK (length(relative_path) > 0 AND substr(relative_path,1,1) != '/'),
    file_identity BLOB,
    available INTEGER NOT NULL CHECK (available IN (0,1)),
    modified_at REAL,
    UNIQUE(root_id,relative_path)
) STRICT;
CREATE TABLE task_note_links (
    id TEXT PRIMARY KEY NOT NULL,
    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE RESTRICT,
    role TEXT NOT NULL CHECK (role IN ('plan','context','evidence')),
    created_at REAL NOT NULL,
    UNIQUE(task_id,note_id)
) STRICT;
CREATE INDEX note_backlinks ON task_note_links(note_id,task_id);
CREATE TABLE note_document_links (
    id TEXT PRIMARY KEY NOT NULL,
    source_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    target_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    fragment TEXT
) STRICT;
CREATE UNIQUE INDEX unique_document_link ON note_document_links(source_id,target_id,coalesce(fragment,''));
CREATE INDEX document_backlinks ON note_document_links(target_id,source_id);
CREATE TABLE journal (
    sequence INTEGER PRIMARY KEY AUTOINCREMENT,
    id TEXT NOT NULL UNIQUE,
    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    link_id TEXT,
    host_id TEXT,
    provider TEXT,
    session_id TEXT,
    source_event_id TEXT,
    source_turn_id TEXT,
    question_id TEXT,
    source_key TEXT NOT NULL,
    occurred_at REAL NOT NULL,
    received_at REAL NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('response','question','questionResolved','userNote')),
    text TEXT NOT NULL CHECK (length(CAST(text AS BLOB)) <= 16384),
    preview_only INTEGER NOT NULL CHECK (preview_only IN (0,1)),
    attribution TEXT NOT NULL CHECK (attribution IN ('identifiedTurn','observedEpisode','userSelected')),
    CHECK ((host_id IS NULL AND provider IS NULL AND session_id IS NULL) OR (host_id IS NOT NULL AND provider IS NOT NULL AND session_id IS NOT NULL)),
    FOREIGN KEY(link_id,task_id) REFERENCES task_chat_links(id,task_id) ON DELETE CASCADE,
    FOREIGN KEY(host_id,provider,session_id) REFERENCES chats(host_id,provider,session_id) ON DELETE RESTRICT,
    UNIQUE(task_id,source_key)
) STRICT;
CREATE INDEX task_journal_sequence ON journal(task_id,sequence);
CREATE INDEX journal_source_event ON journal(source_event_id,task_id);
CREATE TABLE assignment_episodes (
    id TEXT PRIMARY KEY NOT NULL,
    link_id TEXT NOT NULL REFERENCES task_chat_links(id) ON DELETE CASCADE,
    source_start_id TEXT NOT NULL,
    turn_id TEXT,
    started_at REAL NOT NULL,
    ended_at REAL CHECK (ended_at IS NULL OR ended_at >= started_at),
    UNIQUE(link_id,source_start_id)
) STRICT;
CREATE INDEX episodes_by_link ON assignment_episodes(link_id,turn_id,started_at);
CREATE TABLE processed_events (source_event_id TEXT PRIMARY KEY NOT NULL) STRICT;
CREATE TABLE mutation_receipts (
    command_id TEXT PRIMARY KEY NOT NULL,
    request_hash TEXT NOT NULL,
    result_json TEXT NOT NULL CHECK (json_valid(result_json))
) STRICT;
CREATE TABLE preferences (
    key TEXT PRIMARY KEY NOT NULL,
    value_json TEXT NOT NULL CHECK (json_valid(value_json))
) STRICT;
PRAGMA user_version = 1;
