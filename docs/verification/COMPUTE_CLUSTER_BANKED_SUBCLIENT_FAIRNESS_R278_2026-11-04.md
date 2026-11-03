# Compute Cluster Matrix/CNM Banked-Client Fairness — R278

## Disposition

R278 fixes a reproduced starvation defect in `ai_spad_arbiter` and passes the
focused fairness test plus a clean replay of the exact published source/test
tree. The fix is limited to arbitration priority between the Matrix banked
client and CNM client when they compete for the shared banked class. It does
not add simultaneous multi-bank service for different clients, alter the
software ABI, or close the broader seven-engine fairness requirement.

`REQ-CL-014` and `REQ-PC-007` remain **PARTIAL**. The 38-row requirement matrix
remains 27 `PASS-SCOPED` / 11 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Reproduced defect and correction

The prior one-shot response-ownership test removed the CNM request before
issuing the Matrix banked request, so it could not expose sustained contention.
A diagnostic bench held `cnm_valid=4'hf` and `banked_valid=1` for 24 cycles on
the previous arbiter and observed 24 CNM grants and zero Matrix banked grants.
This diagnostic was used to reproduce the defect; it is not counted as a
formal coverage result.

The RTL now rotates the Matrix/CNM sub-priority after each accepted request in
the shared banked class. Existing response tags remain Matrix `3` and CNM `5`.
Reset retains the previous CNM-first initial priority. The focused regression
holds both clients valid continuously, checks every tagged response and CNM
lane mask, then verifies the registered response pipeline drains.

## Fixed identity and evidence

| Item | Value |
|---|---|
| Exact published source/test SHA | `219da45f03af6062db78527a2351b63ccd2e49cf` |
| Source/test tree | `b5763bbaf34f58e8e84bdfa0e8e661e363cd92d7` |
| Test ID | `TC-PC-R278-SUSTAINED-MATRIX-CNM-BANKED-RR` |
| Focused run ID | `CL-SPAD-BANKED-FAIRNESS-R278-PUB-219DA45-20261104` |
| UVM run ID | `R278-UVM-COMPUTE-CLUSTER-3S-20261104` |
| UVM seeds | `20261025`, `20261026`, `20261027` |
| Simulator | Synopsys VCS / URG `V-2023.12-SP1` |
| Clean replay worktree | `/tmp/nmaforge_r278_published_clean_final` |
| Logs archive | `/tmp/nmaforge_r278_published_clean_replay_logs.tar.gz` |
| Logs archive SHA-256 | `fdfdd1e6d1fafa02830d28d6d7a25a831a3507d7098a88e2733eb1c27f3d2e60` |

The tested SHA is the exact GitHub closeout branch head at replay time. The
documentation commit containing this report is a docs-only descendant; it does
not change the tested source or test tree.

## Requirement-to-evidence disposition

| Requirement | Status | Testpoint and checker | Result |
|---|---|---|---|
| `REQ-CL-014` | PARTIAL | `TC-PC-R278-SUSTAINED-MATRIX-CNM-BANKED-RR`; grant counter, owner/lane checker, response-drain checker | 24 sustained banked-class grants split 12 CNM / 12 Matrix; maximum observed wait is one banked-class opportunity; all response tags and lane masks match; pipeline drains. The all-engine fault/phase/reset fairness cross remains open. |
| `REQ-PC-007` | PARTIAL | Production Matrix banked and CNM request/response clients in the standalone arbiter bench; real-top UVM remains the broader owner evidence | This closes the specific sustained Matrix/CNM starvation defect only. Other requester pairs and full owner/error/latency combinations remain open. |

The focused standalone arbiter bench has no separate URG functional covergroup;
its acceptance criteria are the explicit grant counts, response owner/lane
checks, and drain assertion. Do not interpret the passing test as a new global
coverage percentage.

## Commands and results

All commands below ran in the detached clean worktree at the exact published
SHA above.

```sh
cd dv/subsystem/top_smoke/sim
make ai_spad_arb_run VCS=/usr/local/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

PASS. The ordinary and 10,000-cycle seeded scheduler tests pass. The sustained
three-client scheduler test grants `10/10/10` with max wait `2`; the added
Matrix/CNM banked-class test grants `12/12` over 24 measured cycles with max
wait `1`. All Matrix/CNM responses carry the expected client tag and lane mask,
and the response pipeline drains.

```sh
make ai_compute_spad_path_fairness \
  COMPUTE_SPAD_PATH_RUN=/tmp/nmaforge_r278_final_path \
  VCS=/usr/local/bin/vcs URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

PASS. The 4,096-cycle production SPAD-path test accepts 4,096 requests; per
engine grants are `193/194/193/193/193/193/193`, maximum engine wait is
`22/22/22/22/22/22/22`, and 3,465 responses are checked. URG assertion
failures, incomplete checks, and no-attempt checks are all zero for this test.

```sh
make ai_smoke SEED=20261104 AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS=/usr/local/bin/vcs VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  VCS_ARCH_OVERRIDE=linux
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261104 \
  VCS=/usr/local/bin/vcs VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  VCS_ARCH_OVERRIDE=linux
```

Both PASS. Top Smoke reports `TEST PASS`; the fixed 20-case seeded Top
regression passes. The existing `[LOOP-REROLL-ENABLED]` fixture warning remains
in Top Smoke and is not attributed to R278.

```sh
cd ../../../../
make uvm_compute_cluster_regress \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r278_final_cluster_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

All three real-top UVM seeds PASS. Each seed reports focused applicable
compute coverage at 100%, checks 96,071 Memory Image words across 77,498 writes
with zero mismatch/unknown/stale data, and drains the response ledger:
6,139 accepted, 6,119 returned, 20 reset-dropped, zero route/data/error
mismatch, and zero pending. UVM warning/error/fatal counts are `0/0/0`. The
merged URG report still has two unattempted UVM RAL internal assertions; they
are disclosed and are not reported as DUT checker passes.

## Remaining open items

- The arbiter test covers sustained Matrix/CNM contention only. It does not
  inject randomized downstream memory latency or establish a general bound for
  all seven production engine requesters under every legal phase.
- Engine × fault × phase × reset × response-owner coverage remains incomplete;
  no requirement disposition is promoted by R278.
- The Top Smoke fixture warning remains for its existing disposition.
- This is functional simulation evidence with behavioral SPAD. It is not ASIC
  timing, power, area, or PPA evidence.

## TinyNPU comparison context

The latest paired GEMM evidence is [R273](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R273_2026-11-04.md),
using NMAForge's 16×16 matrix array at depth 4 with prefetch and A-tile cache
enabled, and TinyNPU SHA `8216c22b762011aa20c05fc2768423fd12dda59d`:

| Shape | NMAForge cycles | TinyNPU array cycles | TinyNPU serialized endpoint | Difference vs endpoint | NMAForge SPAD read bytes |
|---|---:|---:|---:|---:|---:|
| 16×16×16 | 152 | 52 | 151 | NMAForge +0.7% | 512 |
| 16×16×32 | 231 | 100 | 231 | parity | 1,024 |
| 32×32×64 | 1,198 | 790 | 1,305 | NMAForge −8.2% | 6,144 |

The 1,305-cycle TinyNPU figure is a normalized serialized endpoint model, not a
measured TinyNPU memory-controller result. On the largest shape, NMAForge uses
50% more read bytes than the model's 4,096-byte allowance. Thus the current
evidence is near parity on small GEMMs and a promising but not yet fair
large-GEMM controller result. Common-memory service, GEMV/decode and CNN remain
unmeasured or unpaired; no overall TinyNPU performance advantage is established.
