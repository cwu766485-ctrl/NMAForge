#!/usr/bin/env python3
"""Create and compare content inventories for conservative project migration."""

import argparse
import hashlib
import json
import os
from collections import defaultdict
from pathlib import Path

DEFAULT_EXCLUDES = {".git", ".hg", ".svn", "__pycache__"}


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def snapshot(root, excludes):
    root = root.resolve()
    entries = []
    for base, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in excludes)
        for name in sorted(files):
            path = Path(base) / name
            rel = path.relative_to(root).as_posix()
            try:
                if path.is_symlink():
                    entries.append({"path": rel, "type": "symlink", "target": os.readlink(path)})
                else:
                    stat = path.stat()
                    entries.append({"path": rel, "type": "file", "size": stat.st_size, "sha256": digest(path)})
            except OSError as exc:
                entries.append({"path": rel, "type": "error", "error": str(exc)})
    return {"format": 1, "root": str(root), "excludes": sorted(excludes), "entries": entries}


def content_key(entry):
    if entry["type"] == "file":
        return ("file", entry["sha256"], entry["size"])
    if entry["type"] == "symlink":
        return ("symlink", entry["target"])
    return ("error", entry.get("error", ""))


def compare(before, after):
    old = {e["path"]: e for e in before["entries"]}
    new = {e["path"]: e for e in after["entries"]}
    added = sorted(set(new) - set(old))
    removed = sorted(set(old) - set(new))
    changed = sorted(p for p in set(old) & set(new) if content_key(old[p]) != content_key(new[p]))

    new_by_content = defaultdict(list)
    for path in added:
        new_by_content[content_key(new[path])].append(path)
    moves = []
    unmatched_removed = []
    for path in removed:
        candidates = new_by_content.get(content_key(old[path]), [])
        if candidates:
            destination = candidates.pop(0)
            moves.append({"from": path, "to": destination})
            added.remove(destination)
        else:
            unmatched_removed.append(path)

    report = {
        "unchanged_path_count": len(set(old) & set(new)) - len(changed),
        "moved_same_content": moves,
        "added": added,
        "removed_without_same_content_destination": unmatched_removed,
        "changed_in_place": changed,
    }
    report["preservation_ok"] = not unmatched_removed and not changed
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command")
    snap = sub.add_parser("snapshot")
    snap.add_argument("root", type=Path)
    snap.add_argument("-o", "--output", type=Path, required=True)
    snap.add_argument("--exclude", action="append", default=[])
    comp = sub.add_parser("compare")
    comp.add_argument("before", type=Path)
    comp.add_argument("after", type=Path)
    args = parser.parse_args()

    if not args.command:
        parser.error("a command is required")

    if args.command == "snapshot":
        data = snapshot(args.root, DEFAULT_EXCLUDES | set(args.exclude))
        args.output.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"snapshotted {len(data['entries'])} entries to {args.output}")
        return 0

    before = json.loads(args.before.read_text(encoding="utf-8"))
    after = json.loads(args.after.read_text(encoding="utf-8"))
    report = compare(before, after)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if report["preservation_ok"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
