# Bank-Level Near-Memory Lanes — Gate 5 Design Contract (Round 38)

Status: **contract only, not implemented.** This document fixes the ABI,
ownership, verification and acceptance gates for the third Round-35 innovation
item (bank-level programmable lanes). It records the evidence that decides
whether the lane should be built and what it must beat. No RTL, source list
or SPEC opcode table changes are made by this document.

## 1. Motivation and measured opportunity

The CNM path already has one local controller per SPAD bank
(`rtl/compute/cnm/ai_bank_local_controller.v`, fixed dot4 with a local
accumulator). The lane proposal generalizes it: each bank-local controller
gets a small vector micro-op set that runs on data resident in its own bank.
The four banks then work in parallel, and the shared SFU stream unit and the
arbiter's single core port stop being the only elementwise path.

Engine occupancy measured on Product Top in Round 38 (compiled-program v3
profile, `+AI_COMPILED_SEG_TIMING`), GPT-2 small, 1 layer, prefill 32 rows +
4 decode steps, queued DMA overlap + GEMM accumulate epilogue:

| Window | Cycles | Matrix busy | SFU busy | DMA busy | DMA only (nothing computes) |
|---|---:|---:|---:|---:|---:|
| Whole program | 15,483,428 | 9,462,961 (61%) | 2,516,876 (16%) | 7,182,887 | 3,495,983 (23%) |
| Prefill LN1 segment (32 rows) | 524,683 | 0 | 504,414 | 21,691 | 20,083 |
| Decode attention segment | 831,797 | 412,358 | 113,806 | 486,174 | 305,006 |
| Decode FFN segment | 1,505,651 | 911,571 | 97,951 | 945,403 | 495,586 |

Implications:

- Elementwise SFU work is at most 16% of the window. Even an infinitely fast
  lane removes at most that share, and less where the SFU already overlaps the
  Matrix and the DMA.
- The larger costs are Matrix small-M efficiency (61%) and exposed DMA (23%,
  which the INT4 expansion addresses).
- One SFU-bound window does exist: prefill LayerNorm. It costs 0.50 M cycles
  per LN over 32 rows of 768 elements, because rows longer than 256 elements
  fall back to the legacy SFU FSM. For that window, either the >256-row SFU
  fast path or a lane reduction would help.

## 2. Proposed ABI (reserved, not active)

- Opcode `0x3c` `LANE_VOP` (ABI v7 descriptor, version 7).
- `aux0[3:0]` selects the micro-op:
  - `ADD`: `sat32(a+b)`
  - `SHR`: `a>>>s`
  - `REQ8`: `sat8((a + round) >>> s)`, packed
  - `RSUM`: row sum
  - `RSSQ`: row sum of squares
  - `RMAX`: row max
- Operands:
  - `src0` and `src1` are the operand rows. `dst` receives the result row or,
    for reductions, a 4-word per-lane partial vector that the SFU or the host
    folds.
  - `length` is the element count. `m_size` is the row count, with
    `src0_stride`/`dst_stride` as row strides.
- Placement rule: all operand rows must be 16-byte aligned. Element `i` lives
  in bank `(addr>>2) & 3`, so lane `j` touches only words `≡ j (mod 4)`. Every
  lane access is therefore bank-local, and no cross-bank traffic is needed.
- Errors: unaligned rows, `length` not a multiple of 4, or overlap between
  `dst` and a source row is `ERR_DESC` (validator) or `ERR_CONFIG` (engine).
- Capability: a new `CAP2` bit would be allocated only when the RTL lands.

## 3. Ownership and invariants

- **Arbiter.** Lanes reuse the existing per-bank CNM request lanes into
  `ai_spad_arbiter`. The arbiter stays the only admission point, and no new
  scratchpad port is added.
- **Dispatcher.** `LANE_VOP` runs on the CNM engine slot (engine 2). This keeps
  the dispatcher at 8 engines and leaves the event/retire rules unchanged.
- **Reads.** Reads stay registered, and lane responses use the existing
  per-lane parity and protection reporting.
- **Abort.** Abort drains outstanding lane reads the same way the dot4
  controller does today.

## 4. Verification plan (Gate 5 steps)

1. **Reference.** An integer Python reference per micro-op, bit-exact against
   `nmaf.intops` (`residual`, `requant`, the LN statistics).
2. **Block DV.** A directed + random bench for `ai_bank_local_controller`
   lanes covering:
   - every micro-op;
   - saturation edges;
   - ready/latency randomization;
   - abort and parity at each phase;
   - lane-locality assertion: no lane address outside its bank residue.
3. **Validator DV.** Legal and illegal `0x3c` fields.
4. **Top DV.** A compiled-program self-test (as `ai_qdma_selftest`) and a GPT-2
   1-layer run with residual adds and requant packs moved to lanes. The run
   must be bit-exact and must measure segment-level gains with the occupancy
   profile above.
5. **Regression.** `make ai_smoke`, `make ai_run AI_RANDOM_CASES=20
   AI_SEED=12345`, control/DMA UVM, `ai_cnm_signoff`.
6. **Static and PPA.** SpyGlass lint, plus a DC area/timing delta at 4.0 ns
   with the same TSMC28 setup as the Round 35 report (pre-layout).

## 5. Acceptance criteria

- **Bit exactness.** Bit-exact on every test above.
- **Performance.** At least a 5% end-to-end cycle reduction on the GPT-2
  1-layer prefill + decode program versus the Round 38 baseline
  (15,483,428 cycles). Below that, the area is not justified and the item
  closes as "not built".
- **Timing.** No setup regression at 4.0 ns. The lane area overhead is
  reported per bank.

## 6. Decision

Under the measured profile, the expected gain is capped by the 16% SFU share,
and part of that is already hidden behind Matrix and DMA. The higher-return
next steps are:

1. Matrix small-M (decode) efficiency, for example the `0x52` K-fold GEMV
   mapping for `M <= 4`.
2. Extending the SFU fast path to rows longer than 256 elements (prefill and
   DeiT LayerNorm).

The lane is kept as a research option behind this contract. It should be
built only if, after (1) and (2), the elementwise share rises enough to clear
the 5% gate.
