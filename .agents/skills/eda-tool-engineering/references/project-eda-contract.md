# Project EDA contract

`eda.yaml` belongs in each project's root, for example:
`/path/to/project/tsmc28_dft_smoke/eda.yaml`.

```yaml
name: tsmc28_smoke
top: tsmc28_smoke
rtl:
  - rtl/tsmc28_smoke.v
filelists: []
include_dirs: []
defines: []
pdk:
  root: /path/to/pdk/TSMC28
  target_library: path/to/slow.db
constraints: constraints/tsmc28.sdc
flows:
  sim: { simulator: vcs, tb: sim/tb.sv }
  synth: { tool: dc, script: run_dc.tcl }
dft:
  enabled: true
  scan: { chains: 1, compression: false }
  mbist: { enabled: false, controller: vendor_ip }
  lbist: { enabled: false, controller: vendor_ip }
  atpg: { faults: [stuck_at, transition], tool: tmax }
# Optional DFT adapter overrides (paths are relative to project root):
# scan_netlist: netlist/chip_scan.v
# test_protocol: dft/chip.spf
# library_verilog: /path/to/standard_cell.v
```

The parser accepts mappings, scalar lists, and inline `{...}`/`[...]` values. Keep secrets (license tokens, passwords) out of this file. The API passes only declared paths and options to adapters.

DFT terminology: `dft` is the orchestration contract; `scan` describes insertion; `mbist` and `lbist` describe controller/IP integration and test modes; `atpg` describes TestMAX pattern generation. A configured MBIST/LBIST block is not evidence of implementation until reports and a post-DFT netlist exist.
