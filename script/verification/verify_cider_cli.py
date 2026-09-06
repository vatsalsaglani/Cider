#!/usr/bin/env python3
"""Synthetic, app-closed contract check for the packaged read-only Cider CLI."""
import argparse
import datetime
import hashlib
import json
import pathlib
import sqlite3
import subprocess
import tempfile
import uuid


HOST = "00000000-0000-4000-8000-000000000001"
TASK = "00000000-0000-4000-8000-000000000010"
NOTE = "00000000-0000-4000-8000-000000000020"
ROOT = "00000000-0000-4000-8000-000000000030"
ENTRY = "00000000-0000-4000-8000-000000000040"
LINK = "00000000-0000-4000-8000-000000000050"
SESSION = "synthetic-contributor"


def run(binary, store, *args, expect=0):
    result = subprocess.run([binary, "--store", str(store), "todo", *args, "--json"], text=True, capture_output=True)
    assert result.returncode == expect, (result.returncode, result.stdout, result.stderr)
    return json.loads(result.stdout if expect == 0 else result.stderr)


def build_fixture(repo, store, note_root):
    schema = (repo / "Sources/CiderData/LinkedWork/Schema.sql").read_text()
    database = sqlite3.connect(store)
    database.executescript(schema)
    database.execute("INSERT INTO metadata VALUES (1,1,7,?,NULL)", (HOST,))
    today = datetime.date.today().isoformat()
    database.execute("INSERT INTO tasks VALUES (?,?,?,?,?,?,?,?,?)", (TASK, "CLI synthetic", "Saved description", today, None, "inProgress", 100.0, 1, 1))
    database.execute("INSERT INTO criteria VALUES (?,?,?,?,?,?)", ("00000000-0000-4000-8000-000000000011", TASK, 0, "Synthetic criterion", 0, 101.0))
    database.execute("INSERT INTO folder_roots VALUES (?,?,?)", (ROOT, str(note_root), 1))
    database.execute("INSERT INTO notes VALUES (?,?,?,?,?,?)", (NOTE, ROOT, "evidence.md", None, 1, 100.0))
    database.execute("INSERT INTO task_note_links VALUES (?,?,?,?,?)", ("00000000-0000-4000-8000-000000000021", TASK, NOTE, "evidence", 100.0))
    database.execute("INSERT INTO chats VALUES (?,?,?,?,?,?,?,?,?,?)", (HOST, "codex", SESSION, "Synthetic contributor", "/synthetic", None, 100.0, "turn-1", "Working", None))
    database.execute("INSERT INTO task_chat_links VALUES (?,?,?,?,?,?,?,?,?,?)", (LINK, TASK, HOST, "codex", SESSION, "contributor", 100.0, None, "turn-1", 1))
    database.execute("INSERT INTO journal (id,task_id,link_id,host_id,provider,session_id,source_event_id,source_turn_id,question_id,source_key,occurred_at,received_at,kind,text,preview_only,attribution) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", (ENTRY, TASK, LINK, HOST, "codex", SESSION, None, "turn-1", "question-1", "synthetic-stop", 102.0, 103.0, "response", "Synthetic preview", 1, "identifiedTurn"))
    # More than a full wire-budget of journal previews verifies that context
    # truncates while a raw activity page returns a stable output-limit error.
    for index in range(2, 502):
        database.execute("INSERT INTO journal (id,task_id,link_id,host_id,provider,session_id,source_event_id,source_turn_id,question_id,source_key,occurred_at,received_at,kind,text,preview_only,attribution) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", (str(uuid.UUID(int=index)), TASK, None, None, None, None, None, None, None, f"bulk-{index}", float(index), float(index), "response", "x" * 600, 1, "identifiedTurn"))
    database.commit(); database.close()


def assert_lower_uuid_values(value):
    if isinstance(value, dict):
        for key, nested in value.items():
            if key in {"id", "taskID", "noteID", "rootID", "linkID", "hostID", "sourceID", "targetID", "sourceEventID"} and isinstance(nested, str):
                assert nested == nested.lower(), (key, nested)
            assert_lower_uuid_values(nested)
    elif isinstance(value, list):
        for nested in value:
            assert_lower_uuid_values(nested)


def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--binary", required=True)
    args = parser.parse_args()
    binary = pathlib.Path(args.binary)
    assert binary.is_file() and binary.stat().st_mode & 0o111
    repo = pathlib.Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="cider-cli-") as temporary:
        root = pathlib.Path(temporary); store = root / "work.sqlite"; note_root = root / "notes"; note_root.mkdir()
        note = note_root / "evidence.md"; note.write_text("# Evidence\nSynthetic saved note.\n")
        build_fixture(repo, store, note_root)
        before = hashlib.sha256(store.read_bytes()).hexdigest()
        listing = run(binary, store, "list", "--today")
        assert listing["schemaVersion"] == 1 and listing["storeRevision"] == 7
        assert listing["data"][0]["id"] == TASK
        assert listing["data"][0]["plannedDay"] == datetime.date.today().isoformat()
        assert listing["nextCursor"] is None
        shown = run(binary, store, "show", TASK)
        assert shown["data"]["task"]["descriptionMarkdown"] == "Saved description"
        activity = run(binary, store, "activity", TASK, "--since", "500")
        assert activity["data"][0]["sequence"] == 501 and activity["data"][0]["previewOnly"] is True
        context = run(binary, store, "context", TASK, "--include-notes")
        assert context["data"]["notes"][0]["content"] == "# Evidence\nSynthetic saved note.\n"
        assert context["data"]["throughSequence"] >= 1 and context["truncated"] is True
        assert_lower_uuid_values(context)
        capped = run(binary, store, "activity", TASK, "--since", "0", expect=6)
        assert capped["error"]["code"] == "outputLimit"
        today = run(binary, store, "summarize-context", "--today")
        task_context = today["data"]["tasks"][0]
        assert task_context["detail"]["task"]["id"] == TASK
        assert task_context["detail"]["chats"][0]["identity"]["sessionID"] == SESSION
        assert task_context["activity"]["items"][0]["id"] == ENTRY
        malformed = run(binary, store, "show", "not-a-uuid", expect=2)
        assert malformed["error"]["code"] == "invalidInput"
        unavailable = root / "newer.sqlite"; sqlite3.connect(unavailable).close()
        bad = run(binary, unavailable, "list", expect=4)
        assert bad["error"]["code"] == "unsupportedSchema"
        after = hashlib.sha256(store.read_bytes()).hexdigest()
        assert before == after, "read-only CLI changed the synthetic store"
    print("cider CLI synthetic verification passed")


if __name__ == "__main__":
    main()
