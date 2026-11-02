# Mixed FP Read Protection + Abort Formal Disposition — R181

**Disposition:** Formal proof confirms that a *new accepted read* with Protection cannot coincide with Abort at the Mixed FP core interface. The corresponding coverage cross is a candidate unreachable/N/A disposition, pending SPEC and independent reviewer approval. This is not PASS coverage and does not close `REQ-CL-019`; `CL-DV-v1.0` remains **HOLD**. No product RTL or SPEC was changed.

## Frozen identity and run

| Item | Evidence |
|---|---|
| Run ID | `R181-FP-READ-PROTECTION-ABORT-FORMAL-CLEAN-20261102` |
| Formal/test commit | `183983d2bdb6d5447b2b3af3edf40754abc9e6d5` |
| Commit tree | `52e2cb47b3673f4eef34bd8ee0c0079b0fc7cedc` |
| Clean worktree | `/tmp/nmaforge_r181_fp_read_protection_abort_clean` (detached at the exact commit; clean before and after run) |
| Tool | Synopsys VC Formal `V-2023.12-SP2`, linux64 |
| Command | `make -C dv/block/compute/fp/formal read-protection-abort-disposition VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf OUT=/tmp/nmaforge_r181_fp_read_protection_abort_clean_out FORMAL_PROBE_TIMEOUT=120` |
| DUT source | `rtl/compute/fp/ai_mixed_precision_dot_fp32_core.v`, SHA-256 `0c31adf0316370520e50271aaf65cdff64c95373dcbc1fdaba12a13392f016e1` |
| Full log | `/tmp/nmaforge_r181_fp_read_protection_abort_clean_out/vc_formal.log`, SHA-256 `e5df6a8baffe3d90e16b60c24781fcf79037e353ebb7d76512b67cb8169d11d3` |
| Evidence archive | `/tmp/nmaforge_r181_fp_read_protection_abort_evidence.tar.gz`, SHA-256 `e277c90d5810d5c3da7a57e540cf89bd661695e7661a214ace63dd5d0bf3627b` |

The formal harness instantiates the production Mixed FP core with a legal aligned one-element BF16 descriptor. It assumes only the reset sequence. `start`, `abort`, `spad_ready`, `spad_rsp_valid`, parity error, and Protection error remain unconstrained; no accepted-read or fault assumption is added to force the exclusion.

## Formal properties

| Property | Result | Meaning |
|---|---|---|
| `ap_abort_blocks_read_accept` | Proven, non-vacuous | While busy in `ST_RUN`, Abort implies no accepted SPAD read (`read_fire`). |
| `ap_abort_blocks_read_protection_failure` | Proven, non-vacuous | While busy in `ST_RUN`, simultaneous Abort, ready, and Protection cannot produce `read_protection_failure`. |
| `cp_abort_protection_attempt_reachable` | Covered at depth 2 | Active-operation Abort and Protection inputs can coincide; the proof is not excluding the input combination itself. |
| `cp_read_protection_failure_reachable` | Covered at depth 2 | Without Abort, an accepted read Protection failure is reachable in the same harness. |

VC Formal reports `2/2` assertions proven, `2/2` non-vacuous, `2/2` covers reached, and `No setup issues found`. The run completed with exit status 0 in a clean worktree.

## Warning and scope disposition

The log includes non-fatal `COM_OPT009` and `COM_OPT010` (no formal `search_path`/`link_library` configured), `CLOCK_W_UNIT_ADJUST`, `LEARNED_DATA_NOT_FOUND` on the first proof pass, and unused-worker notices. The elaborated DUT reports zero errors and zero warnings; the formal setup gate found no setup issue. These notices are retained in the archived full log.

This proves only the core-level structural exclusion for a *new accepted read* on the same sampling edge as Abort. It does not prove the treatment of an already accepted read's later response, external fabric behavior, owner/completion error ABI, broad Engine × Fault × Phase × Reset coverage, or other engines. The exploratory R177 UVM fatal remains a non-PASS and receives no coverage credit. A formal result supports the reachability disposition but does not itself amend the SPEC or authorize a waiver. Keep `REQ-CL-019` PARTIAL until that review and the remaining integration obligations are complete.

## Reproduction

```sh
git worktree add --detach /tmp/nmaforge_r181_fp_read_protection_abort_clean 183983d2bdb6d5447b2b3af3edf40754abc9e6d5
make -C dv/block/compute/fp/formal read-protection-abort-disposition \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_r181_fp_read_protection_abort_clean_out \
  FORMAL_PROBE_TIMEOUT=120
```
