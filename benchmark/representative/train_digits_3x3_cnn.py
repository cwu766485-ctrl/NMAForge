#!/usr/bin/env python3
"""Train and export a deterministic INT8 3x3/pointwise CNN for Top replay.

The model is trained from scikit-learn's bundled Digits data.  Its convolution
is evaluated through the production Matrix GEMM path after host-side Im2col;
the host lowering and transfer costs are recorded separately.
"""

import argparse
import hashlib
import json
import platform
import time
from pathlib import Path

import numpy as np
import sklearn
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split


SEED_DEFAULT = 20261119
EPOCHS_DEFAULT = 250
HIDDEN = 63
OUTPUTS = 10
IMAGE_SIZE = 16
CONV_SIZE = 14
POSITIONS = CONV_SIZE * CONV_SIZE


def load_dataset(seed):
    dataset = load_digits()
    labels = dataset.target.astype(np.int64)
    images = dataset.images.astype(np.float32) / 16.0
    images = np.repeat(np.repeat(images, 2, axis=1), 2, axis=2)
    coords = np.linspace(-1.0, 1.0, IMAGE_SIZE, dtype=np.float32)
    yy, xx = np.meshgrid(coords, coords, indexing="ij")
    planes = np.stack(
        (images, np.ones_like(images), np.broadcast_to(yy, images.shape),
         np.broadcast_to(xx, images.shape)), axis=-1
    )
    raw_hash = hashlib.sha256(
        dataset.images.tobytes(order="C") + labels.astype("<i8").tobytes()
    ).hexdigest()
    train_idx, test_idx = train_test_split(
        np.arange(len(labels)), test_size=0.2, random_state=seed,
        stratify=labels
    )
    return planes, labels, train_idx, test_idx, raw_hash


def lower_images(planes):
    # Feature order is [input-channel][dy][dx], with four planes per pixel.
    n = len(planes)
    patches = np.stack(
        [planes[:, y:y + CONV_SIZE, x:x + CONV_SIZE, :].reshape(
            n, POSITIONS, 4
        ) for y in range(3) for x in range(3)], axis=2
    )
    return patches.reshape(n, POSITIONS, 36).astype(np.float32)


def forward_float(columns, w1, w2):
    conv = columns @ w1
    hidden = np.concatenate(
        (np.maximum(conv, 0.0), np.ones((*conv.shape[:2], 1), np.float32)),
        axis=2,
    )
    logits = (hidden @ w2).mean(axis=1)
    return logits


def train(columns, labels, train_idx, seed, epochs):
    rng = np.random.default_rng(seed)
    w1 = rng.normal(0.0, 0.12, (36, HIDDEN)).astype(np.float32)
    w2 = rng.normal(0.0, 0.12, (HIDDEN + 1, OUTPUTS)).astype(np.float32)
    m1, v1 = np.zeros_like(w1), np.zeros_like(w1)
    m2, v2 = np.zeros_like(w2), np.zeros_like(w2)
    step = 0
    batch_size = 32
    learning_rate = 0.005
    for _epoch in range(epochs):
        order = rng.permutation(train_idx)
        for start in range(0, len(order), batch_size):
            ids = order[start:start + batch_size]
            x = columns[ids]
            batch = len(ids)
            conv = x @ w1
            hidden = np.concatenate(
                (np.maximum(conv, 0.0),
                 np.ones((batch, POSITIONS, 1), np.float32)), axis=2
            )
            logits = (hidden @ w2).mean(axis=1)
            logits -= logits.max(axis=1, keepdims=True)
            exp = np.exp(logits)
            prob = exp / exp.sum(axis=1, keepdims=True)
            prob[np.arange(batch), labels[ids]] -= 1.0
            dlogits = np.repeat(
                (prob[:, None, :] / (batch * POSITIONS)), POSITIONS, axis=1
            )
            grad_w2 = np.einsum("bpc,bpn->cn", hidden, dlogits,
                                optimize=True)
            d_hidden = dlogits @ w2.T
            d_conv = d_hidden[:, :, :HIDDEN] * (conv > 0.0)
            grad_w1 = np.einsum("bpk,bpc->kc", x, d_conv, optimize=True)
            step += 1
            for weight, grad, moment, variance in (
                (w1, grad_w1, m1, v1), (w2, grad_w2, m2, v2)
            ):
                moment *= 0.9
                moment += 0.1 * grad
                variance *= 0.999
                variance += 0.001 * grad * grad
                weight -= learning_rate * (moment / (1.0 - 0.9 ** step)) / (
                    np.sqrt(variance / (1.0 - 0.999 ** step)) + 1e-8
                )
    return w1, w2


def quantize(w1_float, w2_float, columns, labels, train_idx):
    # A constant input plane implements the learned feature-63 offset without
    # requiring a bias-enabled Matrix descriptor.
    w1_scale = max(1.0, float(np.max(np.abs(w1_float))))
    w1_q = np.zeros((36, 64), dtype=np.int8)
    w1_q[:, :HIDDEN] = np.rint(w1_float * (127.0 / w1_scale)).clip(
        -127, 127
    ).astype(np.int8)
    w1_q[:, HIDDEN] = 0
    w1_q[1, HIDDEN] = int(np.rint(127.0 / w1_scale))

    w2_scale = float(np.max(np.abs(w2_float)))
    w2_q = np.zeros((64, 16), dtype=np.int8)
    w2_q[:, :OUTPUTS] = np.rint(w2_float * (127.0 / w2_scale)).clip(
        -127, 127
    ).astype(np.int8)

    columns_q = np.rint(columns * 127.0).clip(-127, 127).astype(np.int32)
    raw1 = columns_q @ w1_q.astype(np.int32)
    max_raw1 = max(1, int(np.max(np.maximum(raw1[train_idx], 0))))
    shift1 = max(0, min(31, int(np.ceil(np.log2(max_raw1 / 100.0)))))
 