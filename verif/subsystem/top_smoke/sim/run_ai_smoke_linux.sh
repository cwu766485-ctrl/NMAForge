#!/usr/bin/env bash
# Run inside the Linux-resident CIMForge checkout.  It is intentionally small:
# environment/module setup stays with the owner of the licensed WSL image.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../../../.." && pwd)"
results_dir="${script_dir}/results"
seed="${AI_SEED:-20260722}"
random_cases="${AI_RANDOM_CASES:-0}"

find_python() {
    if [[ -n "${PYTHON_BIN:-}" ]]; then
        printf '%s\n' "${PYTHON_BIN}"
        return 0
    fi
    local candidate
    for candidate in python3.12 python3.11 python3.10 python3.9 python3.8 python3; do
        if command -v "${candidate}" >/dev/null 2>&1 &&
           "${candidate}" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 7) else 1)'; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done
    return 1
}

if ! command -v vcs >/dev/null 2>&1; then
    echo "ERROR: vcs is not on PATH. Source the WSL EDA/module environment first." >&2
    exit 127
fi
if ! python_bin="$(find_python)"; then
    echo "ERROR: Python 3.7 or newer is required for the fixed-point reference gate." >&2
    exit 127
fi

mkdir -p "${results_dir}"
cd "${script_dir}"

"${python_bin}" ../../../block/compute/matrix/ref/ai_a3_reference.py --cases "${AI_REF_CASES:-1000}" \
    --seed "${AI_REF_SEED:-20260722}" | tee "${results_dir}/a4_reference.log"

if ! vcs -ID >"${results_dir}/vcs_preflight.log" 2>&1; then
    echo "ERROR: VCS preflight failed; see ${results_dir}/vcs_preflight.log" >&2
    cat "${results_dir}/vcs_preflight.log" >&2
    exit 126
fi

make ai_comp | tee "${results_dir}/ai_comp.log"
./simv +ntb_random_seed="${seed}" +AI_RANDOM_CASES="${random_cases}" \
    +AI_SEED="${seed}" -l "${results_dir}/ai_quick.log"

grep -q "TEST PASS" "${results_dir}/ai_quick.log"
echo "CIMFORGE_A4_VCS_QUICK_PASS seed=${seed} random_cases=${random_cases}"
