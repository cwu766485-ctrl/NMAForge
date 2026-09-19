#!/usr/bin/env python3
"""Verify a completed physical migration against its map and content snapshots."""

from __future__ import print_function

import argparse
import json
import os
from pathlib import Path


ACTIONS = {"move", "retain_protected", "compatibility_shim"}


def valid_relative(value):
    if not isinstance(value, str) or not value or os.path.isabs(value):
        return False
    normalized = os.path.normpath(value).replace("\\", "/")
    return normalized != "." and not normalized.startswith("../") and "/../" not in normalized


def content_key(entry):
    if not entry:
        return None
    if entry.get("type") == "file":
        return ("file", entry.get("sha256"), entry.get("size"))
    if entry.get("type") == "symlink":
        return ("symlink", entry.get("target"))
    return (entry.get("type"), entry.get("error"))


def load_snapshot(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    return {entry["path"]: entry for entry in data.get("entries", [])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("migration_map", type=Path)
    parser.add_argument("before_snapshot", type=Path)
    parser.add_argument("after_snapshot", type=Path)
    parser.add_argument("--allow-in-progress", action="store_true", help="Do not fail entries not yet marked completed")
    args = parser.parse_args()

    mapping = json.loads(args.migration_map.read_text(encoding="utf-8"))
    before = load_snapshot(args.before_snapshot)
    after = load_snapshot(args.after_snapshot)
    errors = []
    warnings = []
    entries = mapping.get("entries")
    if mapping.get("format") != 1:
        errors.append("migration map format must be 1")
    if not isinstance(entries, list) or not entries:
        errors.append("migration map must contain a non-empty entries list")
        entries = []

    seen_from = set()
    seen_to = set()
    checked = []
    for index, entry in enumerate(entries):
        label = "entries[%d]" % index
        action = entry.get("action")
        source = entry.get("from")
        destination = entry.get("to")
        status = entry.get("status")
        if action not in ACTIONS:
            errors.append("%s has unsupported action %r" % (label, action))
            continue
        if not valid_relative(source):
            errors.append("%s has invalid source path %r" % (label, source))
            continue
        if source in seen_from:
            errors.append("source appears more than once: %s" % source)
        seen_from.add(source)
        if not args.allow_in_progress and status != "completed":
            errors.append("%s (%s) is not marked completed" % (label, source))
        old = before.get(source)
        new_source = after.get(source)
        if not old:
            errors.append("%s source missing from before snapshot: %s" % (label, source))
            continue

        if action == "move":
            if not valid_relative(destination):
                errors.append("%s move has invalid destination %r" % (label, destination))
                continue
            if destination in seen_to:
                errors.append("destination appears more than once: %s" % destination)
            seen_to.add(destination)
            new_destination = after.get(destination)
            if new_source:
                errors.append("move source still exists after migration: %s" % source)
            if not new_destination:
                errors.append("move destination missing after migration: %s" % destination)
            elif content_key(old) != content_key(new_destination):
                errors.append("move content changed: %s -> %s" % (source, destination))
            checked.append({"action": action, "from": source, "to": destination})
        elif action == "retain_protected":
            if content_key(old) != content_key(new_source):
                errors.append("protected path changed or disappeared: %s" % source)
            if not entry.get("reason"):
                errors.append("protected path lacks a reason: %s" % source)
            checked.append({"action": action, "from": source})
        else:
            if not valid_relative(destination):
                errors.append("%s compatibility shim has invalid destination %r" % (label, destination))
                continue
            if destination in seen_to:
                errors.append("destination appears more than once: %s" % destination)
            seen_to.add(destination)
            new_destination = after.get(destination)
            if not new_source:
                errors.append("compatibility shim missing at old path: %s" % source)
            if not new_destination:
                errors.append("compatibility target missing: %s" % destination)
            elif content_key(old) != content_key(new_destination):
                errors.append("compatibility target content changed: %s -> %s" % (source, destination))
            if not entry.get("consumers") or not entry.get("validation"):
                errors.append("compatibility shim lacks consumers or validation: %s" % source)
            warnings.append("compatibility shim remains at %s; remove it when external consumers migrate" % source)
            checked.append({"action": action, "from": source, "to": destination})

    report = {
        "migration_map": str(args.migration_map),
        "checked_entries": checked,
        "errors": errors,
        "warnings": warnings,
        "physical_migration_ok": not errors,
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0 if not errors else 2


if __name__ == "__main__":
    raise SystemExit(main())
