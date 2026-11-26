#!/usr/bin/env python3
"""Check TinyNPU outputs and write the matched operator comparison."""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
from pathlib import Path

NMA_NAME = {0x35: "gelu", 0x32: "softmax", 0x38: "layernorm", 0x34: "residual",
            0x36: "requant"}
TINY_NAME = {0: "gelu", 1: "softmax", 2: "layernorm", 3: "residual"}


def s8(text: str):
    if "x" in text.lower() or "z" in text.lower():
        return None  # 4-state unknown observed in VCS
    v = int(text, 16)
    return v - 256 if v >= 128 else v


def gelu_ref(x: int) -> int:
    # Same formula as TinyNPU tb_engines.cpp gelu_ref / gelu_lut.sv ROM.
    xf = x / 32.0
    r = round(xf * 0.5 * (1.0 + math.erf(xf / math.sqrt(2.0))) * 32.0)
    return max(-128, min(127, r))


def pearson(a, b) -> float:
    n = len(a)
    ma, mb = sum(a) / n, sum(b) / n
    va = sum((x - ma) ** 2 for x in a)
    vb = sum((y - mb) ** 2 for y in b)
    if va == 0 or vb == 0:
        return float("nan")
    return sum((x - ma) * (y - mb) for x, y in zip(a, b)) / math.sqrt(va * vb)


def check_tiny(case, raw):
    op, x, y = case["op"], case["x"], case["y"]
    unknown = sum(v is None for v in raw)
    out = [0 if v is None else v for v in raw]
    ok, note = _check(op, x, y, out)
    if unknown:
        note += f" unknown_x_outputs={unknown}"
    return ok and (unknown == 0 or op == "layernorm"), note


def _check(op, x, y, out):
    if op == "gelu":
        err = max(abs(o - gelu_ref(v)) for o, v in zip(out, x))
        return err <= 5, f"max_abs_err={err} (TinyNPU own tolerance 5)"
    if op == "residual":
        bad = sum(o != max(-128, min(127, a + b)) for o, a, b in zip(out, x, y))
        return bad == 0, f"exact_saturating_add_mismatches={bad}"
    if op == "softmax":
        ref = [math.exp(v - max(x)) for v in x]
        s = sum(ref)
        ref = [r / s for r in ref]
        ok = all(o >= 0 for o in out) and any(o > 0 for o in out)
        corr = pearson(out, ref)
        return ok, (f"tiny_criterion(non_negative,has_positive)={ok} "
                    f"out_sum={sum(out)} pearson_vs_float={corr:.4f}")
    if op == "layernorm":
        # Scale-free checks: a correct LayerNorm makes (out - beta) track
        # (x - mean).  The diagnostic also tests the observed one-element
        # output offset against beta.
        m = sum(x) / len(x)
        corr_norm = pearson([o - b for o, b in zip(out, y)], [v - m for v in x])
        corr_beta_shift1 = pearson(out[1:], y[:-1])
        valid = corr_norm > 0.9
        return True, (f"tiny_criterion(completes)=True gamma=hardwired_127 "
                      f"pearson(out-beta,x-mean)={corr_norm:.4f} "
                      f"pearson(out[i+1],beta[i])={corr_beta_shift1:.4f} "
                      f"layernorm_numerically_valid={valid}")
    raise AssertionError(op)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()
    out = Path(args.out_dir)

    legacy = {}
    legacy_log = out / "nma_legacy_run.log"
    if legacy_log.exists():
        for line in legacy_log.read_text().splitlines():
            m = re.match(r"NMA_OP_PERF op=(\w+) length=(\d+) cycles=(\d+) .*mismatches=0", line)
            if m:
                legacy[(NMA_NAME[int(m[1], 16)], int(m[2]))] = int(m[3])
    nma = {}
    for line in (out / "nma_run.log").read_text().splitlines():
        m = re.match(r"NMA_OP_PERF op=(\w+) length=(\d+) cycles=(\d+) .*reads=(\d+) "
                     r"writes=(\d+) golden_words=(\d+) mismatches=(\d+)", line)
        if m:
            name = NMA_NAME[int(m[1], 16)]
            nma[(name, int(m[2]))] = {"cycles": int(m[3]), "reads": int(m[4]),
                                      "writes": int(m[5]), "mismatches": int(m[7])}

    cases = json.loads((out / "tiny_vectors.json").read_text())
    lines = (out / "tiny_outputs.txt").read_text().split("\n")
    tiny, pos = {}, 0
    for case in cases:
        sel, n, cyc = map(int, lines[pos].split())
        assert sel == case["sel"] and n == case["length"], (sel, n, case["op"])
        vals = [s8(v) for v in lines[pos + 1:pos + 1 + n]]
        pos += 1 + n
        ok, note = check_tiny(case, vals)
        tiny[(case["op"], n)] = {"cycles": cyc, "ok": ok, "note": note}

    rows = []
    for (name, n), r in sorted(nma.items()):
        t = tiny.get((name, n))
        rows.append({
            "op": name, "length": n,
            "nma_legacy_cycles": legacy.get((name, n), ""),
            "nma_legacy_cycles_per_elem": (round(legacy[(name, n)] / n, 2)
                                           if (name, n) in legacy else ""),
            "nma_cycles": r["cycles"], "nma_cycles_per_elem": round(r["cycles"] / n, 2),
            "nma_reads": r["reads"], "nma_writes": r["writes"],
            "nma_check": "exact_golden_pass" if r["mismatches"] == 0 else "FAIL",
            "tiny_cycles": t["cycles"] if t else "",
            "tiny_cycles_per_elem": round(t["cycles"] / n, 2) if t else "",
            "tiny_check": ("PASS " if t["ok"] else "FAIL ") + t["note"] if t else "no_tiny_engine",
            "tiny_over_nma": round(t["cycles"] / r["cycles"], 3) if t else "",
        })
    with (out / "transformer_ops_results.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    for r in rows:
        print("TRANSFORMER_OP_ROW " + " ".join(f"{k}={v}" for k, v in r.items()
                                               if k not in ("tiny_check",)))
    fails = [r for r in rows if r["nma_check"] != "exact_golden_pass" or
             (r["tiny_check"] and r["tiny_check"].startswith("FAIL"))]
    print(f"TRANSFORMER_OPS_SUMMARY rows={len(rows)} check_failures={len(fails)}")


if __name__ == "__main__":
    main()
