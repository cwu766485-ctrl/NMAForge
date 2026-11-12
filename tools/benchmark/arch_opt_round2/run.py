#!/usr/bin/env python3
"""Real product Top paired dispatch and address-level B-cache attribution."""
import argparse,collections,csv,gzip,hashlib,json,re,subprocess,sys,time
from pathlib import Path
root=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(root/'sw/tools'),str(root/'tools/benchmark/stage_c')]
from shape_aware_dispatch import map_matmul
from generate_h16_incremental_decode import write_pairs
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--simv',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
rows=[]
cases=[(m,k,pol) for m in (4,8,16) for k in (16,32,64,128) for pol in ('legacy','gemm')]
cases += [(1,k,'legacy') for k in (16,32,64,128)]
cases += [(m,k,'shape-aware') for m in (1,4,8,16) for k in (16,32,64,128)]
cases += [(m,k,'legacy') for m in (1,4,8,16) for k in (63,64,65,96,127,128,129)]
for m,k,pol in dict.fromkeys(cases):
 d=a.out/f'{pol}_m{m}_k{k}';d.mkdir(exist_ok=True)
 aa=[[(r*3+i*2+1)%9-4 for i in range(k)] for r in range(m)]
 bb=[[(i*2-c*3+5)%9-4 for c in range(16)] for i in range(k)]
 t=time.perf_counter_ns();desc,av,bv=map_matmul(aa,bb,policy=pol,isolated=True);packing_ns=time.perf_counter_ns()-t
 gold={0x9000+4*(r*16+c):sum(aa[r][i]*bb[i][c] for i in range(k))&0xffffffff for r in range(m) for c in range(16)}
 image={0x1000+4*i:v for i,v in enumerate(av)};image.update({0x4000+4*i:v for i,v in enumerate(bv)});image.update({x:0xa55aa55a for x in gold});image.update({0x1a000+4*i:v for i,v in enumerate(desc.words())})
 write_pairs(d/'image.memh',image);write_pairs(d/'golden.memh',gold)
 cmd=[str(a.simv),'+AI_REPRESENTATIVE_MODEL','+ROUND2_PROFILE','+AI_RANDOM_CASES=0','+AI_SEED=20261112','+ACLK_PERIOD_NS=4',f'+AI_REPRESENTATIVE_MEMORY={d}/image.memh',f'+AI_REPRESENTATIVE_GOLDEN={d}/golden.memh','+AI_REPRESENTATIVE_DESC_BASE=106496','+AI_REPRESENTATIVE_CPL_BASE=107008','+AI_REPRESENTATIVE_DESC_COUNT=1',f'+AI_REPRESENTATIVE_USEFUL_MACS={m*16*k}',f'+PHASE1_PROFILE={d}/profile']
 (d/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 with (d/'top.log').open('w') as f:subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,check=True)
 assert 'REPRESENTATIVE_MODEL_PASS' in (d/'top.log').read_text()
 cr=list(csv.DictReader((d/'profile_cycles.csv').open()));mr=list(csv.DictReader((d/'profile_memory.csv').open()))
 cnt=collections.Counter(int(r['bucket']) for r in cr);assert sum(cnt.values())==len(cr)
 reads=[r for r in mr if r['kind']=='A' and r['client']=='3' and r['window']=='0']
 b=collections.Counter(int(r['address'],16) for r in reads if 0x4000<=int(r['address'],16)<0x9000)
 writes=sum(int(r['bytes']) for r in mr if r['kind']=='A' and r['window']=='0' and r['client']=='2' and r['write']=='1')
 queues=collections.defaultdict(collections.deque)
 for r in mr:
  if r['kind']=='A' and r['write']=='0':queues[r['client']].append(int(r['clock']))
  elif r['kind']=='R':assert int(r['clock'])-queues[r['client']].popleft()==2 and r['error']=='0'
 assert not any(queues.values())
 with (d/'b_addresses.csv').open('w') as f:
  w=csv.writer(f);w.writerow(['address','accepted_reads']);w.writerows((hex(addr),count) for addr,count in sorted(b.items()))
 rows.append(dict(m=m,n=16,k=k,policy=pol,opcode=hex(desc.op),cycles=len(cr),operand_wait=cnt[2],compute=cnt[3],writeback=cnt[4],read_bytes=len(reads)*16,write_bytes=writes,b_read_bytes=sum(b.values())*16,b_unique_bytes=len(b)*16,b_repeated_bytes=(sum(b.values())-len(b))*16,packing_ns=packing_ns,packed_a_bytes=len(av)*4,packed_b_bytes=len(bv)*4,golden_sha256=sha(d/'golden.memh'),golden='PASS',dma_cycles='NOT_MEASURED',response_latency=2))
 rows[-1].update({key:int(value) for key,value in re.findall(r'(hits|reads_saved|prefetch_completed|prefetch_wait|arbiter_stall)=(\d+)',(d/'top.log').read_text())})
 print(d.name,len(cr),'PASS',flush=True)
with (a.out/'results.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
for m in (4,8,16):
 for k in (16,32,64,128):
  pair=[r for r in rows if r['m']==m and r['k']==k and r['policy'] in ('legacy','gemm')]
  assert len(pair)==2 and pair[0]['golden_sha256']==pair[1]['golden_sha256']
# Public traces are compressed text only, never simulation databases or binaries.
(a.out/'manifest.json').write_text(json.dumps(dict(source_sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),rtl_tree=subprocess.check_output(['git','rev-parse','HEAD:rtl'],text=True).strip(),simv_sha256=sha(a.simv),source_files={str(f.relative_to(root)):sha(f) for f in [root/'sw/tools/shape_aware_dispatch.py',Path(__file__).resolve(),root/'dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv']},spad_bytes=131072,banks=4,macs=256,clock_ns=4,model='VCS registered behavioral SPAD; exclusive single descriptor; no DMA timing',cases=len(rows)),indent=2)+'\n')
print('ROUND2_PAIRED_TOP_PASS',flush=True)
