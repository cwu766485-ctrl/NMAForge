#!/usr/bin/env python3
"""Replay existing exact fixtures after observer-only rebuild; do not regenerate."""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args();sim=a.run/'top/simv'
cmd=json.loads((a.run/'h16/persistent_decode.json').read_text())['sim_command']
with (a.run/'h16/top_session.log').open('w')as f:subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,check=True)
s=(a.run/'h16/top_session.log').read_text();assert 'H16_INCREMENTAL_TOP_PASS' in s and 'Fatal:'not in s
print('h16 PASS',flush=True)
for label in ['h32_old','h32']:
 d=a.run/label;cmd=json.loads((d/'top.command.json').read_text())
 with (d/'top.log').open('w')as f:subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,check=True)
 s=(d/'top.log').read_text();assert 'STAGE_C_TOP_PASS'in s and 'Fatal:'not in s
 print(label,'PASS',flush=True)
