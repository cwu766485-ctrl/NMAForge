# Compute Cluster Conv accepted-write Abort prefix — R85

**Date:** 2026-10-30  
**Exact clean code/test SHA:** `5a35d60d20ee6fc6622e46f92d05fc1ef00dd14d`  
**Product RTL/SPEC baseline:** `9d4e9abdba1f745644a485960620fa6bbc4979db`; R85 changes only the UVM sequence and regression gate.  
**Run ID:** `CLUSTER-CONV-ABORT-WRITE-PREFIX-3S-5A35D60`  
**Tool:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Testpoint

A real top-level Conv 3×3 task is aborted immediately after its first accepted output write. The checker verifies that accepted memory contains the correct contiguous one-word Golden prefix, all three unaccepted output words retain their sentinels, all accepted source/kernel reads drain, and the task completes with `ERR_ABORT`. The regression gate requires `CLUSTER_CONV_ABORT_WRITE_PREFIX_PASS` for each configured seed.

This is one legal Conv prefix length and Abort timing point. It does not cover the other three prefix lengths, every Conv fault phase, other engines' accepted-write prefixes, simultaneous fault/Abort combinations, or the full Engine × Fault × Phase × Reset matrix.

## Exact clean replay

Fresh detached worktree: `/tmp/nmaforge_r85_remote_5a35d60`, HEAD `5a35d60d20ee6fc6622e46f92d05fc1ef00dd14d`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r85_remote_5a35d60_uvm
make ai_smoke
```

The UVM command ran from the detached worktree root; Top Smoke ran from `dv/subsystem/top_smoke/sim`. Both exited 0. Seeds `20261025`, `20261026`, and `20261027` each reported:

- `accepted_output_prefix=1/4`, `read_drain=21/21`, completion `ERR_ABORT`;
- independent memory scoreboard: 14,943 writes and 17,304 checked words, zero mismatch/unknown/stale responses;
- UVM warning/error/fatal `0/0/0`;
- focused applicable compute group `31/31`; the new Conv prefix marker hit once per seed.

The merged URG assertions report 17/22 properties with real successes, zero failures/incomplete and five uncovered. Two UVM RAL properties have no attempts; top-level AR/AW payload and 4-KiB assertions are uncovered in this compute-focused run. The W stall-to-accept cover matches in all three seeds; AR/AW stall-to-accept covers remain unhit. This result is not full assertion closure.

Top Smoke prints `TEST PASS`. Its compile retains the existing fixture warning `[LOOP-REROLL-ENABLED]` at `ai_transformer_workload.svh:9`; the R85 UVM compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostic.

## Evidence hashes

Generated simulator outputs are retained locally under `/tmp` and are not committed.

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `66f3113d8435695d4a0238689f315386a8307a69465d45b69572c3e4386161b3` |
| Seed 20261025 run log | `8b5cc1a2ff51ff239dfe867caa06c254cc149cd7568a83842e3e588cfd1719d6` |
| Seed 20261026 run log | `d030ea7c414850e80731a59944360aac861b972eab152b68377f8947d28755e8` |
| Seed 20261027 run log | `bc2fd64ebddc413f6bde0de5f7d21279e71129a11306157888044dcf32eb4f07` |
| URG merge log | `159a04865b4c6cb7acc75cd2772dc275e6765a81bfd928e90665159deedac9c1` |
| URG assertion report | `78bbff6cfad2c09135bea95ad576e067dfb15a725095ebb7500a910f4b5bfe0c` |
| URG dashboard | `233e2407097ed33faed1fe5e333f38e9d10c0e8c6ae3b30fd589cf5ce4bef419` |
| Top Smoke compile log | `146321210128e8c10f0564deb9ed9de4c3550df4a0e1eaee6466e297100d914f` |
| Top Smoke run log | `7dbe2bd778935c667c429255d63dc5c7b55dff89951319e55585600a55ba6fdc` |

## Disposition

R85 adds a reproducible real-top Conv accepted-write-prefix point without changing product RTL, SPEC, or any requirement disposition. `REQ-CL-017` and `REQ-CL-019` remain PARTIAL because the other legal prefix lengths and broad fault/phase/Abort/Reset combinations are not yet closed. RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains HOLD.
