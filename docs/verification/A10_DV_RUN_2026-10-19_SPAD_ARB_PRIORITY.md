# A10 SPAD Arbiter Priority and Response-Invariant Follow-up — 2026-10-19

## Scope and source identity

- Repository: NMAForge, branch `main`.
- Priority/response simulation source commit:
  `a1e87d9652ae84ed98ffcfcacc1a396064544f3b`.
- Formal-harness and top-regression source commit:
  `d0ae9b5907ae7465a4462340511e868e8b1f1218`; no product RTL changed between
  these commits.
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

## Formal disposition of raw condition tuples

An independent RTL-only VC Formal harness was added under
`dv/block/spad_arbiter/formal/`. It instantiates the production arbiter, leaves
all request-valid and write controls unconstrained, and proves local decode and
registered-response invariants. The only setup is deterministic reset
initialization; no request-protocol assumptions are applied.

Exact committed-source command:

```sh
make -C dv/block/spad_arbiter/formal decode-invariants \
  OUT=/tmp/nmaforge_spad_arbiter_decode_formal_d0ae9b5 \
  VCF=vcf TIMEOUT=120
```

VC Formal `V-2023.12-SP2` exited 0. Setup reported `No setup issues found`;
the acceptance gate passed with 8/8 assertions proven, all 8 non-vacuous, and
4/4 covers reached. The assertions establish:

- Idle decode selects the documented default DMA client; descriptor,
  completion, core, and banked client tags cannot appear without an accepted
  request.
- A banked/CNM selection always creates response metadata, including through
  the registered response stage.
- Line metadata and response qualifiers cannot be asserted without an accepted
  request.

These invariants formally disposition the eight `Not Covered` raw condition
tuples in the exact `a1e87d9` URG report: impossible `accept_valid=0` paired
with descriptor/completion/core/banked client tags; invalid delayed banked
metadata; invalid line metadata for core/DMA; and the duplicate banked/CNM
ready decode. The raw URG condition percentage remains 86.89%—formal results
do not synthesize coverage hits or waivers. This is a proof of the stated
local invariants, not of end-to-end memory fairness, downstream response
back-pressure, or all V3 behavior.

After committing the formal harness at `d0ae9b5`, both top-level checks were
rerun on that source:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run \
  SEED=20261019 AI_RANDOM_CASES=20 AI_SEED=12345
```

Both exited 0 and printed `TEST PASS`; the seeded run requested 20 cases.
Archived logs are under `/tmp/nmaforge_spad_arbiter_top_d0ae9b5/`.

## Verification status and limits

This closes the tested standalone arbiter line and branch bins and adds
simulation evidence for control-plane priority/response alignment plus a
formal disposition of all eight observed raw condition tuples. Raw condition
coverage remains 86.89% and toggle coverage is 10.73%; neither is presented
as 100% raw coverage. `ai_spad_arbiter` has no downstream `spad_ready` input,
so the tests do not model memory-response back-pressure or establish
end-to-end system fairness. Broader randomized DMA/SPAD/compute fault, abort,
and reset interactions remain separate requirements; overall V3/A10/V5 remain
open.
