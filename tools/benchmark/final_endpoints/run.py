#!/usr/bin/env python3.12
"""Matched DMA/compute/output endpoint experiment; no product RTL change."""
import argparse,csv,json,re,subprocess,sys,time,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'sw/tools'),str(ROOT/'tools/benchmark/stage_c')]
from shape_aware_dispatch import map_matmul
from generate_h16_incremental_decode import write_pairs

def invoke(cmd,log):
 with log.open('w') as f: subprocess.run([str(x) for x in cmd],stdout=f,stderr=subprocess.STDOUT,check=True,cwd=ROOT)

def run_case(simv,d,meta,mode):
 cmd=[str(simv),'+FINAL_ENDPOINT','+AI_REPRESENTATIVE_MODEL','+AI_REPRESENTATIVE_DMA_PRELOAD','+AI_RANDOM_CASES=0','+AI_SEED=20261112','+ACLK_PERIOD_NS=4',f'+AI_REPRESENTATIVE_DMA_PAYLOAD={d}/dma_payload.memh',f'+AI_REPRESENTATIVE_DMA_PLAN={d}/dma_plan.memh',f'+AI_REPRESENTATIVE_MEMORY={d}/image.memh',f'+AI_REPRESENTATIVE_GOLDEN={d}/golden.memh',f'+AI_REPRESENTATIVE_DESC_BASE={meta["descriptor_base"]}',f'+AI_REPRESENTATIVE_CPL_BASE={meta["completion_base"]}',f'+AI_REPRESENTATIVE_DESC_COUNT={meta["descriptor_count"]}',f'+AI_REPRESENTATIVE_USEFUL_MACS={meta["macs"]}']
 if mode=='dma':cmd+=['+FINAL_DMA_OUTPUT']
 log=d/f'{mode}.log';invoke(cmd,log);s=log.read_text();assert 'REPRESENTATIVE_MODEL_PASS' in s and 'FINAL_ENDPOINT_PASS' in s
 match=re.search(r'FINAL_ENDPOINT_PASS (.*)',s);r={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',match[1])}
 pre=re.search(r'REPRESENTATIVE_DMA_PRELOAD_PASS (.*)',s)
 r.update({f'load_{k}':int(v) for k,v in re.findall(r'(\w+)=(\d+)',pre[1])})
 (d/f'{mode}_command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 return r

def main():
 p=argparse.ArgumentParser();p.add_argument('--simv',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--cnn',action='store_true');p.add_argument('--smoke',action='store_true');a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);rows=[]
 if a.cnn:
  d=a.out/'cnn';d.mkdir(exist_ok=True)
  invoke([sys.executable,ROOT/'benchmark/representative/generate_trained_3x3_cnn_workload.py','--model',ROOT/'benchmark/representative/models/r19_trained_digits_3x3_cnn.json','--out-dir',d,'--fusion-mode','both_fused_row_major','--test-rank','0'],d/'generate.log')
  invoke([sys.executable,ROOT/'benchmark/representative/verify_trained_3x3_cnn_workload.py','--workload-dir',d],d/'verify.log')
  (d/'image.memh').write_bytes((d/'model_memory.memh').read_bytes());(d/'golden.memh').write_bytes((d/'model_golden.memh').read_bytes())
  invoke([sys.executable,ROOT/'benchmark/representative/prepare_cnn_dma_payload.py','--memory-image',d/'image.memh','--out-dir',d],d/'payload.log')
  m=json.loads((d/'manifest.json').read_text());m['macs']=570164
  # Keep full intermediate/sentinel Golden in a separate strict replay, then
  # compare exactly the final tensor for the common delivery endpoint.
  toks=(d/'golden.memh').read_text().split();pairs={int(toks[i],16):int(toks[i+1],16) for i in range(1,len(toks),2)}
  final={addr:val for addr,val in pairs.items() if 0x19000 <= addr < 0x19d00}
  assert len(final)==832
  (d/'strict_golden.memh').write_bytes((d/'golden.memh').read_bytes())
  # A strict original-mode replay checks every intermediate and untouched word.
  strict=[str(a.simv),'+AI_REPRESENTATIVE_MODEL','+AI_REPRESENTATIVE_DMA_PRELOAD','+AI_RANDOM_CASES=0','+AI_SEED=20261112','+ACLK_PERIOD_NS=4',f'+AI_REPRESENTATIVE_DMA_PAYLOAD={d}/dma_payload.memh',f'+AI_REPRESENTATIVE_DMA_PLAN={d}/dma_plan.memh',f'+AI_REPRESENTATIVE_MEMORY={d}/image.memh',f'+AI_REPRESENTATIVE_GOLDEN={d}/strict_golden.memh',f'+AI_REPRESENTATIVE_DESC_BASE={m["descriptor_base"]}',f'+AI_REPRESENTATIVE_CPL_BASE={m["completion_base"]}',f'+AI_REPRESENTATIVE_DESC_COUNT={m["descriptor_count"]}','+AI_REPRESENTATIVE_USEFUL_MACS=570164']
  invoke(strict,d/'strict.log');assert 'REPRESENTATIVE_MODEL_PASS' in (d/'strict.log').read_text()
  write_pairs(d/'golden.memh',final)
  for mode in ['axil','dma']:rows.append(dict(workload='cnn',policy=mode,**run_case(a.simv,d,m,mode)))
 else:
  cases=[(8,128)] if a.smoke else [(m,k) for m in [1,4,8,16] for k in [16,32,64,128]]
  for m,k in cases:
   for pol in ['legacy','shape-aware']:
    d=a.out/f'm{m}_k{k}_{pol}';d.mkdir(exist_ok=True)
    aa=[[(r*3+i*2+1)%9-4 for i in range(k)] for r in range(m)];bb=[[(i*2-c*3+5)%9-4 for c in range(16)] for i in range(k)]
    t=time.perf_counter_ns();desc,av,bv=map_matmul(aa,bb,policy=pol,isolated=True);packing_ns=time.perf_counter_ns()-t
    gold={0x9000+4*(r*16+c):sum(aa[r][i]*bb[i][c] for i in range(k))&0xffffffff for r in range(m) for c in range(16)}
    image={0x1000+4*i:v for i,v in enumerate(av)};image.update({0x4000+4*i:v for i,v in enumerate(bv)});image.update({x:0xa55aa55a for x in gold});image.update({0x1a000+4*i:v for i,v in enumerate(desc.words())})
    write_pairs(d/'image.memh',image);write_pairs(d/'golden.memh',gold)
    invoke([sys.executable,ROOT/'benchmark/representative/prepare_cnn_dma_payload.py','--memory-image',d/'image.memh','--out-dir',d],d/'payload.log')
    meta={'descriptor_base':0x1a000,'completion_base':0x1a200,'descriptor_count':1,'macs':m*16*k}
    r=run_case(a.simv,d,meta,'dma');rows.append(dict(workload='matrix',m=m,n=16,k=k,policy=pol,packing_cpu_ns=packing_ns,packed_a_bytes=len(av)*4,packed_b_bytes=len(bv)*4,golden_sha256=hashlib.sha256((d/'golden.memh').read_bytes()).hexdigest(),**r))
    print(d.name,r['total_cycles'],'PASS',flush=True)
 with (a.out/'results.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
 (a.out/'manifest.json').write_text(json.dumps({'source_sha':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'spad_bytes':131072,'macs':256,'banks':4,'clock_ns':4,'simv_sha256':hashlib.sha256(a.simv.read_bytes()).hexdigest(),'scope':'Test-only poison initialization and validation excluded before production_begin; includes DMA setup, load, CMDQ setup, completion checks and output. Serialized real DMA load/Top CMDQ/Completion/common external output; CPU packing time separate; behavioral SPAD and external AXI latency model; no silicon timing claim'},indent=2)+'\n')
if __name__=='__main__':main()
