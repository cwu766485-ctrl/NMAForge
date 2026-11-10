"""Validate hashes and enforce that failed Gate 0 cannot become a speedup claim."""
import argparse
import csv
import gzip
import hashlib
import json
import subprocess
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--archive',type=Path,default=Path('benchmark/research/stage_b'))
a=p.parse_args();m=json.loads((a.archive/'manifest.json').read_text())
for name,sha in m['artifacts'].items():assert hashlib.sha256((a.archive/name).read_bytes()).hexdigest()==sha,name
for name,sha in m['source_hashes'].items():assert hashlib.sha256(Path(name).read_bytes()).hexdigest()==sha,name
assert m['decision']=='REJECT' and not m['cache_rtl_implemented'] and not m['product_rtl_changed']
assert not subprocess.check_output(['git','diff',m['baseline_commit'],'--','rtl/'])
assert m['results']['b2_rtl_cycles'] is None and m['results']['cache_hits_rtl'] is None
s=json.loads((a.archive/'model/summary.json').read_text())
assert s['eligible_leases']==64 and s['eligible_reads']==2048 and s['strict_removable_reads']==0
sweep=list(csv.DictReader((a.archive/'model/latency_hit_invalidation_sweep.csv').open()))
assert len(sweep)==47
for r in sweep:
    assert r['rtl_measured']=='False'
    assert int(r['hits'])+int(r['misses'])==2048
    assert int(r['estimated_decode_clocks'])==65771-int(r['net_estimated_saved_clocks'])
    if r['gate0_qualified']=='True':assert int(r['net_estimated_saved_clocks'])<=0
    else:assert r['mode']=='IDEAL_BYPASS_UNAPPROVED'
log=gzip.decompress((a.archive/'contract/run.log.gz').read_bytes()).decode()
for marker in ['STAGE_B_PARITY_COUNTEREXAMPLE_PASS','STAGE_B_PROTECTION_COUNTEREXAMPLE_PASS',
               'STAGE_B_DENIED_WRITE_PASS','STAGE_B_GATE0_RTL_PASS']:
    assert marker in log
assert json.loads((a.archive/'baseline/same_golden.json').read_text())['token_metrics_identical']
phases=list(csv.DictReader((a.archive/'baseline/analysis/exclusive_phases.csv').open()))
assert sum(int(r['cycles']) for r in phases if r['workload']=='h16' and r['stage']!='prefill_kv_0_3')==65771
print('STAGE_B_VALIDATION_PASS hashes, baseline Golden/phase closure, model-only bounds, no disallowed B2 result claims')
