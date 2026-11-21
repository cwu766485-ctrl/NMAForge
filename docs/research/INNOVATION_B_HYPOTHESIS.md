# Innovation B proposal: precision-preserving cross-engine forwarding

Decision: **select Matrix→Requant B2 for architecture review only**.
Status: NOT_IMPLEMENTED; novelty NOT_ESTABLISHED. B3 ephemeral tensor mode is
rejected for this stage: all required INT32 producer writes and observation
semantics remain mandatory. No product RTL has been changed.

## Baseline and measurement

B0 is the existing product Matrix/GEMV+SFU flow, including opcode0x52 capability;
current trained H16 actually uses0x30 Matrix descriptors for its projections.
Do not rename its measured flow “0x52 H16” without changing and revalidating the
mapper. B1 includes the already-implemented exact LN cache/fast arithmetic,
Residual and scheduling fixes, with65,771 cycles/8 tokens=8,221.375 cycles/token.
Earlier same-model scheduling ablation66,931→66,795→65,771 is retained historical
evidence; it is not a newly repeated baseline product variant in Stage A.

Current exclusive SFU fetch34,888 clocks dominates Matrix busy6,600.
Existing LN64 B input cache removes variance and affine X rereads; each length16
LN still reads16 X+16 Gamma+16 Beta and writes16 INT32 words. Caching Gamma/Beta
across commands requires coherent weight lifetime/invalidation; it is not a
safe implicit optimization. Existing Gamma multiply already overlaps Beta fetch.

Accepted address traces and SFU states identify explicit sequential producer/
consumer edges. Matching address alone is insufficient: analysis also filters
consumer opcode/clock to avoid reused-address double counting. Request plus the
following WAIT clocks is measured, three clocks/read in this run:

| Edge, all8 tokens | Consumer read B | Reads | Optimistic zero-cost removed read-service clocks |
|---|---:|---:|---:|
| Matrix→Requant | 8,192 | 2,048 | 6,144 |
| Residual→LN | 4,096 | 1,024 | 3,072 |
| LN→Requant | 4,096 | 1,024 | 3,072 |
| Other SFU→Requant | 2,048 | 512 | 1,536 |

These are independent **optimistic upper bounds**, not additive measured savings.
Register lookup, dependency control, capture misses and timing effects subtract
from them. Required producer writes are retained. A cache restricted to selected
opcodes/shapes may cover less than the complete trace bound.

## Selected bounded mechanism

Matrix→Requant is highest measured individual opportunity and crosses real engine
ownership. All measured eligible consumers read32 INT32 words=128 B per edge;
64 such edges occur over8 tokens. Proposed one-entry **128 B /32-word write-through
snoop cache**, no extra SPAD read port and no second arithmetic engine:

1. On a supported Matrix command start, establish one candidate contiguous,
   word-aligned output interval and format using the latched descriptor. Reject
   unsupported layouts/strides/ranges; leave ordinary SPAD flow active.
2. Capture only **accepted** Matrix output writes in that interval; retain the
   complete original INT32 output after product shift/clamp. Cache stores the
   committed memory representation, not a different internal accumulator value.
3. Set committed-word mask. Mark usable only after successful producer completion
   and an explicit completed dependency; partial capture never becomes a hit.
4. A subsequent supported Requant binds `{base,length,format,producer epoch}`.
   Register cache data into the normal SFU input path, apply the unchanged
   arithmetic right shift, sat8 and packing. Preserve one source per operand:
   a hit must suppress the corresponding SPAD request, and a miss must use the
   ordinary tagged response path. Never issue then also consume a cache response.
5. One consumer lease, invalidate after consume or conservative loss of
   exclusivity; ordinary command completion and all output writes remain intact.

Candidate metadata:32-bit base,16-bit extent,16-bit epoch,32-bit committed mask,
format/producer/consumer/valid/busy flags and small index. Target envelope≤160
metadata/control bits plus1,024 data bits (128 B), not synthesized area. Datapath
adds a registered32-bit indexed select, capture lane enables for accepted
128-bit writes and an SFU source mux. No CAM, FIFO enlargement, MAC or SRAM port.
Wider shapes miss/fall back rather than growing state. A256 B variant is not
selected without showing additional trace coverage worth its cost.

## Lifetime, alias and memory correctness

Address+length equality does not prove the cache is current. Observe accepted
writes from **all** compute engines, DMA and host/debug A port. Any overlap
invalidates the entry, including byte enables; conservative invalidation on
ambiguous/protected/error traffic is acceptable. A same-cycle competing writer
wins invalidation and prevents a cache hit. Host writes must be monitored even
though they use a separate physical port. If this observation cannot be implemented
without changing ownership/protocol timing, disable the cache whenever a writer
can be concurrent. A descriptor with unknown/in-place overlap is ineligible.

Epoch tracks command/reset generation; wrap must flush before reuse. Capture
bank may not be overwritten while a consumer has bound it. Cache acceptance,
consumer decrement and response retirement must be exactly once under stall.
Reset, abort, watchdog, protection/parity fault or unsuccessful producer/consumer
completion clear all state and pending-hit response. On partial writes, original
SPAD prefix remains visible and cache validity is discarded. Never serve old
or failed-command values. Reset of valid/masks suffices; no new requirement to
reset every data flop. Required INT32 observation, completion ordering and
legacy descriptor operation remain intact.

Snoop forwarding also raises a parity issue: returning a cached copy could hide
a later SRAM corruption. Architecture review must decide whether parity/protection
semantics require actual re-read or whether checked committed data plus cache
parity suffices for an explicitly opted-in contract. Until resolved, B2 is not
approved and not eligible for design freeze. Protection must still authorize the
consumer access even when no physical SPAD read is issued. No new ABI bit is
allocated here; any opt-in needs a separate backward-compatible specification.

## Benefit/cost rejection rule

Absolute zero-lookup ideal6,144/65,771=9.34% cycle removal is not a prediction.
If each cache read costs one clock instead of three, the local service bound is
4,096 clocks (~6.23%) before other overheads; perfect edge coverage and timing
are unproven. Full persistent decode, not an internal request counter, determines
success. This does not establish the >1.10× matched Transformer system target.
A single16-element Gamma/Beta cache can be smaller but offers a narrower
same-engine opportunity and stronger weight-coherence assumptions; LN→Requant
needs256 B for full tensor and has half the observed read bound. Requant/Residual
read pipelining is a valid alternate if cache protection/coherence cost is too high.

Later required validation: B1/B2 enable/disable on the same model/token sequence,
all intermediate/Logits/KV Golden words, same quality, actual CMDQ cycles and
read/write bytes; random request/output stalls, simultaneous writers, byte
aliasing, descriptor reuse, epoch wrap, parity/protection, reset/abort in capture,
bind and response. Check no duplicate/stale response and exact accepted prefix.
Run focused SFU+Matrix+fabric regression and top smoke/seeded regression; structural
review and limited synthesis must show bounded area and no unconstrained
response→mux→arithmetic path at2.5 ns. If coherence, parity/protection or timing
cannot be preserved economically, reject B2 and keep B1.
