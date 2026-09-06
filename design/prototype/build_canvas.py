"""Assemble the editable preview sources into the self-contained canvas."""
from pathlib import Path

root = Path(__file__).resolve().parent
styles = "\n".join((root / name).read_text() for name in ("base.css", "tasks.css", "chrome.css", "document.css"))
markup = (root / "shell.html").read_text()
scripts = (root / "tasks.js").read_text() + (root / "app.js").read_text()
output = root.parent / "cider-canvas.html"
output.write_text("<style>\n" + styles + "</style>\n" + markup + "<script>\n" + scripts + "</script>\n")
print(output)
