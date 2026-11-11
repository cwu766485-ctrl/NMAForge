#!/usr/bin/env python3
"""Allowlist public Phase2 results; never copy simulator/coverage/private assets."""
import argparse, gzip, hashlib, json, shutil
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[3];dest=root/'benchmark/research/phase2';dest.mkdir(parents=True,exist_ok=True)
def copy(src,rel,compress=False):
 target=dest/rel
 if compress:target=Path(str(target)+'.gz')
 target.parent.mkdir(parents=True,exist_ok=True)
 raw=src.read_bytes();target.write_bytes(gzip.compress(raw,mtime=0) if compress else raw)
for label in ['baseline','optimized']:
 base=a.run/label
 for f in (base/'analysis').iterdir():
  if f.suffix in ['.json','.csv']:copy(f,Path(label)/'analysis'/f.name)
 for f in base.rglob('*'):
  if not f.is_file() or 'top' in f.relative_to(base).parts[:-1]:continue
  rel=f.relative_to(base)
  if f.name.endswith(('_cycles.csv','_memory.csv','_traffic.csv','_axi.csv')) or f.name in ['top.log','top_session.log','independent.log','smoke.log']:
   copy(f,Path(label)/rel,True)
  elif f.name.endswith('.command.json') or f.name in ['manifest.json','shape.json']:
   copy(f,Path(label)/rel)
  elif rel.parts[0] in ['h32','h32_old'] and f.name.endswith(('_golden.memh','_observed.memh')):
   copy(f,Path(label)/rel,True)
 for name in ['compile.log','compile.stdout']:copy(base/'top'/name,Path(label)/'build'/name,True)
for f in (a.run/'analysis').iterdir():copy(f,Path('analysis')/f.name)
for f in (a.run/'streaming').iterdir():copy(f,Path('streaming')/f.name)
for label in ['ln32','ln32-baseline']:
 for name in ['oracle.json','vectors.txt','mean.txt','variance.txt','run.log','compile.log']:
  copy(a.run/label/name,Path('directed')/label/name,compress=name.endswith('.log'))
for label in ['sfu-baseline','sfu-optimized']:
 for f in (a.run/label).glob('seed_*/*'):
  if f.name in ['run.log','sfu_vectors.txt']:copy(f,Path('regression')/label/f.relative_to(a.run/label),True)
for f in a.run.glob('*.log'):copy(f,Path('logs')/f.name,True)
copy(a.run/'blind_quality.json',Path('quality')/'blind_quality.json')
for f in (a.run/'matched').iterdir():
 if f.suffix in ['.json','.csv'] or f.name.endswith(('_nma.log','_tiny.log')):
  copy(f,Path('matched')/f.name,compress=f.suffix=='.log')
# Phase1 static helper's hardcoded product_rtl_changed=false is not a Phase2 audit.
static=json.loads((a.run/'static/summary.json').read_text())
static['product_rtl_changed']=True
static['phase2_note']='Raw helper baseline.log is current LN32 candidate; only its counts/diagnostics reused. Hardcoded Phase1 product_rtl_changed=false replaced; no diagnostic patch is product RTL.'
(dest/'metadata/static-summary.json').write_text(json.dumps(static,indent=2)+'\n')
copy(a.run/'static/baseline.log',Path('metadata/top-lint.log'),True)
paths=list((root/'rtl').rglob('*.v'))+list((root/'tools/benchmark/phase2').glob('*'))+[root/'dv/block/compute/sfu/tb/tb_phase2_ln32.sv']
paths += [f for f in (root/'benchmark/research/phase1').rglob('*') if f.is_file()]
source={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(paths) if f.is_file()}
(dest/'metadata/source_sha256.json').write_text(json.dumps(source,indent=2)+'\n')
manifest={str(f.relative_to(dest)):hashlib.sha256(f.read_bytes()).hexdigest()for f in sorted(dest.rglob('*'))if f.is_file()and f.name!='sha256.json'}
(dest/'sha256.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PHASE2_PUBLIC_ARCHIVE_PASS files='+str(len(manifest)))
