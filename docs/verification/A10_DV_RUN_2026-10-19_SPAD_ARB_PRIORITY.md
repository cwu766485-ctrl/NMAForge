# A10 SPAD Arbiter Priority and Response-Invariant Follow-up — 2026-10-19

## Scope and source identity

- Repository: NMAForge, branch `main`.
- Tested source commit: `a1e87d9652ae84ed98ffcfcacc1a396064544f3b`.
- Product RTL, SPEC, and ABI were not changed. This increment extends the
  standalone arbiter testbench and its coverage target with control-priority,
  response-alignment, and simulation-assertion checks.
- Tool environment: Rocky Linux 8.10; Synopsys VCS/URG
  `V-2023.12-SP1_Full64`.

## Commands and results

Focused arbiter coverage:

```sh
make -C dv/subsystem/top_smoke/sim ai_spad_arb_cov \
  VCS='vcs -licwait 1' URG=urg \
  SPAD_ARB_COV_RUN=/tmp/nmaforge_a10_spad_arb_a1e87d9_cov
```

VCS and URG exited 0. The run passed the existing fairness and data-plane
fallback cases, and added these checks:

- Descriptor read wins over pending completion write and data-plane requests.
- Completion write is serviced before pending data-plane requests after the
  descriptor read retires.
- The descriptor read returns the expected owner and data; completion write
  does not generate a read response; the pending core request resumes after
  control traffic.
- A protection-error read response remains aligned to its request and does
  not spuriously report parity error.
- Two simulation assertions were attempted 10,097 times each, with 0 failures,
  0 incomplete attempts, and 0 unattempted assertions. The default-idle-client
  property had 3,358 real successes; the banked-response-metadata property had
  18 real successes.
- Both selected coverage properties matched: descriptor-selected=2 and
  completion-selected=1.

The run also retained the earlier scheduler checks: 30-cycle round-robin
fairness (10 grants per client, maximum wait 2 cycles); seeded 10,000-cycle
fairness (core/banked/DMA grants `3334/3334/3334`, maximum wait `2/2/2`); all
six request forms; CNM/DMA contention `6/6`; twelve legal directed data-plane
fallback cases.

Standalone `ai_spad_arbiter` raw URG coverage:

| Metric | Result |
| --- | ---: |
| Line | 100.00% |
| Condition | 86.89% |
| Branch | 100.00% |
| Toggle | 10.73% |
| URG score | 74.40% |

There are no uncovered DUT source lines or branches. Raw condition coverage
is not closed: the remaining tuples are correlated decode combinations (for
example, a selected client value paired with `accept_valid=0`, although client
selection and valid assertion occur in the same selection branch). The new
assertions check selected default-idle and registered-response invariants in
simulation; they are not a formal proof that every raw uncovered tuple is
unreachable. No waiver or synthetic coverage was added. Toggle coverage is
also low and is not a closure claim.

Exact-source top smoke:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke
```

VCS exited 0 and printed `TEST PASS` (random seed `1792378955`,
`AI_RANDOM_CASES=4`, `AI_SEED=12345`, `ACLK_PERIOD_NS=10.0`).

Seeded top regression:

```sh
make -C dv/subsystem/top_smoke/sim ai_run \
  SEED=20261019 AI_RANDOM_CASES=20 AI_SEED=12345
```

VCS exited 0 and printed `TEST PASS`; all 20 requested random cases completed.
The log is `/tmp/nmaforge_a10_spad_rr_top_a1e87d9/ai_run_20_seed20261019.log`.

## Verification status and limits

This closes the tested standalone arbiter line and branch bins and adds
simulation evidence for control-plane priority and response alignment. It does
not close raw condition coverage, prove the residual tuples unreachable, or
close V3/A10/V5. `ai_spad_arbiter` has no downstream `spad_ready` input, so the
tests do not model memory-response back-pressure or establish end-to-end
system fairness. Broader randomized DMA/SPAD/compute fault, abort, and reset
interactions remain separate requirements.
