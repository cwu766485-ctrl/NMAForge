# SFU in-flight parameter latch — R75 (2026-10-30)

## Result

**PASS, SFU block-core scope only.** Exact code/test SHA: `969992291732cf694d7de4bdfef2808d4f017d57`; replayed from detached clean worktree `/tmp/nmaforge_r75_clean_9699922`. The change adds one direct-core GELU parameter-latch test and makes the SFU random-regression target require its pass marker. It does not modify product RTL or the Compute Cluster SPEC. `REQ-CL-005` remains PARTIAL and Compute Cluster v1.0 remains HOLD.

## Test behavior

The test starts a 16-element GELU operation and changes every execution input after the core accepts `start`, while the first source request is active: opcode, A/B/beta addresses, beta/packing flags, destination, length, M/N, shift, epsilon, and watchdog limit. It then checks all 16 original destination words against fixed outputs from the independent Python `ai_a3_reference.gelu_q8_8` model and verifies that the changed destination remains at its per-word sentinel. This is a core-interface launch-snapshot check; it does not mutate a production CMDQ descriptor through the real Cluster top.

Golden reference source: `dv/block/compute/matrix/ref/ai_a3_reference.py`, SHA-256 `ff411b7b30753e812525de4cc83743a1051b72c93e0b70761564cb33ba9c1fe2`.

An exploratory real-top SFU descriptor rewrite was discarded: the host SPAD write coincided with an active SFU core request and the existing top correctly returned `SLVERR` for the conflicting host access. The Cluster test does not treat that response as acceptable or alter the arbiter/checker. A legal top-level SFU descriptor-mutation window remains unproven.

## Exact clean-SHA run

Tools: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

```sh
cd /tmp/nmaforge_r75_clean_9699922
make -C dv/block/compute/sfu/sim random-latency-regress \
  OUT_DIR=/tmp/nmaforge_r75_clean_run_9699922
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  -dir /tmp/nmaforge_r75_clean_run_9699922/coverage.vdb \
  -report /tmp/nmaforge_r75_clean_run_9699922/urg_report
```

| Evidence | Result | Artifact / SHA-256 |
|---|---|---|
| Three-seed SFU regression | PASS 3/3. Each seed passes 64 vector cases, 9 error cases, late fault, Abort/watchdog priority, reset recovery, FSM reset/Abort probes, RMSNorm gamma bypass, Tile-A packing, and the added 16-word in-flight parameter-latch Golden. Reads/responses match `1091/1091`; maximum response delay is 7 cycles; ready stalls are 521/536/530 for seeds `20261021/22/23`. | `/tmp/nmaforge_r75_clean_run_9699922/seed_{20261021,20261022,20261023}/run.log`; SHA-256 `5a361bf180b92636b7ccfdb082a02b2282a78cdc7c2d5662895d2412738cf16d`, `f925ce5260a4fecf69f12fe1f5d66798ea484271779f72bf717147649ce15081`, `43906a9956df0d6516c29878e177ccae7483028d0f2c595108046900b0bc730b` |
| Compile | PASS; no `Warning-`, `Error-`, or `[TFIPC]` diagnostics found. | `/tmp/nmaforge_r75_clean_run_9699922/compile.log`; SHA-256 `e8b039f03846703b81b635b7d0cc0eb5366ee92b2413c0d5ba18d967962a8d8c` |
| Merged block URG | Line `421/484 = 86.98%`; condition `188/221 = 85.07%`; FSM `139/139 = 100%`; branch `165/198 = 83.33%`. These are the SFU block DUT coverage metrics for this three-seed run, not functional testpoint closure or Cluster coverage. | `/tmp/nmaforge_r75_clean_run_9699922/urg_report/session.xml`; SHA-256 `f34806851cade11b9bb03cced49ff648b3e422f038076c989413d2533f4af993`; dashboard SHA-256 `20fe5ff2f5fd0750c6cff07881f794ec905ba44359269625d881da70bb07fb72` |

The compile/test SHA is clean and exact; generated VCS/URG databases and logs remain under `/tmp` and are not checked in.

## Disposition

R75 adds only a SFU block-core launch-snapshot testpoint. It is useful evidence that live command inputs are not consumed after launch at this interface, but it does not prove Cluster descriptor retention, shared-SPAD ownership, or seven-engine top behavior. Keep `REQ-CL-005` PARTIAL until legal top-level descriptor mutation evidence exists across the required engine/field scope. The overall RTM disposition remains 24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN; `CL-DV-v1.0` remains HOLD. External-fabric reset qualification and the legal fault/phase/engine crosses remain open.
