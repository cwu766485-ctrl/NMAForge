# Matrix Protection with pending CNM response reset epoch — R156

**Result: PASS for this bounded testpoint; Compute Cluster v1.0 remains HOLD.** R156 exercises a real Matrix source-B Protection denial while a separate real CNM task has accepted SPAD reads outstanding, then checks reset suppression and recovery for both engines. It adds evidence to the existing partial requirements; it does not close the full legal engine × fault × phase × reset matrix.

## Frozen identity and scope

| Item | Identity |
|---|---|
| Clean replay test SHA | `96874695e7a5fa1865b1b9ad97e8546ff934b8d6` |
| Test tree | `cf362140553abf17d9d2795cc80938adb94ec5c3` |
| Parent | `6da42896cd9173ec6834516a59967d91c1df94fc` |
| Test ID | `TC-CL-R156-MATRIX-SOURCE-B-PROTECTION-CNM-PENDING-RESET` |
| Run ID | `R156-UVM-MATRIX-PROTECTION-CNM-RESET-3S-20261101` |
| Changed files in test commit | `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh`; `dv/uvm/sim/Makefile` |
| Tools | Synopsys VCS `V-2023.12-SP1_Full64`; UVM 1.2; behavioral SPAD (`+define+VCS`) |

R156 changes the UVM sequence and regression gate only. Product RTL, SPEC, and checker strictness are unchanged. The regression was run from a detached clean worktree at the exact test SHA.

## Scenario and checkers

The test initializes a legal 16-output CNM GEMV with an independent signed-byte Golden, then publishes the CNM descriptor before the Matrix descriptor in CMDQ order. It observes CNM's real accepted and returned SPAD traffic, and requires both Matrix and CNM to be active when Matrix reaches an accepted, Protection-denied source-B request. The production Matrix `error_code` is read hierarchically and must equal `ERR_PROTECTION=6`. The Matrix descriptor uses the same 4×4 encoding as the existing reset test (`M=4`, `N=4`, descriptor length field `1`); its source-A read must have been accepted before the denied B request.

At the shared reset cut, the CNM monitor has counted 152 accepted reads and 148 returned reads, so four accepted responses are pending. Reset/release checkers require no SPAD, Matrix, or CNM response during four reset cycles and eight release-quiet cycles. The test verifies CPLQ tail zero, unchanged completion sentinels, unchanged Matrix output, and the CNM accepted-write prefix plus untouched suffix. In this workload the accepted CNM write prefix is 0/16.

Both tasks are then reissued in a fresh epoch with new task IDs. The checker verifies ordered CNM then Matrix completions, all 16 CNM Golden outputs, and all 16 Matrix outputs. A six-bin phase covergroup is required to reach 6/6.

| Seed | Matrix accepted A reads | Matrix error | CNM reads accepted/returned at reset | Reset-dropped | Old epoch suppressed | Recovery | Focused bins | UVM warning/error/fatal |
|---|---:|---|---:|---:|---|---|---|---|
| 20261025 | 1 | `ERR_PROTECTION=6` | 152/148 | 4 | Yes | Matrix 16/16; CNM 16/16 | 6/6 (100%) | 0/0/0 |
| 20261026 | 1 | `ERR_PROTECTION=6` | 152/148 | 4 | Yes | Matrix 16/16; CNM 16/16 | 6/6 (100%) | 0/0/0 |
| 20261027 | 1 | `ERR_PROTECTION=6` | 152/148 | 4 | Yes | Matrix 16/16; CNM 16/16 | 6/6 (100%) | 0/0/0 |

The complete per-seed Memory Scoreboard checks 67,961 words with zero mismatch, unknown read, stale epoch, or orphan response. Pending response ledgers end at zero. Merged URG reports 100.00% for `matrix_protection_cnm_reset_cg` and the enclosing `cluster_cg`. This is functional testpoint coverage, not 100% RTL code coverage or global sign-off closure. The VCS compile log contains no `Warning-`, `Error-`, or `[TFIPC]` diagnostic.

## Fixed-SHA command and evidence

The following command exits 0 from the detached R156 worktree and prints `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r156_clean_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'
```

Per-seed logs are `/tmp/nmaforge_r156_clean_uvm/seed_*/run.log`; compile log is `/tmp/nmaforge_r156_clean_uvm/compile.log`; merged functional group evidence is `/tmp/nmaforge_r156_clean_uvm/urg_merged/groups.txt`. The logs/report archive is `/tmp/nmaforge_r156_matrix_protection_cnm_clean_logs.tar.gz`, SHA-256 `68a12a842cf0df8d6a227e08b852c3c8bf5f59ed320562354bdac0858ed273db`. Compile log SHA-256 is `5e75a290cf1d15140030c04b846b0aeab765175987054cc987d71add702afa07`; merged groups SHA-256 is `0359f98b9c8c24d3c3bf5854a1ecb3deb5cac2eb8ac94d1b2da2b265827ea56a`.

## Requirement traceability delta

| Requirement | Disposition | Testpoint / checker / observed coverage | Run ID, seeds, and evidence |
|---|---|---|---|
| REQ-CL-017 | PARTIAL | `TC-CL-R156-MATRIX-SOURCE-B-PROTECTION-CNM-PENDING-RESET`; production Matrix denied-B and error-code checker while CNM has pending reads. Other engines/faults/phases remain open. | `R156-UVM-MATRIX-PROTECTION-CNM-RESET-3S-20261101`; `20261025/26/27`; per-seed `run.log` |
| REQ-CL-018 | PARTIAL | Reset/release quiet-window and response-owner checkers observe four pending CNM reads dropped and no old-epoch responses. This is one Matrix/CNM reset cut. | Same run and seeds; `urg_merged/groups.txt` |
| REQ-CL-019 | PARTIAL | CPLQ tail and completion sentinels remain unchanged for the interrupted epoch; both new-epoch completions retire in CMDQ order. Other error-priority/backpressure combinations remain open. | Same run and seeds; per-seed `run.log` |
| REQ-CL-027 | PARTIAL | Production `ERR_PROTECTION=6`, suppressed old task, new task IDs/status/results checked. The full engine × error ABI matrix remains open. | Same run and seeds; per-seed `run.log` |
| REQ-PC-006 | PARTIAL | Full Memory Scoreboard checks 67,961 words/seed with zero mismatch/unknown/stale/orphan; all pending ledgers drain. Broader owner/fault/backpressure combinations remain open. | Same run and seeds; `CLUSTER_MEMORY_SCOREBOARD` in per-seed logs |
| REQ-PC-007 | PARTIAL | Real Matrix and CNM issue traffic through the production shared SPAD. Matrix accepts A, CNM has four pending responses at reset; this does not measure every pairwise collision or all seven engines. | Same run and seeds; per-seed `run.log` |

The 38-row RTM remains **24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN**. `CL-DV-v1.0` remains **HOLD**; no requirement is promoted by this bounded result.
