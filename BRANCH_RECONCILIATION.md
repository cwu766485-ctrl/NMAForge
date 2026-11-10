# Round 28 branch reconciliation

Fetch completed before candidate creation. Remote product was `800c5b0ab1f0b9de5937c65e7c5f57b6d6fbc92c`; remote research was `3ec0be579c6847d4ae707a30e5e30ccd64ab0813`. Original worktree was on research with only untracked `novas.conf` and `novas.rc`. These files and all existing worktrees were left untouched.

Candidate `feat/nmaforge-rtl-finalize` was created with:

```sh
git fetch origin
git worktree add -b feat/nmaforge-rtl-finalize /tmp/nmaforge-round28 origin/feature/npu-architecture-v2
git diff --name-status origin/feature/npu-architecture-v2 origin/feat/shape-adaptive-gemv-v2 -- rtl sw/tools docs/spec
```

## File-by-file disposition of differing product RTL

All paths below retain the complete product version. No whole-branch merge or file overwrite from research was performed.

| Paths (relative to rtl/) | Product-side reason |
|---|---|
| compute/common/ai_unsigned_divider.v | Exact acceleration input and zero-skip machinery absent in research |
| compute/sfu/ai_tensor_sfu_core.v | Input cache, length-16 exact mean/variance division fast path |
| compute/matrix/ai_tensor_matrix_core.v; compute/matrix/ai_tensor_matrix_array.sv | Product 0x52 shared-array K-fold, 0x53 fused output, local reuse/forwarding |
| compute/int8/ai_int8_compute_core.v | Error retirement guards avoid sticky abort/watchdog trapping ST_ERROR |
| compute/kv/ai_kv_cache_engine.v | Incremental KV lifecycle and validation changes; retain product scope |
| control/descriptor/ai_accel_opcode_decode.v; control/descriptor/ai_descriptor_validator.v | Additive opcode decoding, shape/layout/alias restrictions |
| control/axi_lite/ai_accel_regs.v; control/queue/ai_parallel_compute_dispatcher.v | Product integration and register identity |
| memory/ai_scratchpad.v | Parameterized research capacity support |
| top/ai_accel_top.v; top/fabric/compute/ai_accel_compute_cluster.v | Product core wiring and SPAD parameters |
| top/fabric/memory/ai_accel_memory_fabric.v; top/fabric/memory/ai_accel_spad_subsystem.v | Product memory configuration/integration |

`rtl/research/` is identical between the two frozen tips. There is no research-only RTL improvement to migrate. The differing research simulation Makefile only replaces product Python-version discovery with `python3`; retain discovery for this host's old default Python. Research benchmark CSV snapshots differ and are historical observations, not product patches.

Product Mapper contains 0x52/0x53 encoding, padded layouts, alias checks and trained-model composition absent from research. Retain it. Product-only `docs/spec/NPU_ARCHITECTURE_V2_SPEC.md`, incremental H16 generator/reference/session scripts and their tests are retained. Research's incomplete Round 27 archive is not imported into product documentation.

Only new product optimization: LayerNorm reciprocal reuses existing divider acceleration, plus simulation-only exclusive phase sampling. Product RTL implementation commit: `3f108df` (full SHA in Round 28 manifest). Main and both existing branches remain unchanged by candidate work. This reconciliation does not imply full equivalence of all historical tests across branches.
