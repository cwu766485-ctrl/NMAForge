# Compute Cluster Checker Mutation Replay — R66

Date: 2026-10-30  
Run ID: `R66-CLUSTER-MUTATION-28-CLEAN-2AB887A`  
Exact code/test SHA: `2ab887ae1b4846512e7673e3d5ea4ce0061c0d0a`  
Worktree: clean detached `/tmp/nmaforge_protection_phases_r65_clean`  
Tools: Synopsys VCS `V-2023.12-SP1_Full64`, UVM 1.2; VCS coverage enabled.

## Result

The exact R65 source recompiles and all 28 expected checker-sensitivity mutations are caught. The Makefile campaign exits 0 only after it sees both the injected marker and the expected checker marker for each mutation, plus the expected UVM error from the deliberate corruption.

| Mutation family | Cases | Expected checker | Result |
|---|---:|---|---|
| Address | 1 | `matrix_request_address` | PASS |
| Data | 1 | `memory_data` | PASS |
| Response owner | 1 | `response_owner_route` | PASS |
| WSTRB | 1 | `matrix_write_mask` | PASS |
| Completion error code | 1 | `completion_error_code` | PASS |
| Write after terminal error | 1 | `write_after_error_prefix` | PASS |
| Stale response epoch | 1 | `response_epoch` | PASS |
| Done / missing Done / duplicate Done | 7 each | `engine_done_lifecycle` | PASS 21/21 |
| **Total** | **28** | Checker-specific expected catch | **PASS 28/28** |

This is passive monitor/scoreboard sensitivity: it deliberately corrupts observed data or lifecycle observations to show that the named checker reports the expected failure. It is not synthesized RTL fault injection, a DUT mutation score, or functional coverage closure. The VCS compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Mutation run logs intentionally contain the checker UVM errors required by each test; the enclosing Make target treats those expected catches as PASS.

## Reproduction

From the exact detached clean worktree:

```sh
cd dv/uvm/sim
make uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_protection_phases_r65_mutations \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_protection_phases_r65_mutations/campaign
```

Exit status: `0`. Artifacts: `/tmp/nmaforge_protection_phases_r65_mutations/`. Compile/elaboration completes for the checked-in UVM source and the target prints `COMPUTE_CLUSTER_MUTATION_CAMPAIGN_PASS` after the 28 expected catches.

## Artifact hashes

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `f3e43614c63848912096df4c68c25eea765c4476ef73187801ca25a3088ac2c6` |
| `campaign/address.log` | `f19d058dd1a9a358057f1f827941bd5681b0fad07e8eea33bd2aeb9ca14ac129` |
| `campaign/data.log` | `19382016786bc1a62ae77e4d953a976aeae466e23342a0262d1c6916ddca117b` |
| `campaign/owner.log` | `b34eadef259028fe6fe85f51f9841fa962989bb093ac3ec296a97af4188f1b1b` |
| `campaign/wstrb.log` | `fecf35b86b47d5257c6181ce98f71428fa7f189cd2a14456097248c8de8646e6` |
| `campaign/completion_error_code.log` | `3b595f4987087ab1da7a1e8abfaf97a0204104f41af75dd11ec1307ee878edb4` |
| `campaign/write_after_error.log` | `197e2bd39653720c441f02a821409ecf0a243844342a7e432a6f8553954b8f86` |
| `campaign/response_epoch.log` | `3f43c5cf857f0c48c24fa9e1179ca3c7eae901f9b1f11a0265a708d5695eccd8` |
| `campaign/done_engine_0.log` | `f9496d474a614100794fe5c79db44e1e2d34655f32e96afb5a5f443ff76b7b71` |
| `campaign/done_engine_1.log` | `08eb65b27719fd1ca3b987b2b98b9ddbc5a5a90e39621363321fcf2ab3eb6801` |
| `campaign/done_engine_2.log` | `5dbc5da4495291b6d1b67ac7507e6a6c076d28d800c0f7f227e3322b31091b90` |
| `campaign/done_engine_3.log` | `5df1204b43cf02a8531b8fc301939c258339b8f8e8c90b68e12dc3394d4a75f6` |
| `campaign/done_engine_4.log` | `0b7656a0a486fe4c9fc2d6e8b52f58f013e21bf64d7a34a2b1880615424c615a` |
| `campaign/done_engine_5.log` | `ed68136c191d8c1a4d9e3e17fbd7cee4a5c920dbc817cd44b962e85718c65dbe` |
| `campaign/done_engine_6.log` | `0e2408a516a82e20cc945b62a434d0db58e72fa9f520e21800303b2f35bfa34d` |
| `campaign/missing_done_engine_0.log` | `b81c95389f82a3988b41c928e9bec1ed2d3f92cd04bafa2b4f2f87c9d77abb59` |
| `campaign/missing_done_engine_1.log` | `c1a302dab1e6922af88df4743b395c777bdbe0cfb55a7977be8a368782527acc` |
| `campaign/missing_done_engine_2.log` | `c59e08adc9e1a1ae824cdfdf6551b488af1fee5845df7bab0bd5ddc67a8faa36` |
| `campaign/missing_done_engine_3.log` | `05b848db876cabd40f33c3ea2af24e31f5629351dd1a59d1c2a37c8bee07d097` |
| `campaign/missing_done_engine_4.log` | `194358d26ba69bec62affc211ca77480805fb6823a856bcbc0851edfc908777c` |
| `campaign/missing_done_engine_5.log` | `567cd84e464527fbe611c8f85bb3d869f4885d687de38e4a45b6f012fd98df82` |
| `campaign/missing_done_engine_6.log` | `85b9c280ab6abac0ceed78fe0a7004bf229b98b8acd6938e44c2c66277e5aed1` |
| `campaign/duplicate_done_engine_0.log` | `c6f953d4f01c7cd294cfd8a0271427acbafa7503be3723a22d832c3a9a8eb001` |
| `campaign/duplicate_done_engine_1.log` | `11629539b98042c8400d8894df41bd2984f5f8b723f5aecafc0e482fef43a1db` |
| `campaign/duplicate_done_engine_2.log` | `645d079c1994e294ed2d3f104738d80957c8eff34c52e19c6b3bd24d7b98474d` |
| `campaign/duplicate_done_engine_3.log` | `875cb0d68841ef97b3b2c33c1d1675581ef9b61028c778605f694127740e9d2a` |
| `campaign/duplicate_done_engine_4.log` | `839b015b769f43ffa718a96f3124437687dfe1e5eafa7b1da021074f723e1dc6` |
| `campaign/duplicate_done_engine_5.log` | `30c7c30870061cede67da095064e4ab75d0e3e6330cf21a85dedb86700fae436` |
| `campaign/duplicate_done_engine_6.log` | `148caf1bb50750a9967a68a25152e7671a9f52ee0df0415e06ddba0a359e91b0` |

## Sign-off impact

R66 reconfirms checker sensitivity for these 28 named corruption classes on the exact R65 source/test SHA. It does not alter the 38 requirement dispositions (24 PASS-SCOPED / 14 PARTIAL) or close the legal Engine × Fault × Phase × Reset cross. `OPEN-CL-003` and the Compute Cluster v1.0 **HOLD** disposition remain.
