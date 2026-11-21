#!/usr/bin/env python3
"""Check placement, capacity rejection and unchanged fixed-point workload data."""
import json, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from sw.tools.spad_memory_planner import SpadMemoryPlanner
from sw.tools.cimforge_mapper import Mapper, build_workload
for capacity in (131072, 524288):
    p = SpadMemoryPlanner(capacity)
    assert p.reserve("full", capacity) == 0
    try:
        p.reserve("overflow", 4)
    except ValueError:
        pass
    else:
        raise AssertionError("SPAD overflow was accepted")
    mapper, _ = build_workload(capacity_bytes=capacity)
    desc = (mapper.next_addr + 4095) & ~4095
    cpl = (desc + len(mapper.descriptors)*64 + 4095) & ~4095
    mapper.check_queues(desc, cpl)
    try:
        mapper.check_queues(capacity, cpl)
    except ValueError:
        pass
    else:
        raise AssertionError("queue overflow was accepted")
# The numerical payload/descriptor words remain identical in both builds.
a, ga = build_workload(capacity_bytes=131072)
b, gb = build_workload(capacity_bytes=524288)
assert ga == gb and [d.words() for d in a.descriptors] == [d.words() for d in b.descriptors]
assert [(t.addr,t.values) for t in a.tensors.values()] == [(t.addr,t.values) for t in b.tensors.values()]
print("SPAD_ALLOCATOR_PASS capacities=128K/512K overflow=reject queue_overflow=reject numerical_payload=identical")
