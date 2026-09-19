# Formal verification entry point

This folder is intentionally separate from UVM: simulation demonstrates chosen
traces; formal proves control properties for all legal traces under explicit
AXI assumptions.  The first proof scope is block/control-plane oriented:

- AXI valid payload stability while READY is low;
- DMA 4 KiB boundary, RID/RLAST and BID ownership;
- CMDQ/CPLQ monotonic pointers and four-word completion commit;
- scratchpad control-plane forward progress and reset recovery.

`ai_accel_formal_properties.sv` is a property checklist/template, not evidence
of a completed proof.  A VC Formal harness, clocks, reset assumptions and proof
logs must be added before any property is called proven.
