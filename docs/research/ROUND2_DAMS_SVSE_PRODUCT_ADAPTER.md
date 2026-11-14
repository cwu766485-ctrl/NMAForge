# Round 2 DAMS/SVSE Product Adapter Evidence

## Baseline and scope

The adapter is based on product candidate `0492c47d12cd11bcc22be1930da7af77ed870b6e`
and research baseline `2d85b11e42b45a8fbdb73398c3bc884fbc69f3bf`. It does not
modify `ai_accel_top`, the product dispatcher, or the product ABI.

`ai_streaming_sfu_spad_adapter.sv` maps one Residual or Requant element onto
the product's single-word SPAD request/registered-response contract. Requests
remain asserted until `spad_ready`; reads wait for `spad_rsp_valid`; the
writeback is accepted through the same ready handshake. The testbench uses a
passive behavioral SPAD and compares both results with the product
`ai_tensor_sfu_math` implementation.

## Measured results

```text
DAMS_SVSE_PASS accepted=3 denied=1
SVSE_PRODUCT_ADAPTER_PASS residual=140 requant=127
```

The adapter test covers nonzero signed Residual (`120 + 20 = 140`) and
Requant (`4096 >>> 5`, saturating to `127`). Both output memory words and the
adapter result match the product arithmetic module bit-for-bit. An early test
exposed that the research streaming block incorrectly added stale operand B
for unary Requant; the prototype was corrected so Requant uses only operand A.

Reproduction:

```sh
cd /tmp/nmaforge-v2-round2-dams
make -C dv/research/dams_svse/sim all
make -C dv/research/dams_svse/sim adapter
```

## Integration boundary

This is a product-contract adapter, not product integration. The current
`ai_compute_spad_mux` exposes one ordinary compute requester into the sole
`ai_spad_arbiter` core admission point, while product SFU commands are owned
by the existing command processor and engine lifecycle. The adapter has no
legal command ID, completion queue slot, descriptor allocator, or protection
ownership connection. Connecting it to Top without those contracts would
change ownership and completion semantics.

Therefore Gate 3/4 status is:

| Item | Status |
|---|---|
| Standalone DAMS/SVSE research prototype | PASS |
| SVSE product arithmetic bit-exact adapter | PASS |
| Real product Top/Dispatcher integration | `BLOCKED_BY_CONTROL_CONTRACT` |
| Real Transformer overlap / cycle gain | `NOT_RUN` |
| Product ABI change | NOT AUTHORIZED |

The next integration step requires an approved descriptor/command ownership
contract and a subsystem harness connecting the adapter to the real mux,
arbiter, protection, response owner and completion writer. No performance
claim is made from this adapter-only result.
