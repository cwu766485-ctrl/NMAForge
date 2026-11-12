# NMAForge frontend closeout candidate

**Release disposition: HOLD / PARTIAL.** Gate2 integration candidate is prepared for review; Gate3 is not globally closed; Gate4 is ASIC_MAPPING_BLOCKED; Gate5 publishes reproducible scoped results. No automatic product merge, architecture addition or physical signoff is performed.

Tested production RTL: `fc60f95d72c0cfb7dfa9df895a30a701c842d21e` on `candidate/frontend-closeout`, remote product base `c93ea144713d5fafe2e8a5509029927cd6859e75`. Later report commits retain these RTL hashes in [manifest](benchmark/verification/frontend_closeout/manifest.json). Default128KiB/four banks/256INT8MAC; optional512KiB elaboration only. VCS V-2023.12-SP1, Python3.12.13, Verilator5.052; 4ns functional clock, registered two-cycle behavioral SPAD. No achieved-Fmax claim.

## Integration and verification

Retained modifications: protected Phase4 fused ping-pong writeback, explicit offline bounded Mapper with fallback, existing output-DMA scheduling, DMA late-source-fault B-response drain fix. A small combinational Mux cleanup removes10 LATCH/3 UNOPTFLAT diagnostics. No added SRAM port, engine, SFU pipeline or ABI change. [Integration audit](docs/verification/frontend_closeout/INTEGRATION_REVIEW.md) records ancestry and software ownership limitations. PR#5 and all original worktrees remain intact.

**DESIGN VERIFIED — scoped only:** directed DMA12 cases, Matrix3 seed directed/random/opcode-fault suites, original seed20261116 non-vacuous capture stall, Control9 UVM, DMA19 UVM, DMA/SPAD3 seeds, Top smoke and20 random cases, immutable CNN/H16/H32 Golden. Optional512KiB20-case smoke passes. Detailed [RTM](docs/verification/frontend_closeout/RTM.csv) distinguishes scope and open requirements.

**ARCHITECTURE FROZEN: NOT DECLARED. FRONTEND READY: NOT DECLARED.** Seven-engine default128KiB UVM fails on legacy512KiB fixture address0x7d000; it requires reviewed compact allocation, protection-region and collision checks. No address masking or weakened response assertion is used to hide failure. Width/sign, illegal-state, reset-release, optional dual-clock and fault/concurrency crossings remain open. [Static review](docs/verification/frontend_closeout/STATIC_REVIEW.md) and per-message disposition retain all warnings. Passing smoke is not signoff.

## Measured performance

All entries below are new runs on the fixed RTL, with independent Golden PASS.

| Boundary/workload | Result |
|---|---:|
| Trained CNN useful MAC |570164|
| CNN CMDQ |11376 cycles|
| CNN useful MAC/CMDQ cycle |50.1199|
| CNN compute SPAD read/write |64064/16640 B|
| CNN hardware delivery via AXI-Lite |19507 cycles|
| CNN hardware delivery via DMA |15437 cycles|
| Delivery improvement |20.86%|
| Same test with AXI gaps: Lite/DMA |20919/17267 cycles (17.46%)|
| H16 persistent8 tokens |65771 cycles;8221.375/token|
| H32 persistent8 tokens |350155 cycles;43769.375/token|
| H16 compute SPAD read/write |72448/42112 B|
| H32 compute SPAD read/write |546816/227840 B|
| H32 SFU busy |273699 cycles|

CNN input preload10944B takes3019 cycles in the normal model. Output3328B: Lite4992cycles vs DMA922cycles (gapped1340cycles). Delivery window includes preload/configuration, CMDQ setup/run, completion consumption, output store setup/status and consumer-visible output. CPU model loading, software packing and application preprocessing/postprocessing are not hardware cycles. Host packing nanoseconds are logged separately and never added to simulated cycles. Poison/Golden checking lies outside timing. Therefore this is a hardware delivery interval, not an implemented whole-application latency.

[Shape/system A/B CSV](benchmark/verification/frontend_closeout/system.csv) includes32 M1/M4/M8/M16×K16/32/64/128 mapper cases plus2 CNN output cases; [gapped CSV](benchmark/verification/frontend_closeout/system-bp.csv) repeats with actual AXI gaps. M8K128 normal delivery1845→1642 (11.00%); M16K1282729→2142 (21.51%). M1/M4 retain legacy path; opcode selection does not imply dynamic Host/permission equivalence. Tensor numerical quality is the existing fixed trained-fixture Golden; this run does not retrain or establish new held-out accuracy.

Engine summaries and traffic are in [Transformer CSV](benchmark/verification/frontend_closeout/transformer.csv). Matrix utilization must use accepted active MAC workload and full CMDQ window; the historical `array_utilization_pct` debug field uses an internal boundary and must not be interpreted as whole-model256MAC efficiency. H32 useful MAC marker is zero/unpopulated, so no H32 MAC utilization is claimed.

TinyNPU reference remains `8216c22b762011aa20c05fc2768423fd12dda59d`. No matched-endpoint TinyNPU replay is made in this closeout. Raw-array/common-adapter historical results do not establish native-controller or complete CNN/Transformer system speedup; unsupported graph operations and different SRAM/port/host contracts prevent such a claim.

## ASIC boundary

**ASIC_MAPPING_BLOCKED. PHYSICAL SIGNOFF NOT DONE.** [Macro audit](docs/verification/frontend_closeout/ASIC_READINESS.md) records4×8192×32 dual-port data banks plus32768parity bits, masks/collisions/two-cycle response requirements and missing compatible legal macro/library/adapter inputs. DC is installed but no mapped128KiB netlist/area/timing/activity-power report exists. Old512KiB evidence is not substituted. DFT, floorplan, CTS, routing, MMMC STA, IR/EM remain undone.

## Reproduction

Use a clean isolated checkout at the tested RTL SHA, with installed VCS and Python3.12+numpy:

```bash
CLOSEOUT_OUT=/tmp/nmaforge-closeout-replay CLOSEOUT_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python bash tools/verification/frontend_closeout/run.sh
cd dv/block/control/sim
make uvm_regress
cd ../../dma/sim
make uvm_regress
cd ../../../subsystem/dma_spad/sim
make subsystem_regress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
cd ../../../uvm/sim
make uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge-closeout-cluster
```

The last target currently FAILS as documented. The consolidated replay script is added after the tested RTL checkpoint; use the final report commit for that convenience wrapper, with identical manifest RTL hashes. SpyGlass: `PATH=<installation>/SPYGLASS_HOME/bin:$PATH bash dv/spyglass/run_spyglass_a8.sh {lint|cdc|rdc}`; public profile uses depth256 and cannot replace full-capacity ASIC mapping. Verilator exact parameter commands and coverage distinctions are recorded in the static review. No tests are disabled to obtain a pass.

Next release blockers: default-capacity seven-engine fixture, individual static dispositions, reset/fault-cross closure, actual macro mapping and constrained synthesis. Candidate remains draft review material until resolved.

Reproduced test-contract failure (subsequently corrected below): `make descriptor-validator-regress` fails its obsolete expectation that0x53 aux0bit7 is reserved; existing product uses it for Row-Major output. Original failure is retained in the RTM evidence; corrected reserved-bit vector subsequently passes. Single-clock depth256 SpyGlass CDC structural check completes with0errors/2warnings and0unsynchronized crossings; it is not a dual-clock/RDC waiver.

Validator follow-up: corrected the reserved-bit negative vector to actual reserved bit8 without changing RTL or removing the rejection check. Target now PASS (29legal/33invalid/43accepted/26rejected). Initial failure remains archived; dedicated Row-Major boundary coverage is still limited. Final-checkpoint depth256 SpyGlass lint completes0errors/467warnings/5infos.
