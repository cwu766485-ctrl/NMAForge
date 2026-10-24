# Mixed-precision FP block verification

The current block flow is split across arithmetic units, the mixed BF16/FP16
dot core, UVM scoreboard coverage, and bounded formal properties. Run the
aggregate compute-cluster regression with:

```sh
make -C dv/subsystem/tensor_datapath/sim cluster_regress
```

It runs the dot-core and maximum-length parity tests, three mixed-format UVM
seeds, three seeded BF16 compatibility-wrapper tests, three FP16/BF16 add/sub
reference sweeps, and the independent Python FP reference unit tests. The
compatibility wrapper and add/sub flows collect DUT-only code coverage across
their seeds. Focused targets live in `sim/`; formal harnesses and their proof
boundary are in `formal/README.md`.

Selected numeric, response-ordering, parity cutoff, error suppression, and
no-reset recovery scenarios are covered. The interaction follow-up adds a
same-cycle parity+abort response check (parity classification wins after all
accepted reads drain) and reset while abort/parity are active. Full-domain
formal setup is clean and proves read/response accounting, parity cutoff
compute blocking, and drain-to-error; cutoff validity, progress bound, and
writeback exclusion remain inconclusive at the 150-second limit. This is
partial full-domain formal evidence, not closure. Residual DUT code-coverage
disposition also remains open; timeouts are recorded as inconclusive rather
than passes in the verification matrix. Current module coverage and residual
work are summarized in the
[compute-engine status](../../../../docs/verification/COMPUTE_ENGINE_STATUS.md).
