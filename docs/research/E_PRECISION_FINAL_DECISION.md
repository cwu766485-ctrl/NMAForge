# E Reconfigurable Precision MAC Final Decision

The product already has separate, tested responsibilities: the 256-lane INT8
Matrix/CNM datapaths and the arbiter-owned mixed FP dot path (`0x50`
BF16-to-FP32 and `0x51` FP16-to-FP32). The FP extension specification freezes
packed operands, ordered FP32 accumulation, NaN/Inf handling, and the existing
descriptor layout. The H16/H32 representative Transformer artifacts are
INT8 contracts; mixed FP has independent directed and E2E verification.

Existing evidence does not show a workload that benefits from replacing these
paths with one shared runtime-reconfigurable MAC. There is no current legal
standard-cell/SRAM view and SDC set in the public checkout for a new candidate,
and no common mapped area/timing comparison. The 28 nm report is historical
pre-layout evidence for the documented product profile, not evidence for a new
precision datapath.

**Stage 4: DEFER.** Retain the existing INT8 array and mixed-FP core. Do not
add a shared precision MAC or alter the ABI. Re-open only with a frozen
precision-demand matrix, matched workload cycles and packing traffic, a
resource model, and legal synthesis/timing inputs. Behavior-only modeling may
continue, but it cannot claim ASIC feasibility or system speedup.
