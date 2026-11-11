# Phase 3 Gate 0 — Phase 2 LN32 admission review

**PASS for the bounded LN32 change; merged through [PR #4](https://github.com/cwu766485-ctrl/NMAForge/pull/4).**
Reviewed Phase 2: `20bd47ca714551607268d62a74e2c507fbadc7c4`.
Product merge: `c93ea144713d5fafe2e8a5509029927cd6859e75`.
The remote `nmaforge` SHA was checked after merge. Phase 2 and merged product
have identical RTL trees: `fe0e999fa187c4ed52a512d27509d5922e6137eb`.
This is a bounded change admission, not front-end signoff.

## RTL and numerical review

Only `rtl/compute/sfu/ai_tensor_sfu_core.v` differs from the Phase 2 product
base `cb08797e612355b404f9eb697a34f99628deebfd`: 22 insertions, 2 deletions.
The new length-32 cases specialize existing unsigned mean-square division and
signed mean division. No added flop, memory, MAC, port, descriptor or ABI field.
The SFU source SHA256 is
`a517e7072b503c7a5a144a69c58ee85475cb42b8d48c183d38b5d6dd7471f4fd`.

Mean uses unsigned absolute magnitude, division by 32, then restores sign.
Arithmetic right shift of a negative odd sum would round down and is deliberately
not used. Full-width quotient comparison retains the generic divider's
`> 2^31` error threshold, including its existing quotient-exactly-`2^31`
INT32 cast behavior. Variance uses unsigned division by 32. No changes to
Gamma/Beta, epsilon, inverse/sqrt, saturation or affine staging. The existing
length-16 path and its input cache remain unchanged. LN32 still performs its
original SRAM reads, including separate sum, variance and affine input passes;
no newly cached read or skipped protection/parity check.

Fresh VCS replay of the independent Python arbitrary-precision integer oracle:
1,231 mean probes, 1,208 variance probes; 40 generated full vectors plus recovery
(the simulation counts 41); 11 parity/protection fault points; 27 reset/abort/
watchdog events. Includes INT32 extremes, negative odd sums, arbitrary 64-bit
accumulator/overflow boundaries, variance corners, optional operands, held request
payload, accepted output prefixes and recovery. All PASS. See
[run log](../../../benchmark/research/phase3/logs/review/ln32/run.log.gz) and
[oracle scope](../../../benchmark/research/phase3/metadata/oracle.json).
State probes beyond normative input ranges check divider equivalence; they do
not extend the documented software numeric domain.

## Static and timing disposition

Fresh Verilator 5.052 focused SFU lint reproduces exactly six WIDTHTRUNC,
ten WIDTHEXPAND and one SYMRSVDWORD warning. No LATCH or UNOPTFLAT warning;
no additional warning compared with the reviewed Phase 2 focused result.
Sequential cases assign existing registers with no new combinational feedback.
The signed casts and full quotient guard were reviewed against the generic
path and integer oracle. This is not a complete formal equivalence proof.

Whole-top inherited warnings remain: PINMISSING 2, WIDTHTRUNC 64,
WIDTHEXPAND 113, CASEINCOMPLETE 4, LATCH 10, UNOPTFLAT 3. Phase 2's top-level
static report is retained; the new focused run does not close those findings.
Length decode, existing magnitude/negation, overflow compare and sign restoration
feed existing state/register logic. No new divider or multiplier, but mapped STA
is still needed for that path and existing SFU multiply/saturation paths.
No synthesis, area, 400 MHz or Fmax claim follows from simulation/lint.

## Fresh merged-product replay

VCS `V-2023.12-SP1_Full64`, 4 ns simulation clock, behavioral registered SRAM,
128 KiB / four banks / 8,192 words per bank; measured read response is two edges.
Fixed Phase 1 trained inputs/Golden are reused. All 12 workload summary records
and every archived cycle/memory trace in the fresh replay match Phase 2 optimized
sources byte for byte; H32 observed images also match their strict Golden.
The [replay ledger](../../../benchmark/research/phase3/metadata/fresh_replay_ledger.json)
records hashes and references rather than duplicating large identical traces.

| Fixed workload | Measured CMDQ cycles | Accepted compute reads / writes B | Result |
|---|---:|---:|---|
|Qualified H32 decode, eight persistent tokens|350,155 (43,769.375/token)|546,816 / 227,840|Logits/KV/intermediate Golden PASS|
|Qualified H32 prefill, four tokens|172,881|273,408 / 113,920|Golden PASS|
|H16 decode, eight tokens|65,771 (8,221.375/token)|72,448 / 42,112|Golden PASS|
|Trained CNN both-fused row-major|12,351|64,064 / 16,640|Independent 570,164 useful-MAC Golden PASS|
|GEMM 4×4×32 / 16×16×16 / 32×32×64|126 / 186 / 986|See workloads CSV|Golden PASS|
|Product 0x52 GEMV M=1 / 4 / 8, N16,K32|143 / 161 / 213|See workloads CSV|Golden PASS|

Legacy/first-fused CNN, previous H32 fixtures and Top 20 random cases/seed12345
also PASS. These are fresh replay results for unchanged merged RTL. The original
Phase 2 measured improvement remains 367,051 → 350,155 = 4.603175% H32 decode
reduction; Phase 3 adds no measured product performance improvement.

All commands and public evidence checks are in
[Phase 3 reproduction](../../../tools/benchmark/phase3/README.md).
No existing worktree or main was reset. An unused local integration worktree
created from a stale local product branch is not this PR's merge or evidence
source and was never published; only the GitHub merge SHA above is authoritative.
