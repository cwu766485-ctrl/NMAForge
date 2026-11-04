# Mixed FP Parity Response + Read Protection Formal Disposition — R295

**Disposition:** Formal evidence supports a candidate unreachable/N/A disposition for a same-edge Parity response plus *new accepted-read* Protection failure at the Mixed FP core interface. This candidate still needs independent SPEC/reviewer approval. It is not a coverage PASS or waiver; `REQ-CL-019` remains `PARTIAL` and `CL-DV-v1.0` remains **HOLD**. Product RTL and the frozen SPEC were not changed.

| Item | Evidence |
|---|---|
| Test ID / Run ID | `TC-CL-R295-FP-PARITY-READ-PROTECTION-FORMAL`; `R295-FP-PARITY-READ-PROTECTION-FORMAL-CLEAN-20261104` |
| Formal/test commit and tree | `36e089e61136a5c947e03147dbac293b03620d0f` / `8d3c7306ef3664653310d964c185fffea64f71a9` |
| Clean worktree | `/tmp/nmaforge_r295_fp_parity_protection_clean`, detached at the exact commit; clean before and after run |
| Product RTL baseline | `e1fcde57c70936f2eb2cd8ed9aea14303a61c717`; Mixed FP RTL SHA-256 `0c31adf0316370520e50271aaf65cdff64c95373dcbc1fdaba12a13392f016e1` |
| Tool | Synopsys VC Formal `V-2023.12-SP2` |
| Command | `make -C dv/block/compute/fp/formal read-protection-parity-disposition VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf OUT=/tmp/nmaforge_r295_fp_parity_protection_formal FORMAL_PROBE_TIMEOUT=120` |
| Formal log | `/tmp/nmaforge_r295_fp_parity_protection_formal/vc_formal.log`, SHA-256 `aedfb2c276e2ac9fee5a219b04a06380dcef1c0f6b00d719f4743568c4c19e1c` |
| Evidence archive | `/tmp/nmaforge_r295_fp_parity_protection_evidence.tar.gz`, SHA-256 `5a4894672b79bc4d6ce1ff8825aac7025ffbb0d2b52085f432de0388c6e4ee81` |

## Formal result

The harness instantiates the production Mixed FP core. Only reset sequencing is assumed. Abort, SPAD ready, response-valid, Parity, and Protection inputs remain unconstrained.

| Property | Result | Meaning |
|---|---|---|
| `ap_parity_response_excludes_read_protection_failure` | Proven, non-vacuous; safe depth 191 | A parity response suppresses a new read acceptance, so `read_protection_failure` cannot also be true on that sampled edge. |
| `cp_parity_response_with_outstanding_read_reachable` | Covered at depth 3 | A parity response is reachable while the core has a previously accepted read outstanding. |
| `cp_parity_response_and_protection_sideband_reachable` | Covered at depth 3 | Protection sideband may overlap that response, but the parity request gate prevents a new read handshake; the sideband is therefore not an accepted-read Protection failure. |

The target exits 0 with 1/1 selected assertions proven and non-vacuous, 2/2 selected covers reached, and `No setup issues found`. The log retains non-fatal `COM_OPT009`, `COM_OPT010`, `CLOCK_W_UNIT_ADJUST`, `LEARNED_DATA_NOT_FOUND`, and unused-worker notices. The elaborated DUT reports zero errors and warnings.

## Exploratory UVM attempt

R294 tried to require the same edge in a directed UVM probe. On seed `20261025`, the sampled-edge guard correctly found `spad_valid=0` when the parity response arrived. The run ended with one intentional `UVM_FATAL` guard, zero UVM warnings/errors, and no coverage credit. Seeds `20261026/20261027` were `NOT_RUN`; this was a reachability probe, not a product regression failure. Its compile/run logs and vector input are included in the archive above.

## Scope and sign-off handling

This evidence applies only to the same-edge combination of an outstanding-read Parity response and a *new* accepted-read Protection failure. Record that cross as candidate N/A until an independent review approves the disposition. Do not force an unaccepted Protection sideband into a passing test. A previously captured Protection error followed by a later Parity response, response drain, completion/error ownership, other fault phases, Reset, and the full Engine × Fault × Phase × Reset matrix remain separate obligations. `REQ-CL-019` remains `PARTIAL`; no requirement disposition is promoted.

## Reproduction

```sh
git worktree add --detach /tmp/nmaforge_r295_fp_parity_protection_clean \
  36e089e61136a5c947e03147dbac293b03620d0f
make -C dv/block/compute/fp/formal read-protection-parity-disposition \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_r295_fp_parity_protection_formal \
  FORMAL_PROBE_TIMEOUT=120
```
