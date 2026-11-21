# Round 4 SVSE Direct Forwarding Prototype

Opcode `0x3a` consumes two signed INT32 vectors, computes the existing
Residual sum without a shift, then applies the existing arithmetic right-shift
and INT8 saturation before packing four results per output word. `length` is a
nonzero multiple of four and `flags[4]` must be set. The operation uses the
ordinary SFU SPAD request/response protocol. It is research-only on this branch.

The Product Top A/B uses seed `20261115`, 64 elements, shift 3, the same input
memory and the same independent Golden:

| metric | baseline | direct | delta |
|---|---:|---:|---:|
| descriptor count | 2 | 1 | -1 |
| end-to-end cycles | 740 | 468 | -36.76% |
| SPAD read bytes | 768 | 512 | -33.33% |
| SPAD write bytes | 320 | 64 | -80.00% |
| output memory Golden | PASS | PASS | no regression |
| completion retirement | PASS | PASS | no regression |

Raw logs and images are under
`/tmp/nmaforge_round4_sfu_fusion_verified_20261115/`. Reproduce with:

```sh
cd /tmp/nmaforge-v2-round4/dv/subsystem/top_smoke/sim
make ai_sfu_residual_requant_ab \
  AI_SFU_FUSION_RUN=/tmp/nmaforge_round4_sfu_fusion_verified_20261115
```

This proves a real traffic and cycle reduction for one vector shape only.
Before product admission, add deterministic backpressure, parity/protection
injection, abort/reset at accepted-read and writeback boundaries, packed-word
commit-prefix checking, SVA success evidence, and a representative graph use.
Decision: `REWORK_FOR_PRODUCT`.
