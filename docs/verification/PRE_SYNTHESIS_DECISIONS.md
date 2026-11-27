# Pre-synthesis decision record (Rounds 37–41)

Status 2026-11-28. This page records:

- the RTL changes since the last commercial-28-nm DC run;
- the build options that DC must decide;
- what each synthesis run must report so the decision can be made.

The DC flow, libraries and SRAM macros are in the private overlay
(`syn/README.md`). This page names the knobs and criteria, not foundry data.

## 1. Baseline

The last DC run is recorded in
[TSMC28_SYNTHESIS_REPORT.md](TSMC28_SYNTHESIS_REPORT.md):

- `ai_accel_top`, 512 KiB SPAD as 32 single-port SRAM macros;
- TT / 0.9 V / 25 °C, 4.0 ns clock (250 MHz), 100 ps setup uncertainty;
- WNS = TNS = 0 for setup and hold, pre-layout;
- the critical path crossed the SPAD read path and the SFU accumulation and
  control region;
- SRAM dominated the area. The largest logic blocks were the AXI DMA, the
  Matrix and the Conv3x3 line buffer.

That run predates every change below. Its timing and area no longer describe
the current RTL.

## 2. RTL changes since the baseline

| Round | Change | Module | Expected PPA effect | DC check |
|---|---|---|---|---|
| 37 | Queued DMA engine 7, 32-entry in-flight FIFO, event-on-complete | `ai_dma_queue_engine`, dispatcher | small control logic | area delta only |
| 38 | GEMM accumulate epilogue (old-C read, 128-bit sum) | `ai_tensor_matrix_core` | +128-bit register, 4 adders/saturators | write-path timing |
| 38 | INT4 block-exponent expansion in DMA drain | `ai_axi128_dma` | 16 × (sign-extend, shift ≤4, saturate) per line | DMA drain timing |
| 38 | SFU stream row cache 256 → 1024 entries (3 × 1024 × 32 bit) | `ai_tensor_sfu_core` | **+72 Kbit of flops if not mapped to SRAM** | area; cache read timing |
| 39 | Bias line reads (banked port, meta bit 70) | `ai_tensor_matrix_core` | small | none expected |
| 39 | GEMM operand staging: 32 × 32-bit stage plus per-buffer counters | `ai_tensor_matrix_core` | about +1.1 Kbit, one more mux level in front of the array load | **array operand load path** |
| 39 | Scratchpad line read two-stage (`+define+VCS` model only) | `ai_scratchpad` | none (the synthesized XPM/macro path is unchanged) | — |
| 41 | `ENABLE_CNM` parameter (default 1) | top, compute cluster, regs | `ENABLE_CNM=0` removes the bank-local CNM engine | area saved |

## 3. Decisions DC must settle

### 3.1 Clock: keep 250 MHz (4.0 ns)

- All performance numbers (Rounds 36–40) assume 250 MHz.
- The baseline closed with no reported margin.
- New risk points:
  - the operand-stage mux in front of the array load;
  - the 1024-entry SFU cache read;
  - the INT4 expansion in the DMA drain.

**Rule:** keep 4.0 ns if WNS ≥ 0 with the product configuration (§4, run A).
If a new path fails, add a register stage at that point; the three candidates
above each have an obvious cut. Do not lower the clock. Every throughput
number scales with it.

### 3.2 DMA burst length (`DMA_MAX_BURST_BEATS`, default 16)

Measured with the streaming memory model (Round 40):

| Workload (latency 100 cycles) | 16-beat | 32-beat |
|---|---:|---:|
| GPT-2 1-layer final program | 10.10 M | 9.88 M (−2.2%) |
| 4-sequence decode, 1 layer | 5.38 M | 4.73 M (−12%) |
| 12-layer 4-sequence decode | 52.6 tok/s | 54.6 tok/s (+3.8%) |

- **Cost:** the read slot buffer `rd_data_r` grows from 4 × 16 to 4 × 32
  beats of 128 bit, +8,192 flops. Beat counters gain 1 bit. The INT4 expansion
  passes at 32 (qdma self-test, bit-exact).
- **Rule:** switch the default to 32 if the extra area is below about 1% of
  the non-SRAM logic, or if the buffer maps to a register file. Otherwise keep
  16 and document 32 as an option.
- If 32 is adopted, update:
  - SPEC "burst at most 16 beats" (to v7.5);
  - the UVM AXI coverage bins (`burst = [1:15]`);
  - the README tables.

### 3.3 SFU row cache depth (1024 entries)

- **Benefit:** LayerNorm rows up to D = 1024 use the fast path. On GPT-2 this
  gave −4.8% end to end (232.7 M → 221.5 M cycles, Round 38). DeiT
  (D = 192) needs only 256 entries.
- **Cost:** 3 × 1024 × 32 bit = 96 Kbit. Before the change it was 24 Kbit.
- **Options:**
  - (a) keep 1024 in flops;
  - (b) map the three arrays to single-port SRAM macros (needs the private
    macro list);
  - (c) 768 entries (exactly GPT-2 small D).
- **Rule:** prefer (b) if a small macro exists. Take (c) if flops are too
  costly. Fall back to 256 only if the area budget forces it; GPT-2 LN then
  returns to the slow path.

### 3.4 Bank-local CNM (`ENABLE_CNM`)

Round 40 measured no benefit for the target workloads:

- On decode GEMV the CNM streams about 5 B/cycle; the staged Matrix streams
  about 13 B/cycle (64×768: 9,697 vs 3,977 cycles).
- Moving per-sequence attention onto the CNM was 3.7–10.8% slower at
  contexts of 64 and 256.

**Decision:** synthesize the product configuration with `ENABLE_CNM=0`. With
it, CAP2[11] = 0 and opcodes `0x20/0x21` complete with `ERR_OP`; the check is
`make ai_no_cnm_check`. The RTL, block tests and default simulation build keep
the CNM for research. The `ENABLE_CNM=1` run is only needed to quote the area
the option saves.

### 3.5 GEMM operand staging (`ENABLE_GEMM_OPERAND_STAGE`, default 1)

- **Benefit:** −38% to −43% on decode GEMM shapes. GPT-2 12 layers went from
  221.5 M to 181.4 M cycles together with bias line reads.
- **Cost:** about +1.1 Kbit of flops.
- **Rule:** keep it. If the array-load path fails timing, register the
  staged lane vector instead of removing the feature.

## 4. Synthesis runs to request

| Run | Purpose | Parameters |
|---|---|---|
| A (product) | Timing and area of the configuration to tape out | `ENABLE_CNM=0`, `DMA_MAX_BURST_BEATS=16` |
| B | Cost of 32-beat bursts | as A, `DMA_MAX_BURST_BEATS=32` |
| C | Area saved by dropping the CNM | as A, `ENABLE_CNM=1` |

Collect from each run:

1. WNS/TNS (setup and hold) at 4.0 ns, and the 10 worst path groups with
   start and end points.
2. Area split into SRAM macros, plus logic per hierarchy: DMA, Matrix, SFU,
   Conv, KV, dispatcher/command processor, CNM, arbiter.
3. Flop count per hierarchy. This shows whether the SFU cache or the
   operand stage became flops.
4. Power with a SAIF from a workload. The 12-layer GPT-2 program (`gt39a`) or
   the 4-sequence decode (`gx4`) can produce one with `+define+` VCD dumping.
   This is a pre-layout estimate only.

These numbers also give the tokens/s per mm² that Round 40 left open:
54.6 tok/s (4-sequence decode) divided by the run-A area.

## 5. Static analysis and verification before or with DC

Static analysis status (see `STATIC_ANALYSIS_REPORT.md`): last lint was 465
warnings, 0 errors, no waivers. Structural CDC: 0 unsynchronized crossings,
open `Reset_sync04` / `FLAT_504`. RDC has never completed: it stalls in
`Ar_resetcross01` at 6–15 GB. The `Advanced_CDC` / `rdc_adv_checker`
licenses are missing.

| Step | Why | Blocks DC? |
|---|---|---|
| SpyGlass lint on the current RTL | catches synthesizability and width issues in the Round 37–41 code | yes (quick) |
| SpyGlass CDC structural | single clock `aclk`, so low risk; confirms no new crossing | no |
| SpyGlass RDC | one async reset `aresetn`; historically does not finish here | no (best effort, bounded run) |
| Matrix formal for accumulate/staging | formal tops tie `accumulate=0` and predate staging | no |
| UVM coverage for new descriptor bits (accumulate, INT4 expand, queued DMA) | random DV has not covered them | no |

DC results can force RTL changes (§3.1–3.3). Lint and RDC would then have to
be redone. Recommended order:

1. lint (fix new warnings);
2. CDC structural, in parallel with DC run A;
3. RTL fixes from DC;
4. final lint/CDC plus a bounded RDC attempt;
5. formal and UVM additions.
