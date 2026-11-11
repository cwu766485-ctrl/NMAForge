#!/usr/bin/env python3
"""Audit warning identities plus a diagnostic COPY; product RTL is never edited."""
import argparse,collections,json,re,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--verilator',required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);root=Path.cwd();filelist=root/'dv/subsystem/top_smoke/sim/ai_accel.f'
files=[(filelist.parent/s.strip()).resolve() for s in filelist.read_text().splitlines() if s.strip()]
base=['--lint-only','--timing','-Wno-fatal','+define+VCS','--top-module','ai_accel_top']
for name,edit in [('baseline',False),('diagnostic_default',True)]:
 paths=[]
 for f in files:
  if edit and f.name=='ai_compute_spad_mux.v':
   dst=a.out/f.name;dst.write_text(f.read_text().replace('    always @(*) begin','    always @(*) begin\n        candidate = 0;',1));paths.append(dst)
  else:paths.append(f)
 cmd=[a.verilator]+base+[str(x) for x in paths]
 with (a.out/(name+'.log')).open('w') as log:subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,check=True)
text=(a.out/'baseline.log').read_text();diagnostic=(a.out/'diagnostic_default.log').read_text()
counts=lambda s:dict(collections.Counter(re.findall(r'%Warning-([A-Z0-9_]+)',s)))
expected={'PINMISSING':2,'WIDTHTRUNC':64,'WIDTHEXPAND':113,'CASEINCOMPLETE':4,'LATCH':10,'UNOPTFLAT':3};assert counts(text)==expected
summary={'baseline':counts(text),'diagnostic_copy':counts(diagnostic),'product_rtl_changed':False,'diagnostic':'candidate=0 default in throwaway copy only; not admitted RTL repair','findings':re.findall(r'(%Warning-[^\n]+)',text)}
(a.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items() if k!='findings'},indent=2))
