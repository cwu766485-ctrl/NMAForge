# NMAForge-V1.2 Round 29 — DeiT Tensor Repack Prototype

## Scope and disposition

- Research branch: `research/nmaforge-v1.2-round29b-deit`
- Audited base commit: `bd36be685490337278c02e9ccf9184c074237c13`
- RTL worktree diff SHA-256 at the directed run: `7f848ca618171acff781cf73bd2c79753cf67b1c6986186ce2bf9b4ede948f7a`
- Disposition: **PARTIAL**. The bounded SFU Repack opcode passes a standalone VCS test across a 16-row physical tile boundary and the existing Product Top smoke/seeded regressions pass. The new opcode has not yet been exercised through a submitted command in Product Top, and the requested same-Top QKV→Attention/Encoder flow is not closed.

No main branch or other worktree was modified.

## Hardware prototype

Research-only opcode `0x3b` routes through the existing SFU request/response port and completion path; it adds no MAC array. Descriptor `aux0[1:0]` selects dense Q (`0`), K-major (`1`), or Matrix-B V (`2`); `aux0[3:2]` selects head 0–2. `length` is the number of valid token rows; `m_size` is the padded row count (16–256, multiple of 16); `n_size` is the total channel count (48–384, multiple of 48). Physical padding rows are zero-filled without issuing source reads. The validator rejects unsupported fields, aliasing, and address wrap.

The SPAD source is the existing Matrix-A 16×16-tile representation: each physical tile occupies 256 32-bit words (1 KiB). The first cross-tile debug trace exposed an RTL address bug: feature column 16 selected `src + 0x100` (`0x1100`) instead of the next tile at `src + 0x400` (`0x1400`). The Repack tile address had used `tile_index << 8`; it now uses `tile_index << 10`. The independent layout model and physical SPAD trace agree on the corrected tile boundary.

A second directed boundary check found that descriptor range arithmetic failed to reject an exact 4 GiB end address. Validation now rejects either source or destination end-address carry; alias and exact-wrap negative controls confirm the disposition.

## Directed VCS evidence

VCS: Synopsys V-2023.12-SP1_Full64, WSL2 Linux; license was available.

Command:

```bash
benchmark/deit/round29/run_tensor_repack_directed.sh
```

Run ID: `round29-repack-20261118T164129Z`. The full compile/run logs and SHA manifest are under `benchmark/deit/round29/evidence/repack/`.

Results: Q, K-major, and V Matrix-B modes × 3 heads all passed bit-exact comparison for 29 valid rows in a 32-row allocation with 64 channels per head. Each case accepted 464 source word reads and 512 destination word writes; the three padded rows were zero and caused no source reads. This crosses one 16-row Matrix-A tile boundary. The test also checks deterministic SPAD backpressure and request stability, unsupported mode rejection, alias and exact-4-GiB range rejection, Abort with no writes after termination, and reset during an in-flight read followed by a successful replay. The SV assertion checks that a stalled SPAD request remains stable.

Key log hashes:

| Evidence | SHA-256 |
|---|---|
| Directed compile log | `3be6b6601fc3ee06c1f946e9ae0ed63f31cb57519530885562ba99353c676fac` |
| Directed run log | `d9873106648853e8b09cdba90de3453c6031245b5fdf59717f41ec5b6d33ac57` |
| Product Top compile log | `8aa0e171a7e45a60ab57cb964e6c7f021a16bfda69483ae91703aaa31ee23bd9` |
| `make ai_smoke` output | `c09fc03306e9eb1c6904b2a9ccbb6a153ce2d51d8296d2477dc1059c83af42ae` |
| Seeded Top run log | `caa7bc32551d0bf98ae09ce04cbf973aa37654feef1b137a3585303cd4685284` |

Top regression commands, run sequentially in `dv/subsystem/top_smoke/sim/`:

```bash
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=290029
```

Both exited 0 and reported `TEST PASS`. The Top compile log contains VCS `Warning-[LOOP-REROLL-ENABLED]` at the pre-existing `ai_transformer_workload.svh:10` loop, which notes reduced line-debug capacity; compilation reports zero errors. This is not evidence of a new RTL warning disposition. These are compatibility regressions for the existing Product Top; they do not exercise opcode `0x3b` through the Product Top command path.

## Files changed

- `rtl/compute/sfu/ai_tensor_sfu_core.v`: bounded Q/K/V repack states, Matrix-A source addressing, zero padding, and packed destination layouts.
- `rtl/control/descriptor/ai_accel_opcode_decode.v`, `rtl/control/descriptor/ai_descriptor_validator.v`, `rtl/control/queue/ai_parallel_compute_dispatcher.v`: research opcode decode, validation, and routing; range-overflow and alias checks.
- `docs/spec/SPEC_ZH.md`, `docs/spec/NPU_ARCHITECTURE_V2_SPEC.md`: research opcode fields and limits.
- `benchmark/deit/round29/tb_tensor_repack.sv`, `run_tensor_repack_directed.sh`, `evidence/`: standalone directed verification and raw results.

## Gate status and limits

| Gate | Status | Evidence / remaining work |
|---|---|---|
| Standalone Repack RTL Q/K/V layouts | **PASS** | 3 modes × 3 heads, 29/32 rows, all expected bytes match. |
| Repack backpressure/Abort/reset/descriptor boundaries | **PASS, directed** | Standalone VCS test; limited to the tested interface scenarios. |
| Existing Product Top compatibility | **PASS** | `make ai_smoke`; `make ai_run AI_RANDOM_CASES=20 AI_SEED=290029`. |
| Opcode `0x3b` through Product Top command/Completion | **NOT_RUN** | The new op has not yet been tested end-to-end through Top descriptor fetch, dispatch, SFU completion, and SPAD protection. |
| Same-session Product Top QKV→Repack→3-head Attention | **NOT_RUN** | No host repacking is used in the standalone module test, but the continuous Product Top path is not integrated. |
| Full 197-token DeiT Encoder | **NOT_RUN** | Attention, residual, LN2, FFN, GELU, and classifier remain open. |
| Synthesis/area/timing | **NOT_RUN** | No resource or timing claim is made for the added state/mux logic. |

The test's input values and output-layout checker are independently indexed from the physical Matrix-A tile formula and the documented consumer formats. The direct block test does not prove integration with the existing Matrix producer's runtime output; that remains the first integration gate.
