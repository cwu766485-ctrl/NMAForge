# Opcode and descriptor ABI review

No ABI modifications. Normative sources: `docs/spec/SPEC_ZH.md`, `docs/spec/NPU_ARCHITECTURE_V2_SPEC.md`, `docs/spec/SFU_NUMERIC_CONTRACT_ZH.md`.

Descriptor words 0..15: task/opcode; src0; src1; bias; dst; M/N; extent; flags; aux0; postprocess; src0/src1/dst strides; batch/head; events; ABI/clear. Software publishes CMDQ_TAIL and consumes CPLQ_HEAD. Ordered completion remains four words then tail.

0x30/31 use legacy 4×4 tile-major operands. 0x52 uses bounded dense padded A/B layout, M/N<=16 and supported field restrictions; rejects unsupported strides/transposes/batches and illegal alias/range. 0x53 applies exact Matrix clamp followed by requant, optional bounded row-major layout or tagged forwarding, preserving opted-in SPAD writes. It does not replace legacy materialized INT32 mode.

SFU 0x38 keeps mean truncation toward zero, floor variance/division and integer sqrt, gamma arithmetic shift and sat32, reciprocal scaling and beta/saturation. All INT32 outputs remain materialized. Cache setup bypass changes latency only. Requant, Residual, event ordering, completion fields and error codes are unchanged.
