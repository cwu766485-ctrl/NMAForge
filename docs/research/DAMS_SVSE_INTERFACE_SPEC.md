# DAMS / SVSE Research Interface Specification

This isolated prototype does not modify the product dispatcher, SPAD arbiter,
or Legacy ABI. No product integration or performance claim is implied.

`ai_dams_scheduler` provides a bounded tile reservation table. An issue is
accepted only if a slot is free, all dependency-engine bits are complete, the
four-bit bank demand is disjoint from active reservations, and an atomic issue
requests at least one bank. A granted item remains reserved until a matching
`done_tag`. `epoch_bump` and `fault_abort` clear outstanding reservations and
completion state while advancing the epoch. Tags must be unique while active.
The prototype models tile-level dependencies and bank exclusion, not byte-range
RAW/WAR/WAW checking; the eventual command frontend must provide validated
dependency masks and ownership regions.

`ai_streaming_sfu` is a one-entry decoupled datapath. `OP_RESIDUAL` performs
signed 32-bit addition modulo 2^32. `OP_REQUANT` performs arithmetic right
shift followed by signed INT8 saturation and sign extension. The same-cycle
consume/refill case preserves one item per cycle. An epoch bump flushes a
pending item, so its caller must account for the uncommitted output in the
fault/commit-prefix model.
