# AI Accelerator Queue Protocol

## Scope

This document defines the queue-mode contract of `ai_accel_top`.  It applies
when `CMDQ_SIZE` is non-zero.  `CMDQ_SIZE == 0` retains the legacy mode where
one descriptor at `CMDQ_BASE_LO` is launched by each doorbell.

## Ownership

| Queue | Software-owned pointer | Hardware-owned pointer |
|---|---|---|
| Command queue | `CMDQ_TAIL` | `CMDQ_HEAD` |
| Completion queue | `CPLQ_HEAD` | `CPLQ_TAIL` |

Descriptors are 64 bytes and completion entries are 16 bytes.  Queue pointers
are entry indices and wrap at their corresponding `*_SIZE` value.

## Producer/consumer flow

1. Software writes one or more descriptors, then publishes them by updating
   `CMDQ_TAIL`.
2. Software writes `DOORBELL`.  Hardware fetches at `CMDQ_HEAD`, advances it,
   and continues consuming published descriptors after each completion.
3. Hardware writes a completion entry at `CPLQ_TAIL` and advances `CPLQ_TAIL`
   only after all four words are committed.
4. Software reads the completion entry, then advances `CPLQ_HEAD` to release
   the slot.

The rings reserve one slot to distinguish full from empty, so a ring programmed
with size `N` holds at most `N - 1` outstanding entries.  Queue mode requires a
size of at least two.

## Registers

| Offset | Register | Meaning |
|---:|---|---|
| `0x80` | `CMDQ_BASE_LO` | Command descriptor ring base |
| `0x88` | `CMDQ_SIZE` | Command ring size in descriptors |
| `0x8c` | `CMDQ_HEAD` | Hardware consumer index |
| `0xc8` | `CMDQ_TAIL` | Software producer index |
| `0x90` | `CPLQ_BASE_LO` | Completion ring base |
| `0x98` | `CPLQ_SIZE` | Completion ring size in entries |
| `0x9c` | `CPLQ_TAIL` | Hardware producer index |
| `0xcc` | `CPLQ_HEAD` | Software consumer index |
| `0xd0` | `QUEUE_STATUS` | bit0 cmdq_empty, bit1 cplq_empty, bit2 cplq_full, bit3 queue_running |

## Error behaviour

| Error code | Name | Cause |
|---:|---|---|
| `8` | `ERR_CMDQ_EMPTY` | Doorbell while command ring is empty |
| `9` | `ERR_CPLQ_FULL` | Doorbell while completion ring is full, or queue mode has no completion ring |

Both conditions set `STATUS.done`, `STATUS.error`, the global IRQ status, and
`ERROR_CODE`.  No descriptor fetch occurs, so unread completion data is never
overwritten.
