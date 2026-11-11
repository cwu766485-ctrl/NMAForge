#!/usr/bin/env python3
"""Replay immutable Phase1 public fixtures using a chosen product Top binary."""
import argparse,gzip,json,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[3];src=root/'benchmark/research/phase1';a.out.mkdir(parents=True,exist_ok=True);old='/tmp/nmaforge-phase1-runs';sim=a.out/'top/simv'
for prefix in ['h32','h32_old','h16','cnn','h16_profile']+[d.name for d in src.glob('kernel_*')]:
 for f in (src/prefix).rglob('*'):
  if not f.is_file():continue
  rel=f.relative_to(src)
  if f.name.endswith(('_cycles.csv.gz','_memory.csv.gz','_traffic.csv.gz','_axi.csv.gz','.log.gz')):continue
  dst=a.out/rel;data=f.read_bytes()
  if f.suffix=='.gz':dst=dst.with_suffix('');data=gzip.decompress(data)
  dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(data)
def execute(cmd,log,marker):
 log.with_suffix('.command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 with log.open('w')as f:subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,check=True)
 text=log.read_text();assert marker in text and 'Fatal:'not in text and 'TEST FAIL'not in text,(log,marker)
 print(log.parent.name,marker,flush=True)
for d in sorted(a.out.glob('kernel_*'))+list((a.out/'cnn').iterdir())+[a.out/'h32_old',a.out/'h32']:
 cmd=json.loads((d/'top.command.json').read_text());cmd=[x.replace(old,str(a.out)) for x in cmd];cmd[0]=str(sim)
 execute(cmd,d/'top.log','STAGE_C_TOP_PASS' if d.name.startswith('h32') else 'REPRESENTATIVE_MODEL_PASS')
 if d.name.startswith('h32'):
  for i in range(12):assert (d/f'stage_{i}_t{i}_golden.memh').read_bytes()==(d/f'stage_{i}_t{i}_observed.memh').read_bytes()
 if d.parent.name=='cnn':execute([sys.executable,str(root/'benchmark/representative/verify_trained_3x3_cnn_workload.py'),'--workload-dir',str(d)],d/'independent.log','R19_TRAINED_CNN_GOLDEN_PASS')
(a.out/'h16_profile').mkdir(exist_ok=True)
d=a.out/'h16';cmd=json.loads((d/'persistent_decode.json').read_text())['sim_command'];cmd=[x.replace(old,str(a.out)) for x in cmd];cmd[0]=str(sim);cmd+=['+PHASE1_PROFILE='+str(a.out/'h16_profile/profile'),'+STAGE_A_PROFILE='+str(a.out/'h16_profile/stage_a')]
execute(cmd,d/'top_session.log','H16_INCREMENTAL_TOP_PASS')
execute([str(sim),'+AI_RANDOM_CASES=20','+AI_SEED=12345'],a.out/'smoke.log','TEST PASS')
print('PHASE2_TOP_REPLAY_PASS immutable Phase1 inputs/Golden',flush=True)
