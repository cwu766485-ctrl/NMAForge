# R202 — Execution RTM evidence-link audit — 2026-11-02

## Run

- Run ID: `CL-RTM-LINK-AUDIT-R202-20261102`
- RTM baseline: published closeout commit `1a304d102df958365dfceacf967629f93b8413a5`, tree `0a3fa7555341146efe4b261ea3af31d1c67bb292`
- Checker: `tools/verify_compute_cluster_rtm.py`
- Command: `python3 tools/verify_compute_cluster_rtm.py`

## Result

```text
REQ-CL execution matrix: 28/28 rows
REQ-PC execution matrix: 10/10 rows
dispositions: {'PARTIAL': 14, 'PASS-SCOPED': 24}
repository evidence links: 92/92 targets exist
COMPUTE_CLUSTER_RTM_INTEGRITY_PASS: 38/38 IDs; evidence fields populated; repository links resolve
```

The checker validates the expected IDs, duplicate/missing rows, disposition labels, six-column row shape, nonempty Test/Checker, Coverage/Result, Run/Seed, and Evidence cells, and existence of each relative Markdown evidence target within the repository. Absolute `/tmp` log references and external URLs are not checked. Existing repository documents are not thereby proven to contain sufficient or reproducible evidence; this audit does not replay the historical runs.

## Sign-off impact

No requirement disposition changes: 24 remain `PASS-SCOPED`, 14 remain `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**. The latest VCS replay attempt remains `BLOCKED_ENV` in [R199](COMPUTE_CLUSTER_FINAL_HEAD_REPLAY_R199_2026-11-02.md).
