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
