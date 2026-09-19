# Project
<One-sentence purpose and scope.>

# Sources of Truth
- `<path>` — <what it defines>

# Important Paths
- `<path>` — <purpose>

# Tool Entry
- `<command>` — <build/test/simulation/regression entry point>

# Before Work
Read:
1. `AGENTS.md`
2. `<execution frontier or project plan>`
3. `<relevant specification>

# Common Commands
- `<command>` — <when to run>

# Modification Policy
Allowed:
- `<path>`

Do not modify without approval:
- `<generated/vendor/signoff/secrets path>`

# Debug and Review Policy
- Reproduce the failure and find the root cause before editing.
- Do not delete or weaken assertions, tests, lint rules, or scoreboard expectations to make a check pass.
- Check the specification before changing expected behavior.

# Definition of Done
- Failing case reproduced (when fixing a bug).
- Target check passes; related checks pass when practical.
- No new errors or warnings of the project’s prohibited classes.
- Relevant status/frontier documentation updated.
