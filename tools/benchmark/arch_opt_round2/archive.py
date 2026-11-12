#!/usr/bin/env python3
"""Archive portable evidence, verify paired decisions and exact B-read counts."""
import argparse,csv,gzip,hashlib,json,shutil
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--runs',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
r=list(csv.DictReader((a.runs/'paired/results.csv').open()))
lookup={(int(x['m']),int(x['k']),x['policy']):x for x in r}
for m in (1,4,8,16):
 for k in (16,32,64,128):
  selected=lookup[m,k,'shape-aware'];base=lookup.get((m,k,'legacy'))
  if base:
   assert selected['golden_sha256']==base['golden_sha256'] and int(selected['cycles'])<=int(base['cycles'])
for m in (8,16):
 for k in (63,64,65,96,127,128,129):
  row=lookup[m,k,'legacy'];expected=max(k-64,0)*16*(m//4-1)
  assert int(row['b_repeated_bytes'])==expected,(m,k,row,expected)
shutil.copy(a.runs/'paired/results.csv',a.out/'results.csv')
shutil.copy(a.runs/'paired/manifest.json',a.out/'manifest.json')
for d in (a.runs/'paired').iterdir():
 if not d.is_dir():continue
 target=a.out/'runs'/d.name;target.mkdir(parents=True,exist_ok=True)
 for f in d.iterdir():
  if f.name in ('top.log','command.json','image.memh','golden.memh','profile_memory.csv','profile_cycles.csv','b_addresses.csv'):
   with gzip.open(target/(f.name+'.gz'),'wb') as out:out.write(f.read_bytes())
for f in (a.runs/'fault').glob('*seed_*.log'):
 target=a.out/'fault';target.mkdir(exist_ok=True)
 with gzip.open(target/(f.name+'.gz'),'wb') as out:out.write(f.read_bytes())
for name in ('smoke-driver.log','fault-driver.log','paired-driver.log'):
 with gzip.open(a.out/(name+'.gz'),'wb') as out:out.write((a.runs/name).read_bytes())
files={str(f.relative_to(a.out)):hashlib.sha256(f.read_bytes()).hexdigest() for f in a.out.rglob('*') if f.is_file() and f.name!='SHA256.json'}
(a.out/'SHA256.json').write_text(json.dumps(files,indent=2)+'\n')
print('ROUND2_ARCHIVE_PASS exact_B_boundary=14 selected_no_regressions=16')
