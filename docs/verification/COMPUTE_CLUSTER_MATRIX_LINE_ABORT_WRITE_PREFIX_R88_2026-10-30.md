# Compute Cluster Matrix aligned Line accepted-write Abort prefix — R88

**Date:** 2026-10-30  
**Exact clean code/test SHA:** `ce2e36d0d38a92d70e0bf2f64ff2523617c6dfec`  
**Product RTL/SPEC baseline:** `9d4e9abdba1f745644a485960620fa6bbc4979db`; R88 changes the UVM sequence and regression gate only.  
**Run ID:** `CLUSTER-MATRIX-LINE-ABORT-WRITE-PREFIX-3S-CE2E36D`  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Testpoint

A real-top Matrix 4×16 INT8 GEMM with one packed K word writes an aligned destination through sixteen 128-bit Line transactions. A passive monitor waits for the first accepted Line write, then the sequence issues software Abort. The monitor records every accepted Line address, payload and WSTRB; the independent Golden checks the transaction-order output prefix, row-major SPAD image and all untouched suffix words. The test also drains accepted Matrix reads and checks the completion owner/status.

All three seeds accept exactly 6/16 Line writes (24/64 output words), with WSTRB `16'hffff`, drain 5/5 accepted banked reads, preserve all unaccepted output words, and complete with `ERR_ABORT`. The output Line addresses and payloads match the independent signed Golden. The explicit R88 marker is gated once per seed. The existing focused covergroup remains 31/31 applicable variables; the R88 marker is separately gated and is not counted as a new functional coverage bin.

## Exact clean replay

The first GitHub upload attempt, `a16a176c503bb51a18f45a922d04997539d9ff74`, contained a truncated large sequence-file blob and failed clean compilation. It is superseded by the complete-source correction at the SHA reported above; no PASS is attributed to the truncated commit.

Fresh detached worktree: `/tmp/nmaforge_r86_remote_3d6fe5c`, HEAD `ce2e36d0d38a92d70e0bf2f64ff2523617c6dfec`, full sequence source size 171,000 bytes.

From the worktree root, with default output paths and no overrides:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress uvm_compute_cluster_mutation
```

The command exits 0. All seeds (`20261025/26/27`) report 15,153 scoreboard writes, 17,388 checked words, zero mismatch/unknown/stale, UVM warning/error/fatal `0/0/0`, and the R88 marker `accepted_line_prefix=6/16 accepted_output_words=24/64 read_drain=5/5 wstrb=ffff completion=ERR_ABORT`. The default output roots use one captured run stamp: `/tmp/nmaforge_real_compute_cluster_uvm_20261030_200702_249551336` and `/tmp/nmaforge_compute_cluster_mutations_20261030_200702_249551336`. The 28 passive checker-sensitivity mutations all reach their expected named checker; expected UVM errors in those individual mutation runs are the tested checker responses.

At the same clean SHA, `make ai_smoke` and `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` pass from `dv/subsystem/top_smoke/sim`. Top Smoke retains the existing fixture warning `[LOOP-REROLL-ENABLED]` at `ai_transformer_workload.svh:9`. UVM compilation has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

## Artifact hashes

Generated logs/databases remain under `/tmp`.

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `a9e9ec3e0896a807862dc140a05b1316210149bb9047bce8e6cceeb6664f0b99` |
| Seed 20261025 log | `c0b4bc3751a063831577342910cc1ed77f26871342522bb544549d90535dc457` |
| Seed 20261026 log | `6b830ca0c64f2d61cf2d8ceccdba24d7496b798cba0f5cee461b3ad2932242f7` |
| Seed 20261027 log | `1107da24a2997acaefa2a03639ebe9cc7f8c4c4c76c3efd3836b921159b4cde0` |
| URG merged log | `37fa67f33988bf9cfc5e0373322ea9366aae06df9ac2c8f1d2736915110d6d7f` |
| Mutation log SHA-256 manifest (28 logs) | `dffc1f3eb9c4de88ebca1b0e27e65e2425e2deaf8ccb03b4b1611da0ad152bcc` |
| UVM regression + mutation driver log | `ca8044eaf7a889fd6c0ed73ce5010ca666f85558b3290b0ad9ae6b2535643333` |
| Top Smoke log | `9f60104962c6f24bdf6a167a8b30a2a5e1e199af8ce28b86ee069f1e3aeb0421` |
| 20-case seeded Top log | `8da2dbeae0786e9d8e60ea3b9df76bf433dee995e909117c4851facc1e73bb67` |

## Disposition

R88 closes one additional Matrix error/recovery point: aligned 128-bit Line accepted-write Abort after a deterministic six-Line prefix for this shape and timing point. Scalar fallback remains separately covered by R86. Other Matrix shapes/prefix cut points, all-engine accepted-write prefixes, broad legal fault × phase × reset crosses, external-fabric qualification, and the remaining partial requirements remain open. The RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD. Product RTL/SPEC and requirement dispositions are unchanged.
