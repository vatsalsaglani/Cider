#!/usr/bin/env python3
"""Exercise the packaged CLI through a separate native app with only synthetic data."""
import argparse
import json
import os
from pathlib import Path
import signal
import sqlite3
import subprocess
import tempfile
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--app', required=True, type=Path)
args = parser.parse_args()
app = args.app.resolve()
binary = app / 'Contents/Helpers/cider'

with tempfile.TemporaryDirectory(prefix='cider-write-smoke-') as temporary:
    root = Path(temporary)
    store = root / 'work.sqlite'
    pid = None

    def run(*arguments, body=None, expect=0):
        result = subprocess.run([str(binary), '--store', str(store), *arguments, '--json'],
                                input=body, capture_output=True, timeout=40)
        assert result.returncode == expect, (arguments, result.returncode, result.stdout, result.stderr)
        return json.loads(result.stdout if expect == 0 else result.stderr)

    try:
        subprocess.run(['open', '-n', '-F', str(app), '--env', 'CIDER_LINKED_FIXTURE_ROOT=' + str(root),
                        '--args', '-ApplePersistenceIgnoreState', 'YES'], check=True)
        for _ in range(200):
            leases = list(root.glob('.cider-cli-*/lease'))
            if leases:
                pid = json.loads(leases[0].read_text())['processID']
                break
            time.sleep(.1)
        assert pid is not None, 'Native write service did not start'
        help_result = subprocess.run([str(binary), '--help'], capture_output=True, text=True, check=True)
        assert 'note append' in help_result.stdout
        run('todo', 'create', '--title', 'Invalid day', '--day', '2026-02-30', expect=2)
        task = run('todo', 'create', '--title', '--json', '--description-file', '-', body=b'Keep description')['data']['task']
        assert task['title'] == '--json'
        updated = run('todo', 'update', task['id'], '--if-revision', str(task['revision']), '--title', 'Changed')['data']['task']
        assert updated['descriptionMarkdown'] == 'Keep description'
        run('todo', 'update', task['id'], '--if-revision', str(task['revision']), '--title', 'Stale', expect=5)
        complete = run('todo', 'complete', task['id'], '--if-revision', str(updated['revision']))['data']['task']
        assert complete['status'] == 'done'
        reopened = run('todo', 'reopen', task['id'], '--if-revision', str(complete['revision']))['data']['task']
        assert reopened['status'] == 'planned'
        run('todo', 'add-note', task['id'], '--markdown-file', '-', body=b'User-requested journal note')
        markdown = b'---\ntitle: Plan\n---\n# Plan\n![asset](Plan.assets/local.png)\n'
        saved = run('note', 'create', '--title', 'Plan', '--markdown-file', '-', body=markdown)['data']
        path = Path(saved['path'])
        assert path.parent == root / 'Cider'
        assert path.read_bytes() == markdown
        note = saved['note']['id']
        assert run('note', 'show', note)['data']['markdown'].encode() == markdown
        assert run('note', 'list')['data']
        assert run('folder', 'list')['data']
        run('todo', 'link-note', task['id'], '--note', note, '--role', 'plan')
        appended = run('note', 'append', note, '--if-hash', saved['sha256'], '--markdown-file', '-', body=b'\nMore\n')['data']
        run('note', 'append', note, '--if-hash', saved['sha256'], '--markdown-file', '-', body=b'Wrong', expect=5)
        assert path.read_bytes() == markdown + b'\nMore\n'
        replacement = markdown + b'\nExact replacement\n'
        run('note', 'update', note, '--if-hash', appended['sha256'], '--markdown-file', '-', body=replacement)
        assert path.read_bytes() == replacement
        run('note', 'create', '--title', '../escape', expect=2)
        run('note', 'create', '--title', 'Unknown root', '--folder', str(uuid.uuid4()), expect=3)
        run('note', 'create', '--title', 'Bad UTF-8', '--markdown-file', '-', body=b'\xff', expect=2)
        run('note', 'create', '--title', 'Too large', '--markdown-file', '-', body=b'x' * 65537, expect=6)
        with sqlite3.connect(store.as_uri() + '?mode=ro', uri=True) as db:
            assert db.execute('SELECT count(*) FROM task_note_links').fetchone()[0] == 1
            assert db.execute('SELECT count(*) FROM tasks').fetchone()[0] == 1
            assert db.execute('SELECT count(*) FROM notes').fetchone()[0] == 1
        print('PASS: packaged native task writes, completion/reopen, journal, note create/update/append, linking, conflict/input guards and default-folder isolation.')
    finally:
        if pid:
            # The fixture lease names the exact app process serving this temporary store.
            command = subprocess.check_output(['ps', '-p', str(pid), '-o', 'comm='], text=True).strip()
            if Path(command).resolve() == (app / 'Contents/MacOS/Cider').resolve():
                os.kill(pid, signal.SIGTERM)
                time.sleep(.2)
