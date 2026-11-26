# NMAForge-V1.2 Round 25 — DeiT Attention AV Closure

## Disposition

**AV operand/dependency closure: PASS for the first 16-query block on all three heads. Full Encoder Layer 0: NOT RUN.** The failure did not demonstrate a Matrix Reader RTL defect. The Round 24 image had a poisoned V operand region; after that data was reconstructed from real Product Top QKV readback, a separate missing producer/consumer dependency allowed AV to start before Softmax probability packing retired. Round 25 fixes the workload dependency in the descriptor stream; Product RTL is unchanged.

This is not a complete 197-query DeiT Encoder Layer, nor a classification result.

## Baseline and artifacts

| Item | Value |
|---|---|
| Research branch/base | `research/nmaforge-v1.2-round25-deit` / `ba646a7b2b4791bc365cf8ef42ec011a0552fcbb` |
| SPAD profile | Four banks × 16,384 words = 256 KiB |
| Workload | 16 query rows × 197 valid keys × head dimension 64, one head per Top run |
| Descriptors | 245 per head |
| VCS | `V-2023.12-SP1_Full64` |
| Compile log SHA-256 | `672730b171fd063e7b507807b5f82442066807cfe67ef3b4b2f4bc3c07ba24f9` |
| Product QKV readback SHA-256 | `e0020f46eeec6eed4281044bfca52d5f607954b648987086f62148eb9f2027cc` |
| QKV independent projection Golden SHA-256 | `0e80b814562772cee306f2b10a368e97920e035aa78e5524c6a432b0cb0655ce` |

Archived VCS logs, descriptor images, memory/Gol­den images, manifests, Product readbacks, failure reproductions and the audit are in `benchmark/deit/round25/av_rootcause/`. The testbench change only adds optional trace output selected with `+AI_DEIT_AV_TRACE`; no Product RTL or ABI changed.

## Root-cause evidence

1. **Original Round 24 operand image:** all 4,096 words in the V_B region at `0x24000` were the poison value `0xA55AA55A`. The original failure was therefore not sufficient evidence against the Matrix Reader.
2. **Rebuilt V from actual Product QKV:** the archived Product QKV readback has 9,984 valid V projection words and zero mismatches against the projection Golden. Reconstructing the physical Matrix-B panels from that readback produced 3,328 consumed words with zero mismatch against the generated panel payload.
3. **First rerun still failed:** tracing showed AV requests before the final Softmax probability-pack write retired. In the no-fence run, the reader saw poison on the probability operand while the pack was incomplete; the first output mismatch was `addr=0x00028040 expected=0x000002be actual=0x00001465`. The separate earlier Round 24 observation was `addr=0x00028000 expected=0x0000024c actual=0x000002ce`.
4. **Dependency correction:** the generator uses descriptor event bit 15. The first QK descriptor clears stale event state; the probability pack signals only after successful retirement; all four AV N-panel descriptors wait on that sticky event. This is a producer/consumer ordering change in workload generation, not an RTL timing workaround.
5. **Physical reader audit:** each head’s event-ordered run has 416 AV response records. Every returned 128-bit response equals the four live bank words and the reconstructed expected image (initial memory overlaid with the 832 runtime probability-pack words): 1,664 bank words and 6,656 byte lanes per head, zero mismatches. All 3,328 packed V words consumed per head match the Product QKV-derived expected panels.
6. **Ordering:** for all three heads, the last probability-pack write is trace line 868 and the first AV read request is line 870. Thus AV begins after the producer’s final write in these runs.

The complete machine-readable result is `benchmark/deit/round25/av_rootcause/operand_audit.json` (`OPERAND_EVENT_AND_PHYSICAL_READ_AUDIT_PASS`).

## Product Top results

The three head runs each check 8,512 Golden words across the QK/Softmax/packed-probability/AV workload and report 605,184 useful MACs. Input Q/K/V values were derived from archived Product Top QKV readback; host processing only rearranged those readback values into the existing Matrix-A/Matrix-B physical layouts. Host did not calculate or write QK scores, Softmax probabilities, or AV results.

| Head | CMDQ cycles | End-to-end cycles* | Useful MAC/cycle | SFU busy | Matrix MAC cycles | SPAD read/write bytes | Golden |
|---:|---:|---:|---:|---:|---:|---:|---|
| 0 | 172,873 | 431,304 | 3.5007 | 136,350 | 4,160 | 304,768 / 34,048 | 8,512/8,512 PASS |
| 1 | 176,052 | 434,483 | 3.4375 | 139,529 | 4,160 | 304,768 / 34,048 | 8,512/8,512 PASS |
| 2 | 164,488 | 422,919 | 3.6792 | 127,965 | 4,160 | 304,768 / 34,048 | 8,512/8,512 PASS |

Each run reports 56.83% useful array utilization. `end_to_end_cycles` includes the testbench preload interval (258,431 AXI cycles). `preloaded_spad_bytes=172,288` is the fixture image; 83,968 bytes of it are test-only poison/sentinel initialization and must not be represented as production model traffic. No late DMA traffic was observed. Allocation high-water is 181,248 bytes, below the 262,144-byte profile; descriptor and completion bases are 221,184 and 253,952.

The three runs are separate Top invocations, one per head, not one invocation containing a complete model. Aggregate evidence is 735 descriptors, 25,536 Golden words and 1,815,552 useful MACs across the three head workloads.

\* The testbench’s label says `end_to_end_cycles`, but this is workload preload plus command execution; it is not host image preprocessing, a complete DeiT inference, or a production DMA session.

## Gate status

| Gate | Status | Evidence / limitation |
|---|---|---|
| B0 Physical operands | PASS | Product QKV readback, V panel packing and every AV physical read lane match; no poison reaches the event-ordered AV inputs. |
| B1 Directed AV closure | PASS for real query-block path; standalone 4×4 micro-case NOT RUN | All three 16Q × 197K head paths use Product QK, opcode `0x32` non-causal Softmax of 197 valid keys, runtime probability packing and Product AV; all outputs are exact. A separate 4×4-only matrix micro-test was not run. |
| B2 Full Encoder Layer 0 | NOT RUN | Remaining 181 query rows, output projection, residuals, LN2, FFN/GELU and final residual have not been connected as one Product Top path. |
| B3 Twelve-layer/classifier readiness | NOT RUN | Depends on a passing full Encoder Layer 0. |

### Reproduction

From the repository root, with VCS `V-2023.12-SP1_Full64` licensed and Python 3.12 plus NumPy available:

```bash
PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
VCS=vcs \
bash benchmark/deit/round25/replay_attention_qblock.sh /tmp/nmaforge_round25_deit_replay
```

The script compiles the 256 KiB Product Top once and runs three heads using the archived Product QKV readback and projection Golden. To rerun only the physical-read/root-cause audit over archived raw logs:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python \
  benchmark/deit/round25/av_rootcause/audit_av_operands.py
```

The audit exited 0. The VCS compile transcript has a `Warning-[LOOP-REROLL-ENABLED]` informational warning; it has no compile error. The existing `make ai_smoke` focused regression also passed with exit code 0 on this testbench revision. No claim of broad DV closure is made.
