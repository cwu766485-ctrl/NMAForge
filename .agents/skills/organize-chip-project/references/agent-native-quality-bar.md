# Agent-Native deliverable quality bar

Deliver an **operational project entrance**, not generic documentation or an empty directory taxonomy. A fresh agent should need at most this read sequence:

```text
AGENTS.md
  ├── docs/ai-native/repository-map.md
  ├── docs/ai-native/design-verification-index.md
  ├── docs/ai-native/commands.md
  └── docs/exec-plans/active/execution-frontier.md
```

## Required `AGENTS.md` facts

Use the actual repository. Include the following only when evidence supports it; write `not discovered` for required but unresolved information.

1. A one-paragraph purpose and current maturity/status, grounded in a README, spec, manifest, or explicit user statement.
2. Source-of-truth map: exact relative paths for requirements/architecture, RTL, DV, manifests/file lists, constraints/power intent, and CI/tool flow.
3. Before-work read order and `git status`/baseline expectations.
4. Exact root-relative commands from Make/Just/CI/README/tool scripts, including configuration or testbench parameters when known. Do not list invented commands.
5. Modification boundaries: generated source and its generator input; vendor/PDK/licensed content; secrets; run artifacts; tests/assertions/waivers/signoff collateral.
6. Debug/review invariants: reproduce, find root cause, preserve assertions/scoreboards/constraints, and review source-order/generated diffs.
7. Definition of done and the frontier path to update.

## Required documentation layer

- `docs/ai-native/repository-map.md` maps actual path → role and lists HDL modules only as a heuristic.
- `docs/ai-native/design-verification-index.md` separates design, DV, constraints, manifests, and tool flow.
- `docs/ai-native/commands.md` gives discovered commands and targets. A command index is not permission to run a tool without its required environment/licence/PDK.
- `docs/exec-plans/active/execution-frontier.md` records baseline, current task, exact next action, evidence, blockers, and residual risk.

## Completion test

Before finishing, ask whether a new agent can answer these questions in under two minutes without a broad repository search:

- What does this IP/chip do and what is its current state?
- Which files are authoritative, and where are RTL, DV, constraints, and tool entry points?
- Which command should I run first, and where should I inspect its result?
- What may I edit, and which files must be regenerated, preserved, or approved?
- What is the exact next task and its acceptance evidence?

If the answer to any question is missing, gather more repository evidence and revise the entrance; do not fill the gap with a generic TODO.
