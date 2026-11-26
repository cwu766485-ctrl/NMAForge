# Round 5 SVSE `0x3A` Closure

The research-only opcode `0x3A` was exercised on the existing Product Top with
the same independent residual/requant Golden for six vector lengths. No Legacy
opcode or product RTL ABI was changed in this round.

| length | cycles | SPAD reads | SPAD writes | status |
|---:|---:|---:|---:|---|
| 4 | 93 | 32 B | 4 B | PASS |
| 8 | 118 | 64 B | 8 B | PASS |
| 16 | 168 | 128 B | 16 B | PASS |
| 32 | 268 | 256 B | 32 B | PASS |
| 64 | 468 | 512 B | 64 B | PASS |
| 128 | 868 | 1,024 B | 128 B | PASS |

The cycles are end-to-end Product Top command intervals. The raw logs are in
`/tmp/nmaforge_round5_sfu_{4,8,16,32,64,128}_20261115/run.log`.

The normal numerical shape sweep is closed for this prototype. The following
required contracts remain open because this run did not produce non-vacuous
evidence for them:

- read backpressure and request stability,
- read parity fault,
- write protection fault,
- abort during read and writeback,
- reset with an outstanding response,
- accepted write commit-prefix checks,
- source/destination alias rejection and dependency checks,
- SVA and functional cross coverage for those phases.

Decision: `REWORK_FOR_PRODUCT`. Keep `0x3A` research-only until those protocol
tests and an in-model GPT-2/H64 legal match are demonstrated. The earlier
64-element A/B remains a local result (740 -> 468 cycles, 768 -> 512 read
bytes, 320 -> 64 write bytes), not a full-model performance claim.
