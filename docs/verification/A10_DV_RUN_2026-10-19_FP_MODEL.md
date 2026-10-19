# A10 V1 FP reference-model recheck

## Scope

- Tested source SHA: `2f7b82d448acf3616081407a8261ad4c359582db`
- Python: `3.12.10`
- Test module: `dv/block/compute/fp/model/test_fp_reference.py`
- RTL and UVM were not changed or exercised by this Python-only run.

## Command and result

Run from the model directory:

```sh
python -m unittest test_fp_reference -v
```

Result: 19 tests passed in 0.233 seconds. Coverage includes BF16/FP16 dot
sanity vectors, exact conversions, per-product/per-accumulation rounding,
subnormals, ties-to-even, overflow boundaries, signed zero, infinities, NaNs,
and deterministic finite-value properties.

This is a license-independent refresh of the numerical reference-model unit
tests. It does not replace the existing RTL-vs-model UVM evidence and does not
close V1-FP-04's full-domain parity-to-writeback formal question.

## Current-main rerun — 2026-10-19

- Repository SHA at run time: `7fd70d871a64a858dcdf424024602c50624cfaa6`.
- `dv/block/compute/fp/model` is byte-identical to tested SHA
  `2f7b82d448acf3616081407a8261ad4c359582db` (`git diff --quiet` returned 0).
- Python: `3.12.10`.
- Command: `python -m unittest test_fp_reference -v` from
  `dv/block/compute/fp/model`.
- Result: 19/19 tests passed in 0.104 seconds.

This confirms the numerical model checks still pass on current `main`; it does
not exercise RTL, UVM, or the unresolved full-domain formal property.
