# R141 Matrix parity response reset epoch — 2026-10-31

## Disposition

R141 adds one real-top legal Matrix parity/reset/recovery testpoint. It does not close a requirement row: `REQ-CL-017/019/027` and `REQ-PC-006/007` remain `PARTIAL`; the 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Fixed source and run identity

- Test/source commit: `f686f1260156472d6ea9e564fadd172b1dcbf565`
- Source tree: `e86f41efbc29cd8e6a27531c5714d44ad83d62a2`
- Parent: R140 documentation commit `09e61246d0ff82bcf73b85941488d60dccea04ac`; product RTL and SPEC are unchanged.
- Run ID: `R141-MATRIX-PARITY-RESET-EPOCH-3S-20261031`
- Seeds: `20261025`, `20261026`, `20261027`
- Tools: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Testpoint

The real CMDQ path launches a legal 4×4×4 Matrix GEMM with packed A/B words `0x01010101`, whose 16 expected outputs are all 4. The test injects a parity fault at Matrix A, waits for the exact banked A read to be accepted, then asserts top reset after that accepting edge and before the registered parity response is consumed. Parity is restored during reset.

The test checks no response-valid during four reset cycles and eight post-reset quiet cycles, all compute engines idle, no completion-tail advance, and unchanged destination/completion memory. It then reissues the descriptor and compares all 16 output words with the independent Golden result. Reset discards the accepted old-epoch read before a parity completion can be published; this test does not claim a parity completion was already pending when reset asserted.

## Results

| Seed | UVM severity W/E/F | Memory words checked | Mismatch / unknown / stale / orphan | Reset-dropped accepted reads | Focused compute coverage |
|---:|---:|---:|---:|---:|---:|
| 20261025 | 0/0/0 | 44,851 | 0/0/0/0 | 12 | 100% applicable |
| 20261026 | 0/0/0 | 44,851 | 0/0/0/0 | 12 | 100% applicable |
| 20261027 | 0/0/0 | 44,851 | 0/0/0/0 | 12 | 100% applicable |

The required marker `[CLUSTER_MATRIX_PARITY_RESET_EPOCH_PASS]` appears once per seed. The cluster scoreboard pending ledger is empty on every seed. URG reports `cluster_cg` at 100.00% (64/64 declared bins), a scoped functional group. Merged URG totals are line 56.04%, condition 69.31%, toggle 63.52%, FSM 42.10%, branch 59.59%, assertion 72.00%, and groups 29.72%. These mixed metrics do not mean 100% design coverage or sign-off.

## Commands and evidence

Three-seed UVM regression:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r141_clean_replay_f686f12 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

Same-tree Top Smoke:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=20261025
```

Checker-sensitivity mutation campaign:

```sh
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r141_clean_replay_f686f12 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r141_clean_mutations_f686f12
```

All commands pass. Top Smoke mapper precheck accepts 86 descriptors / 60 tensors and ends `TEST PASS`; the existing fixture `LOOP-REROLL-ENABLED` notice remains. The passive checker-sensitivity campaign catches 28/28 named mutations: address, data, owner, WSTRB, write-after-error, response epoch, completion error code, and per-engine Done/missing-Done/duplicate-Done. This measures checker sensitivity; it is not DUT fault injection or an RTL mutation score.

SHA-256 evidence:

| Artifact | SHA-256 |
|---|---|
| VCS compile log | `27e09f59cea1780ea2312da19d7de82a8d89933740f75e32c64e9438c1295cad` |
| URG merged log | `f12ad2f86d5c1c7c2c06ab06862024750be6bab31b11292f791bfb00d2ad3d52` |
| Seed 20261025 UVM log | `87cdf3f233be431a280c26bf1a8ca75200116dff787bd303de469da411262ecd` |
| Seed 20261026 UVM log | `1a7731613f687feff902f63318d8d83ba98ff9fdc439c8907f27c014af57c451` |
| Seed 20261027 UVM log | `0b9d4ad8293bb9ebcb2e42e8c3f625ad13529ab5b1ef9a63b9b0a34956be91e4` |
| Mutation `SHA256SUMS` manifest | `2815339dbdd058a3a5b87e1c6a6dbe62928e8b245b47d3c5c3dc1d17a6be5bd5` |
| Top Smoke log | `208491ca671d43065e5193b6ab43f059e5f9aee765f7e1ddc5062ccf8a29c69b` |
| Top compile log | `7b8ded9681d9c7d2031894c0c21b09d851385a5a2a2ead18a4fbabda40156b9e` |

Raw artifacts are under `/tmp/nmaforge_r141_clean_replay_f686f12`, `/tmp/nmaforge_r141_clean_mutations_f686f12`, and the Top Smoke simulator output directory. Per-seed UVM evidence is in `seed_*/run.log`; the mutation directory has 28 named logs and a hash manifest.

## Remaining work

This adds a legal Matrix accepted-read reset point with old-epoch response suppression and post-reset numerical recovery. It does not establish parity completion behavior after the response has been consumed, response ownership across all seven production engines, or the full engine × fault × phase × reset space. `REQ-CL-017/019/027` and shared-SPAD ownership portions of `REQ-PC-006/007` therefore remain partial. No coverage bins were forced with illegal requests.
