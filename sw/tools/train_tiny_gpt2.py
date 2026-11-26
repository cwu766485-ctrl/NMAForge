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


def fake_quant(x: torch.Tensor, scale: int, qmin: int, qmax: int,
               rounding: str = "nearest") -> torch.Tensor:
    scaled = x * float(scale)
    quantized = torch.round(scaled) if rounding == "nearest" else torch.floor(scaled)
    quantized = quantized.clamp(qmin, qmax) / float(scale)
    return x + (quantized - x).detach()


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

    def forward_qat(self, tokens: torch.Tensor, norm_scale: int = 16,
                    gelu_scale: int = 64, wdown_scale: int = 16,
                    return_trace: bool = False):
        """Fake-quant forward matching the exported INT8/Q8.8 datapath."""
        batch, length = tokens.shape
        trace: dict[str, torch.Tensor] = {}

        def qweight(layer: nn.Linear, scale: int) -> torch.Tensor:
            return fake_quant(layer.weight, scale, -128, 127)

        positions = torch.arange(length, device=tokens.device)
        emb = fake_quant(self.token_embedding(tokens), 8, -128, 127)
        pos = fake_quant(self.position_embedding(positions)[None, :, :], 8, -128, 127)
        x0 = fake_quant(emb + pos, 8, -128, 127)
        trace["embedding_position"] = x0

        qw = qweight(self.q, 16)
        kw = qweight(self.k, 16)
        vw = qweight(self.v, 16)
        q = fake_quant(F.linear(x0, qw), 8, -128, 127, "floor")
        k = fake_quant(F.linear(x0, kw), 8, -128, 127, "floor")
        v = fake_quant(F.linear(x0, vw), 8, -128, 127, "floor")
        q = q.view(batch, length, HEADS, HEAD_DIM).transpose(1, 2)
        k = k.view(batch, length, HEADS, HEAD_DIM).transpose(1, 2)
        v = v.view(batch, length, HEADS, HEAD_DIM).transpose(1, 2)
        trace.update({"q": q, "k": k, "v": v})

        scores = torch.matmul(q, k.transpose(-1, -2)) / 4.0
        causal = torch.triu(torch.ones(length, length, dtype=torch.bool,
                                       device=tokens.device), diagonal=1)
        scores = scores.masked_fill(causal[None, None, :, :], float("-inf"))
        trace["scores"] = scores
        # RTL consumes Q8.8 log2 scores and evaluates exp2, so ln(2) converts
        # them to the equivalent natural-exponential softmax domain.
        prob = torch.softmax(scores * math.log(2.0), dim=-1)
        prob_q15 = fake_quant(prob, 32768, 0, 32768, "floor")
        prob_i8 = fake_quant(prob_q15, 128, 0, 127, "floor")
        trace["probabilities"] = prob_q15
        av = torch.matmul(prob_i8, v)
        av = fake_quant(av, 8, -128, 127, "floor")
        trace["av"] = av

        wo = qweight(self.wo, 16)
        head_projection = []
        for head in range(HEADS):
            panel = wo[:, head * HEAD_DIM:(head + 1) * HEAD_DIM]
            partial = F.linear(av[:, head], panel)
            head_projection.append(fake_quant(partial, 8, -(1 << 31), (1 << 31) - 1, "floor"))
        trace["head_projection"] = torch.stack(head_projection, dim=1)
        merged = torch.stack(head_projection, dim=0).sum(dim=0)
        trace["merged"] = merged
        residual1 = fake_quant(merged + x0, 8, -(1 << 31), (1 << 31) - 1, "floor")
        trace["residual1"] = residual1

        # The RTL LN output is integer Q-format. Export scales its affine
        # coefficients so the INT8 boundary retains `norm_scale` fractional
        # levels while the dequantized value remains the same real LayerNorm.
        ln1 = F.layer_norm(residual1, (HIDDEN,), self.ln1.weight, self.ln1.bias,
                           eps=1.0 / (8.0 * 8.0))
        ln1_q = fake_quant(ln1, norm_scale, -128, 127, "floor")
        trace["layernorm1"] = ln1_q
        wup = qweight(self.up, 256)
        up = F.linear(ln1_q, wup)
        up = fake_quant(up, 256, -(1 << 31), (1 << 31) - 1, "floor")
        trace["ffn_up"] = up

        up_q8_8 = fake_quant(up, 256, -(1 << 31), (1 << 31) - 1, "floor")
        gelu = torch.where(up_q8_8 <= -2.0, torch.zeros_like(up_q8_8),
                           torch.where(up_q8_8 >= 2.0, up_q8_8,
                                       up_q8_8 * (up_q8_8 + 2.0) / 4.0))
        gelu = fake_quant(gelu, 256, -(1 << 31), (1 << 31) - 1, "floor")
        trace["gelu"] = gelu
        gelu_i8 = fake_quant(gelu, gelu_scale, -128, 127, "floor")
        trace["gelu_i8"] = gelu_i8

        down = F.linear(gelu_i8, qweight(self.down, wdown_scale))
        down = fake_quant(down, norm_scale, -(1 << 31), (1 << 31) - 1, "floor")
        trace["ffn_down"] = down
        residual2 = fake_quant(down + ln1_q, norm_scale,
                               -(1 << 31), (1 << 31) - 1, "floor")
        trace["residual2"] = residual2
        ln2 = F.layer_norm(residual2, (HIDDEN,), self.ln2.weight, self.ln2.bias,
                           eps=1.0 / float(norm_scale * norm_scale))
        ln2_q = fake_quant(ln2, norm_scale, -128, 127, "floor")
        trace["layernorm2"] = ln2_q
        lm_weight = fake_quant(self.token_embedding.weight, 8, -128, 127)
        logits = F.linear(ln2_q, lm_weight)
        logits = fake_quant(logits, 8, -(1 << 31), (1 << 31) - 1, "floor")
        trace["logits"] = logits
        if return_trace:
            return logits, trace
        return logits

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
    parser.add_argument("--norm-output-scale", type=int, default=1,
                        help="power-of-two integer output scale for LayerNorm tensors")
    parser.add_argument("--gelu-output-scale", type=int, default=256,
                        help="power-of-two integer output scale after Q8.8 GELU requant")
    parser.add_argument("--wdown-weight-scale", type=int, default=8,
                        help="power-of-two INT8 scale used to export FFN down weights")
    parser.add_argument("--qat-epochs", type=int, default=0,
                        help="hardware-contract fake-quant fine-tuning epochs (0 disables QAT)")
    parser.add_argument("--qat-lr", type=float, default=0.0005)
    parser.add_argument("--float-checkpoint-dir", type=Path, default=None,
                        help="optional directory for pre-QAT and final FP32 state_dict checkpoints")
    args = parser.parse_args()

    norm_scale = int(args.norm_output_scale)
    gelu_scale = int(args.gelu_output_scale)
    wdown_scale = int(args.wdown_weight_scale)
    for name, value in (("norm-output-scale", norm_scale),
                        ("gelu-output-scale", gelu_scale),
                        ("wdown-weight-scale", wdown_scale)):
        if value < 1 or value & (value - 1):
            raise ValueError(f"{name} must be a positive power of two")
    if gelu_scale > 256:
        raise ValueError("GELU output scale cannot exceed its Q8.8 input scale 256")
    if 256 % gelu_scale:
        raise ValueError("GELU output scale must divide 256")
    wup_shift = int(math.log2(norm_scale))
    gelu_shift = int(math.log2(256 // gelu_scale))
    wdown_ratio = gelu_scale * wdown_scale // norm_scale
    if (gelu_scale * wdown_scale) % norm_scale or wdown_ratio < 1 or wdown_ratio & (wdown_ratio - 1):
        raise ValueError("GELU/Wdown/LayerNorm scales must yield a power-of-two GEMM shift")
    wdown_shift = int(math.log2(wdown_ratio))
    lm_head_shift = int(math.log2(norm_scale))

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

    if args.float_checkpoint_dir is not None:
        args.float_checkpoint_dir.mkdir(parents=True, exist_ok=True)
        torch.save({
            "state_dict": model.state_dict(),
            "seed": args.seed, "epochs": args.epochs,
            "qat_epochs": 0, "phase": "pre_qat_fp32",
            "architecture": {"hidden": HIDDEN, "heads": HEADS,
                             "head_dim": HEAD_DIM, "layers": 1,
                             "context": CONTEXT, "vocab": VOCAB},
        }, args.float_checkpoint_dir / "tiny_gpt2_h16_pre_qat_fp32.pt")

    qat_train_loss = None
    if args.qat_epochs:
        qat_optimizer = torch.optim.AdamW(model.parameters(), lr=args.qat_lr,
                                          weight_decay=1.0e-5)
        for _ in range(args.qat_epochs):
            model.train()
            order = torch.randperm(x_train.shape[0])
            for start in range(0, x_train.shape[0], batch_size):
                indexes = order[start:start + batch_size]
                logits = model.forward_qat(x_train[indexes], norm_scale,
                                           gelu_scale, wdown_scale)
                loss = F.cross_entropy(logits.reshape(-1, VOCAB),
                                       y_train[indexes].reshape(-1))
                qat_optimizer.zero_grad(set_to_none=True)
                loss.backward()
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                qat_optimizer.step()
                with torch.no_grad():
                    model.up.weight.clamp_(-0.48, 0.48)
        qat_train_loss = float(loss.detach())

    model.eval()
    with torch.no_grad():
        logits = model.forward_float(x_test)
        heldout_loss = float(F.cross_entropy(logits.reshape(-1, VOCAB), y_test.reshape(-1)))
        heldout_accuracy = float((logits.argmax(-1) == y_test).float().mean())
        float_decode_logits = logits[:, 4:8, :]
        float_decode_targets = y_test[:, 4:8]
        heldout_float_decode_loss = float(F.cross_entropy(
            float_decode_logits.reshape(-1, VOCAB), float_decode_targets.reshape(-1)))
        heldout_float_decode_accuracy = float(
            (float_decode_logits.argmax(-1) == float_decode_targets).float().mean())
        qat_logits = model.forward_qat(x_test, norm_scale, gelu_scale, wdown_scale)
        heldout_qat_loss = float(F.cross_entropy(
            qat_logits.reshape(-1, VOCAB), y_test.reshape(-1)))
        heldout_qat_accuracy = float((qat_logits.argmax(-1) == y_test).float().mean())
        qat_decode_logits = qat_logits[:, 4:8, :]
        heldout_qat_decode_loss = float(F.cross_entropy(
            qat_decode_logits.reshape(-1, VOCAB), float_decode_targets.reshape(-1)))
        heldout_qat_decode_accuracy = float(
            (qat_decode_logits.argmax(-1) == float_decode_targets).float().mean())

    if args.float_checkpoint_dir is not None:
        torch.save({
            "state_dict": model.state_dict(),
            "seed": args.seed, "epochs": args.epochs,
            "qat_epochs": args.qat_epochs,
            "qat_learning_rate": args.qat_lr if args.qat_epochs else None,
            "phase": "post_qat_fp32" if args.qat_epochs else "post_training_fp32",
            "architecture": {"hidden": HIDDEN, "heads": HEADS,
                             "head_dim": HEAD_DIM, "layers": 1,
                             "context": CONTEXT, "vocab": VOCAB},
        }, args.float_checkpoint_dir / "tiny_gpt2_h16_post_qat_fp32.pt")

    # Power-of-two scales and opcode shifts form the fixed-point export contract.
    emb = to_i8(model.token_embedding.weight, 8)
    pos = to_i8(model.position_embedding.weight, 8)
    qkv = {f"w{name}": weight_to_i8(getattr(model, name), 16)
           for name in ("q", "k", "v")}
    wo = weight_to_i8(model.wo, 16)
    wup = weight_to_i8(model.up, 256)
    wdown = weight_to_i8(model.down, wdown_scale)
    lm_head = [[emb[token][feature] for token in range(VOCAB)]
               for feature in range(HIDDEN)]
    state = model.state_dict()
    gamma1 = [int(round(float(x) * 32768.0 * norm_scale)) for x in state["ln1.weight"]]
    beta1 = [int(round(float(x) * norm_scale)) for x in state["ln1.bias"]]
    gamma2 = [int(round(float(x) * 32768.0 * norm_scale)) for x in state["ln2.weight"]]
    beta2 = [int(round(float(x) * norm_scale)) for x in state["ln2.bias"]]

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
            "heldout_float_decode_positions_4_to_7_cross_entropy_nats": heldout_float_decode_loss,
            "heldout_float_decode_positions_4_to_7_perplexity": math.exp(heldout_float_decode_loss),
            "heldout_float_decode_positions_4_to_7_next_token_accuracy": heldout_float_decode_accuracy,
            "qat_epochs": args.qat_epochs,
            "qat_learning_rate": args.qat_lr if args.qat_epochs else None,
            "heldout_fake_quant_cross_entropy_nats": heldout_qat_loss,
            "heldout_fake_quant_next_token_accuracy": heldout_qat_accuracy,
            "heldout_fake_quant_decode_positions_4_to_7_cross_entropy_nats": heldout_qat_decode_loss,
            "heldout_fake_quant_decode_positions_4_to_7_perplexity": math.exp(heldout_qat_decode_loss),
            "heldout_fake_quant_decode_positions_4_to_7_next_token_accuracy": heldout_qat_decode_accuracy,
            "qat_last_training_batch_loss": qat_train_loss,
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
        "activation_scales": {"layernorm_output": 1, "gelu_output": 256,
                               "wdown_weight": 8},
        "gamma1_q15": gamma1, "beta1": beta1,
        "gamma2_q15": gamma2, "beta2": beta2,
        "host_fallback": [
            "token/position embedding lookup and INT8 saturated sum are host input preparation",
            "tokenizer and greedy argmax are host responsibilities",
            "no Transformer intermediate activation is host-computed; Top RTL executes QKV, KV append/read, attention, FFN, LayerNorm, and LM Head",
        ],
    }
    model_json["gemm_shifts"]["wup"] = wup_shift
    model_json["gemm_shifts"]["wdown"] = wdown_shift
    model_json["gemm_shifts"]["lm_head"] = lm_head_shift
    model_json["activation_scales"] = {"layernorm_output": norm_scale,
                                       "gelu_output": gelu_scale,
                                       "wdown_weight": wdown_scale}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(model_json, indent=2, sort_keys=True) + "\n").encode()
    args.out.write_bytes(payload)
    print("TINY_GPT2_TRAIN_PASS "
          f"seed={args.seed} epochs={args.epochs} vocab={VOCAB} hidden={HIDDEN} "
          f"float_loss={heldout_loss:.6f} float_ppl={math.exp(heldout_loss):.4f} "
          f"float_accuracy={heldout_accuracy:.6f} fake_quant_loss={heldout_qat_loss:.6f} "
          f"fake_quant_accuracy={heldout_qat_accuracy:.6f} "
          f"float_decode_accuracy={heldout_float_decode_accuracy:.6f} "
          f"fake_quant_decode_accuracy={heldout_qat_decode_accuracy:.6f} "
          f"qat_epochs={args.qat_epochs} "
          f"model_sha256={hashlib.sha256(payload).hexdigest()} "
          f"out={args.out}")


if __name__ == "__main__":
    main()
