#!/usr/bin/env python3
"""Build temporary RTL mutants and require v2 Matrix checkers to reject them."""

import argparse
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys


MUTATIONS = {
    "output_data": {
        "old": "line_wdata = fused_requant_output ? fused_line_buffer_r :\n"
              "                     {write_result3,write_result2,write_result1,write_result0};",
        "new": "line_wdata = fused_requant_output ? (fused_line_buffer_r ^ 128'd1) :\n"
              "                     {write_result3,write_result2,write_result1,write_result0};",
        "plusarg": "+MATRIX_TILE_FORWARD_CHAIN_ONLY",
        "checker": r"tile-forward producer SPAD image",
    },
    "output_address": {
        "old": "line_addr = write_row_addr;",
        "new": "line_addr = write_row_addr + 32'd16;",
        "plusarg": "+MATRIX_TILE_FORWARD_CHAIN_ONLY",
        "checker": r"tile-forward producer SPAD image",
    },
    "response_operand_owner": {
        "old": "wire response_operand_b = response_meta[51];",
        "new": "wire response_operand_b = ~response_meta[51];",
        "plusarg": "+MATRIX_GEMV_ABLATION_M4_SHAPE",
        "checker": r"product GEMV completion error=",
    },
    "wstrb": {
        "old": "assign line_wstrb = 16'hffff;",
        "new": "assign line_wstrb = 16'hfffe;",
        "plusarg": "+MATRIX_TILE_FORWARD_CHAIN_ONLY",
        "checker": r"Matrix v1 line port emitted unsupported WSTRB=",
    },
    "tile_tag": {
        "old": "tile_forward_tag_base_r <= dst_batch_base_r;",
        "new": "tile_forward_tag_base_r <= dst_batch_base_r + 32'd16;",
        "plusarg": "+MATRIX_TILE_FORWARD_CHAIN_ONLY",
        "checker": r"tile-forward valid rose before a full tagged capture committed",
    },
    "early_tile_valid": {
        "old": "tile_forward_capture_mask_r[tile_forward_capture_line_index] <= 1'b1;",
        "new": "tile_forward_capture_mask_r[tile_forward_capture_line_index] <= 1'b1;\n"
               "                if (tile_forward_capture_line_index == 4'd0)\n"
               "                  tile_forward_valid_r <= 1'b1;",
        "plusarg": "+MATRIX_TILE_FORWARD_CHAIN_ONLY",
        "checker": r"tile-forward valid rose before a full tagged capture committed",
    },
    "request_address_hold": {
        "old": "banked_addr = a_read_addr;",
        "new": "banked_addr = banked_ready ? a_read_addr : (a_read_addr + cycle_count);",
        "plusarg": "+MATRIX_V2_OPCODE_HANDSHAKE_ONLY",
        "checker": r"Matrix bank request address changed while stalled",
    },
}


def run(command, cwd, env, log_path, timeout):
    with log_path.open("w") as log:
        return subprocess.run(command, cwd=str(cwd), env=env, stdout=log,
                              stderr=subprocess.STDOUT, timeout=timeout).returncode


def mutate_once(text, old, new, name):
    count = text.count(old)
    if count != 1:
        raise RuntimeError("{} expected one source match, found {}".format(name, count))
    return text.replace(old, new, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="isolated temporary output directory")
    parser.add_argument("--vcs", default=os.environ.get("VCS", "vcs"))
    parser.add_argument("--vcs-home", default=os.environ.get("VCS_HOME", "/opt/Synopsys/vcs/V-2023.12-SP1"))
    parser.add_argument("--seeds", nargs="+", default=["20261105", "20261106", "20261107"])
    parser.add_argument("--timeout", type=int, default=300)
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[5]
    sim_dir = Path(__file__).resolve().parent
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    vcs = shlex.split(args.vcs)
    if not vcs:
        raise RuntimeError("VCS command is empty")
    env = os.environ.copy()
    env["VCS_HOME"] = args.vcs_home
    env.setdefault("VCS_ARCH_OVERRIDE", "linux")

    datapath = root / "rtl/compute/matrix/ai_tensor_matrix_datapath.v"
    array = root / "rtl/compute/matrix/ai_tensor_matrix_array.sv"
    core = root / "rtl/compute/matrix/ai_tensor_matrix_core.v"
    tb = root / "dv/block/compute/matrix/tb/tb_ai_tensor_matrix_core_random.sv"
    core_text = core.read_text()
    results = []

    for name, spec in MUTATIONS.items():
        variant = out / name
        variant.mkdir(parents=True, exist_ok=True)
        mutant_core = variant / core.name
        mutant_core.write_text(mutate_once(core_text, spec["old"], spec["new"], name))
        compile_db = variant / "compile.vdb"
        binary = variant / "simv"
        compile_cmd = vcs + [
            "-full64", "-sverilog", "-debug_access+all", "-timescale=1ns/1ps",
            "-assert", "enable_diag",
            "+define+MATRIX_MAX_OUTSTANDING_READS=4",
            "+define+MATRIX_A_TILE_CACHE_ENABLE=1",
            "+define+MATRIX_NEXT_K_PREFETCH_ENABLE=1",
            "+define+MATRIX_GEMV_B_TILE_CACHE_ENABLE=1",
            "+define+MATRIX_ARRAY_SIZE=16",
            "+define+MATRIX_ELASTIC_TILE_FORWARDING_ENABLE=1",
            "-cm", "line+cond+fsm+branch+assert", "-cm_dir", str(compile_db),
            "-Mdir=" + str(variant / "csrc"), "-top", "tb_ai_tensor_matrix_core_random",
            str(datapath), str(array), str(mutant_core), str(tb),
            "-o", str(binary), "-l", str(variant / "compile.log"),
        ]
        compile_rc = run(compile_cmd, sim_dir, env, variant / "compile.stdout.log", args.timeout)
        if compile_rc != 0 or not binary.is_file():
            raise RuntimeError("{} mutant compile failed; see {}".format(name, variant / "compile.log"))

        for seed in args.seeds:
            run_log = variant / ("run_seed_{}.log".format(seed))
            run_cmd = [
                str(binary), "+SEED=" + seed, spec["plusarg"],
                "-assert", "report=" + str(variant / ("assertions_seed_{}.rpt".format(seed))) + "+verbose",
                "-cm", "line+cond+fsm+branch+assert", "-cm_dir", str(variant / "run.vdb"),
                "-cm_name", "v2_mutant_{}_{}".format(name, seed), "-l", str(run_log),
            ]
            run(run_cmd, sim_dir, env, variant / ("run_seed_{}.stdout.log".format(seed)), args.timeout)
            log = run_log.read_text(errors="replace")
            if not re.search(spec["checker"], log):
                raise RuntimeError("{} mutant escaped its assigned checker at seed {}; see {}".format(
                    name, seed, run_log))
            if ("MATRIX_TILE_FORWARD_CHAIN_ONLY_PASS" in log or
                    "MATRIX_GEMV_ABLATION_PASS" in log or
                    "MATRIX_V2_OPCODE_HANDSHAKE_PASS" in log):
                raise RuntimeError("{} mutant reached the normal PASS marker at seed {}".format(name, seed))
            results.append((name, seed, spec["checker"]))
            print("V2_OPCODE_MUTATION_CAUGHT mutation={} checker={} seed={}".format(
                name, spec["checker"], seed))

    summary = out / "summary.txt"
    summary.write_text("\n".join("{} seed={}: {}".format(name, seed, checker)
                                  for name, seed, checker in results) + "\n")
    print("V2_OPCODE_MUTATION_CAMPAIGN_PASS: {}/{} mutant-seed checks caught; "
          "mutants={} seeds={}; artifacts={}".format(
              len(results), len(MUTATIONS) * len(args.seeds),
              len(MUTATIONS), ",".join(args.seeds), out))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        sys.exit(1)
