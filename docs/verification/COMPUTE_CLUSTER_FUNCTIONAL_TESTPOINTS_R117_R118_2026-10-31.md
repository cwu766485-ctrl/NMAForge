# Compute Cluster subsystem functional testpoint closure — R117/R118

**R117 run ID:** `CL-RREADY-PROFILE-3P-480EB44`
**R118 run ID:** `CL-SUBSYSTEM-TESTPOINT-COVERAGE-15VDB-480EB44`
**Exact published clean HEAD for all new runs:** `480eb443b835f8cbe771682e91ff6d97acae0a99`
**RTL/UVM/SPEC source identity:** identical to code/test SHA `4797a7710a18670d820f8f3815959091f9636e75`; the intervening published commits change documentation only.
**Tools:** VCS and URG `V-2023.12-SP1`; UVM 1.2.
**Disposition:** PASS for all declared functional covergroups in the merged DMA/SPAD/CNM subsystem suite; no Compute Cluster requirement status is promoted.

## Runs

All commands were run from a detached clean worktree at the exact published SHA. VCS platform notices for Rocky Linux 8.10 / WSL2 were retained.

| Run slice | Command / seeds | Result |
|---|---|---|
| Default subsystem baseline | `make subsystem_regress COV_TAG=r118_base_480eb`; seeds `12345, 987654, 20261014` | PASS, each UVM severity `0/0/0`; DMA/SPAD/CNM regression and memory scoreboards complete |
| AXI RREADY stress | `make subsystem_rready_stress RREADY_STRESS_TAG=r117_rready_stress_480eb44`; profiles `16/64/300` cycles, seeds `20261097/20261098/20261099` respectively | PASS for each profile; stable `RVALID` and full response payload during stall, all 4 accepted reads drained, and 32 SPAD words match the memory oracle; each UVM severity `0/0/0`; focused URG group 100% |
| Banked response reset | `make subsystem_banked_reset_regress BANKED_RESET_OUT=/tmp/nmaforge_r118_banked_reset_480eb44`; seeds `20261025/26/27` | PASS; accepted banked response is flushed by reset, quiet interval is checked, then a tagged four-bank Golden read recovers; focused group 100%; UVM severity `0/0/0` |
| Core/banked contention | `make subsystem_banked_contention_regress BANKED_CONTENTION_OUT=/tmp/nmaforge_r118_banked_contention_480eb44`; seeds `20261025/26/27` | PASS; simultaneous scalar/Core and Matrix-like banked requests are arbitrated and both owner/data responses match Golden; focused group 100%; UVM severity `0/0/0` |
| Core/banked reset interleave | `make subsystem_banked_core_reset_regress BANKED_CORE_RESET_OUT=/tmp/nmaforge_r118_banked_core_reset_480eb44`; seeds `20261025/26/27` | PASS; Core response is checked while a Banked response is pending, reset flushes that response, and both owners recover; focused group 100%; UVM severity `0/0/0` |

The RREADY checks are directed protocol stress, not random memory delays. The banked/Core clients are testbench-driven at the production fabric boundary; these results do not claim that production Matrix-engine traffic has been exhaustively combined with every other engine and fault.

## Merged functional coverage

URG merged **15 VDBs** produced from the same RTL/UVM test content at this exact published SHA: the three default subsystem seeds, three RREADY duration profiles, and three seeds each for banked reset, Core/banked contention, and Core/banked reset. The merged `groups.html` reports **17/17 functional covergroups at 100.00%**:

`dma_cmd_cg`, `dma_cnm_shared_reset_cg`, `dma_rready_stall_cg`, `banked_core_contention_cg`, `cnm_dma_error_overlap_cg`, `cnm_dma_write_abort_cg`, `cnm_gemv_shape_cg`, `banked_reset_epoch_cg`, `cnm_dma_abort_overlap_cg`, `banked_core_reset_epoch_cg`, `cnm_reset_phase_cg`, `dma_reset_phase_cg`, `arbiter_cg`, `cnm_parity_abort_reset_cg`, `cnm_protection_source_cg`, `cnm_parity_contention_cg`, and `cnm_parity_dma_abort_cg`.

Merged assertions report 29 real successes, zero failures, and zero incomplete attempts. The only two properties without attempts are UVM RAL `do_read` / `do_write` internals. The merged dashboard's raw mixed testbench/UVM/DUT code metrics are line `73.24%`, condition `59.49%`, toggle `40.51%`, FSM `54.82%`, branch `62.47%`, assertion `93.55%`; these are not DUT-only metrics and are not the functional-covergroup result.

This closes the declared functional testpoints in this DMA/SPAD/CNM subsystem campaign. It does **not** close the 38-row Execution RTM: dispositions remain 24 PASS-SCOPED / 14 PARTIAL, and `CL-DV-v1.0` remains **HOLD**. Production-engine fault/backpressure/reset crosses, Matrix and descriptor scope gaps, and requirement-level evidence remain open.

## Reproduction

The aggregate URG report was built from the following 15 databases:

- `coverage/dma_spad_subsystem_test_r118_base_480eb_seed{12345,987654,20261014}.vdb`
- `coverage/r117_rready_stress_480eb44_{16,64,300}.vdb`
- `/tmp/nmaforge_r118_banked_reset_480eb44/seed_{20261025,20261026,20261027}/coverage.vdb`
- `/tmp/nmaforge_r118_banked_contention_480eb44/seed_{20261025,20261026,20261027}/coverage.vdb`
- `/tmp/nmaforge_r118_banked_core_reset_480eb44/seed_{20261025,20261026,20261027}/coverage.vdb`

```sh
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir <three default seed VDBs> \
  -dir <RREADY 16/64/300 VDBs> \
  -dir <three banked reset VDBs> \
  -dir <three Core/banked contention VDBs> \
  -dir <three Core/banked reset VDBs> \
  -report /tmp/nmaforge_r118_all_testpoints_480eb44_final/urg
```

The report and all generated VDBs remain in `/tmp` or the ignored build directory, outside tracked Git content.

## Evidence hashes

| Artifact | SHA-256 |
|---|---|
| Default baseline driver log | `64b356fed716457bf466cb4225dc95dc8112540dc213f7a980a349688a37dba0` |
| Default run `12345` | `c12116b17581b2e2d3bf9fbac1459f730abca81936de8043b853062504fd56db` |
| Default run `987654` | `7e59d6c54b174f374f893a678bb3b4bee1c3bc5f7d295c18fe8b9fd19e7404ae` |
| Default run `20261014` | `10ec1c76ab558df11bd4cc0743a6b4576870582257068b177df13c66909b958e` |
| RREADY run `16` | `d73f943933a3f928759721b735fbf497cbe2d409d498be8409005d1a5b3a0841` |
| RREADY run `64` | `db484396aacf379db8f33e0ee0ef1c26f29708be1ef1f35dd132654114246cb3` |
| RREADY run `300` | `fe72ab36b6287eade445c6a9384cdf82ca567cd3acc7ed4de540a3d7c8356af9` |
| RREADY focused URG `groups.html` | `c1d4c1ab427bd4ba32577e766d506445e2bc35ad8b6086476801de4a977eb728` |
| Banked reset driver log | `9e01f4f6519d87560580adaa942367ac7d01400f8ecbe0e14f14eda63c16d8b3` |
| Banked reset runs `20261025/26/27` | `1a8ace4dc5b5e0b0b690ecc390b335a8b0957794a6deb981e1fa2ce72c40d357` / `fa8b97435095b53622f7db989f236593324fbbfd16598386af230adeb89c47fb` / `64401fb53dc39fb929b5fdc25739701883cc972a45bc27d9d6233237a5b86272` |
| Core/banked contention driver log | `db4811d6f7b187f00e86e2dc5b36aaf7bf065e81709330c9afb226cfe313ee8a` |
| Core/banked contention runs `20261025/26/27` | `e9c6b1b3bf9b7faf591968acd8309106c81cb4e04021948786b5ac31987943c2` / `023b8cbde8ee4fad3795a06209328f876040553c8fcb670f49eb82b4bd6d974b` / `2787ff707fdbfce5b924faf8b62886884d2647f5866a08b11fce8a82539002e3` |
| Core/banked reset driver log | `dc951bb0bda5bbfef57fd75f1c95a6f27754caa06ee90ee152d18d83de3cd9a7` |
| Core/banked reset runs `20261025/26/27` | `f386f95680b7b0facbd763811fd1aaf56a9d8ce0a83359a7ec398d475e664181` / `b1a8a89a74bb19c67cd8b63da9659969ddf3a201b9020fe6aeadd20cee9d09e3` / `33f04e8c3d8695aa5dc78643bc33f1f8b8e6956027db1e3e8d829cda2d38233c` |
| Final merged URG driver log | `27902fa8554592e9153a7fa84a1810fa9e43aecebd3bfec14222bf33b71ccf67` |
| Final merged `dashboard.html` | `2d4ef93ecd951a41e04c73b21693a3e7898060dee9eb5f381ea9a7f52f8544be` |
| Final merged `groups.html` | `9d5ffbaa3864b2917d109054d9c1148d91ff4d14d86ed3061c482424a542b669` |
| Final merged `asserts.html` | `2aef67c10ee82647b395b62ca686380c32b877a75b949cc46859882cf3feef00` |
