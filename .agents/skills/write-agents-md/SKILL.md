---
name: write-agents-md
description: Inspect a software, hardware, or mixed repository and create or update a concise, actionable AGENTS.md (normally 80–120 lines and never over 150). Use when onboarding Codex to a repository, documenting project conventions, refreshing stale agent instructions, or converting scattered build/debug knowledge into durable repo guidance.
---

# Write AGENTS.md

Create the smallest durable instruction file that answers: “How should an agent work in this repository?” Do not turn AGENTS.md into a project encyclopedia, a prompt about expertise, or a duplicate of design documentation.

## Workflow

1. Establish scope. Identify the repository root and any existing `AGENTS.md` files. A nested file applies to its subtree; preserve useful narrower rules and avoid contradicting them.
2. Discover evidence before writing. Inspect `README*`, `CONTRIBUTING*`, `Makefile`, `justfile`, package/tool manifests, CI workflows, `docs/`, and top-level directories. Use `rg --files` and targeted reads. Treat checked-in commands and CI as stronger evidence than guesses.
3. Check existing instructions and history for conventions, generated files, required checks, and ownership. Do not invent commands, paths, test results, or policies. If a fact is uncertain, say so or omit it.
4. Draft or update the root `AGENTS.md` using the template in [references/agents-template.md](references/agents-template.md). Keep it under 150 lines; target 80–120. Preserve project-specific facts and remove stale or redundant prose.
5. Make rules operational: name exact commands, paths, prerequisites, approval boundaries, and expected evidence. Prefer imperative bullets. Link to detailed sources instead of copying them.
6. Validate with `python3 <skill-dir>/scripts/validate_agents.py AGENTS.md` (or `python` if that is the repository convention). Re-read the result and fix omissions or unsupported claims.

## Required content

Include only sections supported by repository evidence, in roughly this order:

- project purpose and scope;
- sources of truth (specs, architecture, verification, API/design docs);
- important paths and tool entry points;
- before-work reading order;
- build, test, lint, simulation, or regression commands;
- modification policy, including generated/vendor/signoff boundaries;
- debugging and review invariants (find root cause; do not weaken assertions or expectations merely to pass);
- definition of done, including relevant validation and updating execution-frontier/status notes.

Mention language/tool versions only when discoverable. Distinguish required checks from optional ones. For hardware repositories, preserve RTL/DV/tool-flow distinctions and signoff constraints; for software repositories, include package, service, migration, and integration-test commands when evidenced.

## Quality and safety checks

- Keep the file self-contained enough for a new agent, but defer detailed domain knowledge to linked docs.
- Use repository-relative paths and commands that work from the stated root.
- Never prescribe deleting tests, assertions, lint waivers, generated outputs, or scoreboard expectations to hide failures.
- Do not broaden write permissions. Explicitly mark generated, third-party, secrets, release, and signoff paths as read-only or approval-required when applicable.
- Avoid speculative universal rules (“always use…”) unless the repository demonstrates them.
- Preserve existing valid user edits; update only what is stale, missing, or requested.

## Output

Write `AGENTS.md` unless the user requests another location. Report the path, line count, evidence inspected, commands included, and any unresolved assumptions. If an AGENTS.md already exists, summarize material changes rather than dumping the entire file.
