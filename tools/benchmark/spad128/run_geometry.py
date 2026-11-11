#!/usr/bin/env python3
"""Check valid elaboration and required time-zero rejection; no SRAM workload."""
import argparse, json, subprocess
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--out', type=Path, required=True); a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
sources=['rtl/memory/ai_scratchpad.v','rtl/memory/ai_spad_protection.v',
 'rtl/memory/ai_spad_arbiter.v','rtl/top/fabric/memory/ai_spad_response_demux.v',
 'rtl/top/fabric/memory/ai_accel_spad_subsystem.v','rtl/top/fabric/memory/ai_accel_memory_fabric.v',
 'tools/benchmark/spad128/tb_geometry.sv']
results=[]
for name,defs,valid in [('128k',[],True),('512k',['DEPTH=32768'],True),
 ('bad_depth',['DEPTH=12288'],False),('bad_banks',['BANKS=8'],False),
 ('bad_row',['ROW_WIDTH=12'],False),('bad_capacity',['CAPACITY=524288'],False)]:
 d=a.out/name;d.mkdir(exist_ok=True)
 cmd=['vcs','-full64','-sverilog','-timescale=1ns/1ps','+define+VCS']+['+define+'+x for x in defs]+[
 '-Mdir='+str(d/'csrc'),'-top','tb_spad_geometry']+sources+['-o',str(d/'simv'),'-l',str(d/'compile.log')]
 (d/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 with (d/'stdout.log').open('w') as f:subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,check=True)
 r=subprocess.run([str(d/'simv'),'-l',str(d/'run.log')],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 text=(d/'run.log').read_text()
 assert (r.returncode==0 and 'SPAD_GEOMETRY_VALID' in text) if valid else ('Fatal:' in text and 'SPAD_GEOMETRY_VALID' not in text), (name,text)
 results.append(dict(test=name,result='PASS',expected='valid' if valid else 'fatal',exit_code=r.returncode))
 print(name,'PASS')
(a.out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
