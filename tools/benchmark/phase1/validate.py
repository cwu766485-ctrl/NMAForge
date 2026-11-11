#!/usr/bin/env python3
"""Verify public evidence hashes and exact closure after checkout."""
import csv,gzip,hashlib,io,json
from pathlib import Path
root=Path(__file__).resolve().parents[3];d=root/'benchmark/research/phase1';m=json.loads((d/'manifest.json').read_text())
for e in m['evidence']:
 p=d/e['path'];raw=p.read_bytes();assert hashlib.sha256(raw).hexdigest()==e['sha256'],p
 if p.suffix=='.gz':raw=gzip.decompress(raw)
 assert hashlib.sha256(raw).hexdigest()==e['uncompressed_sha256'],p
for f,h in m['sources'].items():assert hashlib.sha256((root/f).read_bytes()).hexdigest()==h,f
s=json.loads((d/'analysis/summary.json').read_text())
for k,v in s.items():assert sum(v['exclusive'].values())==v['cycles'],k
for r in csv.DictReader((d/'analysis/golden_checks.csv').open()):assert r['golden_sha256']==r['observed_sha256'] and r['status']=='PASS'
matched=json.loads((d/'matched/matched.json').read_text());assert len(matched)==12
for r in matched:assert r['golden']=='PASS' and r['system_speedup']is None
assert s['h16']['cycles']==65771 and s['cnn_both_fused_row_major']['cycles']==12351 and s['h32']['cycles']==367051
assert json.loads((d/'model/blind_quality.json').read_text())['status']=='PASS'
print('PHASE1_PUBLIC_EVIDENCE_PASS hashes/exclusive windows/Golden/matched boundary/quality')
