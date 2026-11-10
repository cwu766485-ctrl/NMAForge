# Stage C — CNN A3 admission and K64 continuation feasibility

Decision: **transparent A3 REJECT; K64 continuation PARTIAL**. No product RTL,
ABI, SRAM port, accumulator, or buffer is added. Baseline reviewed commit is
`4e65a2ac2fc176acc5621aebec000874f2c5ab24`.

## Fault and commit audit

Actual `ai_tensor_matrix_core.v` capture requires opcode0x53, aux0[5], M=N=16,
one instance and zero destination batch stride. Capture fires only at
`line_valid && line_ready && !output_write_has_protection_error`, with a
per-line mask; duplicates cancel capture. ST_DONE publishes the completed mask.
The current synchronous behavioral memory commits that accepted line on the
edge; a future macro write-error response would need a stronger commit contract.

Consume requires aux0[6], matching base, M16,K16, nontransposed A and a live tag.
`tile_forward_a_copy`, prefetch selection and request gating copy local bytes
instead of issuing A banked reads. All producer INT8 writes still occur. This
path does not create legacy INT32 outputs absent from the fused opcode; ordinary
INT32 opcodes must retain their specified writes. A3 may not remove either kind
of software-visible output.

The ordinary arbiter/protection + scratchpad read checks current permissions and
current SRAM parity. The copied tile cannot perform these checks. A correct
committed cached byte does not detect a silent later SRAM upset. Replayed
Stage B VCS contract test uses real product fabric and SFU, actual accepted line
writes, then changes SRAM23→22 without changing parity or generating a bus write:
baseline reports ERR_PARITY5 with zero writes. Denied source read reports
ERR_PROTECTION6; ready with denied destination write does not commit. Recovery
passes. This is the same counterexample applied to A3's cancelled read, **not a
new direct A3 fault-injection simulation**. Evidence: `benchmark/research/stage_c/contract/`.

Existing A2 reset, abort/watchdog and Matrix error paths clear local validity;
a nonconsuming Matrix start also invalidates. No producer epoch/consumer identity,
DMA/Host/Debug/SFU write snoop or protection-generation tag establishes coherent
freshness between commands. Address match and optional dependency events alone
do not provide it. A successful consumer retires through the normal command
lifecycle; a skipped fault can nevertheless turn a formerly failing command into
success. Existing A2 is an explicit legacy opt-in, **not certified under the
strict Stage C contract**. H32 and trained CNN do not set either forwarding bit.
No relaxed mode is introduced. Stop Gate0: no transparent A3 RTL implementation.

## Exact K16×4 model

`tools/benchmark/stage_c/k64.py` reads frozen trained CNN ACT1 Golden and K64×N16
weights. For each of13 row tiles, it accumulates four exact K16 dot products in
INT64; it clears once before K0, retains sums through K1/K2/K3, and applies final
shift7 and signed INT8 saturation once after K3. Consumer ReLU is disabled;
producer ReLU precedes shift9/sat8. All3,328 outputs match the independent frozen
Golden; byte hash is `04b138d012cc69ccdbd28dfb2c36f187bf0c6b7e91596dd088d4e93641c3a5f6`.
Premature per-partial shift/saturation causes **1,854 output mismatches**.
52 lifetime records and input/model/Golden hashes are in `k64/k64.json`.

| Live object | Bytes | Consequence |
|---|---:|---|
| One16×16 INT8 channel slice |256|One elastic bank fits|
| Existing two banks |512|Ping-pong two slices; not all four|
| Complete16×64 input row tile |1,024|Cannot retain until producer finishes in512B|
|16×16 INT64 consumer partial sums |2,048|Already in array; must survive producer switches|
| Four-row×K64 packed input |256|Potential narrower schedule, not existing forwarding eligibility|
| Four-row×N16 INT64 partial sums |512|Would consume both banks if reused for sums|

Ordinary Matrix K loops already preserve one output-stationary accumulator through
K groups and postprocess only at the end. However, the **same array** must also
produce the next activation slice: `array_clear_accumulators` is asserted on
new command start and ST_NEXT. Producer/consumer interleaving clobbers consumer
sums. Two activation banks do not supply a second accumulator context or a
save/restore datapath. A full-tile context would require another2,048B plus
selection/control; retaining full activation instead requires at least1,024B.
Neither is admitted by this stage. These are concrete full-tile alternatives,
not a proof that every possible narrow algorithm needs2,048B extra.

A four-row schedule could fit256B input but needs different capture eligibility,
producer output scheduling, layout/writeback behavior and validated continuation.
The current ABI has no external accumulator save/restore or cross-command
continue bit. Internally interrupting K loops needs arbitration for accumulator
ownership and must preserve exactly-once commits, fault order and drain behavior.
A software partial-output approach can use ordinary SRAM and existing engines,
but adds writes/reads and changes intermediate/descriptor schedule; no measured
net gain is established. No unsupported "four GEMMs then early requant" is emitted.

Original required SRAM reads would still be necessary under the strict fault
contract even if tile capacity and accumulator scheduling were solved. Therefore
512B is sufficient for local streaming slices **but not demonstrated sufficient
for a beneficial, strict-fault-compatible K64 producer/consumer reuse schedule**.

Abort/reset discard live tile ownership and partial work; accepted writes cannot
be rolled back. Backpressure requires a retained committed mask and stable data
until acceptance; producer cannot overwrite leased bytes. Any future proposal
must prove fault propagation before dependent output/success and preserve pending
responses. This report establishes these obligations, not their implementation.

Reproduce:

```bash
python3 tools/benchmark/stage_c/k64.py --out /tmp/stage_c_k64_replay
STAGE_B_CONTRACT_OUT=/tmp/stage_c_fault_replay bash tools/benchmark/stage_b/run_contract.sh
```
