# A10 SPAD Arbiter Coverage Follow-up — 2026-10-19

> **Superseded latest status:** This first coverage increment was extended at
> exact source commit `a1e87d9652ae84ed98ffcfcacc1a396064544f3b`: control-plane
> priority and response-alignment tests, two simulation assertions, and a
> seeded 20-case top regression were added. Latest raw coverage is
> line/condition/branch/toggle=`100.00/86.89/100.00/10.73%`. See the
> [priority/response follow-up](A10_DV_RUN_2026-10-19_SPAD_ARB_PRIORITY.md);
> raw condition coverage and V3/A10/V5 remain open.

## Scope and source identity

- Repository: NMAForge, branch `main`.
- Tested source commit: `cc89574ad5a69947d6dd1fff9210456c3516b867`.
- RTL was not changed. This increment adds legal directed request-form stimulus to
  `tb_ai_spad_arbiter_rr` and a separate URG coverage target in the top-smoke
  Makefile.
- Tool environment: Rocky Linux 8.10; Synopsys VCS and URG
  `V-2023.12-SP1_Full64`. The license was available for both runs.

## Commands and results

The reproducible standalone command was:

```sh
make -C dv/subsystem/top_smoke/sim ai_spad_arb_cov \
  VCS='vcs -licwait 1' URG=urg \
  SPAD_ARB_COV_RUN=/tmp/nmaforge_a10_spad_arb_cov_20261019_retry4
```

VCS and URG exited 0. Functional gates passed:

- 30-cycle directed round-robin: 10 grants per continuously pending client,
  maximum wait 2 cycles.
- Seeded 10,000-cycle request-mode run: grants core/banked/DMA
  `3334/3334/3334`, maximum wait `2/2/2`; all six request forms occurred.
- CNM/DMA contention `6/6`, response parity alignment, and 12 directed legal
  RR fallback selections passed.
- URG loaded the design and produced `modinfo.txt` and `dashboard.txt`.

Standalone `ai_spad_arbiter` raw code coverage from
`/tmp/nmaforge_a10_spad_arb_cov_20261019_retry4/urg/modinfo.txt`:

| Metric | Result |
| --- | ---: |
| Line | 96.79% |
| Condition | 81.97% |
| Branch | 96.97% |
| Toggle | 6.22% |
| URG score | 70.49% |

The six previously unhit legal data-plane fallback source lines (83, 89, 100,
106, 117, 123) are now fully hit. One executable CPL selection line remains
uncovered: source line 78, `spad_valid=1'b1` under `cpl_valid`; this standalone
data-plane RR test does not issue a completion request. The related branch is
also uncovered. Raw condition coverage remains 81.97%, including descriptor /
completion paths and residual `accept_valid`/client combinations. No coverage
exclusions or unreachable waivers were added; remaining tuples require an
explicit legal-stimulus or structural/formal disposition. Therefore this is a
substantial raw-coverage improvement, not full arbiter code-coverage closure.

The exact-source top smoke was then run:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke
```

VCS `V-2023.12-SP1_Full64` exited 0 and printed `TEST PASS`. The run used
`+ntb_random_seed=1792378327`, `AI_RANDOM_CASES=4`, `AI_SEED=12345`, and
`ACLK_PERIOD_NS=10.0`; the integrated command-fetch ownership monitor reported
`responses=56 state=ST_FETCH`. The final log contains no `TEST FAIL` marker.

## Verification status

This closes neither all V3 requirements nor A10/V5. It specifically closes the
previously missed legal data-plane RR fallback lines and reproduces scheduler
fairness on the fixed source commit. Completion selection, residual raw
conditions, low toggle coverage, and broader fault/abort/reset interactions
remain open. The arbiter has no downstream memory-ready input, so this test
does not model SPAD response back-pressure or claim end-to-end system fairness.
