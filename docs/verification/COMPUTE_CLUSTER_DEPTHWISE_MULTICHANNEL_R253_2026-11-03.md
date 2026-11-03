# Compute Cluster Depthwise Multi-Channel CMDQ Evidence — R253

## Result

At fixed candidate `78476b2762149db5703645a55bd26dd94259c344` (tree `a4bc4f8200fc735200866c3dc7243ecea17918fd`, parent `9871bb29f64e83e83c500c87a39ca7b55ba5b0fa`), the clean-worktree three-seed Compute Cluster UVM regression passes a real CMDQ sequence with two ordered Depthwise opcode `0x17` descriptors. Each descriptor represents one channel and uses its own source, weight, and destination region. The independent signed INT32 Golden checks all 8 output words; both completions and adjacent sentinels match.

This adds evidence for one sequential two-channel workload. It does not claim concurrent channel execution, more than two channels, broader shape/stride/alias coverage, or sign-off closure. Requirement dispositions do not change: the RTM remains 24 `PASS-SCOPED` and 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Fixed run

- Run ID: `R253-COMPUTE-CLUSTER-3SEED-20261103`
- Git candidate/tree: `78476b2762149db5703645a55bd26dd94259c344` / `a4bc4f8200fc735200866c3dc7243ecea17918fd`
- Replay: detached clean worktree at the candidate SHA
- Tools: VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`
- Seeds: `20261025`, `20261026`, `20261027`
- Command, from `dv/uvm/sim`:

  ```sh
  make uvm_compute_cluster_regress \
    COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
    COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r253_depthwise_multichannel_clean_78476b2_3seed \
    VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
  ```

The aggregate target and URG merge exited 0. Every seed emitted `COMPUTE_CLUSTER_REAL_UVM_PASS` and `CLUSTER_DEPTHWISE_MULTICHANNEL_PASS`. The compile KDB reports 0 errors and 0 warnings; the captured compile log contains no `Warning-`, `Error-`, or `TFIPC` diagnostics.

## Requirement evidence overlay

| Requirement | Disposition | Test / checker | Coverage and result | Run ID / seeds | Evidence |
|---|---|---|---|---|---|
| `REQ-CL-002` | `PARTIAL` | `TC-CL-R253-DEPTHWISE-MULTICHANNEL-CMDQ`; real CMDQ fetch/launch snapshot monitor and ordered-completion checker | Two legal `0x17` descriptors launch in order with independent A/weight/destination addresses; no same-engine overlap is claimed. Broader opcode and descriptor legality remain open. | `R253-COMPUTE-CLUSTER-3SEED-20261103`; `20261025/26/27` | Per-seed `run.log` in the evidence archive below |
| `REQ-CL-015` | `PARTIAL` | Same test; launch count, completion ID/order/result checker | Exactly 2 launches and 2 matching ordered completions per seed; this is one dispatch point, not the full dispatch matrix. | Same run / seeds | Per-seed `run.log` |
| `REQ-CL-024` | `PARTIAL` | Independent signed INT32 Golden, full output image, completion and boundary-sentinel checker; `depthwise_channel_sequence_cg` | 8/8 output words, 2/2 completions, and sentinels pass per seed. Focused bin `two_channel_descriptors` is 1/1 per seed and 3/3 merged (100%). | Same run / seeds | Per-seed `run.log`; merged URG `grpinfo.txt` |
| `REQ-PC-006` | `PARTIAL` | Full Compute Cluster Memory Scoreboard and response-owner ledger | Each seed checks 93,839 words with 0 mismatch, unknown read, stale epoch, or orphan. Owner ledger: 5,887 accepted / 5,867 checked / 20 reset-dropped; route/data/error mismatch 0 and pending 0. This does not close the broad memory-client/fault cross. | Same run / seeds | Per-seed `run.log` |

UVM severity for each seed is `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`. The specific new functional bin is 100%; this is not global functional coverage, RTL code coverage, or requirement closure.

## Evidence archive

Generated logs and URG database remain outside the repository, at:

`/tmp/nmaforge_r253_depthwise_multichannel_clean_78476b2_3seed`

Logs-only archive:

`/tmp/nmaforge_r253_depthwise_multichannel_clean_78476b2_3seed.tar.gz`

SHA-256: `e1e25ab8abb7de4f03529cb612f03006bc4fc08b749a3ea8348ae1f10415ab1f`

Key file hashes:

| Evidence file | SHA-256 |
|---|---|
| `compile.log` | `662a53d24d0d050f9e028c5b2889c758069f97b16acfa9c564d507a1a4fdb06c` |
| `seed_20261025/run.log` | `fa9b85254c20ee869ca162e19f2a9344f82626a6bf63d0e8e54b49410745fc84` |
| `seed_20261026/run.log` | `09d4ba02caef628a86ecd8bcaae044a8bb01590ed771a461c3030cb86a87b199` |
| `seed_20261027/run.log` | `66f0d2add8d6b0570d2acc9a31d4a34a5a53569634dd99210214bfc6c3d69d28` |
| `urg_merged/urg_merge.log` | `579337bebd2a9904d1e38bd70d34f34b8666cc98ad3d54bb0e75097320644f22` |
| `urg_merged/grpinfo.txt` | `94ea2a2935950e8d36f6f5302e05d09aa9d106e026e090317aac9d6030c0ee38` |

## Remaining limits

- The test covers two sequential per-channel descriptors only; it does not test concurrent channels or more than two channels.
- It does not close remaining per-engine dimensions, strides, aliasing, address-overflow, zero-value, and fault/phase/reset/backpressure combinations.
- The clean replay proves this candidate's reproducibility for the named workload; it does not promote any of the 38 RTM rows or establish full Compute Cluster sign-off.
