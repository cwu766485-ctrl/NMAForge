"""Archive selected public evidence for the GEMM/LN scheduling experiment.

Use --prefix /tmp/nmaforge-opt after the commands in the owning report.
Build products, coverage, libraries and environment/credential data are excluded.
"""
import argparse
import collections
import csv
import gzip
import hashlib
import json
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--prefix', type=Path, required=True)
parser.add_argument('--out', type=Path, default=Path('benchmark/representative/schedule_optimization'))
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
prefix = str(args.prefix)


def source(suffix):
    return Path(prefix + suffix)


def archive(suffix, dest):
    raw = source(suffix).read_bytes()
    path = args.out / dest
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.suffix == '.gz':
        raw = gzip.compress(raw, mtime=0)
    elif path.suffix == '.csv':
        raw = raw.replace(b'\r\n', b'\n')
    path.write_bytes(raw)


def csv_write(name, rows):
    with (args.out / name).open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator='\n')
        writer.writeheader()
        writer.writerows(rows)


baseline = list(csv.DictReader(source('-base/session/persistent_decode.csv').open()))
rows = []
for variant, suffix in [('baseline', '-base'), ('matrix_only', '-matrix-ablation'), ('final', '-accepted')]:
    data = list(csv.DictReader(source(suffix + '/session/persistent_decode.csv').open()))
    assert len(data) == len(baseline) == 8
    for before, after in zip(baseline, data):
        for key in ['top_logits_sha256', 'top_kv_physical_sha256', 'expected_kv_physical_sha256']:
            assert before[key] == after[key], (variant, key)
        assert after['top_logits_bit_exact'] == 'True'
    total = sum(int(item['cycles']) for item in data)
    rows.append(dict(variant=variant, cycles=total, cycles_per_token=total / 8,
                     spad_read_bytes=sum(int(x['spad_read_bytes']) for x in data),
                     spad_write_bytes=sum(int(x['spad_write_bytes']) for x in data),
                     golden='PASS same logits and KV hashes'))
    for name in ['persistent_decode.csv', 'persistent_decode.json', 'opcode_profile.csv', 'opcode_profile.json']:
        archive(suffix + '/session/' + name, variant + '/' + name)
    archive(suffix + '/session/top_session.log', variant + '/session.log.gz')
    archive(suffix + '/compile.log', variant + '/compile.log.gz')
csv_write('decode_ablation.csv', rows)

# Verify actual accepted-request ownership from the trace, not inferred FSM counts.
trace_summary = []
for variant, suffix in [('baseline', '-matrix-trace-base'), ('final', '-matrix-accepted')]:
    queue = collections.deque()
    counts = collections.Counter()
    for row in csv.DictReader(source(suffix + '/trace.csv').open()):
        if row['response'] == '1':
            assert queue
            assert queue.popleft() == (row['response_operand_b'], row['response_address'])
            counts['responses'] += 1
        if row['accept'] == '1':
            queue.append((row['operand_b'], row['address']))
            counts['requests'] += 1
        if len({entry[0] for entry in queue}) > 1:
            counts['mixed_operand_outstanding_cycles'] += 1
    assert not queue and counts['requests'] == counts['responses'] == 480
    trace_summary.append(dict(variant=variant, requests=counts['requests'], responses=counts['responses'],
                              mixed_operand_outstanding_cycles=counts['mixed_operand_outstanding_cycles']))
    archive(suffix + '/trace.csv', variant + '/matrix_trace.csv.gz')
    archive(suffix + '/shapes.log', variant + '/matrix_random.log.gz')
csv_write('trace_validation.csv', trace_summary)

# All matrix state counts are exclusive; prefetch counters are overlapping observations.
matrix_rows = []
for variant, suffix in [('baseline', '-fixed-base.log'), ('final', '-accepted-fixed.log')]:
    for line in source(suffix).read_text().splitlines():
        if not line.startswith('MATRIX_CORE_PROFILE '):
            continue
        d = {k: int(v) for k, v in re.findall(r'(\w+)=(\d+)', line)}
        buckets = dict(input_fetch=d['a_req'] + d['a_wait'] + d['b_req'] + d['b_wait'] + d['bias_req'] + d['bias_wait'],
                       compute=d['prep_mac'] + d['mac'], writeback=d['write'],
                       prefetch_wait=d['prefetch_wait'], lifecycle=d['next'] + d['done'] + d['error'] + d['error_drain'])
        assert sum(buckets.values()) == d['total']
        matrix_rows.append(dict(variant=variant, case_id=d['id'], **buckets, total=d['total']))
    archive(suffix, variant + '/matrix_fixed.log.gz')
csv_write('matrix_exclusive_phases.csv', matrix_rows)

files = [
    ('-fixed-gemv-base.log', 'baseline/gemv_fixed.log.gz'),
    ('-accepted-fixed-gemv.log', 'final/gemv_fixed.log.gz'),
    ('-isolated-gemv-base.log', 'baseline/gemv_isolated.log.gz'),
    ('-isolated-gemv-final.log', 'final/gemv_isolated.log.gz'),
    ('-cnn-base.log', 'baseline/cnn.log.gz'), ('-accepted-cnn.log', 'final/cnn.log.gz'),
    ('-common-cnn-final/run.log', 'final/common_cnn.log.gz'),
    ('-tiny/run.log', 'tiny/array.log.gz'), ('-tiny/engine_regression.log', 'tiny/engines.log.gz'),
    ('-accepted-smoke.log', 'validation/smoke.log.gz'), ('-accepted-seeded.log', 'validation/seeded.log.gz'),
    ('-sfu-base-lint.log', 'validation/sfu_baseline_lint.log.gz'),
    ('-sfu-lint.log', 'validation/sfu_final_lint.log.gz'),
    ('-matrix-base-lint.log', 'validation/matrix_baseline_lint.log.gz'),
    ('-accepted-matrix-lint.log', 'validation/matrix_final_lint.log.gz'),
    ('-depth2/run.log', 'validation/matrix_depth2.log.gz'),
    ('-no-prefetch-driver.log', 'validation/no_prefetch.log.gz'),
]
# Tiny's upstream engine regression log name is discovered explicitly by its runner.
for suffix, dest in files:
    archive(suffix, dest)
for seed in [20261109, 20261110, 20261111]:
    for suffix, dest in [('-matrix-accepted/run_seed_%d.log', 'matrix_%d.log.gz'),
                         ('-matrix-accepted/product_gemv_seed_%d.log', 'gemv_%d.log.gz'),
                         ('-sfu/seed_%d/run.log', 'sfu_%d.log.gz')]:
        archive(suffix % seed, 'validation/' + dest % seed)
for path in sorted(source('-qkv').iterdir()):
    if path.suffix in ['.json', '.memh', '.log']:
        dest = 'qkv/' + path.name + ('.gz' if path.suffix == '.log' else '')
        archive('-qkv/' + path.name, dest)

rtl_paths = ['rtl/compute/matrix/ai_tensor_matrix_core.v', 'rtl/compute/sfu/ai_tensor_sfu_core.v']
manifest = dict(baseline_sha='9095832f049629dbfb3ee8a6f10839cdb50f4aa4',
                source_parent_sha=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
                source_tree_dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], text=True)),
                rtl_sha256={name: hashlib.sha256(Path(name).read_bytes()).hexdigest() for name in rtl_paths},
                tinynpu_sha='8216c22b762011aa20c05fc2768423fd12dda59d',
                model_sha256=hashlib.sha256(Path('benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json').read_bytes()).hexdigest(),
                tools={'VCS': 'V-2023.12-SP1_Full64', 'Verilator': '5.052', 'Python': '3.12.13'},
                status='DESIGN_PARTIAL', decode=rows,
                timing_limit='NMA controller/SPAD vs Tiny direct array are different endpoints; no system speedup',
                artifacts={str(p.relative_to(args.out)): {'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                           for p in sorted(args.out.rglob('*')) if p.is_file() and p.name != 'manifest.json'})
(args.out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('SCHEDULE_OPTIMIZATION_ARCHIVE_PASS same Golden; traces ordered; exclusive states closed')
