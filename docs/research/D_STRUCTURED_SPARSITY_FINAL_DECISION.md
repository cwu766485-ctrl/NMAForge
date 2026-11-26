# D Structured Sparsity Final Decision

## Frozen real model inputs

The audited trained CNN is `benchmark/models/nma_tiny_cnn_10class`, model SHA
`ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`, dataset
SHA `87ff0c9e40dc7e2c0e34e7257799c2e3f3aec1a016363bb11cad869ec428a826`, and
test-set SHA `cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`.
The deployed contract is INT8 weights/activations with INT32 accumulation;
the recorded test accuracy is 384/396 (`96.97%`).

After symmetric per-tensor INT8 quantization of the checked-in weights, the
CNN has 0/36 zero convolution weights and 20/1,440 zero fully-connected
weights (`1.39%`). All-zero 4x4, 8x8, and 16x16 weight blocks are `0%` for
both layers. The real test activations contain `57.90%` element zeros, but
only `9.33%` of 4-element blocks are all-zero and `0%` of 8/16-element blocks
are all-zero. These figures were computed from the frozen NPZ artifacts with
no synthetic sparsity.

Metadata, zero detection, block addressing, and fallback overhead would cost
more than the measured block opportunity for this model. No end-to-end
zero-skip RTL result exists.

**Stage 4: REJECT for the current product workload.** Do not change the ABI,
descriptor format, or dense INT8 datapath. A future sparsity study would need a
different representative workload with stable block structure, an
accuracy-preserving retraining/QAT report, and a metadata-inclusive hardware
measurement. Synthetic all-zero matrices remain corner tests only.
