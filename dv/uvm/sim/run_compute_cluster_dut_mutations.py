#!/usr/bin/env python3
"""Build temporary RTL mutants and require the real Compute Cluster checker to catch each."""

import argparse
import os
from pathlib import Path
import re
import subprocess
import sys


MUTATIONS = {
    "address": {
        "source": "rtl/top/fabric/compute/ai_compute_spad_mux.v",
        "replacements": [(
            "spad_addr = req_addr[selected_owner*32 +: 32];",
            "spad_addr = req_addr[selected_owner*32 +: 32] + 32'd4;",
        )],
        "checker": r"CLUSTER_(MEMORY_UNKNOWN|GOLDEN)",
    },
    "data": {
        "source": "rtl/top/fabric/compute/ai_compute_spad_mux.v",
        "replacements": [(
            "spad_wdata = req_wdata[selected_owner*32 +: 32];",
            "spad_wdata = req_wdata[selected_owner*32 +: 32] ^ 32'h0000_0001;",
        )],
        "checker": r"CLUSTER_(GOLDEN|MEMORY_MISMATCH)",
    },
    "response_owner": {
        "source": "rtl/top/fabric/compute/ai_compute_spad_mux.v",
        "replacements": [
            (
                "engine_rsp_valid[response_owner_r]",
                "engine_rsp_valid[(response_owner_r == 3'd6) ? 3'd0 : response_owner_r + 3'd1]",
            ),
            (
                "engine_rsp_rdata[response_owner_r*32 +: 32]",
                "engine_rsp_rdata[((response_owner_r == 3'd6) ? 3'd0 : response_owner_r + 3'd1)*32 +: 32]",
            ),
            (
                "engine_rsp_error[response_owner_r]",
                "engine_rsp_error[(response_owner_r == 3'd6) ? 3'd0 : response_owner_r + 3'd1]",
            ),
        ],
        "checker": r"CLUSTER_ENGINE_RESPONSE_OWNER",
    },
    "wstrb": {
        "source": "rtl/compute/matrix/ai_tensor_matrix_core.v",
        "replacements": [
            ("assign line_wstrb = 16'hffff;", "assign line_wstrb = 16'hfffe;")
        ],
        "checker": r"CLUSTER_(MATRIX_WSTRB|GOLDEN)",
    },
    "completion_error": {
        "source": "rtl/control/queue/ai_parallel_compute_dispatcher.v",
        "replacements": [
            ("fifo_error_code_r[fifo_head_r] : 4'd0;",
             "fifo_error_code_r[fifo_head_r] : 4'd1;")
        ],
        "checker": r"CLUSTER_COMPLETION_ERROR_CODE",
    },
}


def replace_exactly_once(text, old, new, name):
    count = text.count(old)
    if count != 1:
        raise RuntimeError("{} expected one source match, found {}: {}".format(name, count, old))
    return text.replace(old, new, 1)


def run(command, cwd, env, log_path, timeout):
    with log_path.open("w") as log:
        result = subprocess.run(command, cwd=str(cwd), env=env, stdout=log,
                                stderr=subprocess.STDOUT, timeout=timeout)
    return result.returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="temporary output directory")
    parser.add_argument("--vcs-home", default=os.environ.get(
        "VCS_HOME", "/opt/Synopsys/vcs/V-2023.12-SP1"))
    parser.add_argument("--seed", default="20261025")
    parser.add_argument("--timeout", type=int, default=300,
                        help="maximum seconds for each compile and simulation")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[3]
    sim_dir = root / "dv/uvm/sim"
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    vcs = Path(args.vcs_home) / "bin/vcs"
    if not vcs.is_file():
        raise RuntimeError("VCS executable not found: {}".format(vcs))

    env = os.environ.copy()
    env["VCS_HOME"] = args.vcs_home
    env.setdefault("VCS_ARCH_OVERRIDE", "linux")
    base_filelist = (sim_dir / "ai_accel_uvm.f").read_text()
    common = [
        str(vcs), "-full64", "-sverilog", "-ntb_opts", "uvm-1.2",
        "-debug_access+all", "-kdb", "-timescale=1ns/1ns", "+define+VCS",
        "-cm", "line+cond+branch+fsm+assert",
    ]

    results = []
    for name, spec in MUTATIONS.items():
        variant_dir = out / name
        variant_dir.mkdir(parents=True, exist_ok=True)
        source_rel = spec["source"]
        source = root / source_rel
        mutated_text = source.read_text()
        for old, new in spec["replacements"]:
            mutated_text = replace_exactly_once(mutated_text, old, new, name)

        mutant_source = variant_dir / source.name
        mutant_source.write_text(mutated_text)
        filelist_entry = "../../../" + source_rel
        if base_filelist.count(filelist_entry) != 1:
            raise RuntimeError("{} filelist entry is missing or ambiguous".format(filelist_entry))
        filelist = variant_dir / "ai_accel_uvm_mutant.f"
        filelist.write_text(base_filelist.replace(filelist_entry, str(mutant_source)))

        compile_db = variant_dir / "compile.vdb"
        binary = variant_dir / "simv_uvm"
        compile_cmd = common + [
            "-cm_dir", str(compile_db), "-Mdir=" + str(variant_dir / "csrc"),
            "-top", "tb_ai_accel_uvm", "-f", str(filelist), "-o", str(binary),
            "-l", str(variant_dir / "compile.log"),
        ]
        compile_rc = run(compile_cmd, sim_dir, env, variant_dir / "compile.stdout.log",
                         args.timeout)
        if compile_rc != 0 or not binary.is_file():
            raise RuntimeError("{} mutant compile failed; see {}".format(
                name, variant_dir / "compile.log"))

        run_db = variant_dir / "run.vdb"
        run_cmd = [
            str(binary), "+UVM_TESTNAME=ai_compute_cluster_e2e_test",
            "+COMPUTE_CLUSTER_SEED=" + args.seed,
            "+ntb_random_seed=" + args.seed,
            "-cm", "line+cond+branch+fsm+assert", "-cm_dir", str(run_db),
            "-l", str(variant_dir / "run.log"),
        ]
        # UVM deliberately terminates each mutant with $finish after the expected
        # checker reports an error; VCS may therefore return zero on a caught mutant.
        run(run_cmd, sim_dir, env, variant_dir / "run.stdout.log", args.timeout)
        with (variant_dir / "run.log").open("r", errors="replace") as log_file:
            log = log_file.read()
        expected = re.compile(r"UVM_(?:ERROR|FATAL).*\[{}\]".format(spec["checker"]))
        match = expected.search(log)
        if not match:
            raise RuntimeError("{} mutant escaped its checker or hit a different checker; see {}".format(
                name, variant_dir / "run.log"))
        if "[COMPUTE_CLUSTER_REAL_UVM_PASS]" in log:
            raise RuntimeError("{} mutant reached the normal PASS marker".format(name))
        result_line = match.group(0).splitlines()[0]
        results.append((name, result_line))
        print("DUT_MUTATION_CAUGHT name={} checker={}".format(name, result_line))

    summary = out / "summary.txt"
    summary.write_text("\n".join("{}: {}".format(name, checker)
                                  for name, checker in results) + "\n")
    print("COMPUTE_CLUSTER_DUT_MUTATION_PASS: {}/{} real RTL mutants caught; logs={}".format(
        len(results), len(MUTATIONS), out))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print("ERROR: {}".format(error), file=sys.stderr)
        sys.exit(1)
