"""Independent one-entry transaction model. No product RTL or ABI changes.

STRICT preserves the per-read SPAD permission/parity observation and cannot
remove SRAM reads. IDEAL_BYPASS is a counterfactual, unapproved observation mode.
The trace model estimates serialized local service replacement, not RTL cycles.
"""
from dataclasses import dataclass, field


@dataclass
class Entry:
    base: int = 0
    length: int = 0
    epoch: int = 0
    producer: int = -1
    signal_mask: int = 0
    mask: int = 0
    valid: bool = False
    capturing: bool = False
    retired: bool = False
    lease: bool = False
    poisoned: bool = False
    pending: tuple | None = None
    format: str = 'committed_i32_row_major'
    data: list = field(default_factory=lambda: [0]*32)

    def invalidate(self):
        self.mask = 0
        self.valid = self.capturing = self.retired = self.lease = False
        self.pending = None

    def begin(self, base, length, epoch, producer, signal_mask, fmt='committed_i32_row_major'):
        # One bank cannot be recaptured while leased; caller must use SPAD.
        if self.lease or self.pending is not None:
            return False
        self.invalidate()
        self.poisoned = False
        self.base, self.length, self.epoch = base, length, epoch
        self.producer, self.signal_mask, self.format = producer, signal_mask, fmt
        self.capturing = (base % 4 == 0 and base >= 0 and base+4*length <= 131072
                          and 0 < length <= 32 and fmt == 'committed_i32_row_major')
        return self.capturing

    def capture(self, address, values, *, accepted=True, allowed=True, committed=True):
        if not accepted:
            return
        if not allowed or not committed:
            self.invalidate()
            return
        if not self.capturing:
            return
        for i, word in enumerate(values):
            index = (address+4*i-self.base)//4
            if address % 4 or not 0 <= index < self.length or self.mask >> index & 1:
                self.poisoned = True
                self.invalidate()
                return
            self.data[index] = word & 0xffffffff
            self.mask |= 1 << index

    def complete(self, success):
        self.valid = (success and self.capturing and not self.poisoned
                      and self.mask == (1 << self.length)-1)
        self.capturing = False
        if not self.valid:
            self.invalidate()

    def retire(self, producer, epoch, success):
        self.retired = bool(self.valid and success and producer == self.producer and epoch == self.epoch)
        if not success:
            self.invalidate()

    def bind(self, base, length, epoch, producer, wait_mask, last_event_writer,
             fmt='committed_i32_row_major'):
        if self.lease or self.pending is not None:
            return False
        dep = self.signal_mask & wait_mask
        provenance = dep and all(last_event_writer.get(bit) == (epoch, producer)
            for bit in range(16) if dep >> bit & 1)
        self.lease = bool(self.valid and self.retired and not self.lease
            and self.pending is None and self.base == base and self.length == length
            and self.epoch == epoch and self.producer == producer
            and self.format == fmt and provenance)
        return self.lease

    def write(self, address, size, strobes=None):
        # Includes host/debug, DMA, completion and every compute engine.
        # An overlap must dominate a hit on the same clock.
        if strobes is None:
            strobes = (1 << size)-1
        if any(strobes >> i & 1 and self.base <= address+i < self.base+4*self.length
               for i in range(size)):
            self.invalidate()

    def request(self, index, mode, *, allowed=True, protection_epoch_stable=True):
        if mode not in ('STRICT', 'IDEAL_BYPASS'):
            raise ValueError('unknown observation contract')
        if not allowed:
            self.invalidate()
            return 'PROTECTION_ERROR'
        if (mode != 'IDEAL_BYPASS' or not protection_epoch_stable
                or not self.lease or not 0 <= index < self.length):
            return 'SPAD_FALLBACK'
        if self.pending is not None:
            raise RuntimeError('duplicate request while registered cache response pending')
        self.pending = (self.epoch, self.data[index])
        return 'REGISTERED_CACHE'

    def response(self, epoch, ready):
        if self.pending is None:
            return None
        if self.pending[0] != epoch:
            self.invalidate()
            return None
        if not ready:
            return None
        value = self.pending[1]
        self.pending = None
        return value

    def release(self):
        self.invalidate()
