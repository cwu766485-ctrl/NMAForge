# A10 CP randomized completion-payload wrap replay

## Scope and source identity

- Tested CP UVM revision: `eae384812950a867e4ef88611e28d026c8ffa11f`.
- Parent tree: pushed `main` commit `2705baddfb766d547f93172754bea4e6471b9cf4`.
- Changes are limited to the CP UVM package and its Makefile gates; no product
  RTL, SPEC, register ABI, queue depth, or command semantics changed.
- Environment: Rocky Linux 8.10 / WSL2, VCS and URG `V-2023.12-SP1`.
- Retained simulator, logs, VDBs, and URG reports are outside Git under
  `/tmp/nmaforge_cp_high_payload_a10_20261019_retry1/`,
  `/tmp/nmaforge_cp_payload_fullrun_20261019/`, and
  `/tmp/nmaforge_cp_payload_matched_cov_a10_20261019/`.

## Four-record scenario

`CP_HIGH_PAYLOAD` now submits four full-width randomized completion payloads in
one simulation. Each record carries independent 32-bit result, cycle, and
element values; the test consumes each completion before submitting the next
command. Both CMDQ and CPLQ advance through slots 0–3 and wrap to 0. The
scoreboard checks the event fields, completion-start payload, all four
completion words, word addresses, and exactly-once launch/event/completion
counts. This exercises the existing lifecycle; it does not add product
functionality.

Focused and full-suite commands:

```sh
make -C dv/block/command_processor/uvm compile \
  OUT=/tmp/nmaforge_cp_high_payload_a10_20261019_retry1 VCS='vcs -licwait 1'
cd /tmp/nmaforge_cp_high_payload_a10_20261019_retry1
./simv +UVM_TESTNAME=ai_cp_test +ntb_random_seed=20261019 \
  +CP_ONLY_CASE=31 -l high_payload.log

make -C dv/block/command_processor/uvm run \
  OUT=/tmp/nmaforge_cp_payload_fullrun_20261019 \
  SEED=20261019 VCS='vcs -licwait 1'
```

Both passed. The focused log records four slot markers and
`exactly_once launches=4 events=4 completions=4`; the full suite passed all
32/32 scenario markers and UVM severity was warning/error/fatal=`0/0/0`.

## Matched 200-seed randomized coverage

```sh
make -C dv/block/command_processor/uvm cov-random-regress \
  OUT=/tmp/nmaforge_cp_payload_matched_cov_a10_20261019 \
  COV_OUT=/tmp/nmaforge_cp_payload_matched_cov_a10_20261019/coverage \
  RANDOM_SEED_START=20262021 RANDOM_SEED_COUNT=200 \
  VCS='vcs -licwait 1' URG=urg
make -C dv/subsystem/top_smoke/sim ai_smoke
```

The Makefile gates and URG merge passed for all 200 seeds. Each seed exercised
all 32 CP scenarios with UVM warning/error/fatal=`0/0/0`. The high-payload
scenario produced 800 completion records; result, cycles, and elements each
had 800 distinct 32-bit values. Merged `cp_cg` was 63/63 variables and 34/34
crosses; the payload bin was 1/1, reset-word bins 4/4, kind×delay×reset cross
24/24, and abort timing 7/7. Assertions: 13 successes, 0 failures, 0
incomplete; two UVM RAL internal `do_read`/`do_write` properties had no
attempts. Covers were 4/4. Top-level `ai_smoke` printed `TEST PASS`.

## Matched toggle-coverage observation

Using the same 200-seed range (`20262021`–`20262220`) as the prior one-record
payload campaign at `cd50605`, VCS RTL toggle coverage changed as follows:

| DUT module | One payload / seed | Four payloads / seed | Change |
|---|---:|---:|---:|
| `ai_command_processor` | 16.10% | 20.77% | +4.67 percentage points |
| `ai_completion_writer` | 50.43% | 65.66% | +15.23 percentage points |

This is a matched-seed toggle-coverage/stimulus result only. It is not a power,
SAIF, PPA, or physical-design result. Static and reserved bits remain
uncovered by design. The CP condition report remains 237/252 (94.05%); its 15
raw uncovered outcomes retain their existing formal/assume-guarantee
dispositions and are not waived. This closes only the randomized
payload-forwarding/queue-wrap slice, not CP V2, V5, or A10.
