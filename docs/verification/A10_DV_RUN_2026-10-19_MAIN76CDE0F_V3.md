# A10 V3 exact-current-main DMA–SPAD–CNM and arbiter replay — 2026-10-19

## Source and environment

- Pushed `main` SHA: `76cde0f4f14912226f9eff2b5bcf86222d326ac9`.
- Detached clean worktree: `/tmp/nmaforge_clean_76cde0f_v3arb_20261019`.
- Artifacts: `/tmp/nmaforge_a10_main76cde0f_v3arb_20261019` and
  `/tmp/nmaforge_a10_main76cde0f_v3sub_20261019`.
- Rocky Linux 8.10; Synopsys VCS/URG `V-2023.12-SP1_Full64`.
- Worktree was clean before and after. No RTL, testbench, SPEC, or ABI changes
  were made for these replays.

## Reproduction

From `dv/subsystem/top_smoke/sim`:

```sh
make ai_spad_arb_run VCS='vcs -licwait 1'
make ai_spad_arb_cov VCS='vcs -licwait 1' URG=urg \
  SPAD_ARB_COV_RUN=/tmp/nmaforge_a10_main76cde0f_v3arb_20261019/coverage
make ai_smoke VCS='vcs -licwait 1'
```

From `dv/subsystem/dma_spad/sim`:

```sh
make subsystem_regress \
  COV_TAG=a10_exactmain_76cde0f \
  SEEDS='20263001 20263002 20263003 20263004 20263005 20263006 20263007 20263008 20263009 20263010' \
  URG_REPORT=/tmp/nmaforge_a10_main76cde0f_v3sub_20261019/urg_subsystem \
  VCS='vcs -licwait 1' URG=urg

make subsystem_rready_stress \
  RREADY_STRESS_TAG=a10_exactmain_76cde0f VCS='vcs -licwait 1' URG=urg
```

The shared-reset cutpoints used the same instrumented simulator with seeds
`20263011..20263014` and `+SPAD_PARITY_ABORT_RESET_DELAY=0..3`. From
`dv/subsystem/dma_spad/sim`:

```sh
out=/tmp/nmaforge_a10_main76cde0f_v3sub_20261019
for delay in 0 1 2 3; do
  seed=$((20263011 + delay))
  ./simv_dma_spad_uvm +UVM_TESTNAME=dma_spad_subsystem_test \
    +ntb_random_seed=$seed +UVM_VERBOSITY=UVM_MEDIUM \
    +SPAD_PARITY_ABORT_RESET_DELAY=$delay \
    -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir $out/reset_delay_$delay.vdb \
    -l $out/reset_delay_$delay.log
done
```

Each run required `[SPAD_PARITY_ABORT_RESET_PASS]`, `[TEST_DONE]`, and zero
UVM warning/error/fatal counts. The combined URG report merged the 10
subsystem, 3 RREADY, and 4 reset databases.

## Results

- Standalone scratchpad arbiter: the 10,000-cycle three-client campaign
  granted core/banked/DMA `3334/3334/3334`, with maximum wait
  `2/2/2` cycles. The 300-cycle seeded request-mode test granted
  `101/100/101`, also with max wait `2/2/2`. The 12 legal RR fallback forms,
  CNM/DMA contention, descriptor/completion priority, response alignment,
  protection-error alignment, and parity alignment all passed.
- Coverage-instrumented arbiter URG loaded the design and passed its two
  assertions and two cover properties with no failures, incomplete attempts,
  or no-attempts. Its standalone raw coverage was line 218/218 (100%),
  condition 53/61 (86.89%), branch 33/33 (100%), and toggle 281/2620 bits
  (10.73%). The eight remaining raw condition tuples have separate VC Formal
  disposition: the arbiter/formal/testbench sources are unchanged from the
  `d0ae9b5` formal run that proved 8/8 properties non-vacuously and reached
  4/4 covers. The raw URG percentage remains unmodified and unwaived.
- DMA–SPAD–CNM subsystem: all ten seeds `20263001..20263010` reached their
  pass and `TEST_DONE` markers; UVM warning/error/fatal counts were zero.
- DMA R-channel `RREADY` stress: the 16-, 64-, and 300-cycle profiles passed;
  each held the AXI R payload stable, drained the accepted reads, and checked
  all 32 SPAD words against the memory oracle.
- Shared reset after parity fault and DMA abort drain: delays 0/1/2/3 all
  passed, including same-cycle reset and recovery checks.
- Combined URG: `dma_rready_stall_cg` 4/4 variables and 3/3 crosses;
  `cnm_parity_abort_reset_cg` 4/4 variables and 2/2 crosses. Assertions:
  29 successes, 0 failures, 0 incomplete; the two no-attempt properties are
  UVM RAL `do_read`/`do_write` internals. The top `ai_smoke` ended in `TEST PASS`.

## DUT-only raw subsystem coverage and limits

These are module-specific results from the DMA–SPAD–CNM URG merge, not the
aggregate testbench score:

| DUT module | Line | Condition | Toggle | Branch |
|---|---:|---:|---:|---:|
| `ai_axi128_dma` | 81.06% | 60.23% | 37.69% | 70.09% |
| `ai_spad_arbiter` | 80.73% | 78.69% | 37.79% | 81.82% |
| `ai_accel_memory_fabric` | 100.00% | 58.49% | 39.49% | 100.00% |
| `ai_banked_cnm_core` | 93.52% | 73.91% | 46.57% | 74.19% |
| `ai_scratchpad` | 92.45% | 50.74% | 54.92% | 86.49% |

The standalone arbiter coverage database is deliberately separate, so its
100% line/branch scores do not replace the lower arbiter scores in the
subsystem-only merge. Remaining subsystem raw code bins still need review.
The scheduler test bounds admission wait when requests are continuously
eligible; `ai_spad_arbiter` has no downstream response-ready input, so these
results do not claim end-to-end fairness under a stalled SPAD response.
Broader randomized fault×abort×reset combinations, the wider DMA/compute
pairing matrix, full queue/completion lifecycle, V3 overall acceptance, and
A10/V5 remain open.
