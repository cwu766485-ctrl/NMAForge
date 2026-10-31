# Compute Cluster Matrix Parity + CNM Abort Owner Cross — R140

**Run ID:** `R140-MATRIX-PARITY-CNM-ABORT-OWNER-3S-20261031`

**Result:** PASS for this directed testpoint; no global requirement or sign-off closure.

**Fixed test source:** `c9e0214dfbf8847666baa0b3b10faa973b842224`

**Tree:** `b7da3b220d847fd360614e375c007839075291ae`

**Product RTL/SPEC:** unchanged by R140; the commit changes only the UVM sequence and regression Makefile.

## Scenario and checks

The real top dispatches a legal CNM task before a legal Matrix task. Matrix receives a real SPAD parity response while CNM remains active. The sequence checks Matrix `ERR_PARITY=0x52`, issues software Abort, and verifies the accepted CNM task retires with `ERR_ABORT=0x32` before the Matrix parity completion in CMDQ order.

The point checks active-engine overlap, shared-bank acceptance, Matrix/CNM response ownership, held-read cancellation, ordered completion payloads, CNM Golden output prefix/suffix and read drain, and the absence of output writes after the Abort sample. At this trigger point CNM had accepted **0/16** output words before Abort; this test therefore does not claim a nonzero accepted-write prefix for this cross. Separate prefix tests remain the evidence for that behavior.

## Exact-source regression

Tool versions: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

Commands, run from the repository root:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r140_clean_replay_c9e0214 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=20261025

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r140_clean_replay_c9e0214 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r140_clean_mutations_c9e0214
```

The regression ran in detached clean worktree `/tmp/nmaforge_r140_clean_c9e0214` at the fixed SHA above. All three UVM seeds passed. Per seed the required marker reports 7 overlap cycles, 3 shared bank accepts, 1 Matrix response, 41 CNM responses, zero response-route mismatch, one parity held-read cancellation, and zero post-Abort CNM writes. Each run reports 44,811 checked memory words, zero mismatch/unknown/stale/orphan responses, empty pending ledgers, and UVM warning/error/fatal counts `0/0/0`. Focused `cluster_cg` applicable coverage is 100.0%, with completion-read response explicitly marked N/A; this is only the declared focused group. The merged mixed RTL/testbench/UVM URG score is 56.01% (line 69.31%, condition 63.51%, FSM 41.91%, branch 59.59%, assertion 72.00%, group 29.72%); it is not functional requirement closure.

Top Smoke ends `TEST PASS`. Mapper regeneration reports 86 descriptors and 60 tensors. The 28-case checker-sensitivity campaign exits successfully; all 28 per-run logs contain the mutation-injected marker, the expected checker-caught marker, and the expected nonzero UVM_ERROR. It covers Address, Data, Response Owner, WSTRB, Completion Error Code, Write After Error, Response Epoch, and Done/Missing-Done/Duplicate-Done on each of seven engine bits. These are passive-monitor checker-sensitivity mutations, not DUT RTL fault injection.

## Evidence artifacts

Artifacts are kept outside the repository at the paths below. Hashes identify the captured files used for this report.

| Artifact | SHA-256 |
|---|---|
| Seed `20261025` log | `852304908d8eee8456ab656b3d1e5cb6ced2ca23036a8dd7f9f84b9635af722c` |
| Seed `20261026` log | `5296d43b6b06a0ca9f302a0037694c7021955a4688773c6cdf431a90490da477` |
| Seed `20261027` log | `e34597c35267cb47ec03052e329c7a0c98408ee30aaa08b211078585d86589ae` |
| UVM compile log | `cf7d44ddd426e2e396837e81da374e9f4ef81dd2967c3c94ba474d47250dcac2` |
| URG merged report log | `2337104c21be6e431d07022af8bae6e302c8144801a00fa9b8b07552eda3660e` |
| Mutation per-log SHA256 manifest | `a09353480b7f922e47861b2029b29c5a60abd68b55787b682990d328a3fd582f` |
| Top Smoke log | `5927d091f333cc2987f485c9929d7212425507072d0a07b9596de7d9ae0e7ae3` |
| Top Smoke compile log | `6697823a2b34a01a831064b4daad92c14bea438b5c58d975800d08977ea94dd2` |

## RTM and sign-off effect

This bounded point adds evidence to `REQ-CL-017`, `REQ-CL-019`, `REQ-CL-027`, and `REQ-PC-006/007`. Their dispositions remain **PARTIAL** because the wider legal Engine × Fault × Phase × Reset matrix, other error/owner directions, additional accepted-write cut points, and production-engine backpressure combinations are not closed. The full RTM remains **24 PASS-SCOPED / 14 PARTIAL** and `CL-DV-v1.0` remains **HOLD**.
