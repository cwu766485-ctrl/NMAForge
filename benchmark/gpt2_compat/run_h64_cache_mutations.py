#!/usr/bin/env python3
"""Run eight expected-fail Product Top cache-dependency mutation controls."""
from __future__ import annotations

import argparse
import shlex
import subprocess
from pathlib import Path


def command_from_run_log(path: Path) -> list[str]:
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("Command: "):
            return shlex.split(line[len("Command: "):])
    raise ValueError(f"no simulator Command line in {path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-log", type=Path, required=True,
                        help="successful G1 run.log containing the exact simv command")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    base = command_from_run_log(args.run_log)
    if not base or not base[0].endswith("/simv"):
        raise ValueError("run command does not invoke a simv executable")
    args.out.mkdir(parents=True, exist_ok=False)
    results = []
    for head in range(4):
        for kind, kind_name in ((0, "K"), (1, "V")):
            log_path = args.out / f"head{head}_{kind_name}.log"
            command = [item for item in base]
            filtered: list[str] = []
            index = 0
            while index < len(command):
                if command[index] == "-l":
                    index += 2
                    continue
                filtered.append(command[index])
                index += 1
            command = filtered + [
                "+AI_H64_PERSISTENT_CORRUPT_CACHE",
                f"+AI_H64_PERSISTENT_CORRUPT_CACHE_HEAD={head}",
                f"+AI_H64_PERSISTENT_CORRUPT_CACHE_KIND={kind}",
            ]
            with log_path.open("w", encoding="utf-8") as stream:
                subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                               check=False)
            log = log_path.read_text(encoding="utf-8", errors="replace")
            injected = f"H64_PERSISTENT_KV_MUTATION_INJECTED head={head} kind={kind}"
            mismatch = "H64_PERSISTENT_TENSOR_MISMATCH" in log
            terminal_pass = ("H64_PERSISTENT_TWO_TOKEN_PASS" in log or
                             "H64_PERSISTENT_SEQUENCE_PASS" in log)
            passed = injected in log and mismatch and not terminal_pass
            results.append({"head": head, "kind": kind_name,
                            "negative_control": "PASS" if passed else "FAIL",
                            "injection_observed": injected in log,
                            "dependent_golden_mismatch_observed": mismatch,
                            "terminal_pass_observed": terminal_pass,
                            "log": str(log_path)})
            print(f"H64_CACHE_MUTATION {'PASS' if passed else 'FAIL'} "
                  f"head={head} kind={kind_name} golden_mismatch={mismatch} "
                  f"terminal_pass={terminal_pass} log={log_path}")
            if not passed:
                raise SystemExit(1)
    print(f"H64_CACHE_MUTATION_MATRIX_PASS cases={len(results)}")


if __name__ == "__main__":
    main()
