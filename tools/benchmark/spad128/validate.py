#!/usr/bin/env python3
"""Validate published artifacts, recorded source identity and regression results."""
import csv,gzip,hashlib,json
from pathlib import Path
r=Path('benchmark/research/spad128');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for rel,d in json.loads((r/'evidence_sha256.json').read_text()).items():assert sha(r/rel)==d,rel
m=json.loads((r/'manifest.json').read_text())
for rel,d in m['source_sha256'].items():assert sha(Path(rel))==d,rel
for row in csv.DictReader((r/'regression.csv').open()):
 assert row['result']=='PASS' and sha(r/row['evidence'])==row['evidence_sha256']
 if row['test'] in ('bad_depth','bad_banks','bad_row','bad_capacity'):
  assert 'Fatal:' in gzip.decompress((r/row['evidence']).read_bytes()).decode()
assert m['static_warnings_baseline']==m['static_warnings_candidate']
h16=json.loads((r/'h16/persistent_decode.json').read_text());assert h16['total_decode_cycles']==65771
h32=json.loads((r/'h32/analysis/summary.json').read_text());assert h32['decode']['cycles']==367788
assert h32['all_intermediate_logits_kv_golden']=='PASS'
assert json.loads((r/'digits/golden.json').read_text())['independent_integer_golden']=='PASS'
print('SPAD128_VALIDATE_PASS gate01=PASS_SCOPED gate2=DEFERRED static=UNCHANGED_WARNINGS')
