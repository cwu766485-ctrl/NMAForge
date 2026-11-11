#!/usr/bin/env python3
"""Check public hashes and paired cycle/transaction/Golden evidence, without EDA."""
import collections,csv,gzip,hashlib,io,json,re
from pathlib import Path
root=Path(__file__).resolve().parents[3];base=root/'benchmark/research/phase2'
def read(p):return p.read_bytes() if p.suffix!='.gz' else gzip.decompress(p.read_bytes())
def rows(p):return csv.DictReader(io.StringIO(read(p).decode()))
def load(p):return json.loads(p.read_text())
for rel,h in load(base/'sha256.json').items():assert hashlib.sha256((base/rel).read_bytes()).hexdigest()==h,rel
for rel,h in load(base/'metadata/source_sha256.json').items():assert hashlib.sha256((root/rel).read_bytes()).hexdigest()==h,rel
summaries=[load(base/label/'analysis/summary.json')for label in ['baseline','optimized']]
for summary in summaries:
 for name,r in summary.items():assert sum(r['exclusive'].values())==r['cycles'],name
assert summaries[0]['h32']['cycles']==367051 and summaries[1]['h32']['cycles']==350155
for name,b in summaries[0].items():
 c=summaries[1][name];assert b['read_bytes']==c['read_bytes']and b['write_bytes']==c['write_bytes'],name
 if name not in ['h32','h32_old']:assert b['cycles']==c['cycles'],name
for f in (base/'baseline').rglob('*_memory.csv.gz'):
 rel=f.relative_to(base/'baseline');other=base/'optimized'/rel
 def sequence(p):return [tuple(r[k]for k in ['window','client','write','address','bytes','bank_mask'])for r in rows(p)if int(r['window'])>=0 and r['kind']=='A']
 assert sequence(f)==sequence(other),rel
for label in ['baseline','optimized']:
 for f in (base/label).rglob('*_cycles.csv.gz'):
  name=f.relative_to(base/label).parts[0]
  if name=='h16_profile':name='h16'
  elif name=='cnn':name='cnn_'+f.relative_to(base/label).parts[1]
  cycles=sum(1 for r in rows(f)if int(r['window'])>=(4 if name.startswith('h32') else 1 if name=='h16' else 0))
  assert cycles==summaries[['baseline','optimized'].index(label)][name]['cycles'],(name,cycles)
 for name in ['h32','h32_old']:
  for i in range(12):
   stem=f'stage_{i}_t{i}_';gold=read(base/label/name/(stem+'golden.memh.gz'))
   assert read(base/label/name/(stem+'observed.memh.gz'))==gold
   assert read(base/'baseline'/name/(stem+'golden.memh.gz'))==gold
for label in ['ln32','ln32-baseline']:
 log=read(base/'directed'/label/'run.log.gz').decode()
 for marker in ['PHASE2_LN32_DIRECTED_PASS','vectors=41 faults=11','PHASE2_LN32_MEAN_PASS cases=1231','PHASE2_LN32_VARIANCE_PASS cases=1208']:assert marker in log,(label,marker)
 assert 'Fatal:' not in log
for f in (base/'regression').rglob('run.log.gz'):
 log=read(f).decode();assert 'SFU_RANDOM_LATENCY_PASS' in log and 'Fatal:'not in log,f
matched=load(base/'matched/matched.json');assert len(matched)==12
assert all(r['golden']=='PASS'and r['system_speedup']is None for r in matched)
model=load(base/'streaming/summary.json');assert model['ln32']['modeled_saved_cycles']==43504
assert model['ln32']['predicted_full_decode_cycles']==306651
assert model['decision']=='MODEL_BENEFIT_SHOWN_NOT_RTL_ADMITTED_PENDING_FAULT_TIMING_REVIEW'
assert load(base/'quality/blind_quality.json')['status']=='PASS'
print('PHASE2_PUBLIC_EVIDENCE_PASS hashes/cycles/traffic/ordered-accesses/Golden/faults/model')
