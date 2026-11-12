# Architecture Freeze Proposal — NOT READY / REVIEW CHECKPOINT

This is the A/B review checkpoint required by the execution rules, not completion
of Phase D/E. Proposed integrated research branch starts from round2 dispatch
56adb124 and includes the Phase4 CNN RTL ancestry, actual-row mapper packing and
same-endpoint DMA delivery benchmark. No automatic merge to nmaforge or PR#5.

Retained: existing Phase4 ping-pong hardware (prior evidence); bounded offline
shape-aware mapper (M8 K128 full modeled interval1845→1642; M16 K1282729→2142);
existing CNN output DMA scheduling (19507→15437; under added AXI gaps20919→17267).
No hardware state,MAC,SRAM port or new ABI added in this checkpoint. Input/output
layout, common Golden, source hashes, timestep boundaries and full commands are
in the Phase A/B reports and benchmark manifest. Do not add the gains from these
independent workload experiments or call them full host application gains.

Rejected: transparent Matrix→Requant fusion, no SFU product RTL. Deferred: tile
DMA/compute overlap, runtime ownership/lease, dynamic dispatch, new cache capacity.
Archive branches by documentation/reference; no branch deletion or user worktree
modification. TPU/NVDLA/Gemmini/XDNA/Eyeriss-style mapping/fusion/decoupling are
prior art, not originality claims.

Phase D work remaining: common fixed-source H16/H32 full benchmark replay and
new output-DMA fault/abort/reset cross-products, complete protocol/fault requirements
traceability and validation of application ownership enforcement. Existing smoke,
seeded20 and focused three-seed paths are scoped evidence, not full closure.
Seed20261116 forward-chain test missed randomized backpressure nonvacuity and failed;
archive preserves it. Seeds20261112/13/14 replay passed, but do not waive the failure.

Phase E work remaining: inherited top LATCH/UNOPTFLAT triage/fixes, lint/RDC/CDC,
X/reset checking, supported-parameter elaboration, SRAM timing/port mapping, full
7-engine RTM with per-bin evidence/waiver and formal properties. No static warning
is silently accepted by this review. No current compatible128KiB SRAM macro/library
mapping was demonstrated: **ASIC_MAPPING_BLOCKED** for this checkpoint. Historical
512KiB TSMC28 pre-layout reports are not substitutes. No DC/SAIF/Fmax/area/power
signoff is claimed. DFT,MMMC,physical implementation,IR/EM remain later work.

Status: **A/B_REVIEW_CANDIDATE**, not FRONTEND_FREEZE_CANDIDATE, TAPEOUT_READY or
ASIC_SIGNOFF_PASS. Stop for review as directed by this plan.
