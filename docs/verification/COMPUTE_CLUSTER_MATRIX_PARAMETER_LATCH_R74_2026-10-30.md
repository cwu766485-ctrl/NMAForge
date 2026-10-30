# Compute Cluster Matrix in-flight parameter-latch — R74 (2026-10-30)

## Result

**PASS, scoped testpoint.** Exact code/test SHA: `519ca161f3c2ce8beab78161a88bbdcb6cbcdc61`, detached clean worktree `/tmp/nmaforge_r74_clean_519ca16`. R74 changes only the UVM sequence and required regression marker; product RTL and SPEC v1.8 are unchanged from R73. `REQ-CL-005` remains PARTIAL because this is one Matrix workload, not the complete engine × field × workload matrix. Compute Cluster v1.0 remains HOLD.

## Test behavior

The real top launches a legal Matrix GEMM using a 16×32 output shape and 64 INT8 K elements (descriptor packed-word K field is 16). Once the production Matrix engine reports busy, the test rewrites the backing descriptor source, destination, M/N/K, and transpose fields. It then checks:

- launch count increments exactly once, and the accepted Matrix launch snapshot retains the original A/B, destination, 16×32 shape, K=16 packed words, and flags=0;
- all 512 original destination words match the independent Matrix Golden;
- all 512 words at the mutated destination remain their initialization sentinel;
- the ordered completion reports the expected task, final Golden value, and 512 output elements.

The test is deterministic and does not force an internal state or use illegal descriptor values.

## Exact clean-SHA runs

Tools: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

```sh
cd /tmp/nmaforge_r74_clean_519ca16/dv/uvm/sim
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r74_clean_run_519ca16 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026'
make uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r74_clean_run_519ca16 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r74_clean_mutations_519ca16
cd /tmp/nmaforge_r74_clean_519ca16/dv/subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

| Evidence | Result | Artifact / SHA-256 |
|---|---|---|
| Three-seed real-top UVM | PASS 3/3; each seed: 17,070 checked memory words, zero mismatch/unknown/stale response; focused applicable compute coverage 100.0%; UVM warning/error/fatal 0/0/0 | `/tmp/nmaforge_r74_clean_run_519ca16/seed_{20261030,20261025,20261026}/run.log`; hashes `3db2192d79ac8035aca719e1ca18a1168b2ae9e34b24fe5ad2ecd0019ba99463`, `8fb641f49d93ff712ae72d1423e8bde773cdfb164c15e625ac1a96fb2a0cb0ff`, `75ba0257022a39e5d91a7653c40d08732e563145aca383694434a28fd82b40cd` (seed path/hash order is 20261030/25/26) |
| UVM compile and merged URG | PASS; no `Warning-`, `Error-`, or `[TFIPC]`; focused testpoint gate passes | compile `/tmp/nmaforge_r74_clean_run_519ca16/compile.log`, SHA-256 `ba95ab552130bf9b724f1cf2c4f748f54c40fa5b038d6c6582d49e001b7f0cad`; `grpinfo.txt` SHA-256 `284eb779744f3a9b7a65e34b708b66983f005466af577c90749669a06f3ee043` |
| Checker sensitivity | PASS 28/28; address, data, owner, WSTRB, completion error code, write-after-error, response epoch, and done/missing-done/duplicate-done on each of seven engines were caught by the expected checker | `/tmp/nmaforge_r74_clean_mutations_519ca16/`; driver SHA-256 `6254952ec2936cc2ef487c1cc81f51bc48adac1a546e0ac362d8a066035005cb`; per-log hash manifest SHA-256 `82a1128fccd1ea61d971f6a7829dddcc1b741dc9c2175c74d41c302102936243` |
| Top Smoke | PASS (`TEST PASS`) | `/tmp/nmaforge_r74_clean_top_smoke_519ca16.log`, SHA-256 `bb28d5bd07324cfc156125c8a6f80fd2f685d80ee4540f3848e879af79f00c12`; existing fixture warning `LOOP-REROLL-ENABLED` retained |
| Seeded top regression | PASS (`TEST PASS`, 20 cases, seed 12345) | `/tmp/nmaforge_r74_clean_seeded_top_519ca16.log`, SHA-256 `8a83c13798093b09a6408510ec4816be61ffeabdecda436295ec6cdf9da55878` |

The mutation campaign intentionally injects corruptions into passive monitor observations. It proves the named checkers detect those cases; it is not an RTL mutation score.

## Disposition

R74 adds Matrix launch-parameter retention evidence alongside the existing Scalar VDOT latch test. The RTM remains **24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN**. Remaining `REQ-CL-005` scope includes other production engines and legal field/workload combinations. The focused 100% figure is the applicable UVM compute testpoint group only; it is not the 38-requirement closure percentage or DUT code coverage. External fabric reset qualification, broader legal fault/phase/engine crosses, and other partial requirements remain open. No sign-off status is promoted by this run.
