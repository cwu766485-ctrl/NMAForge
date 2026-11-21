#!/usr/bin/env python3
"""Train and evaluate a small H64/4-layer NMAForge-contract byte LM.

This is a bounded research model trained from scratch on Tiny Shakespeare. It
uses the same Pre-LN block topology, dimensions, and 256-symbol vocabulary as
the existing H64 Product-Top path. The exported package is independently
scored by gpt2_compat_golden.int_infer before it is sent to RTL.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import urllib.request
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

ROOT = Path(__file__).resolve().parents[2]
import sys
sys.path.insert(0, str(ROOT / "benchmark/gpt2_quality"))
from product_integer_reference import infer as product_int_infer  # noqa: E402

HIDDEN, HEADS, HEAD_DIM, LAYERS = 64, 4, 16, 4
FFN, VOCAB, CONTEXT = 256, 256, 16
CORPUS_COMMIT = "6f9487a6fe5b420b7ca9afb0d7c078e37c1d1b4e"
CORPUS_URL = ("https://raw.githubusercontent.com/karpathy/char-rnn/" +
              CORPUS_COMMIT + "/data/tinyshakespeare/input.txt")


class H64ByteDecoder(nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.embedding = nn.Embedding(VOCAB, HIDDEN)
        self.position = nn.Embedding(CONTEXT, HIDDEN)
        self.layers = nn.ModuleList()
        for _ in range(LAYERS):
            self.layers.append(nn.ModuleDict({
                "ln1": nn.LayerNorm(HIDDEN), "q": nn.Linear(HIDDEN, HIDDEN, bias=False),
                "k": nn.Linear(HIDDEN, HIDDEN, bias=False),
                "v": nn.Linear(HIDDEN, HIDDEN, bias=False),
                "o": nn.Linear(HIDDEN, HIDDEN, bias=False),
                "ln2": nn.LayerNorm(HIDDEN), "up": nn.Linear(HIDDEN, FFN, bias=False),
                "down": nn.Linear(FFN, HIDDEN, bias=False),
            }))
        self.final_ln = nn.LayerNorm(HIDDEN)
        self.lm_head = nn.Linear(HIDDEN, VOCAB, bias=False)
        self.lm_head.weight = self.embedding.weight
        self.reset_parameters()

    def reset_parameters(self) -> None:
        nn.init.normal_(self.embedding.weight, mean=0.0, std=0.30)
        nn.init.normal_(self.position.weight, mean=0.0, std=0.08)
        for layer in self.layers:
            for key in ("q", "k", "v", "o", "up", "down"):
                nn.init.normal_(layer[key].weight, mean=0.0, std=0.025)
            nn.init.ones_(layer["ln1"].weight)
            nn.init.zeros_(layer["ln1"].bias)
            nn.init.ones_(layer["ln2"].weight)
            nn.init.zeros_(layer["ln2"].bias)
        nn.init.ones_(self.final_ln.weight)
        nn.init.zeros_(self.final_ln.bias)

    def forward(self, tokens: torch.Tensor) -> torch.Tensor:
        batch, length = tokens.shape
        x = self.embedding(tokens) + self.position.weight[:length][None, :, :]
        mask = torch.triu(torch.ones(length, length, dtype=torch.bool,
                                     device=tokens.device), diagonal=1)
        for layer in self.layers:
            n1 = layer["ln1"](x)
            q = layer["q"](n1).view(batch, length, HEADS, HEAD_DIM).transpose(1, 2)
            k = layer["k"](n1).view(batch, length, HEADS, HEAD_DIM).transpose(1, 2)
            v = layer["v"](n1).view(batch, length, HEADS, HEAD_DIM).transpose(1, 2)
            scores = (q @ k.transpose(-1, -2)) / math.sqrt(HEAD_DIM)
            prob = scores.masked_fill(mask[None, None], float("-inf")).softmax(-1)
            attended = (prob @ v).transpose(1, 2).contiguous().view(batch, length, HIDDEN)
            residual = x + layer["o"](attended)
            n2 = layer["ln2"](residual)
            ffn = layer["down"](F.gelu(layer["up"](n2), approximate="tanh"))
            x = residual + ffn
        return self.lm_head(self.final_ln(x))


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def corpus_bytes(path: Path) -> bytes:
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(CORPUS_URL, timeout=60) as response:
            path.write_bytes(response.read())
    raw = path.read_bytes()
    if len(raw) < 1_000_000:
        raise ValueError(f"unexpected corpus size: {len(raw)}")
    return raw


def sample_batch(data: torch.Tensor, count: int, rng: np.random.Generator):
    starts = rng.integers(0, len(data) - CONTEXT - 1, size=count)
    ix = torch.from_numpy(starts.astype(np.int64))
    x = torch.stack([data[int(i):int(i) + CONTEXT] for i in ix])
    y = torch.stack([data[int(i) + 1:int(i) + CONTEXT + 1] for i in ix])
    return x, y


def q_i8(a: np.ndarray, scale: int) -> np.ndarray:
    return np.clip(np.rint(a.astype(np.float64) * scale), -128, 127).astype(np.int8)


def export_int8(model: H64ByteDecoder, path: Path) -> dict[str, np.ndarray]:
    state = model.state_dict()
    out: dict[str, np.ndarray] = {
        "embedding": q_i8(state["embedding.weight"].cpu().numpy(), 8),
        "position": q_i8(state["position.weight"].cpu().numpy(), 8),
        "final_gamma": np.rint(state["final_ln.weight"].cpu().numpy() * 32).astype(np.int32),
        "final_beta": np.rint(state["final_ln.bias"].cpu().numpy() * 8).astype(np.int32),
        "lm_head": q_i8(state["embedding.weight"].cpu().numpy().T, 32),
    }
    for i in range(LAYERS):
        p = f"layers.{i}."
        target = f"l{i}."
        for name in ("q", "k", "v", "o", "up", "down"):
            out[target + name] = q_i8(state[p + name + ".weight"].cpu().numpy().T, 32)
        for name in ("ln1", "ln2"):
            out[target + name + "_gamma"] = np.rint(
                state[p + name + ".weight"].cpu().numpy() * 32).astype(np.int32)
            out[target + name + "_beta"] = np.rint(
                state[p + name + ".bias"].cpu().numpy() * 8).astype(np.int32)
    path.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(path, **out)
    return out


def metrics_from_logits(logits: np.ndarray, targets: np.ndarray) -> dict:
    z = logits.astype(np.float64)
    z -= z.max(axis=-1, keepdims=True)
    logsum = np.log(np.exp(z).sum(axis=-1))
    chosen = np.take_along_axis(z, targets[..., None], axis=-1)[..., 0]
    return {"cross_entropy_nats": float(np.mean(logsum - chosen)),
            "perplexity": float(np.exp(np.mean(logsum - chosen))),
            "next_byte_accuracy": float(np.mean(np.argmax(logits, axis=-1) == targets))}


def evaluate(model: H64ByteDecoder, test: np.ndarray, count: int, seed: int,
             int_model: dict[str, np.ndarray]) -> tuple[dict, dict]:
    rng = np.random.default_rng(seed)
    lo = int(len(test) * 0.05)
    hi = len(test) - CONTEXT - 1
    starts = rng.integers(lo, hi, size=count)
    xs = np.stack([test[s:s + CONTEXT] for s in starts]).astype(np.int64)
    ys = np.stack([test[s + 1:s + CONTEXT + 1] for s in starts]).astype(np.int64)
    with torch.no_grad():
        fp = model(torch.from_numpy(xs)).cpu().numpy()
    fp_metrics = metrics_from_logits(fp, ys)
    int_logits = []
    for x in xs:
        y, _ = product_int_infer(int_model, x.astype(np.int32).tolist())
        int_logits.append(y)
    # Product LM-head weights are stored as Q5. CE must use dequantized logits;
    # argmax itself is unchanged by this positive scale factor.
    int_metrics = metrics_from_logits(np.asarray(int_logits, dtype=np.float64) / 32.0, ys)
    return fp_metrics, int_metrics


def bigram_accuracy(train: np.ndarray, test: np.ndarray, count: int, seed: int) -> float:
    freq = np.ones((VOCAB, VOCAB), dtype=np.int64)
    np.add.at(freq, (train[:-1], train[1:]), 1)
    predictor = np.argmax(freq, axis=1)
    rng = np.random.default_rng(seed)
    starts = rng.integers(0, len(test) - CONTEXT - 1, size=count)
    correct = total = 0
    for start in starts:
        prev = test[start:start + CONTEXT]
        target = test[start + 1:start + CONTEXT + 1]
        correct += int(np.sum(predictor[prev] == target))
        total += CONTEXT
    return correct / total


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", type=Path, default=Path("/tmp/nmaforge_tinyshakespeare.txt"))
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=20261120)
    ap.add_argument("--steps", type=int, default=1200)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--eval-windows", type=int, default=128)
    args = ap.parse_args()
    torch.manual_seed(args.seed)
    torch.set_num_threads(1)
    np_rng = np.random.default_rng(args.seed)
    raw = corpus_bytes(args.corpus)
    corpus_hash = sha(raw)
    encoded = np.frombuffer(raw, dtype=np.uint8).copy()
    split = int(len(encoded) * 0.9)
    train_np, test_np = encoded[:split], encoded[split:]
    train = torch.from_numpy(train_np.astype(np.int64))
    model = H64ByteDecoder().cpu()
    optimizer = torch.optim.AdamW(model.parameters(), lr=3e-4, weight_decay=0.01)
    model.train()
    for step in range(args.steps):
        x, y = sample_batch(train, args.batch, np_rng)
        logits = model(x)
        loss = F.cross_entropy(logits.reshape(-1, VOCAB), y.reshape(-1))
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        if (step + 1) % 200 == 0 or step + 1 == args.steps:
            print(f"TRAIN step={step + 1} loss={float(loss):.6f}", flush=True)
    model.eval()
    args.out.mkdir(parents=True, exist_ok=True)
    package_path = args.out / "canonical_h64_byte_lm_int8.npz"
    int_model = export_int8(model, package_path)
    model_path = args.out / "h64_byte_lm_fp32.pt"
    torch.save({"state_dict": model.state_dict(), "seed": args.seed,
                "steps": args.steps, "architecture": {"hidden": HIDDEN,
                "heads": HEADS, "layers": LAYERS, "ffn": FFN,
                "context": CONTEXT, "vocab": VOCAB},
                "corpus_sha256": corpus_hash}, model_path)
    float_metrics, int_metrics = evaluate(model, test_np, args.eval_windows,
                                          args.seed + 1, int_model)
    bigram = bigram_accuracy(train_np, test_np, args.eval_windows, args.seed + 2)
    manifest = {
        "model": "NMAForge H64 four-layer byte-level next-token LM",
        "status": "TRAINED_RESEARCH_MODEL_NOT_GENERAL_LANGUAGE_QUALITY_CLAIM",
        "architecture": {"hidden": HIDDEN, "heads": HEADS, "head_dim": HEAD_DIM,
                          "layers": LAYERS, "ffn": FFN, "context": CONTEXT,
                          "vocab": VOCAB, "block_order": "PreLN attention, residual, PreLN GELU FFN, residual, final LN; tied token/LM embedding"},
        "dataset": {"name": "Tiny Shakespeare (byte-level; public-domain Shakespeare text)",
                    "source_url": CORPUS_URL, "source_commit": CORPUS_COMMIT,
                    "sha256": corpus_hash, "bytes": len(raw), "split": "first 90% train, last 10% held-out test"},
        "training": {"seed": args.seed, "steps": args.steps, "batch_size": args.batch,
                     "optimizer": "AdamW lr=3e-4 weight_decay=0.01; deterministic CPU",
                     "eval_windows": args.eval_windows,
                     "float_heldout": float_metrics, "int8_heldout": int_metrics,
                     "bigram_baseline_accuracy": bigram,
                     "quantization": "embedding/position round(x*8), matrix weights round(x*32), LN gamma round(x*32), beta round(x*8), signed INT8 saturation; LM logits dequantized by Q5 scale 32 for CE/PPL"},
        "artifacts": {"fp32_sha256": sha(model_path.read_bytes()),
                      "int8_package_sha256": sha(package_path.read_bytes())},
        "host_fallback": ["byte tokenizer/input IDs", "Host Argmax/token feedback"],
    }
    payload = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    (args.out / "manifest.json").write_bytes(payload)
    print("H64_BYTE_LM_TRAIN_PASS " + json.dumps({
        "corpus_sha256": corpus_hash, "float": float_metrics, "int8": int_metrics,
        "bigram_accuracy": bigram, "model_sha256": sha(package_path.read_bytes()),
        "out": str(args.out)}, sort_keys=True))


if __name__ == "__main__":
    main()
