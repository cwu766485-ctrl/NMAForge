"""Validate archived hashes, cycle/traffic closure and comparison eligibility."""
import argparse
import collections
import csv
import gzip
import hashlib
import io
import json
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--archive', type=Path, default=Path('benchmark/research/stage_a'))
a = p.parse_args()
m = json.loads((a.archive/'manifest.json').read_text())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def check_comparison(c):
    if c['classification'] in ('NOT_COMPARABLE', 'MIXED_MEASURED_MODELED'):
        assert c.get('system_speedup') is None and c.get('cycle_ratio') is None, c['id']
    if c.get('cycle_ratio') is not None:
        assert c['classification'] == 'MATCHED_COMPUTE' and c['ratio_scope'] == 'array_only'
        n = c.get('nma_cycles', c.get('nma_cycles_per_projection'))
        t = c.get('tiny_cycles', c.get('tiny_cycles_per_projection'))
        assert c['cycle_ratio'] == t/n
    if c.get('status') in ('NOT_RUN', 'NOT_MEASURED'):
        assert c.get('system_speedup') is None and c.get('cycle_ratio') is None

for name, sha in m['artifact_hashes'].items():
    assert digest(a.archive/name) == sha, name
for name, sha in {**m['source_hashes'], **m['model_hashes']}.items():
    assert digest(Path(name)) == sha, name
assert subprocess.check_output(['git','rev-parse','HEAD:rtl'],text=True).strip() == m['nmaforge']['rtl_tree_git']
assert not subprocess.check_output(['git','diff','HEAD','--','rtl/'])
for comparison in m['comparisons']:
    check_comparison(comparison)
# Sensitivity: invalid benchmark labels must not silently pass the validator.
for cls in ('NOT_COMPARABLE', 'MIXED_MEASURED_MODELED'):
    invalid = dict(id='deliberate_invalid_ratio', classification=cls, system_speedup=2)
    try:
        check_comparison(invalid)
    except AssertionError:
        pass
    else:
        raise AssertionError('eligibility guard did not reject invalid ratio')

def rows(path):
    return list(csv.DictReader((a.archive/path).open()))
phases = rows('analysis/exclusive_phases.csv')
counts = collections.Counter()
for r in phases:
    counts[r['workload'],r['stage']] += int(r['cycles'])
workloads = rows('analysis/workload_counters.csv')
for row in workloads:
    assert counts['h16',row['stage']] == int(row['cycles'])
assert sum(int(r['cycles']) for r in workloads[1:]) == 65771
assert sum(int(r['read_bytes']) for r in workloads[1:]) == 72448
assert sum(int(r['write_bytes']) for r in workloads[1:]) == 42112
for row in rows('analysis/cnn_accounting.csv'):
    assert counts['cnn_'+row['mode'],'cmdq'] == int(row['cycles'])
    assert int(row['output_readback_cycles']) == 4992
    assert row['output_sha256'] == '04b138d012cc69ccdbd28dfb2c36f187bf0c6b7e91596dd088d4e93641c3a5f6'
# Independently close byte traces against counters, including all CNN mappings.
for prefix, expected in [('h16/h16', workloads)] + [
        ('cnn/'+r['mode']+'/profile', [r]) for r in rows('analysis/cnn_accounting.csv')]:
    with gzip.open(a.archive/(prefix+'_cycles.csv.gz'),'rt') as f:
        cycles = collections.Counter(int(r['window']) for r in csv.DictReader(f))
    traffic = collections.Counter()
    with gzip.open(a.archive/(prefix+'_traffic.csv.gz'),'rt') as f:
        for r in csv.DictReader(f): traffic[int(r['window']),r['write']] += int(r['bytes'])
    for window, r in enumerate(expected):
        assert cycles[window] == int(r['cycles'])
        assert traffic[window,'0'] == int(r.get('read_bytes',r.get('spad_read')))
        assert traffic[window,'1'] == int(r.get('write_bytes',r.get('spad_write')))
for r in json.loads((a.archive/'analysis/larger_model_budget.json').read_text()):
    assert sum(r['storage_bytes'].values()) == r['total_bytes']
    assert r['margin_bytes'] == 131072-r['total_bytes']
print('STAGE_A_MANIFEST_PASS hashes; unchanged product RTL; exclusive cycle/traffic closure; budgets; ratio rejection sensitivity')
