#!/usr/bin/env python3
"""Safely add a minimal AI-native chip-project scaffold; never overwrite files."""

import argparse
from pathlib import Path

FILES = {
    "docs/project-overview.md": """# Project overview

No project-specific facts have been established at scaffold time.

Before adding RTL or DV, record the project/IP purpose, lifecycle stage, supported configurations, top-level blocks, interfaces, clocks/resets, dependencies, and authoritative requirement sources. Mark each unknown explicitly rather than inferring it.
""",
    "docs/spec/index.md": """# Specification index

No normative specification is indexed yet.

Add each authoritative requirement/specification with version, owner, requirement identifier, and implementation/verification traceability. Do not treat this index as the specification itself.
""",
    "docs/architecture/index.md": """# Architecture index

No architecture facts are indexed yet.

Map hierarchy, interfaces, data/control paths, clock/reset/power domains, parameters, registers, and implementation notes to authoritative documents as they are created.
""",
    "docs/verification/strategy.md": """# Verification strategy

No verification strategy is established yet.

Before claiming verification progress, define scope, environments, test levels, reference models, assertions/formal plan, coverage model, regressions, configurations, exclusions, and signoff criteria.
""",
    "docs/exec-plans/active/execution-frontier.md": """<!-- organize-chip-project:generated-file -->
# Execution frontier

## Objective

Establish the project specification, design/DV scope, and first reproducible smoke check without inventing requirements or flow commands.

## Baseline and evidence

No baseline exists yet. Record revision, workspace state, environment, commands, outcomes, and log paths before the first functional change.

## Completed

No completed work recorded.

## Current state and blockers

Project requirements, RTL/DV hierarchy, and canonical tool commands have not yet been established.

## Exact next action

Fill `docs/project-overview.md` and `docs/spec/index.md` from authoritative input, then run `generate_agent_native.py <project-root> --apply --update-agents` to refresh the Agent entrance.

## Acceptance criteria and residual risk

The project is not ready to claim functional equivalence, verification closure, or signoff until requirements and reproducible checks exist.
""",
    ".gitignore": """# Reproducible run outputs (adjust to the project's established policy)
runs/
""",
}

DIRS = [
    "docs/exec-plans/completed",
    "config",
    "rtl",
    "dv",
    "tools",
    "runs",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--apply", action="store_true", help="Create missing items; default is dry-run")
    args = parser.parse_args()
    root = args.root.resolve()

    actions = []
    for directory in DIRS:
        path = root / directory
        if not path.exists():
            actions.append(("mkdir", path, None))
    for relative, content in FILES.items():
        path = root / relative
        if not path.exists():
            actions.append(("write", path, content))

    for action, path, content in actions:
        print(f"{action}: {path}")
        if args.apply:
            if action == "mkdir":
                path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
    print(("applied" if args.apply else "dry-run") + f": {len(actions)} action(s); existing paths untouched")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
