#!/usr/bin/env python3
"""Official DeiT-Tiny accuracy under the NMAForge numeric contract.

Evaluates facebook/deit-tiny-patch16-224 (pinned checkpoint SHA-256
e1a51b0c...) top-1 on the public Imagenette validation split, whose ten
classes are ImageNet-1k classes (prediction over all 1000 logits).  Contract
switches mirror benchmark/gpt2_official/ptq_contract_study.py and reuse its
bit-exact LAYERNORM_Q15 / exp2 Softmax / GELU contract functions.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "gpt2_official"))
from ptq_contract_study import (LOG2E, exp2_pwl_q15, gelu_q8_8_t,  # noqa: E402
                                layernorm_q15_t, pow2_scale)

torch.set_grad_enabled(False)
IMAGENETTE_TO_IMAGENET = {
    "n01440764": 0, "n02102040": 217, "n02979186": 482, "n03000684": 491,
    "n03028079": 497, "n03394916": 566, "n03417042": 569, "n03425413": 571,
    "n03445777": 574, "n03888257": 701,
}
MEAN = torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
STD = torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)


def load_image(path: Path) -> torch.Tensor:
    from PIL import Image
    img = Image.open(path).convert("RGB")
    w, h = img.size
    s = 256 / min(w, h)
    img = img.resize((max(256, round(w * s)), max(256, round(h * s))), Image.BICUBIC)
    w, h = img.size
    l, t = (w - 224) // 2, (h - 224) // 2
    img = img.crop((l, t, l + 224, t + 224))
    x = torch.from_numpy(np.asarray(img, dtype=np.float32) / 255.0).permute(2, 0, 1)
    return (x - MEAN) / STD


def gelu_erf(x):
    return 0.5 * x * (1.0 + torch.erf(x / math.sqrt(2.0)))


class DeitInt:
    def __init__(self, sd: dict, cfg: dict):
        self.sd = {k.removeprefix("vit."): v.float().clone() for k, v in sd.items()}
        self.cfg, self.D, self.H, self.L = cfg, 192, 3, 12
        self.act_absmax: dict[str, float] = {}
        self.calibrating = False
        self.qw = {}

    def build_weights(self):
        if not self.cfg["w8"]:
            return
        for k, w in self.sd.items():
            if k.endswith(".weight") and w.dim() == 2 and "layernorm" not in k:
                wt = w.T  # [in, out]
                if self.cfg["w8"] == "pc":
                    s = wt.abs().amax(0, keepdim=True) / 127.0
                else:
                    gs = 16 if wt.shape[1] % 16 == 0 else 8   # Matrix 16-column tiles
                    g = wt.abs().reshape(wt.shape[0], -1, gs).amax((0, 2)) / 127.0
                    s = pow2_scale(g).repeat_interleave(gs)[None, :]
                s = s.clamp(min=1e-12)
                self.qw[k] = torch.clamp(torch.round(wt / s), -127, 127) * s

    def scale(self, name):
        s = max(self.act_absmax[name], 1e-8) / 127.0
        return float(pow2_scale(torch.tensor(s))) if self.cfg["a8"] == "p2" else s

    def qact(self, name, x):
        if self.calibrating:
            v = torch.quantile(x.abs().flatten()[:2_000_000], 0.9999).item()
            self.act_absmax[name] = max(self.act_absmax.get(name, 0.0), v)
            return x
        if not self.cfg["a8"]:
            return x
        s = self.scale(name)
        return torch.clamp(torch.round(x / s), -128, 127) * s

    def linear(self, x, prefix):
        w = self.qw.get(prefix + ".weight") if not self.calibrating else None
        w = self.sd[prefix + ".weight"].T if w is None else w
        return x @ w + self.sd[prefix + ".bias"]

    def res(self, x):
        if self.cfg["res"] and not self.calibrating:
            f = 2.0 ** self.cfg["res_frac"]
            return torch.round(x * f) / f
        return x

    def layernorm(self, x, prefix, out_name):
        g, b = self.sd[prefix + ".weight"], self.sd[prefix + ".bias"]
        if not self.cfg["ln"] or self.calibrating:
            y = torch.nn.functional.layer_norm(x, (self.D,), g, b, 1e-12)
            return self.qact(out_name, y)
        f = 2.0 ** self.cfg["res_frac"]
        rb = self.cfg.get("ln_round_bits", 0)
        s_out = self.scale(out_name) if self.cfg["a8"] else 1.0 / 32.0
        xi = torch.round(x * f).to(torch.int64)
        gq = torch.round(g * 32768.0 * (1 << rb) / s_out).to(torch.int64)
        bq = torch.round(b * (1 << rb) / s_out).to(torch.int64) + ((1 << rb) >> 1)
        yi = layernorm_q15_t(xi, gq, bq, 1) >> rb
        if self.cfg["a8"]:
            yi = yi.clamp(-128, 127)
        return yi.to(torch.float32) * s_out

    def block(self, i, x):
        p = f"encoder.layer.{i}"
        T = x.shape[0]
        h = self.layernorm(x, p + ".layernorm_before", p + ".qkv.in")
        q = self.linear(h, p + ".attention.attention.query")
        k = self.linear(h, p + ".attention.attention.key")
        v = self.linear(h, p + ".attention.attention.value")
        hd = self.D // self.H
        q = self.qact(p + ".q", q).view(T, self.H, hd).transpose(0, 1)
        k = self.qact(p + ".k", k).view(T, self.H, hd).transpose(0, 1)
        v = self.qact(p + ".v", v).view(T, self.H, hd).transpose(0, 1)
        att = (q @ k.transpose(-1, -2)) / math.sqrt(hd)
        if self.cfg["sm"] and not self.calibrating:
            s88 = torch.round(att * LOG2E * 256.0).to(torch.int64)
            e = exp2_pwl_q15(s88 - s88.amax(-1, keepdim=True))
            q15 = torch.div(e << 15, e.sum(-1, keepdim=True), rounding_mode="floor").clamp(0, 32768)
            if self.cfg["sm"] == "q7":
                probs = (q15 >> 8).clamp(0, 127).float() / 128.0
            elif self.cfg["sm"] == "q7r":
                probs = ((q15 + 128) >> 8).clamp(0, 127).float() / 128.0
            elif self.cfg["sm"] == "u8r":
                probs = ((q15 + 64) >> 7).clamp(0, 255).float() / 256.0
            else:
                probs = q15.float() / 32768.0
        else:
            probs = torch.softmax(att, -1)
        y = (probs @ v).transpose(0, 1).reshape(T, self.D)
        y = self.linear(self.qact(p + ".o.in", y), p + ".attention.output.dense")
        x = self.res(x + y)
        h = self.layernorm(x, p + ".layernorm_after", p + ".fc1.in")
        u = self.linear(h, p + ".intermediate.dense")
        if self.calibrating:
            self.qact(p + ".fc1.out", u)
            u = gelu_erf(u)
        elif self.cfg["gelu"] == "pwl":
            u = gelu_q8_8_t(torch.round(u * 256).to(torch.int64)).float() / 256.0
        elif self.cfg["gelu"] == "lut8":
            s = max(self.act_absmax[p + ".fc1.out"], 1e-8) / 127.0
            u = gelu_erf(torch.clamp(torch.round(u / s), -128, 127) * s)
        else:
            u = gelu_erf(u)
        u = self.linear(self.qact(p + ".fc2.in", u), p + ".output.dense")
        return self.res(x + u)

    def forward(self, img):
        patches = img.unfold(1, 16, 16).unfold(2, 16, 16)          # 3,14,14,16,16
        patches = patches.permute(1, 2, 0, 3, 4).reshape(196, 768)
        w = self.sd["embeddings.patch_embeddings.projection.weight"].reshape(192, 768)
        if not self.calibrating and self.cfg["w8"]:
            key = "embeddings.patch_embeddings.projection.weight"
            if key not in self.qw:
                wt = w.T
                s = (pow2_scale(wt.abs().amax(0) / 127.0) if self.cfg["w8"] != "pc"
                     else wt.abs().amax(0) / 127.0).clamp(min=1e-12)
                self.qw[key] = torch.clamp(torch.round(wt / s), -127, 127) * s
            wt = self.qw[key]
        else:
            wt = w.T
        e = self.qact("patch.in", patches) @ wt + self.sd["embeddings.patch_embeddings.projection.bias"]
        x = torch.cat([self.sd["embeddings.cls_token"][0], e], 0) + self.sd["embeddings.position_embeddings"][0]
        x = self.res(x)
        for i in range(self.L):
            x = self.block(i, x)
        h = self.layernorm(x[:1], "layernorm", "head.in")
        return (h @ (self.qw.get("classifier.weight") if not self.calibrating and self.cfg["w8"]
                     else self.sd["classifier.weight"].T) + self.sd["classifier.bias"])[0]


CONFIGS = {
    "fp32": dict(w8=None, a8=None, res=False, ln=False, sm=None, gelu=None),
    "w8a8_pow2": dict(w8="g16p2", a8="p2", res=False, ln=False, sm=None, gelu=None),
    "full_contract_q7_pwl": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q7", gelu="pwl"),
    "ln_rnd_q7_pwl": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q7", gelu="pwl", ln_round_bits=4),
    "ln_rnd_q15_pwl": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu="pwl", ln_round_bits=4),
    "ln_rnd_q15_lut8": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q15", gelu="lut8", ln_round_bits=4),
    "ln_rnd_q7_lut8": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q7", gelu="lut8", ln_round_bits=4),
    "ln_rnd_q7r_lut8": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="q7r", gelu="lut8", ln_round_bits=4),
    "ln_rnd_u8r_lut8": dict(w8="g16p2", a8="p2", res=True, ln=True, sm="u8r", gelu="lut8", ln_round_bits=4),
    "epi_ln_rnd_u8r_lut8": dict(w8="pc", a8="f", res=True, ln=True, sm="u8r", gelu="lut8", ln_round_bits=4),
    "epi_ln_rnd_q15_lut8": dict(w8="pc", a8="f", res=True, ln=True, sm="q15", gelu="lut8", ln_round_bits=4),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", type=Path, required=True)
    ap.add_argument("--val-dir", type=Path, required=True)
    ap.add_argument("--per-class", type=int, default=50)
    ap.add_argument("--calib", type=int, default=16)
    ap.add_argument("--res-frac", type=int, default=8)
    ap.add_argument("--configs", default=",".join(CONFIGS))
    ap.add_argument("--out", type=Path, required=True)
    a = ap.parse_args()
    sd = torch.load(a.checkpoint, map_location="cpu", weights_only=True)
    items = []
    calib_paths = []
    for wnid, idx in sorted(IMAGENETTE_TO_IMAGENET.items()):
        files = sorted((a.val_dir / wnid).glob("*.JPEG"))
        items += [(f, idx) for f in files[:a.per_class]]
        calib_paths += files[-max(1, a.calib // 10):]          # disjoint tail images
    imgs = [load_image(f) for f, _ in items]
    labels = torch.tensor([y for _, y in items])
    calib = [load_image(f) for f in calib_paths]
    res = {"model": "facebook/deit-tiny-patch16-224", "images": len(items),
           "calib_images": len(calib), "configs": {}}
    for name in a.configs.split(","):
        t0 = time.time()
        m = DeitInt(sd, dict(CONFIGS[name], res_frac=a.res_frac))
        m.calibrating = True
        for c in calib:
            m.forward(c)
        m.calibrating = False
        m.build_weights()
        pred = torch.stack([m.forward(x).argmax() for x in imgs])
        acc = (pred == labels).float().mean().item()
        res["configs"][name] = {"top1": acc, **CONFIGS[name]}
        print(f"DEIT_RESULT config={name} top1={acc*100:.2f}% images={len(items)} "
              f"seconds={time.time()-t0:.0f}", flush=True)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(res, indent=2))


if __name__ == "__main__":
    main()
