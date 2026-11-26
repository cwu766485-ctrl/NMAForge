# Compute Cluster DV Replay After License Recovery

## Source identity

- Product worktree: `/tmp/nmaforge-frontend-closeout`
- Branch: `candidate/frontend-closeout`
- Candidate SHA: `f919bb787dab1a4e3bef44b5308ead56d6e77b72`
- VCS: `V-2023.12-SP1_Full64`
- License: `SNPSLMD_LICENSE_FILE=27000@localhost`

## Results

Top Smoke passed on the exact candidate tree. The log ended with `TEST PASS`
and all product Matrix GEMV, tail, fused-forwarding, CNM profile, protection,
KV, random, and reset-recovery gates passed.

The three-seed Compute Cluster UVM target compiled successfully and then failed
at the first seed before any engine transaction. The first transaction tried
an AXI-Lite write to SPAD address `0x0007d000` and received `SLVERR=2`:

```text
UVM_ERROR ... ai_accel_scoreboard.svh(74) ... addr=0x0007d000 resp=2
UVM_FATAL ... ai_compute_cluster_e2e_seq.svh(583) ... write addr=0x0007d000 resp=2
```

The address is `PARALLEL_FAULT_MATRIX_Y` in the UVM sequence. The default
product SPAD is 128 KiB at `0x00010000`, so its legal byte window ends at
`0x00030000`; `0x0007d000` belongs to the retired 512 KiB fixture. This is an
environment allocation failure, not a functional DUT result. No UVM PASS or
coverage claim is made for this replay.

## Reproduction

```sh
cd /tmp/nmaforge-frontend-closeout/dv/subsystem/top_smoke/sim
make ai_smoke

cd ../../uvm/sim
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_license_restored_cluster_20261113
```

Top Smoke passed. The UVM command exited nonzero at the first seed after
successful VCS compilation. The next closure change must allocate all live
CMDQ/CPLQ, operand, output, descriptor, protection, and sentinel regions
inside 128 KiB with a non-overlap proof; truncating addresses is not valid.
