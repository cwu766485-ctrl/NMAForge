# Phase 2 — exact Length-32 LayerNorm implementation

Decision: **RETAIN_LN32**. Paired Top RTL simulation removes 16,896 of 367,051
H32 persistent-decode cycles (4.603175%), exceeding the 4% acceptance target.
This is a cycle improvement, not an implementation-frequency or signoff result.

## Reviewed integration and source identity

- Approved product RTL: `48790076b351cb9d49e1785247d32a1f51b8286d`.
- Reviewed Phase 1: `ae7fd31eced13dcb9dbd70533da60559511d0a90`.
- Reviewed merge into GitHub `nmaforge`: `cb08797e612355b404f9eb697a34f99628deebfd`.
- Phase 1 public evidence validator passed; its diff against the approved
  baseline contains no product RTL changes. The merge preserved that RTL.
- Candidate branch: `feat/phase2-exact-sfu`, based on the above merge.
- Only modified product RTL: `rtl/compute/sfu/ai_tensor_sfu_core.v`.
- Candidate SFU SHA256:
  `a517e7072b503c7a5a144a69c58ee85475cb42b8d48c183d38b5d6dd7471f4fd`.
- Baseline SFU SHA256:
  `fd39b0a7eb318f3d20d9231e4516c0176169c5704d864348a040238e70cd97c4`.

The publishing commit identifies the entire candidate; public
`benchmark/research/phase2/metadata/source_sha256.json` pins individual RTL,
verification tools, and immutable Phase 1 workloads/Golden. Fixture manifests
retain their original generation SHA; they do not claim to describe candidate
RTL. No other worktree or main was edited.

## Existing and new mechanisms

Existing LN16 uses its 16-entry input cache and exact power-of-two mean and
variance division. LN32 previously traversed the generic 64-bit divider twice.
The new length-32 cases replace those two divider transactions only:

1. In `ST_LN_MEAN_START`, divide the existing unsigned 64-bit sum magnitude by
   32, range-check the full quotient, then restore its sign into `mean_r`.
2. In `ST_RMS_MEAN_DIV_START`, LN32 selects `sum_sq_r >> 5`; LN16 still selects
   `sum_sq_r >> 4`. Other lengths and RMSNorm retain the generic divider.

The change adds no registers, RAM, input-cache entries, FIFO capacity, ports,
MACs, descriptors or ABI fields. No source list change is required because no
product module was added. The standalone directed TB has its own compile script.

## Exact arithmetic contract

For a signed 64-bit accumulator S, let M = abs(S) interpreted as unsigned64,
including M=2^63 when S=INT64_MIN. Independent Python integer reference computes
Q=M//32 and restores the sign. This truncates signed division toward zero;
`S >>> 5` alone would round negative odd values downward and is unsuitable.
For accepted Q <= 2^31, bits [36:5] contain the complete 32-bit quotient.
The hardware first checks **all** quotient bits [63:5] against 2^31, avoiding
truncation before overflow detection. The existing generic path reports
ERR_NUMERIC (8) for Q>2^31, and casts Q=2^31 to signed32 in either sign case;
that boundary behavior is intentionally preserved, including positive Q=2^31.

Variance is an unsigned64 accumulator; logical shifting by five equals its
unsigned divide-by-32 for every bit pattern. Squaring, accumulator wrap,
epsilon handling, square root, inverse, gamma/beta, intermediate INT32
saturation and output saturation remain in their existing states. The test
oracle uses Python arbitrary precision `//` and `math.isqrt`, independently
of the RTL's shift/slice implementation.

Normative LN inputs remain the specified signed16 values in INT32 words.
Constant INT32_MIN/MAX vectors are wider hardware stress tests, not a new
promise of general INT32-domain LayerNorm. Arbitrary64 accumulator probes are
hierarchical state-boundary tests, not claims that all such states are reachable.

## SRAM and command lifecycle

LN32 still performs input sum reads, variance reads, affine input reads,
optional gamma reads, optional beta reads and original INT32 output writes.
With gamma and beta present: 160 accepted scalar reads and 32 writes per
length-32 descriptor. Missing gamma/beta still follows the existing identity/
zero defaults and their original read counts. No A3/B2 bypass is introduced.
Authorization checks remain on accepted requests; parity checks remain on
responses. Data/error ownership, registered reads and accepted output-prefix
behavior are unchanged. Reset/abort/watchdog priority and exactly-once terminal
completion logic are untouched. Shorter arithmetic naturally shifts subsequent
accesses in time, while preserving checks at every actual access; wall-clock
fault-injection equivalence across different execution lengths is not claimed.

## Measured validation

Both baseline and candidate passed the same tests, except canonical Top smoke
and seeded regression additionally rerun on the candidate:

| Check | Result / scope |
|---|---|
| Independent mean arithmetic | PASS, 1,231 probes: signed extrema, negative odds, Q=2^31±1 and remainders, INT64 corners |
| Independent variance arithmetic | PASS, 1,208 probes including UINT64_MAX and overflow-edge bit patterns |
| Full LN32 integer Golden | PASS, 40 vectors plus clean recovery; epsilon, gamma/beta, saturation and zero-variance corners |
| LN32 faults | PASS, 6 protection phases and 5 parity phases, rejected writes preserve destination |
| LN32 recovery | PASS, 27 reset/abort/watchdog events, accepted prefix, optional operand modes and stalled payload checks |
| Existing SFU random-latency | PASS, seeds 20261112/13/14; each 64 vectors, 9 error cases, 39 reset and 39 abort states, late errors and watchdog priority |
| Qualified and historical H32 | PASS, all 12 prefill/decode stages each, Logits/KV/intermediate memory Golden |
| H16 persistent decode | PASS, 8 tokens; 65,771 cycles unchanged |
| Trained CNN | PASS, 3 fused/unfused modes and independent 20,800-word Golden per mode |
| Fixed Matrix / product GEMV | PASS, 3 GEMM and M=1/4/8 opcode0x52 shapes |
| Canonical Top smoke / seeded20 | PASS, `make ai_smoke`; `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` |
| Paired accepted SRAM sequence | PASS, identical clients/addresses/order/read-write/byte counts/bank masks |

Directed reset at unreachable/arithmetic states and forced watchdog expiry are
explicit TB injections, complemented by ordinary command-level regression.
No tests, assertions, Golden or fault expectations were weakened.

## Cycle attribution and hardware review

128 LN32 descriptors each change 813 -> 681 busy cycles: 132 saved per descriptor,
16,896 total. H32 SFU pipeline-wait bucket alone drops by that total. All other
exclusive buckets, traffic and useful work are unchanged. See the paired CSV
and H32 report for the complete window definition and counts.

The new combinational logic is a length decode, constant wires/select, full
magnitude quotient bound compare and sign-restoring negation into existing
registers. The existing magnitude absolute-value logic is reused. There is
no new SRAM-response -> arithmetic bypass or long response-select chain.
There are zero added data/metadata flops; area can still change through
combinational gates and control mapping.

Verilator5.052 focused baseline/candidate warning identities match:
6 WIDTHTRUNC, 10 WIDTHEXPAND, 1 SYMRSVDWORD; no new latch or combinational-loop
warning. Whole Top retains Phase 1's 2 PINMISSING, 64 WIDTHTRUNC,
113 WIDTHEXPAND, 4 CASEINCOMPLETE, 10 LATCH and 3 UNOPTFLAT. These are unresolved
static dispositions, not passes. Public static metadata explicitly corrects
the Phase 1 helper's hardcoded `product_rtl_changed=false` field.

No mapped synthesis, area, STA or Fmax evidence was generated. At a 400MHz
(2.5ns) target, absolute-value/compare/negation plus register input selection
requires synthesis and timing review; a 4ns simulation clock proves no Fmax.

Exact reproduction commands: [tools README](../../../tools/benchmark/phase2/README.md).
Public hash/cycle/Golden validation: `python3 tools/benchmark/phase2/validate.py`.
