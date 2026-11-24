# V1.2 integrated P0 evidence

Source commit: `ad58507fa5052ccec61e05428c4e36e493796b8b` on `research/nmaforge-v1.2-integrated-model-dv`. Product RTL was unchanged.

`run_manifest.json` records commands, SPAD capacity parameters, seeds, exact captured outcomes, artifact SHA-256 values, and exclusions. The raw VCS run logs and top smoke/regression output are gzip-compressed byte-for-byte. No simulator binaries, generated VCS directories, coverage databases, or URG report directories are included.

The pre-fix run on parent `5c8952b189c3831d45e41fa2ea3c389c83533b21` reproduced the VDOT fixture ABI conflict. The UVM simulator itself returned 0 while reporting one fatal; the Make PASS-marker gate therefore failed.

The nine post-fix Compute Cluster runs cover 128, 256, and 512 KiB with seeds 20261025, 20261026, and 20261027. All have zero scoreboard mismatches/unknown reads and zero UVM Warning/Error/Fatal. Top `ai_smoke` and the 20-case seed-12345 `ai_run` also pass.

`top/matrix_cnm_profile.csv` is only one smoke-run Matrix/CNM overlap datapoint; unified all-engine profiling and paired A/B performance evidence remain open.

After the opt-in Round31 DeiT testbench path was added, unchanged default Top
`ai_smoke` and seeded `ai_run` were recompiled and replayed once more. Their
current-TB source hashes and five archived raw logs are in
`current_tb_replay/run_manifest.json`; this confirms default-path compatibility
and does not add requirement mapping, coverage, mutation, or formal closure.
