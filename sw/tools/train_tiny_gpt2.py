#!/usr/bin/env python3
"""Train and export a small, quantized, GPT-style causal decoder.

This is a synthetic next-token language task (not natural-language pretraining).
The block intentionally matches NMAForge's available Post-LN ordering and is
therefore described as GPT-2-like, not architecture-identical to GPT-2.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
from pathlib import Path

import torch
from torch import nn
from torch.nn import functional as F


HIDDEN = 16
HEADS = 2
HEAD_DIM = 8
CONTEXT = 8
VOCAB = 32


def make_sequences(count: int, seed: int) -> list[list[int]]:
    """A held-out-testable finite-state token language with mode-conditioned transitions."""
    rng = random.Random(seed)
    result = []
    for _ in range(count):
        mode = rng.randrange(4)
        state = rng.randrange(28)
        seq = [mode, state + 4]
        for position in range(2, CONTEXT + 1):
            state = (state + mode * 5 + position * 3) % 28
            seq.append(state + 4)
        result.append(seq)
    return result


class TinyPostLNDecoder(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.token_embedding = nn.Embedding(VOCAB, HIDDEN)
        self.position_embedding = nn.Embedding(CONTEXT, HIDDEN)
        self.q = nn.Linear(HIDDEN, HIDDEN, bias=False)
        self.k = nn.Linear(HIDDEN, HIDDEN, bias=False)
        self.v = nn.Linear(HIDDEN, HIDDEN, bias=False)
        self.wo = nn.Linear(HIDDEN, HIDDEN, bias=False)
        self.ln1 = nn.LayerNorm(HIDDEN, eps=1.0e-5)
        self.up = nn.Linear(HIDDEN, HIDDEN, bias=False)
        self.down = nn.Linear(HIDDEN, HIDDEN, bias=False)
        self.ln2 = nn.LayerNorm(HIDDEN, eps=1.0e-5)
        self.lm_head = nn.Linear(HIDDEN, VOCAB, bias=False)
        self.lm_head.weight = self.token_embedding.weight

    def forward_float(self, tokens: torch.Tensor) -> torch.Tensor:
        batch, length = tokens.shape
        positions = torch.arange(length, device=tokens.device)
        x = self.token_embedding(tokens) + self.position_embedding(positions)[None, :, :]
        q = self.q(x).view(batch, length, HEADS, HEAD_DIM).transpose(1, 2)
        k = self.k(x).view(batch, length, HEADS, HEAD_DIM).transpose(1, 2)
        v = self.v(x).view(batch, length, HEADS, HEAD_DIM).transpose(1, 2)
        # The fixed-point score scale is chosen to approximate the hardware's
        # Q8.8 interpretation of unscaled INT8 dot products.
        scores = torch.matmul(q, k.transpose(-1, -2)) / 4.0
        causal = torch.triu(torch.ones(length, length, dtype=torch.bool), diagonal=1)
        scores = scores.masked_fill(causal[None, None, :, :], float("-inf"))
        probs = torch.softmax(scores, dim=-1)
        attended = torch.matmul(probs, v).transpose(1, 2).contiguous().view(
            batch, length, HIDDEN
        )
        x = self.ln1(self.wo(attended) + x)
        ffn = self.down(F.gelu(self.up(x)))
        x = self.ln2(ffn + x)
        return self.lm_head(x)

    def forward(self, tokens: torch.Tensor) -> torch.Tensor:
        return self.forward_float(tokens)


def to_i8(value: torch.Tensor, scale: int) -> list[list[int]]:
    quantized = torch.round(value.detach().cpu() * scale).clamp(-128, 127).to(torch.int16)
    return [[int(x) for x in row] for row in quantized.tolist()]


def weight_to_i8(linear: nn.Linear, scale: int) -> list[list[int]]:
    # NMAForge stores GEMM weights as [K,N], while nn.Linear stores [N,K].
    return to_i8(linear.weight.transpose(0, 1), scale)


def bigram_baseline(train: list[list[int]], test: list[list[int]]) -> dict[str, float]:
    counts = [[0] * VOCAB for _ in range(VOCAB)]
    unigram = [0] * VOCAB
    for seq in train:
        for current, following in zip(seq, seq[1:]):
            counts[current][following] += 1
            unigram[following] += 1
    correct = total = 0
    loss = 0.0
    for seq in test:
        for current, target in zip(seq[:CONTEXT], seq[1:CONTEXT + 1]):
            row = counts[current]
            if sum(row):
                pred = max(range(VOCAB), key=lambda i: (row[i], -i))
                prob = (row[target] + 0.1) / (sum(row) + 0.1 * VOCAB)
            else:
                pred = max(range(VOCAB), key=lambda i: (unigram[i], -i))
                prob = (unigram[target] + 0.1) / (sum(unigram) + 0.1 * VOCAB)
            correct += pred == target
            total += 1
            loss -= math.log(max(prob, 1.0e-12))
    return {"next_token_accuracy": correct / total, "cross_entropy_nats": loss / total,
            "perplexity": math.exp(loss / total)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=20261123)
    parser.add_argument("--epochs", type=int, default=100)
    parser.add_argument("--train-sequences", type=int, default=4096)
    parser.add_argument("--test-sequences", type=int, default=1024)
    args = parser.parse_args()

    torch.manual_seed(args.seed)
    random.seed(args.seed)
    torch.set_num_threads(1)
    torch.use_deterministic_algorithms(True)
    train = make_sequences(args.train_sequences, args.seed + 1)
    test = make_sequences(args.test_sequences, args.seed + 2)
    x_train = torch.tensor([s[:CONTEXT] for s in train], dtype=torch.long)
    y_train = torch.tensor([s[1:CONTEXT + 1] for s in train], dtype=torch.long)
    x_test = torch.tensor([s[:CONTEXT] for s in test], dtype=torch.long)
    y_test = torch.tensor([s[1:CONTEXT + 1] for s in test], dtype=torch.long)

    model = TinyPostLNDecoder()
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.012, weight_decay=1.0e-4)
    batch_size = 128
    for epoch in range(args.epochs):
        model.train()
        order = torch.randperm(x_train.shape[0])
        for start in range(0, x_train.shape[0], batch_size):
            indexes = order[start:start + batch_size]
            logits = model.forward_float(x_train[indexes])
            loss = F.cross_entropy(logits.reshape(-1, VOCAB), y_train[indexes].reshape(-1))
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            # The current GELU RTL consumes Q8.8 pre-activation values. Its
            # INT8 GEMM operand is therefore exported at 2^8 scale, which
            # makes |W_up| <= 127/256 a real representability constraint.
            # Keep training inside that hardware contract instead of silently
            # clipping nearly half of the trained FFN matrix during export.
            with torch.no_grad():
                model.up.weight.clamp_(-0.48, 0.48)

    model.eval()
    with torch.no_grad():
        logits = model.forward_float(x_test)
        heldout_loss = float(F.cross_entropy(logits.reshape(-1, VOCAB), y_test.reshape(-1)))
        heldout_accuracy = float((logits.argmax(-1) == y_test).float().mean())

    # Power-of-two scales and opcode shifts form the fixed-point export contract.
    emb = to_i8(model.token_embedding.weight, 8)
    pos = to_i8(model.position_embedding.weight, 8)
    qkv = {f"w{name}": weight_to_i8(getattr(model, name), 16)
           for name in ("q", "k", "v")}
    wo = weight_to_i8(model.wo, 16)
    wup = weight_to_i8(model.up, 256)
    wdown = weight_to_i8(model.down, 8)
    lm_head = [[emb[token][feature] for token in range(VOCAB)]
               for feature in range(HIDDEN)]
    state = model.state_dict()
    gamma1 = [int(round(float(x) * 32768.0)) for x in state["ln1.weight"]]
    beta1 = [int(round(float(x))) for x in state["ln1.bias"]]
    gamma2 = [int(round(float(x) * 32768.0)) for x in state["ln2.weight"]]
    beta2 = [int(round(float(x))) for x in state["ln2.bias"]]

    # Test prompts are held out. Positions 0..3 prefill KV; position 4 is
    # host-supplied context; four subsequent logits are checked by RTL.
    sample = test[0]
    model_json = {
        "model_name": "tiny_gpt2_like_h16_postln_synthetic_lm",
        "model_scope": "trained decoder-only causal next-token model on a synthetic finite-state token language; not natural-text pretraining",
        "architecture_contract": {
            "hidden": 16, "heads": 2, "head_dim": 8, "layers": 1,
            "context": 8, "vocab": VOCAB, "dtype": "signed INT8",
            "block_order": "attention(QKV, causal softmax, AV, Wo) -> residual -> LayerNorm1 -> FFN(up, GELU, down) -> residual -> LayerNorm2 -> tied LM Head",
            "gpt2_compatibility": "GPT-2-like decoder with learned positions and tied LM head; Post-LN order differs from original GPT-2 Pre-LN block",
            "attention_score_scale": "INT8 dot result interpreted as Q8.8; software training divides float dot by 4.0 to approximate exported integer contract",
        },
        "seed": args.seed,
        "training": {
            "framework": f"PyTorch {torch.__version__} CPU",
            "algorithm": "AdamW cross-entropy, deterministic CPU, full causal next-token objective",
            "epochs": args.epochs,
            "train_sequences": args.train_sequences,
            "test_sequences": args.test_sequences, "sequence_tokens": CONTEXT + 1,
            "heldout_float_cross_entropy_nats": heldout_loss,
            "heldout_float_perplexity": math.exp(heldout_loss),
            "heldout_float_next_token_accuracy": heldout_accuracy,
            "baseline_bigram": bigram_baseline(train, test),
            "corpus": "seeded finite-state synthetic token sequences; token IDs 0..3 encode transition mode and 4..31 encode symbol state",
            "quantized_quality": "computed by reference_tiny_gpt2_int8.py; not inherited from float metrics",
        },
        "shape": {"hidden": HIDDEN, "attention_heads": HEADS, "head_dim": HEAD_DIM,
                  "layers": 1, "sequence_length": CONTEXT, "dtype": "signed INT8"},
        "tokenizer": {"kind": "fixed synthetic symbol vocabulary", "vocab_size": VOCAB,
                      "token_ids": list(range(VOCAB))},
        "prefill_tokens": sample[:4],
        "incremental_decode_tokens": sample[4:8],
        "prompt_and_targets": sample,
        "embeddings": emb,
        "position_embeddings": pos,
        "weights": {**qkv, "wo": wo, "wup": wup, "wdown": wdown,
                    "lm_head": lm_head},
        "gemm_shifts": {"qkv": 4, "wo": 4, "qk": 0, "wup": 0,
                        "wdown": 11, "lm_head": 0},
        "gamma1_q15": gamma1, "beta1": beta1,
        "gamma2_q15": gamma2, "beta2": beta2,
        "host_fallback": [
            "token/position embedding lookup and INT8 saturated sum are host input preparation",
            "tokenizer and greedy argmax are host responsibilities",
            "no Transformer intermediate activation is host-computed; Top RTL executes QKV, KV append/read, attention, FFN, LayerNorm, and LM Head",
        ],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(model_json, indent=2, sort_keys=True) + "\n").encode()
    args.out.write_bytes(payload)
    print("TINY_GPT2_TRAIN_PASS "
          f"seed={args.seed} epochs={args.epochs} vocab={VOCAB} hidden={HIDDEN} "
          f"float_loss={heldout_loss:.6f} float_ppl={math.exp(heldout_loss):.4f} "
          f"float_accuracy={heldout_accuracy:.6f} "
          f"model_sha256={hashlib.sha256(payload).hexdigest()} "
          f"out={args.out}")


if __name__ == "__main__":
    main()
