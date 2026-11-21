# SPAD 128 KiB parameterization — Gate 0

Date: 2026-11-11 Asia/Singapore. Baseline: `95c4387bb0ac57ff4fa427fd3c1202320ad0940b`.
Candidate: `feat/spad-128k-closure`. Gate 2–5 performance work is deferred pending architecture review.

## Product configuration and contract

| Property | Default | Compatibility |
|---|---|---|
| Banks / word width | 4 / 32 bits | Same |
| Words per bank | 8192 | 32768 |
| Data capacity | 131072 B (128 KiB) | 524288 B (512 KiB) |
| Row bits | 13 | 15 |
| Local byte range | `0x00000..0x1ffff` | `0x00000..0x7ffff` |
| Host aperture offsets | `0x10000..0x2ffff` | `0x10000..0x8ffff` |
| SPAD_INFO (offset `0x164`) | `0x00020000` | `0x00080000` |

`ai_accel_top.SPAD_WORDS_PER_BANK` selects capacity during elaboration. There is no runtime switching, duplicate SRAM implementation, extra port or MAC array. Top, scratchpad, fabric, subsystem and standalone register defaults now agree. Fabric capacity defaults derive from depth. Top/scratchpad explicitly reject non-power-of-two depths, depth outside 2..32768, and scratchpad rejects non-four-bank/inconsistent row width. The smaller power-of-two depths remain for existing block/FPGA resource profiles; the two product regression profiles above are qualified here. Fabric/subsystem reject mismatched advertised capacity and physical geometry. Invalid constant generate branches terminate simulation at time zero; valid configurations eliminate those branches. VCS can return zero even for `$fatal`, so the geometry checker examines the fatal text and absence of the success marker.

## Code audit

| Path | Verified behavior / change |
|---|---|
| `rtl/top/ai_accel_top.v` | Default depth 8192; capacity/row width/decoder derived; geometry guard |
| `rtl/memory/ai_scratchpad.v` | Same four behavioral/XPM banks; default/geometry checks only |
| `rtl/top/fabric/memory/ai_accel_{memory_fabric,spad_subsystem}.v` | Defaults and consistency guards; unchanged ownership/protection/routing |
| `rtl/control/axi_lite/ai_accel_regs.v` | Standalone SPAD_INFO default 131072; top still supplies elaborated bytes |
| AXI-Lite decoder | Existing low-20-bit aperture localization retained; capacity window derived from base+bytes; unaligned/OOB access SLVERR |
| DMA | Unchanged per-access fabric checks; capacity crossing commits the valid prefix, reports DMA ERR_SPAD=4, drains accepted AXI traffic; no wrap/rollback promise |
| Descriptor fetch | Unchanged registered scalar fetch; crossing produces ERR_FETCH=6 and error completion |
| Completion writer | Unchanged four-word publication; invalid completion range refused with ERR_PROT=10 before command head advance |
| Mapper | Capacity argument/checks for tensors and emitted queues; H16 incremental queue bound no longer assumes 512 KiB |
| Digits/MiniCNN | Shared bounded allocator; emitted layout memh consumed by TB; no manual capacity-specific shifts |
| Software header / bring-up | Default capacity 128 KiB; version stays A10; optional EXPECTED capacity override for compatibility ELF |
| XCZU15EG scripts | Shared elaboration/validation setting `SPAD_WORDS_PER_BANK=8192` or `32768`; synthesis generic, block design property, JTAG and generated ELF checks agree |
| A7 | Explicit 4096 words/bank resource profile retained; product-default comment corrected |
| Synthesis | Existing public cluster/matrix scripts do not hardcode top SPAD depth; private top overlay requires requalification, not included/run |
| Initialization | XPM `MEMORY_INIT_FILE="none"`, `USE_MEM_INIT=0` unchanged; workloads explicitly initialize/read-check accessed tensors; no new SRAM init dependency |

Host/control and data-plane priority, command lifecycle, queue ABI v7.4, integer algorithms and mandatory fault observation are unchanged. No transparent A3/B2 bypass is introduced. Legacy Elastic Forwarding remains existing functionality; its earlier fault-contract limitations are not requalified by this change.

Read pipelines and response tags are untouched: host/scalar/banked/CNM use their existing registered stages; the existing line datapath and arbiter timing are also unchanged. This is a source-diff observation plus functional response-ownership regression, not a new macro timing claim. All RTL edits are defaults or constant-invalid guards; no additional runtime registers, buffers, muxes or arithmetic.

## Capacity-aware fixtures

Digits retains all 360 samples, 23 padded batches, 46 descriptors, hidden outputs and logits. Reserved high-water is 90624 B; no lifetime reuse is required. MiniCNN reserves padded physical Matrix-A storage (576 B for its im2col input, including padded rows), four/ten-class weights and intermediate/output buffers, plus 128-entry queues. Reserved high-water is 18176 B. FC scratch buffers are reused sequentially as before; all layer Golden checks remain.

The deprecated Python `--compact-spad` flag remains harmless; nonzero `--spad-base-shift` fails explicitly. Old immutable benchmark archives retain original commands. New commands consume generated `*_layout.memh` and pass `--spad-bytes`; old binaries/static layouts must not be mixed with new fixtures.

Smoke's 512 KiB highest-row probe now derives from capacity, and its disjoint concurrent-engine result pages are placed below the configured end. All original 21 engine-pair overlap/ordered-abort checks remain. The Make target now requires the final `TEST PASS`, fixing the former false success when selected individual markers passed but 23 fixture errors remained.

## Qualification limits

See [regression evidence](SPAD_CONFIG_REGRESSION.md). No FPGA rebuild, private SRAM mapping, DC/P&R, signoff lint, PPA or implementation Fmax is claimed. Historical 512 KiB FPGA timing/area remains explicitly historical. Existing latch/width/combination-loop warnings are unresolved architecture/static-analysis risks; counts match the same-capacity baseline. Gate 0/1 functional closure does not authorize a front-end freeze.
