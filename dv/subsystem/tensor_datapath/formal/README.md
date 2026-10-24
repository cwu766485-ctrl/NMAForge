# Compute-cluster serial dispatch formal

Run from the repository root:

```sh
make -C dv/subsystem/tensor_datapath/formal run
```

VC Formal elaborates the actual `ai_accel_compute_cluster` and all seven compute
engines, plus the production opcode decoder. The environment models the
command-processor integration contract that a new `core_start` is issued only
when the cluster is idle. The proof checks mutually exclusive opcode classes,
the reduction from engine busy to cluster busy, and that at most one engine is
busy at a time. Seven covers demonstrate dispatch reachability for scalar,
FP, CNM, matrix, SFU, convolution, and KV engine paths.

This is a control-ownership proof with constant memory responses. It does not
prove numerical datapaths, scratchpad arbitration, the command processor in
the same formal cone, DMA overlap, or unrestricted full-top behavior. The
command processor lifecycle has its own formal environment; simulation covers
the integrated top and shared memory fabric.
