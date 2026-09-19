#!/usr/bin/env python3
"""Small deterministic validator for generated AGENTS.md files."""
import argparse
from pathlib import Path
import re

def main():
    p = argparse.ArgumentParser()
    p.add_argument("file", nargs="?", default="AGENTS.md")
    args = p.parse_args()
    path = Path(args.file)
    if not path.is_file():
        raise SystemExit(f"error: not found: {path}")
    lines = path.read_text(encoding="utf-8").splitlines()
    errors = []
    if len(lines) > 150:
        errors.append(f"{len(lines)} lines (maximum is 150)")
    if not re.search(r"^#\s+", path.read_text(encoding="utf-8"), re.M):
        errors.append("missing Markdown heading")
    text = "\n".join(lines).lower()
    for term in ("source", "command", "modif", "done"):
        if term not in text:
            errors.append(f"missing topic containing '{term}'")
    if errors:
        raise SystemExit("invalid AGENTS.md: " + "; ".join(errors))
    print(f"ok: {path} ({len(lines)} lines)")

if __name__ == "__main__":
    main()
