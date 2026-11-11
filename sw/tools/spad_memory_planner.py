"""Bounded local-SPAD byte allocator shared by workload generators.

Capacity is a software build parameter matching SPAD_INFO, never runtime RTL
resizing. Allocations retain required outputs until the workload releases them.
"""
DEFAULT_SPAD_BYTES = 128 * 1024

class SpadMemoryPlanner:
    def __init__(self, capacity_bytes=DEFAULT_SPAD_BYTES, start=0):
        if capacity_bytes < 32 or capacity_bytes % 16 or (capacity_bytes // 16) & ((capacity_bytes // 16)-1):
            raise ValueError('SPAD capacity must represent four power-of-two banks')
        if start < 0 or start > capacity_bytes:
            raise ValueError('SPAD start outside capacity')
        self.capacity_bytes = capacity_bytes
        self.next_addr = start
        self.regions = {}

    def reserve(self, name, size_bytes, alignment=16):
        if size_bytes <= 0 or alignment < 4 or alignment & (alignment-1) or name in self.regions:
            raise ValueError('invalid or duplicate SPAD allocation')
        address = (self.next_addr + alignment - 1) & -alignment
        if address + size_bytes > self.capacity_bytes:
            raise ValueError(f'{name}: SPAD allocation ends at {address+size_bytes}, capacity {self.capacity_bytes}')
        self.regions[name] = {'address': address, 'bytes': size_bytes}
        self.next_addr = address + size_bytes
        return address
