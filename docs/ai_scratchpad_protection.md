# Scratchpad Region Protection

`ai_accel_top` exposes four optional scratchpad protection regions.  This is a
software/hardware contract for data, command and completion buffers; it is not
an MMU or an IOMMU.

## Compatibility and policy

All region permissions reset to zero, so protection is disabled and the legacy
64KB scratchpad behaviour is unchanged.  Once any region has `PERM.enable=1`,
every scratchpad request must fit completely inside one enabled region.

Regions use byte addresses relative to the scratchpad window (`0x0001_0000` is
not included in programmed values).  `LIMIT` is exclusive.  A request may not
cross from one allowed region into another.

| `PERM` bit | Meaning |
|---:|---|
| 0 | read permitted |
| 1 | write permitted |
| 2 | execute permitted for INT8 compute-core accesses |
| 3 | region enabled |

The host and DMA use read/write permissions.  The compute core requires its
normal read/write permission plus execute permission.  Descriptor fetch is a
read and completion writes require write permission.

## Register map

| Region | BASE | LIMIT | PERM |
|---|---:|---:|---:|
| 0 | `0xD4` | `0xD8` | `0xDC` |
| 1 | `0xE0` | `0xE4` | `0xE8` |
| 2 | `0xEC` | `0xF0` | `0xF4` |
| 3 | `0xF8` | `0xFC` | `0x100` |

The control aperture therefore extends through offset `0x100`; software should
use the full AXI-Lite address rather than truncating offsets to eight bits.

## Failure behaviour

A denied host access returns AXI-Lite `SLVERR` and does not access SRAM.  A
denied internal scratchpad request is blocked before SRAM and is forwarded to
the originating compute, DMA or descriptor path as an access error.  The INT8
core reports `ERROR_CODE=6` for this condition.  Descriptor/DMA failures use
their existing error paths; all are reflected in `STATUS`, IRQ and, when the
completion destination itself is permitted, an error completion record.
