# Matrix FSM disposition on the R153 candidate — R154

**Run IDs:** `CL-MATRIX-FSM-FPV-R154-R153-6E47629-20261101`, `CL-MATRIX-FSM-ENABLED-R154-3S-20261101`, `CL-MATRIX-FSM-NOPREF-R154-3S-20261101`

**Exact clean source SHA:** `6e47629f103e3ab36948c5bb4eadc196cd27dfb4`

**Source tree:** `21478d7e4a595e17b27f7b0e89810d3617a4fd82`

**Matrix RTL SHA-256:** `dedc44406ab9f30b270bde12dbfeb3ab88184bb29af446fa1f119321e5d73aad`

**Formal harness SHA-256:** `78c292a3f7471b195335cfe61f8a1abd6070c4ae91f6ff80351e4d2a6d06e1db`

**Tools:** VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`; VC Formal `V-2023.12-SP2`
**Disposition:** PASS for the named simulations and formal properties. Raw enabled-profile FSM coverage remains 49/53; no requirement status is promoted.

## Commands and results

The runs used a detached, clean worktree at the exact source SHA above. No FSM state was forced, and no RTL, testbench, formal assumption, or coverage setting was modified.

```sh
cd /tmp/nmaforge_r153_fsm_clean/dv/block/compute/matrix/sim
VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
  CORE_OUT_DIR=/tmp/nmaforge_r153_matrix_enabled_exact \
  SEEDS='20261030 20261025 20261026' make core-random-regress
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir /tmp/nmaforge_r153_matrix_enabled_exact/coverage.vdb \
  -format text -report /tmp/nmaforge_r153_matrix_enabled_exact/urg \
  -log /tmp/nmaforge_r153_matrix_enabled_exact/urg.log
VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_r153_matrix_no_prefetch_exact \
  SEEDS='20261030 20261025 20261026' make core-no-prefetch-fallback-regress
cd /tmp/nmaforge_r153_fsm_clean
make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r153_matrix_fsm_exact \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

All commands exited 0. The enabled-profile run passed 18 Golden/layout cases and 35 fault/recovery cases on each of three seeds; each seed also passed the Matrix Line contract with 312 stable-stall observations. URG reports 15/15 states and **49/53 transitions (92.45%)**. The compile and run logs contain no VCS `Warning-`, `Error-`, or `Fatal` diagnostics.

The separate prefetch-disabled run passed all five Golden benchmark shapes and emitted `MATRIX_NO_PREFETCH_FALLBACK_PASS` on each seed, directly exercising `ST_MAC→ST_A_REQ`. Its coverage database was not merged with the enabled-profile database.

VC Formal setup reported `No setup issues found`; all five assertions were proven and non-vacuous. Both covers were reached: `ST_PREFETCH_WAIT` at depth 11 and `ST_ERROR_DRAIN` at depth 3. Runtime was 146.50 seconds. The log retains non-fatal `COM_OPT009`, `COM_OPT010`, `CLOCK_W_UNIT_ADJUST`, and `LEARNED_DATA_NOT_FOUND` diagnostics.

## Four raw enabled-profile transition misses

| Transition | Raw URG result | Disposition |
|---|---|---|
| `ST_PREFETCH_WAIT→ST_A_REQ` | Not covered | With `ENABLE_NEXT_K_PREFETCH=1`, the fallback branch is disabled. `ap_prefetch_wait_does_not_fall_back_to_a_req` is proven non-vacuously, and the source state is reachable. The legal disabled-profile transition is covered by the separate three-seed run above. |
| `ST_IDLE→ST_ERROR_DRAIN` | Not covered | The formal guard property proves idle cannot enter drain. Idle has no accepted outstanding read; Abort/watchdog drain entry is guarded by `busy`. |
| `ST_ERROR→ST_ERROR_DRAIN` | Not covered | The formal guard property proves an error state cannot re-enter drain; the state has no outstanding read, and Abort/watchdog re-entry is explicitly excluded. |
| `ST_MAC→ST_A_REQ` | Not covered | This edge is compile-time profile-specific: it is selected only when next-K prefetch is disabled. It is covered in the separate prefetch-off run and is not expected in the enabled-profile FSM database. |

Thus the raw enabled-profile FSM percentage remains 49/53. The three enabled-profile guard-incompatible edges have formal disposition; the remaining legal fallback edge has separate configuration evidence. This is not 100% raw FSM coverage, does not prove every configuration or integrated fault/reset cross, and does not close `REQ-CL-010`.

## Evidence

- Formal log: `/tmp/nmaforge_r153_matrix_fsm_exact/vc_formal.log`, SHA-256 `c6f7dc43564257b77a317ca7662303b225882b701990ecfa31f599be8f310d9f`.
- Enabled-profile URG: `/tmp/nmaforge_r153_matrix_enabled_exact/urg/modinfo.txt`, SHA-256 `e265ad24ef5678fddd52efaa49c24567f2abb826ed8d1301f9ff53e13f5ddee2`.
- Three-seed compile/run logs and the formal/URG reports are collected in `/tmp/nmaforge_r153_matrix_fsm_evidence.tar.gz`, SHA-256 `0420927f00f820363ea4fc0640d79ea03510c3d085fd5cb0c7035b9e24c7f2b6`; the archive includes a `SHA256SUMS` manifest. Coverage databases and generated tool directories remain outside Git.

The complete RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `REQ-CL-010` remains `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.
