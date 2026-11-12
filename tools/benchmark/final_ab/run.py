#!/usr/bin/env python3
"""Serialized same-endpoint hardware timeline using existing load/store DMA."""
import argparse,csv,gzip,json,re,subprocess,sys,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(root/'sw/tools'),str(root/'tools/benchmark/stage_c')]
from shape_aware_dispatch import map_matmul
from generate_h16_incremental_decode import write_pairs
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--simv',type=Path,required=True);p.add_argument('--backpressure',action='store_true');a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
rows=[]
def execute(cmd,log):
 log.with_suffix('.command.json').write_text(json.dumps([str(x) for x in cmd],indent=2)+'\n')
 with log.open('w') as f:subprocess.run([str(x) for x in cmd],stdout=f,stderr=subprocess.STDOUT,check=True)
 return log.read_text()
cases=[(m,k,pol,'dma') for m in (1,4,8,16) for k in (16,32,64,128) for pol in ('legacy','shape-aware')]
cases += [('cnn',0,'both_fused_row_major',out) for out in ('lite','dma')]
for m,k,pol,output in cases:
 name=f'{pol}_m{m}_k{k}_{output}';d=a.out/name;d.mkdir(exist_ok=True)
 if m=='cnn':
  execute([sys.executable,'benchmark/representative/generate_trained_3x3_cnn_workload.py','--model','benchmark/representative/models/r19_trained_digits_3x3_cnn.json','--fusion-mode',pol,'--out-dir',d],d/'generator.log')
  image=d/'model_memory.memh';gold=d/'model_golden.memh';base=102400;words=832;count=2;macs=570164
 else:
  aa=[[(r*3+i*2+1)%9-4 for i in range(k)] for r in range(m)]
  bb=[[(i*2-c*3+5)%9-4 for c in range(16)] for i in range(k)]
  import time
  t=time.perf_counter_ns();desc,av,bv=map_matmul(aa,bb,policy=pol,isolated=True);packing_ns=time.perf_counter_ns()-t
  image=d/'image.memh';gold=d/'golden.memh';base=0x9000;words=m*16;count=1;macs=m*16*k
  im={0x1000+4*i:v for i,v in enumerate(av)};im.update({0x4000+4*i:v for i,v in enumerate(bv)});im.update({base+4*i:0xa55aa55a for i in range(words)});im.update({0x1a000+4*i:v for i,v in enumerate(desc.words())})
  go={base+4*(r*16+c):sum(aa[r][i]*bb[i][c] for i in range(k))&0xffffffff for r in range(m) for c in range(16)}
  write_pairs(image,im);write_pairs(gold,go)
 execute([sys.executable,'benchmark/representative/prepare_cnn_dma_payload.py','--memory-image',image,'--out-dir',d],d/'payload.log')
 cmd=[a.simv,'+AI_REPRESENTATIVE_MODEL','+AI_RANDOM_CASES=0','+AI_SEED=20261112','+ACLK_PERIOD_NS=4','+AI_REPRESENTATIVE_DMA_PRELOAD',f'+AI_REPRESENTATIVE_DMA_PAYLOAD={d}/dma_payload.memh',f'+AI_REPRESENTATIVE_DMA_PLAN={d}/dma_plan.memh',f'+AI_REPRESENTATIVE_MEMORY={image}',f'+AI_REPRESENTATIVE_GOLDEN={gold}','+AI_REPRESENTATIVE_DESC_BASE=106496','+AI_REPRESENTATIVE_CPL_BASE=107008',f'+AI_REPRESENTATIVE_DESC_COUNT={count}',f'+AI_REPRESENTATIVE_USEFUL_MACS={macs}','+SYSTEM_TIMELINE',f'+SYSTEM_OUTPUT_BASE={base}',f'+SYSTEM_OUTPUT_WORDS={words}',f'+STAGE_A_PROFILE={d}/stage_a']
 if a.backpressure:cmd+=['+SYSTEM_BACKPRESSURE']
 if output=='dma':cmd+=['+SYSTEM_OUTPUT_DMA']
 text=execute(cmd,d/'top.log');assert 'SYSTEM_TIMELINE_PASS' in text and 'REPRESENTATIVE_MODEL_PASS' in text
 timeline=next(l for l in text.splitlines() if l.startswith('SYSTEM_TIMELINE_PASS'))
 row=dict(name=name,m=m,k=k,policy=pol,output=output,**{key:int(v) for key,v in re.findall(r'(\w+)=(\d+)',timeline)})
 payload=json.loads((d/'dma_payload_summary.json').read_text());row['load_bytes']=payload['payload_bytes'];row['golden']='PASS';row['packing_ns']=packing_ns if m!='cnn' else 'OFFLINE_EXISTING_GENERATOR'
 row['golden_sha256']=hashlib.sha256(gold.read_bytes()).hexdigest()
 rows.append(row);print(name,row['total'],row['output_cycles'],'PASS',flush=True)
with (a.out/'results.csv').open('w') as f:w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
print('FINAL_AB_TIMELINE_PASS')
