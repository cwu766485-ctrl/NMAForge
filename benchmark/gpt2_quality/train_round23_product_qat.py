#!/usr/bin/env python3
"""Bounded QAT for the frozen H64 Product integer contract.

The STE forward path models the current Q3/Q5/Q8.8 tensor scales, INT8
saturation, Q8.8 Product GELU, Q15 softmax followed by the Q7 AV operand, and
Q3 residuals.  The output is a research candidate; the independent integer
reference and Product Top still decide correctness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

from train_h64_byte_lm import (CONTEXT, FFN, HIDDEN, HEADS, H64ByteDecoder,
                               LAYERS, VOCAB)


def ste_quant(x: torch.Tensor, scale: float, lo: float | None = None,
              hi: float | None = None, rounding: str = "round") -> torch.Tensor:
    q = torch.floor(x * scale) if rounding == "floor" else torch.round(x * scale)
    if lo is not None:
        q = q.clamp(lo, hi)
    dq = q / scale
    return x + (dq - x).detach()


def q15_product_softmax(scores: torch.Tensor, mask: torch.Tensor) -> torch.Tensor:
    smooth = torch.softmax(scores.masked_fill(mask, -1.0e4), dim=-1)
    si = torch.floor(scores * 256.0).to(torch.int64)
    si = si.masked_fill(mask, -(1 << 30))
    maximum = si.max(dim=-1, keepdim=True).values
    delta = (maximum - si).clamp(min=0)
    whole = delta >> 8
    frac = delta & 255
    shift = whole.clamp(max=15)
    base = torch.bitwise_right_shift(torch.full_like(shift, 32768), shift)
    exp = base - (((base - (base >> 1)) * frac) >> 8)
    exp = torch.where(whole >= 15, 0, exp)
    exp = exp.masked_fill(mask, 0)
    denom = exp.sum(dim=-1, keepdim=True).clamp(min=1)
    p15 = (exp << 15) // denom
    # Product AV consumes probability >> 8, i.e. a Q7 probability operand.
    p7 = (p15 >> 8).to(torch.float32) / 128.0
    return smooth + (p7 - smooth).detach()


def product_gelu(x: torch.Tensor) -> torch.Tensor:
    mid = x * (x + 2.0) * 0.25
    y = torch.where(x <= -2.0, torch.zeros_like(x),
                    torch.where(x >= 2.0, x, mid))
    return ste_quant(y, 256.0, rounding="floor")


class ProductQAT(nn.Module):
    def __init__(self, base: H64ByteDecoder):
        super().__init__()
        self.model = base

    @staticmethod
    def qw(w: torch.Tensor, scale: float) -> torch.Tensor:
        return ste_quant(w, scale, -128, 127)

    def _ln(self, x: torch.Tensor, layernorm: nn.LayerNorm) -> torch.Tensor:
        gamma = self.qw(layernorm.weight, 32.0)
        beta = ste_quant(layernorm.bias, 1.0)
        y = F.layer_norm(x, (x.shape[-1],), gamma, beta, layernorm.eps)
        return ste_quant(y, 1.0, rounding="floor")

    def forward(self, tokens: torch.Tensor, return_trace: bool = False):
        batch, length = tokens.shape
        trace: dict[str, torch.Tensor] = {}
        emb = self.qw(self.model.embedding.weight, 8.0)
        pos = self.qw(self.model.position.weight, 8.0)
        x = F.embedding(tokens, emb) + pos[:length][None]
        x = ste_quant(x, 8.0, rounding="round")
        trace["embedding_position"] = x
        causal = torch.triu(torch.ones(length, length, dtype=torch.bool,
                                       device=tokens.device), diagonal=1)
        for layer_index, layer in enumerate(self.model.layers):
            prefix = f"l{layer_index}."
            n1 = self._ln(x, layer["ln1"])
            trace[prefix + "ln1"] = n1
            qkv = {}
            for name in ("q", "k", "v"):
                w = self.qw(layer[name].weight, 32.0)
                raw = F.linear(n1, w)
                qkv[name] = ste_quant(raw, 32.0, -128, 127, rounding="floor")
                trace[prefix + name] = qkv[name]
            q = qkv["q"].view(batch, length, HEADS, HIDDEN // HEADS).transpose(1, 2)
            k = qkv["k"].view(batch, length, HEADS, HIDDEN // HEADS).transpose(1, 2)
            v = qkv["v"].view(batch, length, HEADS, HIDDEN // HEADS).transpose(1, 2)
            # Product QK uses the existing Matrix descriptor shift (2) and
            # does not apply the conventional 1/sqrt(head_dim) multiplier.
            # Keep this fake-quant forward path numerically aligned with that
            # fixed-point contract; introducing the float scale here would
            # train a different attention function.
            scores = torch.matmul(q, k.transpose(-1, -2))
            scores = ste_quant(scores, 256.0, rounding="floor")
            trace[prefix + "scores"] = scores
            probs = q15_product_softmax(scores, causal[None, None])
            trace[prefix + "probabilities"] = probs
            attended = torch.matmul(probs, v).transpose(1, 2).contiguous().view(batch, length, HIDDEN)
            attended = ste_quant(attended, 32.0, -128, 127, rounding="floor")
            trace[prefix + "attention"] = attended
            wo = self.qw(layer["o"].weight, 32.0)
            projection = ste_quant(F.linear(attended, wo), 8.0, rounding="floor")
            trace[prefix + "projection"] = projection
            residual1 = ste_quant(x + projection, 8.0, rounding="floor")
            trace[prefix + "residual1"] = residual1
            n2 = self._ln(residual1, layer["ln2"])
            trace[prefix + "ln2"] = n2
            wup = self.qw(layer["up"].weight, 256.0)
            up = ste_quant(F.linear(n2, wup), 256.0, rounding="floor")
            trace[prefix + "up"] = up
            gelu = product_gelu(up)
            trace[prefix + "gelu"] = gelu
            gelu_i8 = ste_quant(gelu, 8.0, -128, 127, rounding="floor")
            trace[prefix + "gelu_i8"] = gelu_i8
            wdown = self.qw(layer["down"].weight, 32.0)
            # Product executes FFN-down in sixteen K=16 Matrix tiles and
            # applies the Q3 shift to each partial before accumulating it.
            # Quantize each partial separately, as the RTL/reference do; a
            # single requant after the full K reduction is not equivalent.
            down_parts = []
            for tile in range(FFN // 16):
                partial = F.linear(gelu_i8[..., tile * 16:(tile + 1) * 16],
                                   wdown[:, tile * 16:(tile + 1) * 16])
                down_parts.append(ste_quant(partial, 8.0, rounding="floor"))
            down = torch.stack(down_parts, dim=0).sum(dim=0)
            trace[prefix + "down"] = down
            x = ste_quant(residual1 + down, 8.0, rounding="floor")
            trace[prefix + "residual2"] = x
        final_ln = self._ln(x, self.model.final_ln)
        trace["final_ln"] = final_ln
        lm_w = self.qw(self.model.embedding.weight, 32.0)
        logits = ste_quant(F.linear(final_ln, lm_w), 32.0, rounding="floor")
        trace["logits"] = logits
        if return_trace:
            return logits, trace
        return logits


def qmatrix(w: torch.Tensor, scale: int) -> np.ndarray:
    return np.clip(np.rint(w.detach().cpu().numpy().T.astype(np.float64) * scale),
                   -128, 127).astype(np.int8)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fp32", type=Path, required=True)
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=20261123)
    ap.add_argument("--steps", type=int, default=500)
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--lr", type=float, default=1.0e-4)
    ap.add_argument("--eval-batches", type=int, default=16)
    args = ap.parse_args()
    torch.manual_seed(args.seed)
    torch.set_num_threads(1)
    raw = args.corpus.read_bytes()
    data = torch.from_numpy(np.frombuffer(raw, dtype=np.uint8).copy().astype(np.int64))
    split = int(len(data) * 0.9)
    train = data[:split]
    starts = np.random.default_rng(args.seed)
    ckpt = torch.load(args.fp32, map_location="cpu", weights_only=False)
    model = H64ByteDecoder().cpu()
    model.load_state_dict(ckpt["state_dict"])
    qat = ProductQAT(model)
    opt = torch.optim.AdamW(qat.parameters(), lr=args.lr, weight_decay=0.001)
    qat.train()
    for step in range(args.steps):
        ix = starts.integers(0, len(train) - CONTEXT - 1, size=args.batch)
        x = torch.stack([train[int(i):int(i) + CONTEXT] for i in ix])
        y = torch.stack([train[int(i) + 1:int(i) + CONTEXT + 1] for i in ix])
        logits = qat(x)
        # Product integer logits are Q5; ProductQAT returns dequantized real
        # logits, so dividing by 32 again would silently change the training
        # temperature and is not contract-faithful.
        loss = F.cross_entropy(logits.reshape(-1, VOCAB), y.reshape(-1))
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(qat.parameters(), 1.0)
        opt.step()
        if (step + 1) % 100 == 0 or step + 1 == args.steps:
            print(f"QAT step={step+1} train_ce={float(loss.detach()):.6f}", flush=True)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    state = model.state_dict()
    package: dict[str, np.ndarray] = {
        "embedding": np.clip(np.rint(state["embedding.weight"].cpu().numpy() * 8), -128, 127).astype(np.int8),
        "position": np.clip(np.rint(state["position.weight"].cpu().numpy() * 8), -128, 127).astype(np.int8),
        "final_gamma": np.rint(state["final_ln.weight"].cpu().numpy() * 32).astype(np.int32),
        # Product's current package beta is divided by eight in the reference;
        # store integer-effective beta in Q3 package units.
        "final_beta": (np.rint(state["final_ln.bias"].cpu().numpy()) * 8).astype(np.int32),
        "lm_head": qmatrix(model.embedding.weight, 32),
    }
    for li in range(LAYERS):
        p, dst = f"layers.{li}.", f"l{li}."
        for name in ("q", "k", "v", "o", "up", "down"):
            scale = 256 if name == "up" else 32
            package[dst + name] = qmatrix(model.layers[li][name].weight, scale)
        for name in ("ln1", "ln2"):
            package[dst + name + "_gamma"] = np.rint(
                state[p + name + ".weight"].cpu().numpy() * 32).astype(np.int32)
            package[dst + name + "_beta"] = (
                np.rint(state[p + name + ".bias"].cpu().numpy()) * 8).astype(np.int32)
    model_path = args.out_dir / "round23_product_qat_model.npz"
    np.savez_compressed(model_path, **package)
    model_ckpt_path = args.out_dir / "round23_product_qat_fp32.pt"
    torch.save({"state_dict": state, "config": {"hidden": HIDDEN, "heads": HEADS,
                "layers": LAYERS, "ffn": FFN, "vocab": VOCAB, "context": CONTEXT},
                "seed": args.seed, "qat_steps": args.steps}, model_ckpt_path)
    manifest = {"status": "QAT_CANDIDATE_NOT_YET_PRODUCT_TOP_QUALIFIED",
                "seed": args.seed, "steps": args.steps, "batch": args.batch,
                "learning_rate": args.lr, "source_fp32_sha256": hashlib.sha256(args.fp32.read_bytes()).hexdigest(),
                "corpus_sha256": hashlib.sha256(raw).hexdigest(),
                "split": "first 90 percent train/calibration; last 10 percent held-out",
                "contract": "fixed Q3 embeddings/residual, Q5 projections, Q8.8 FFN-up, unscaled Product QK shift-2, Q15 Softmax to Q7 AV, per-K16 Q3 FFN-down requant, Product GELU; STE QAT",
                "package_sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
                "fp32_checkpoint_sha256": hashlib.sha256(model_ckpt_path.read_bytes()).hexdigest(),
                "package": str(model_path), "checkpoint": str(model_ckpt_path)}
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("ROUND23_QAT_CANDIDATE_EXPORTED " + json.dumps(manifest, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
