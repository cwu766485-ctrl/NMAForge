#!/usr/bin/env python3
"""Validate timestamp closure and preserve text evidence with source hashes."""
import argparse,csv,gzip,hashlib,json
from pathlib import Path
import subprocess
p=argparse.ArgumentParser();p.add_argument('--runs',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parents[3]
for suite in ('suite','revised','backpressure'):
 rows=list(csv.DictReader((a.runs/suite/'results.csv').open()));assert len(rows)==34
 for r in rows:
  ts=[int(r[k]) for k in ('start','loaded','cmd_begin','completed','consumed','output_begin','end')]
  assert ts==sorted(ts) and int(r['total'])==ts[-1]-ts[0] and int(r['output_cycles'])==ts[-1]-ts[-2]
  text=(a.runs/suite/r['name']/'top.log').read_text()
  assert 'REPRESENTATIVE_MODEL_PASS' in text and 'SYSTEM_TIMELINE_PASS' in text and 'Fatal:' not in text and 'SVA FAIL' not in text
 for m in (1,4,8,16):
  for k in (16,32,64,128):
   pair=[r for r in rows if r['m']==str(m) and r['k']==str(k)];assert pair[0]['golden_sha256']==pair[1]['golden_sha256']
 for f in (a.runs/suite).rglob('*'):
  if f.is_file() and f.suffix in ('.csv','.json','.log','.memh'):
   target=a.out/suite/f.relative_to(a.runs/suite);target.parent.mkdir(parents=True,exist_ok=True)
   with gzip.open(str(target)+'.gz','wb') as out:out.write(f.read_bytes())
for name in ('smoke.log','seeded.log','fault.log','fault-replay.log','sfu-review.log'):
 with gzip.open(a.out/(name+'.gz'),'wb') as out:out.write((a.runs/name).read_bytes())
for directory in ('fault','sfu/review'):
 for f in (a.runs/directory).rglob('*.log'):
  target=a.out/directory/f.relative_to(a.runs/directory);target.parent.mkdir(parents=True,exist_ok=True)
  with gzip.open(str(target)+'.gz','wb') as out:out.write(f.read_bytes())
source_files=[root/'sw/tools/shape_aware_dispatch.py',root/'dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv']+list((root/'tools/benchmark/final_ab').glob('*.py'))
manifest=dict(base_sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),rtl_tree=subprocess.check_output(['git','rev-parse','HEAD:rtl'],text=True).strip(),source_files={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in source_files},tool='VCS V-2023.12-SP1_Full64',python='3.12.13',spad_bytes=131072,banks=4,macs=256,clock_ns=4,scope='behavioral serialized hardware timeline; CPU layout wall time separate; no ASIC Fmax',fault_limit='seed20261116 forward stress nonvacuity failure retained; known three-seed replay passes; output-DMA dedicated error injection not closed')
(a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
files={str(f.relative_to(a.out)):hashlib.sha256(f.read_bytes()).hexdigest() for f in a.out.rglob('*') if f.is_file() and f.name!='SHA256.json'}
(a.out/'SHA256.json').write_text(json.dumps(files,indent=2)+'\n')
print('FINAL_AB_ARCHIVE_PASS suites=3 runs=102 golden_pairs=48 timestamp_closure=102')
