# Compute Cluster Clean Replay — R55–R58

**Review source SHA:** `ded9d923a432e869592ec8710a22df5501d8d474`  
**Product RTL/SPEC source:** `f916874a9ce60741a4516eaf9e33ebcae4a676c2`  
**Clean worktree:** `/tmp/nmaforge_matrix_r58_clean_ded9d92`  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`  
**Disposition:** named regression and checker-sensitivity runs PASS; overall
CL-DV-v1.0 remains HOLD.

The source SHA `ded9d92` only changes the Matrix verification Makefile to
compile a genuinely separate `ENABLE_NEXT_K_PREFETCH=0` profile. Product RTL,
UVM tests, and SPEC are byte-identical to their respective source commits
`f916874`/`f24c538`. Generated logs, coverage databases and VCS work areas are
kept outside Git under `/tmp`.

## Results

| Run | Test and configuration | Result |
|---|---|---|
| R55 `CLUSTER-REAL-UVM-DED9D92-3S` | Production `ai_accel_top`, all seven real engines, seeds `20261030`, `20261025`, `20261026` | PASS all 3. Each seed: 100% applicable focused compute testpoints (29/29 variables; completion read-response explicitly N/A and zero-hit), 5,094 accepted writes, 5,368 checked words, 0 mismatch/unknown/stale/orphan, 9 reset-dropped responses, pending queues empty, UVM warning/error/fatal `0/0/0`. Each seed exercised 14/14 selected parity cases, Matrix/CNM owner separation, parallel/staged tasks, abort/reset recovery and all-engine accepted-read reset. |
| R56 `CLUSTER-OBS-MUTATION-DED9D92-25` | Deterministic passive-observation mutations | PASS 25/25 expected checker catches: address, data, owner, WSTRB, and done/missing-done/duplicate-done on each of seven engine bits. This is checker sensitivity, not DUT RTL mutation coverage. |
| R57 `MATRIX-CORE-DEPTH4-DED9D92-3S` | 16×16 Matrix core, depth 4, seeds `20261030`, `20261025`, `20261026` | PASS all 3. Each seed: 18 Golden/layout cases, 35 fault/recovery cases, Matrix Line full-WSTRB/alignment/fallback/protection checks, and 312 stable-stall observations. DUT-only URG line/condition/FSM/branch: `97.08/91.05/93.55/95.52%`; FSM is 49/53 raw transitions. |
| R58 `MATRIX-NOPREF-FALLBACK-DED9D92-3S` | Separately compiled `ENABLE_NEXT_K_PREFETCH=0`, seeds `20261030`, `20261025`, `20261026` | PASS all 3. Each seed hits `ST_MAC→ST_A_REQ` fallback and all five benchmark workloads report `next_k_prefetch=0`. Its narrow URG database is kept separate and is not merged with the enabled profile. |

## Checker and assertion disposition

The R55 merged top-UVM URG has 22 assertion properties: 17 with real
successes, 0 failures, 0 incomplete, and 2 UVM RAL properties without
attempts. Three AXI properties have attempts but no real success in this
compute-only test: AR 4KB, AR payload stability, and AW payload stability.
The AR/AW stall-to-accept cover properties have zero matches; W has three.
Do not infer AXI E2E closure from this run. Earlier R15 supplies AXI E2E
successes for its named source/profile; target external-fabric qualification
remains open under `OPEN-CL-003`.

The R57 enabled-profile URG preserves the observed 49/53 FSM result. R58
confirms the compile-time fallback with a separate build but does not claim
all-profile FSM closure. The 4 residual enabled-profile transitions and the
current VC Formal assumption boundary remain as recorded in R23/R28; no FSM
state forcing was used.

## Reproduction commands

```sh
cd /tmp/nmaforge_matrix_r58_clean_ded9d92/dv/uvm/sim
COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_cluster_r59_clean_ded9d92 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026' \
  make uvm_compute_cluster_regress
COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_cluster_r59_clean_ded9d92 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_cluster_r60_mutation_ded9d92 \
  make uvm_compute_cluster_mutation

cd /tmp/nmaforge_matrix_r58_clean_ded9d92/dv/block/compute/matrix/sim
VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_r58_clean_ded9d92/core \
  SEEDS='20261030 20261025 20261026' make core-random-regress
VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_matrix_r58_clean_ded9d92/no_prefetch \
  SEEDS='20261030 20261025 20261026' make core-no-prefetch-fallback-regress
```

## Evidence paths and hashes

R55 compile: `/tmp/nmaforge_cluster_r59_clean_ded9d92/compile.log`  
R55 merged URG: `/tmp/nmaforge_cluster_r59_clean_ded9d92/urg_merged/`  
R55 seed logs: `/tmp/nmaforge_cluster_r59_clean_ded9d92/seed_{20261030,20261025,20261026}/run.log`  
R56 25 logs: `/tmp/nmaforge_cluster_r60_mutation_ded9d92/`; SHA-256 manifest
`/tmp/nmaforge_cluster_r60_mutation_ded9d92.sha256` (`2ffe50c38f75305e2ea85d549907a1f560a19ba924e478b3347522271544fc6a1`).  
R57 logs/URG: `/tmp/nmaforge_matrix_r58_clean_ded9d92/core/`  
R58 logs/URG: `/tmp/nmaforge_matrix_r58_clean_ded9d92/no_prefetch/`

| Log | SHA-256 |
|---|---|
| R55 compile | `e3236527d300b5f3c1c540a7a43d9ca93d2849ca8179f186f9fda3c5fa4b4e78` |
| R55 merged URG log | `6f0ca602101eed59e5d3885da42436d093d8feae4238fc28cee9abe8d883a588` |
| R55 seed 20261030 | `74944da0c53309542857b356024eb5fbcfcaab1cab4a5dce1fa0bd0d3bec37aa` |
| R55 seed 20261025 | `2e3b9f6dffaeb4348636bca6969c4b88085abbddc6042e2a24603ee3f4cbf656` |
| R55 seed 20261026 | `1ffffbff48681243a78115d78398269482343f0e48e40a4457953f4674dd963d` |
| R57 compile | `0569b3f49a81374bed98feb35d3617afe46ee2309b30529bdf290b9b5664bb2e` |
| R57 URG log | `9cbd19f6f7842264f5204b4897e53abe68872d66b5f1bbce8178282eb7352aad` |
| R57 seed 20261030 | `2137880d8c04f4e3dea92eabe517270fae71ece15d67cc6f0b92a8d742ada6d9` |
| R57 seed 20261025 | `82b17f98ad4bc1bf0f6f15825553bd59542965ba7ce790a7e7f03dbd3740c224` |
| R57 seed 20261026 | `aad8ef92191fc9b5028b9facc77813c5486fb085f0a5e4d69e08710aee5a0c07` |
| R58 compile | `39bad2ac6b3f2db4022bf588cd5376ce9c55a63a25901cb5c88c8d80b39b36fc` |
| R58 seed 20261030 | `ad06ac7e391f779d49502e8fc10850942066ee6e64e436accb2c74e142acb37a` |
| R58 seed 20261025 | `424905193116f543c552f323f767df827dcb36ef7f68bf0059d90c8aa488d4eb` |
| R58 seed 20261026 | `66f778bfc2441c889795b8f146f8c87fb77be0bff5d524c8a64c311e32981d40` |

No compile `Warning-`, `Error-`, `[TFIPC]`, or `Fatal` diagnostics were found
in the R55, R57 or R58 VCS compile logs. These runs do not change any of the 38
requirement dispositions by themselves.
