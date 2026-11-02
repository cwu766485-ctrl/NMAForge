# Matrix Line contract and fallback clean replay — R198

**Run ID:** `CL-MATRIX-LINE-CONTRACT-R198-3S-20261102`
**Fixed code/test SHA:** `f87acc9bca3b3ecece385fadfd5623de6837ea8d`
**Source/test tree:** `cfc7ba4955488ae58d58f36deec368173c6ec98c`
**Worktree:** detached clean checkout `/tmp/nmaforge_r194_clean_f87acc9`
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`
**Disposition:** PASS for the named Matrix core Line contract, fault/recovery suite, and prefetch-disabled fallback. `REQ-CL-010` remains `PARTIAL`; no aggregate requirement status changes.

## Reproduction

The default enabled profile uses a 16×16 physical array, four outstanding banked reads, A-tile cache, and next-K prefetch. The fallback profile is separately compiled with next-K prefetch disabled.

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/block/compute/matrix/sim core-random-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  CORE_OUT_DIR=/tmp/nmaforge_r198_matrix_core_20261102 \
  SEEDS='20261025 20261026 20261027'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/block/compute/matrix/sim core-no-prefetch-fallback-regress \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_r198_matrix_no_prefetch_20261102 \
  SEEDS='20261025 20261026 20261027'
```

All six VCS runs pass. Per seed, the enabled profile passes 18 numerical/layout cases and 35 fault/recovery cases, including reset and Abort recovery, outstanding-read drain, parity, watchdog, and prefetch handoff. The contract gate reports:

```text
MATRIX_LINE_CONTRACT_PASS full_wstrb=1 aligned=1 stalled_stability=312 unaligned_scalar_fallback=1 protection_error=1 partial_zero_wstrb=unsupported
```

Thus the tested legal Line writes use full `WSTRB=16'hffff` and 16-byte-aligned addresses; address/data/strobe remain stable during stalls; a 4-byte-aligned non-Line-aligned chunk takes the legal scalar fallback; and Protection denial is reported. Partial and zero WSTRB are explicitly unsupported by SPEC v1.5, so the test does not inject them as invalid stimulus.

The separately compiled prefetch-disabled profile passes its fallback marker and the existing five-workload Matrix size-benchmark marker on each of the three seeds. Those cycle outputs use a one-cycle behavioral SPAD and a 10 ns simulation period; they are not measured SRAM timing, Fmax, or ASIC PPA. Both compile logs have no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

## Requirement traceability

| Requirement / issue | Status | Testpoint and checker | Result | Remaining scope |
|---|---|---|---|---|
| `OPEN-CL-004` | `CLOSED` for the frozen Matrix Line contract | `MATRIX-LINE-001`; full-strobe, address alignment, stall payload, scalar fallback, Protection response and reference-memory checks | Three-seed current-candidate replay passes; 312 stable-stall observations per seed | Unsupported partial/zero WSTRB remain outside the legal contract. |
| `REQ-CL-010` | `PARTIAL` | `core-random-regress`, `core-no-prefetch-fallback-regress`; numerical Golden, fault/recovery checkers, Line contract gate | Both profiles pass three seeds; 18 cases + 35 fault cases per enabled-profile seed | Broader Matrix requester/response, dimensions, and legal fault × phase × reset combinations remain open; enabled-profile raw FSM remains 49/53 with existing dispositions. |
| `REQ-CL-022` | `PASS-SCOPED*` (unchanged) | Independent Matrix Golden and output-image checker | Current candidate replays the named numeric/layout and Line contract points | Existing qualification and broader options/transition coverage remain. |

R198 is a clean fixed-SHA replay and promotes no requirement. The aggregate 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. See [R174](COMPUTE_CLUSTER_MATRIX_LINE_CONTRACT_R174_2026-11-02.md) for the earlier line-by-line test definition and [R186](COMPUTE_CLUSTER_MATRIX_FSM_R186_CLEAN_REPLAY_2026-11-02.md) for the named FSM/formal profile evidence.

## Evidence archive

Logs-only archive: `/tmp/nmaforge_r198_matrix_contract_evidence_20261102.tar.gz`
SHA-256: `1a0099840d43316a6bb320a6fd4d5da2b51b5702c003fd0d00df202cd1fd8690`

It contains both compile logs, six per-seed run logs, a manifest, and per-file SHA-256 checksums. Generated executables and coverage databases are excluded.
