#!/usr/bin/env python3
"""Replay the checked-in Gate2 evidence without VCS; do not replace RTL tests."""
import csv,gzip,hashlib,io,json
from pathlib import Path
r=Path(__file__).resolve().parents[3];a=r/'benchmark/research/phase4';m=json.loads((a/'manifest.json').read_text())
for p,h in m['source_sha256'].items():assert hashlib.sha256((r/p).read_bytes()).hexdigest()==h,p
for p,h in m['artifact_sha256'].items():assert hashlib.sha256((a/p).read_bytes()).hexdigest()==h,p
def rows(p):return list(csv.DictReader(io.StringIO(gzip.decompress(p.read_bytes()).decode())))
g=list(csv.DictReader((r/'benchmark/research/phase3/model/cnn_transactions.csv').open()))
for v in ['baseline','optimized']:
 ls=rows(a/v/'cnn/both_fused_row_major/profile_lines.csv.gz');assert len(ls)==1040
 assert [(x['address'],x['data'],x['wstrb'])for x in ls]==[(x['address'],x['golden_payload'],x['wstrb'])for x in g]
 s=json.loads((a/v/'summary.json').read_text())
 assert s['cnn_both_fused_row_major']['cycles']==(12351 if v=='baseline'else 11376)
 assert all(sum(x['exclusive'].values())==x['cycles']for x in s.values())
 assert s['h32']['cycles']==350155 and s['h16']['cycles']==65771
lint=json.loads((a/'lint.json').read_text())
for top in ['matrix','top']:assert lint['baseline-'+top]==lint['optimized-'+top]
for mode in ['directed-final','disabled']:
 for seed in [20261021,20261022,20261023]:
  for prefix,mark in [('directed','PHASE4_WRITEBACK_RTL_PASS'),('random','MATRIX_CORE_RANDOM_PASS cases=18 faults=35'),('opcode-fault','MATRIX_V2_OPCODE_FAULT_PASS')]:
   s=gzip.decompress((a/mode/f'{prefix}-{seed}.log.gz').read_bytes()).decode();assert mark in s and 'Fatal:'not in s
print('PHASE4_PUBLIC_EVIDENCE_PASS source hashes, 1040 payloads, cycles, Golden, faults and lint ablation')
