# NMAForge-V1.2 Round 29 — DeiT Tensor Repack Prototype

## Scope and disposition

- Research branch: `research/nmaforge-v1.2-round29b-deit`
- Repack block-prototype base: `bd36be685490337278c02e9ccf9184c074237c13`
- Product Top integration follow-up base: `e4970d78fb55cf126fea563652bdfa57c38dbce5`
- RTL worktree diff SHA-256 at the directed run: `7f848ca618171acff781cf73bd2c79753cf67b1c6986186ce2bf9b4ede948f7a`
- Disposition: **PARTIAL**. The bounded SFU Repack opcode passes standalone VCS testing and now also passes a 256 KiB Product Top command/Completion/data-path test. The Product Top fixture preloads the Matrix-A source; it does not test a live QKV producer, Attention consumer, or a complete DeiT execution session.

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
- `rtl/control/descriptor/ai_desc_fetch.v`, `rtl/control/descriptor/axi_desc_fetch.v`: opcode-specific decode of `0x3b` word 6 into `length` with no `k_words` value. The SPAD-fetch path is exercised through Product Top; the external AXI-fetch directed test is checked in but blocked by license availability.
- `dv/subsystem/top_smoke/sim/Makefile`: reproducible 256 KiB Product Top repack target.
- `docs/spec/SPEC_ZH.md`, `docs/spec/NPU_ARCHITECTURE_V2_SPEC.md`: research opcode fields and limits.
- `benchmark/deit/round29/`: independent block DV, Product Top workload generator and runner, external descriptor-fetch directed test, and run manifests. Raw VCS logs remain in ignored evidence paths or `/tmp` and are identified by SHA-256.

## Product Top opcode integration follow-up

The first Product Top attempt, Run ID `nmaforge_deit_round29_top_20261119T1`, reached descriptor 0 and returned completion status `0x72` (`ERR_DESC`, error code 7). The validator contract requires `0x3b` to have a nonzero `length` and `k_words=0`, while both descriptor fetch paths had copied word 6 into both fields. The fetchers now retain word 6 as `length` and set the derived `k_words` to zero only for opcode `0x3b`; other opcodes retain their existing K decode. Descriptor size and field positions do not change.

The corrected Product Top run, Run ID `nmaforge_deit_round29_top_20261119T2`, used VCS V-2023.12-SP1_Full64 with `AI_SPAD_WORDS_PER_BANK=16384`, 16-entry queue storage, 9 descriptors, `m_size=16`, `n_size=48`, and 13 valid rows. It ran Q-dense, K-major, and V-Matrix-B repack for all three heads. All 576 output words matched the independent physical-layout Golden. Each command accepted 52 source-word reads and 64 output-word writes; aggregate traffic was 1,872 SPAD read bytes and 2,304 SPAD write bytes. The 2,304-byte Poison initialization is test setup, not model payload. The source fixture plus descriptors occupied 1,200 bytes; the testbench preloaded 3,504 bytes total including Poison.

The nine command intervals total 2,184 SFU busy cycles. Including 91 dispatch/completion remainder cycles, the measured command window is 2,275 cycles. The testbench End-to-End window is 7,530 cycles, including 5,255 AXI preload cycles; it excludes model-weight loading because this is a repack fixture, not model inference. The run's `useful_macs=0` is expected: this opcode only moves/repacks data.

Product Top command:

```bash
cd dv/subsystem/top_smoke/sim
make ai_deit_round29_top_repack_256k \\
  AI_DEIT_R29_RUN=/tmp/nmaforge_deit_round29_top_20261119T2
```

For a fresh replay, choose a new, nonexistent `AI_DEIT_R29_RUN` directory (the target intentionally refuses to overwrite an existing run directory). The workload generator uses Python 3.12.13 from `/tmp/nmaforge_deit_round17_venv/bin/python`; regeneration reproduced the manifest, memory image, and Golden hashes exactly.

The compile log SHA-256 is `4ab798353fad4348c60cdecadcfcb63eb8fbdbcacaa71a24e631576fb22a9f5c`; the simulation log SHA-256 is `26ef3a39a1f8a69d71af17566c2ac03b43f3311be47f5882d1ae99c44c46284b`. The run reports zero compile errors and the existing `LOOP-REROLL-ENABLED` warning. The fixture and Golden hashes are in `benchmark/deit/round29/evidence/top_repack/run_manifest.txt`; generated logs and databases remain outside the repository.

After the Product Top parser change, the existing compatibility runs were repeated:

```bash
cd dv/subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=290029
```

Both exited 0 and reported `TEST PASS`. Their archived log hashes remain in `benchmark/deit/round29/evidence/top_smoke/SHA256SUMS`.

An additional standalone test was added for the external AXI Descriptor Fetch path. It checks the `0x3b` word-6 decode and confirms legacy GEMM `k_words` behavior. It is **BLOCKED_ENV / NOT_RUN** in this session: VCS V-2023.12-SP1_Full64 could not connect to the configured license server; one bounded license-queue attempt was stopped after it continued waiting past the reported minute. This does not invalidate the Product Top SPAD-fetch run, but the external AXI fetcher's new opcode-specific decode remains unverified until that test runs.

## Gate status and limits

| Gate | Status | Evidence / remaining work |
|---|---|---|
| Standalone Repack RTL Q/K/V layouts | **PASS** | 3 modes × 3 heads, 29/32 rows, all expected bytes match. |
| Repack backpressure/Abort/reset/descriptor boundaries | **PASS, directed** | Standalone VCS test; limited to the tested interface scenarios. |
| Existing Product Top compatibility | **PASS** | `make ai_smoke`; `make ai_run AI_RANDOM_CASES=20 AI_SEED=290029`. |
| Opcode `0x3b` through Product Top command/Completion/SPAD | **PASS, repack fixture only** | Run `nmaforge_deit_round29_top_20261119T2`; 9 descriptors, 576 words exact. Input is a preloaded source fixture, not a live producer output. |
| Opcode `0x3b` via external AXI Descriptor Fetch | **BLOCKED_ENV / NOT_RUN** | Standalone directed test is checked in; VCS license-server connection failure prevented compilation. |
| Same-session Product Top QKV→Repack→3-head Attention | **NOT_RUN** | No host repacking is used in the standalone module test, but the continuous Product Top path is not integrated. |
| Full 197-token DeiT Encoder | **NOT_RUN** | Attention, residual, LN2, FFN, GELU, and classifier remain open. |
| Synthesis/area/timing | **NOT_RUN** | No resource or timing claim is made for the added state/mux logic. |

The test's input values and output-layout checker are independently indexed from the physical Matrix-A tile formula and the documented consumer formats. The direct block test does not prove integration with the existing Matrix producer's runtime output; that remains the first integration gate.
