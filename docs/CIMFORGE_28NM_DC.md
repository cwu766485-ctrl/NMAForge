# CIMForge TSMC28 HPC+ synthesis profile

## Scope

This profile uses matched nominal-PVT TSMC28 HPC+ standard-cell and SRAM
timing views. The selected macro is `TS1N28HPCPL2SVTB4096X32M4MWBASO`, a
4Kx32 synchronous single-port SRAM. Thirty-two instances implement the 512
KiB scratchpad: eight macros per logical 32Kx32 bank.

The mapping is protocol-safe because `ai_spad_arbiter` admits exactly one
scheduler-side request per cycle, and the host interface rejects a request
that overlaps a scheduler request. This must remain true; do not replace this
adapter with a direct two-port instantiation of the single-port macro.

## Run

```bash
cd ~/ic/CIMForge
export TSMC28_STDCELL_DB=/path/to/tcbn28...tt0p9v25c.db
export TSMC28_SRAM_LIB_TT=/path/to/TS1N28...4096X32...tt0p9v25c.lib
export TSMC28_SRAM_DB_TT=$HOME/ic/CIMForge/syn/out/pdk_cache/TS1N28...tt0p9v25c.db
lc_shell -f syn/convert_tsmc28_sram_lib.tcl
bash syn/run_ai_accel_28nm_dc.sh 4.0
```

The default characterization point is TT, 0.9 V, 25 C. SRAM `lib` and
standard-cell `db` must use the same PVT. The run consumes the locally
converted SRAM `db`; the source `lib` remains the foundry timing source.
Unlike the 40nm study, macro area,
leakage and timing are included through `link_library`; extracted RC, CTS,
physical macro placement and signoff STA are still required before claiming
final Fmax.
