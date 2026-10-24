# Mixed-precision FP extension history

The G0/G1 implementation plan is complete and has been removed from the
active-plan directory. This short record preserves its milestones. Current
numeric behavior is specified in [FP_EXTENSION_SPEC_ZH.md](../../spec/FP_EXTENSION_SPEC_ZH.md);
current validation status is in the [A10 RTM](../../verification/A10_DV_RTM.md)
and [compute-engine status](../../verification/COMPUTE_ENGINE_STATUS.md).

| Milestone | Result |
|---|---|
| G0: baseline and contract | FP binary formats, rounding, special values, ABI/versioning, and integration boundaries were frozen before product integration. The current spec is authoritative. |
| G1: arithmetic blocks | BF16/FP16 multiplication, FP32 add/accumulate, and BF16/FP16 add/sub received standalone directed/random tests. These historical leaf-block results do not imply every leaf is instantiated in the product path. |
| G2: product integration | A10 integrates BF16 dot (`0x50`) and FP16 dot (`0x51`) through the shared command processor, SPAD arbiter, and completion path. |
| G3: system evidence | UVM scoreboards, maximum-length parity cutoffs, DMA/SPAD contention, and DDR→SPAD→FP→SPAD→DDR checks have selected passing evidence. Full-domain parity-to-writeback formal and residual code-coverage closure remain open. |

The former G0/G1 reports repeated dated test metrics and implementation notes
already represented by the FP spec, RTM, and dated verification records. They
were removed from `active/` to avoid presenting completed milestones as current
plans. See the [FP block README](../../../dv/block/compute/fp/README.md) for
reproduction targets.
