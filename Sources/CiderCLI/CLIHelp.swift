enum CLIHelp {
    static let text = """
    Cider CLI
    Reads work with Cider closed. Writes require Cider running on the selected store.
    All commands return JSON; --json is accepted for compatibility.

    cider [--store PATH] todo list [--today]
    cider todo show UUID
    cider todo activity UUID [--since SEQUENCE]
    cider todo context UUID [--include-notes]
    cider todo summarize-context --today
    cider todo create --title TEXT [--description-file FILE] [--day YYYY-MM-DD] [--status STATUS]
    cider todo update UUID --if-revision N [--title TEXT] [--description-file FILE] [--day YYYY-MM-DD] [--status STATUS]
    cider todo complete UUID --if-revision N
    cider todo reopen UUID --if-revision N
    cider todo add-note UUID --markdown-file FILE
    cider todo link-note UUID --note NOTE_UUID --role plan|context|evidence

    cider folder list
    cider note list [--folder ROOT_UUID] [--cursor CURSOR]
    cider note show UUID
    cider note create --title TEXT [--folder ROOT_UUID] [--markdown-file FILE]
    cider note update UUID --if-hash SHA256 --markdown-file FILE
    cider note append UUID --if-hash SHA256 --markdown-file FILE

    FILE may be - to read UTF-8 Markdown from stdin (maximum 64 KiB).
    Task statuses: planned, inProgress, blocked, readyForReview, done.
    Get the task revision from todo show and the saved note hash from note show.
    note create defaults to ~/Documents/Cider; --folder selects a registered root.
    note update replaces the complete file; append adds exactly the supplied bytes.
    Writes never start agents, approve tools, or infer verification from agent output.
    On a timeout or partial write, inspect saved state before retrying a create or append.
    """
}
