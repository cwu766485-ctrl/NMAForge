# SPAD Macro Contract

**Product baseline:** `fc60f95d72c0cfb7dfa9df895a30a701c842d21e`
**Status:** behavioral/XPM interface contract captured; ASIC macro binding blocked.

## Geometry and address mapping

| Item | Default product | Compatibility parameter |
|---|---:|---:|
| Banks | 4 | 4 |
| 32-bit words per bank | 8,192 | 32,768 |
| Data capacity | 131,072 B / 128 KiB | 524,288 B / 512 KiB |
| Parity storage in VCS model | 32,768 bits / 4 KiB | 131,072 bits / 16 KiB |
| SPAD host byte window | `[0x00010000, 0x00030000)` | `[0x00010000, 0x00090000)` |
| Row address bits | 13 | 15 |
| Bank select | word address bits `[3:2]` | same |
| Line | four adjacent bank words / 128 bits / 16 bytes | same |

`rtl/top/ai_accel_top.v:24`, `:162..166`; `rtl/memory/ai_scratchpad.v:11..14`, `:45..64`. Address checks, not truncation, determine validity. Default valid offsets are `0x00000..0x1ffff`, absolute host addresses `0x10000..0x2ffff`. The first and last legal byte/word and line boundaries must be explicit in every reduced-capacity fixture.

## RTL port and access contract

The behavioral/XPM module presents host/debug Port A and scheduler Port B. Port A is 32-bit with 4-bit byte strobes. Port B supports scalar 32-bit access, 128-bit line access with 16 strobes, Matrix banked read returning four bank words at one row, and CNM read with four independent per-bank row addresses and lane-valid mask (`rtl/memory/ai_scratchpad.v:16..39`, `:73..89`, `:220..258`).

Top scheduler admission is one request per cycle across descriptor, completion, core, Matrix line, Matrix banked, CNM and DMA paths. Descriptor and completion have priority over data. Data classes rotate core → banked/CNM → DMA. Matrix banked and CNM contend for the same banked class turn and cannot both be accepted in one arbiter slot (`rtl/memory/ai_spad_arbiter.v:76..128`, `:178..184`). CNM lanes within one accepted transaction can address separate banks at once; this does not create cross-client per-bank arbitration.

Scalar/line/CNM/Matrix banked requests obey their alignment and range checks. Host requests that coincide with a scheduler request are explicitly rejected as `host_conflict`; they are not queued (`rtl/memory/ai_scratchpad.v:65..89`). Therefore the top's observable same-cycle host/scheduler collision policy is an error on the host operation, while accepted scheduler work continues. This fact does not make an arbitrary single-port SRAM a drop-in: the interface, latency, per-bank simultaneous accesses, and collision behavior still require an adapter and proof.

Protection regions are four half-open byte ranges with read/write/execute/enable bits. Every request must fit entirely inside one enabled region; adjacent regions do not combine. If all regions are disabled, compatibility mode permits requests. Enabled-region zero-byte requests reject. The checker uses 33-bit end arithmetic (`rtl/memory/ai_spad_protection.v:6..11`, `:41..77`). Host, line, banked, completion and compute accesses have separate protection decisions at the top.

## Read, write and response timing

Both XPM ports request common-clock true-dual-port block RAM, read-first behavior and `READ_LATENCY_A/B=2`; the VCS behavioral code has a memory-read pipeline and registered output stage (`rtl/memory/ai_scratchpad.v:96..123`, `:147..193`). Writes with byte enables merge old/new bytes and recompute parity (`:164..174`, `:229..237`). Storage arrays are not reset; response/control pipeline state is reset/invalidated.

Scheduler scalar reads return one ordered registered response after two cycles at the scratchpad interface; the arbiter pipelines accepted-client, line-kind and request-time protection metadata so response ownership aligns with data/parity (`rtl/memory/ai_spad_arbiter.v:55..65`, `:143..177`). These interfaces have no `rsp_ready` and no response ID. Responses must be returned in issue order. Matrix's default four-entry metadata queue and Mixed FP's two-outstanding read pair are consumer contracts, not a license for the memory to reorder.

The VCS branch stores one parity bit per 32-bit data word and computes even-reduction parity on accepted writes; reads compare calculated parity to stored parity (`rtl/memory/ai_scratchpad.v:149..156`, `:195..215`, `:229..253`). The FPGA XPM branch has no parity array and drives parity error outputs to zero (`:133..143`). Do not use XPM simulation as evidence of ASIC parity fault detection.

## Macro requirements and non-equivalence

The current implementation instantiates `xpm_memory_tdpram` with common clocks, separate A/B enables and byte write masks. A compatible ASIC binding needs either a characterized common-clock true dual-port macro per bank, or an adapter whose admission, throughput and timing behavior are explicitly reverified. A single-port macro does not provide the existing two-port structure: it cannot directly service host Port A and scheduler Port B, cannot preserve an independent Port B pipeline while Port A is enabled, and does not automatically match the selected bank-wide operations. It may be usable only after a reviewed serialization/admission adapter proves all current observable handshake, collision/error, two-cycle response, line WSTRB, parity, reset and protection behavior; simply connecting its pins is not equivalent.

Required macro/adaptor properties:

| Property | Required behavior / verification |
|---|---|
| Clocking | Both logical ports use `aclk`; characterize setup/hold and clock-enable behavior. |
| Read latency | Preserve two registered cycles or retime every consumer, owner tag, protection bit, parity bit and watchdog account in a reviewed interface change. |
| Read-during-write | Define same-port and cross-port same-address behavior. Current XPM selects read-first; VCS nonblocking model observes pre-write data. No unspecified collision mode is acceptable. |
| Writes | 32-bit word with 4 byte enables; 128-bit line with four bank lanes and corresponding 16 byte enables; parity updated from merged word. |
| Banked access | Matrix read returns all four words for one row; CNM can use lane-specific rows in one admitted transaction. Ensure physical macro mapping can service all selected banks in one cycle. |
| Parity | Store/check one parity bit per 32-bit data word or provide equivalent protection code and update the SPEC/test model. Fault injection/readback required. |
| Reset | Do not reset the large array; reset/invalidate response pipelines and validity/owner metadata. Define uninitialized content policy before first write. |
| Power/test | Provide macro test mode, scan isolation, MBIST protocol, sleep/enable semantics and timing arcs for integration. |
| Physical views | Deliver authorized Verilog, Liberty/CCS, LEF, GDS/CDL as appropriate, corner/voltage/temp characterization and synthesis mapping setup. |

## Open ASIC binding blockers

`docs/verification/frontend_closeout/ASIC_READINESS.md` records `ASIC_MAPPING_BLOCKED`: no authorized compatible macro views/wrapper, standard-cell database or characterized project SDC are available in the public review baseline. `eda.yaml` references private `external/private` resources; those were not present/provided for this review. Required before DC: exact macro depth/width/parity composition, legal standard-cell and SRAM libraries, timing constraints/corners, macro adapter and memory mapping setup. Required before implementation signoff: DFT/MBIST, floorplan, placement, CTS, route, extraction, MMMC STA, power, IR/EM and physical verification.

No macro area, Fmax, power or signoff result is claimed here. Behavioral cycles, XPM inference and a synthesis dry-run do not establish ASIC timing or physical feasibility.
