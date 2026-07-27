#!/usr/bin/env bash

set -u

SEEDS="${SEEDS:-101 202 303 404 505}"
RANDOM_SRAM_CASES="${RANDOM_SRAM_CASES:-50}"
RANDOM_VECTOR_CASES="${RANDOM_VECTOR_CASES:-4}"
REG_DIR="${REG_DIR:-regression}"
COV_DIR="${REG_DIR}/regression.vdb"

mkdir -p "${REG_DIR}"
rm -rf "${COV_DIR}"

pass_count=0
fail_count=0

echo "Regression seeds       : ${SEEDS}"
echo "Random SRAM pairs      : ${RANDOM_SRAM_CASES}"
echo "Random vector cases    : ${RANDOM_VECTOR_CASES}"

for seed in ${SEEDS}; do
  log="${REG_DIR}/seed_${seed}.log"
  echo "[RUN] seed=${seed}"

  ./simv \
    +ntb_random_seed="${seed}" \
    +RANDOM_SRAM_CASES="${RANDOM_SRAM_CASES}" \
    +RANDOM_VECTOR_CASES="${RANDOM_VECTOR_CASES}" \
    -cm line+fsm+tgl+cond+branch \
    -cm_dir "${COV_DIR}" \
    -cm_name "seed_${seed}" \
    -l "${log}" >/dev/null 2>&1

  if grep -q "TEST PASS" "${log}" &&
     grep -q "ERROR count = 0" "${log}" &&
     ! grep -q "SVA FAIL" "${log}" &&
     ! grep -q "\[ERROR\]" "${log}"; then
    coverage="$(grep "Functional coverage" "${log}" | tail -1 | sed 's/.*= //')"
    echo "[PASS] seed=${seed}, functional_coverage=${coverage}"
    pass_count=$((pass_count + 1))
  else
    echo "[FAIL] seed=${seed}, inspect ${log}"
    fail_count=$((fail_count + 1))
  fi
done

if command -v urg >/dev/null 2>&1; then
  urg -dir "${COV_DIR}" -report "${REG_DIR}/urg_report" >/dev/null 2>&1 || true
fi

echo "Regression PASS seeds  : ${pass_count}"
echo "Regression FAIL seeds  : ${fail_count}"

if [ "${fail_count}" -ne 0 ]; then
  exit 1
fi
