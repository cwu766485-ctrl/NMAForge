# NMAForge V1.2 Round 21 — DUT Architecture and DV Preparation

This note maps the existing Product Top to the verification plan for the Round 21 model work. It is a preparation document, not a sign-off claim. The normative contracts remain in `docs/spec/SPEC_ZH.md`, `docs/architecture/ARCHITECTURE.md`, and `dv/VERIFICATION_MATRIX.md`.

## Product data/control path

```text
AXI-Lite host
  -> ai_accel_regs / CMDQ-tail doorbell
  -> descriptor fetch + validator
  -> parallel dispatcher / engine ownership / dependency events
  -> Matrix, SFU, CNN, KV, CNM, and DMA clients
  -> ai_compute_spad_mux -> ai_spad_arbiter + protection -> four-bank scratchpad
  -> ordered completion writer -> CPLQ tail / IRQ -> host retirement
```

The command processor/dispatcher own command lifecycle and queue progress. The completion writer publishes all four completion words before advancing CPLQ tail. The SPAD arbiter is the sole scheduler-side memory admission point. DMA has an AXI4 request/response lifecycle separate from compute-SPAD reads. Engine responses must be associated with accepted requests and command ownership; completion alone does not prove tensor contents.

## Interface and testpoint map

| Boundary / block | Observable contract to monitor | Scoreboard / assertion focus | Existing evidence entry |
|---|---|---|---|
| AXI-Lite registers and CMDQ/CPLQ | Tail/head ownership, descriptor publication, completion retirement, IRQ/error status | No pointer overrun; completion words precede tail; one retirement per accepted command | `dv/block/control`, `dv/uvm`, `dv/VERIFICATION_MATRIX.md` |
| Descriptor validator / dispatcher | ABI version, opcode fields, dimensions, flags, dependency and engine ownership | Invalid descriptors do not launch; latched descriptor is stable; dependencies gate consumers | `rtl/control/descriptor`, top smoke, control UVM |
| AXI DMA | AR/AW/W/R/B IDs, burst address/length, LAST, WSTRB, BRESP/RRESP, abort drain | Stable VALID payload under backpressure; accepted responses retire once; no store before producer completion | `dv/block/dma`, DMA-SPAD subsystem tests |
| SPAD arbiter / protection / memory fabric | Accepted request address/client, response owner/order, bank grants, range/permission | No orphan/stale response; no protected/out-of-range access; held requests stable | `dv/subsystem/dma_spad`, `ai_accel_memory_fabric` tests |
| Matrix core / 16x16 array | A/B tile layout, K-group order, INT32 accumulation, output layout and completion | Independent GEMM/GEMV golden, tail/padding, ownership, parity and abort/reset recovery | Matrix block simulation and top smoke |
| SFU | INT32/INT8 formats, Q15 Softmax, LayerNorm affine values, requant/pack layouts | Independent scalar golden; valid length/flag combinations; response wait, fault, reset and abort recovery | `dv/block/compute/sfu` randomized-latency test |
| KV engine | Token/head/stride address and append/read visibility | Append only becomes consumable after producer completion; preserve prior entries and epoch | KV focused/top tests |
| Model workload path | Descriptor-to-tensor map, allocation lifetime, DMA fences, final tensor readback | Compare every boundary tensor to independent integer golden; no Host-produced intermediate writeback | Representative model Top tests |

## Round 21 research extension checks

The DeiT Layout Bridge uses a restricted SFU LayerNorm descriptor: opcode `0x38`, ABI 7, flag bit 6, H=192, physical Matrix-A tensor shape 208x192, row 0..196, and explicit gamma/beta. The descriptor validator rejects unsupported combinations. The Top test reads one selected row from the Product-produced packed embedding, executes LayerNorm in RTL, and checks the output words against an independent integer reference.

Completed for this bounded feature: one real H192 row and the full 197x192 patch-embedding tensor passed the focused 256 KiB Product Top test; existing randomized SFU latency/fault/reset regression passed one seed; the default 128 KiB smoke passed. Not established: negative validator matrix for every flag/shape, repeated rows/all 197 LayerNorm outputs, QKV consumption, full Encoder Layer 0, or 256 KiB broad regression. These remain explicit open testpoints.

The GPT-2 scale-aligned contract experiment is software-only. It does not alter RTL, ABI, the frozen package, or Product Top evidence. A software metric improvement cannot close model quality or RTL qualification.

## Closure planning

Before any future shared RTL/ABI merge, add or identify directed checks for: (1) legal and illegal research descriptor fields, (2) Row-Matrix-A unpack versus full INT32 gamma/beta, (3) all row boundaries and tile-tail addresses, (4) parity/protection/abort/reset while the three LayerNorm input passes are active, (5) completion and DMA fence ordering, and (6) legacy contiguous LayerNorm compatibility. Cross-model regression must include the frozen GPT-2 Top package and existing CNN/matrix smoke.

The current evidence is targeted engineering validation. It is not full DV sign-off, complete functional/code coverage closure, formal proof, or a classification result.

Cross-model compatibility evidence was collected on the isolated DeiT research
branch after the optional LayerNorm tile-row extension: the existing H64
four-layer Product Top autoregressive replay passed four Product-SPAD
Logit/argmax steps, with zero resets and zero Host intermediate writes. The
final default 128 KiB `ai_smoke` also passed at seed 20261121 with four random
cases. These results protect the existing synthetic H64 path; they do not
establish trained GPT-2 quality or full DV sign-off. The optional LayerNorm
tile-row mode still needs its own negative-descriptor and active-mode
abort/reset/fault tests before broader adoption.

