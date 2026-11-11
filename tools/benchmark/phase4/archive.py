#!/usr/bin/env python3
"""Validate real RTL ablation and archive only public, reproducible evidence."""
import argparse, collections, csv, gzip, hashlib, json, re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--runs',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[3];a.out.mkdir(parents=True,exist_ok=True)
def digest(data):return hashlib.sha256(data).hexdigest()
def write(name,data):
 f=a.out/name;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(data)
def js(name,data):write(name,(json.dumps(data,indent=2)+'\n').encode())
def keep(src,dst):
 data=src.read_bytes();write(dst+'.gz',gzip.compress(data,mtime=0))
def rows(path):return list(csv.DictReader(path.open()))
def fields(s):return dict(re.findall(r'(\w+)=([^ ]+)',s))
def windows(rs):
 out=[];cur=[]
 for r in rs:
  if r['matrix_state']=='9' and r['matrix_busy']=='1':cur.append(r)
  elif cur:out.append(cur);cur=[]
 if cur:out.append(cur)
 return out
sums={};lines={};bounds=[]
for variant,folder in [('baseline','baseline'),('optimized','optimized-final')]:
 d=a.runs/folder;summary=json.loads((d/'analysis/summary.json').read_text());sums[variant]=summary
 for name,s in summary.items():assert sum(s['exclusive'].values())==s['cycles']
 js(variant+'/summary.json',summary)
 cnn=d/'cnn/both_fused_row_major';lines[variant]=rows(cnn/'profile_lines.csv')
 win=windows(rows(cnn/'profile_cycles.csv'));assert len(win)==65 and len(lines[variant])==1040
 assert {len(x)for x in win}==({80}if variant=='baseline'else{65})
 for mode in ['both_fused_row_major','first_fused','legacy']:
  c=d/'cnn'/mode;log=(c/'top.log').read_text();assert 'REPRESENTATIVE_MODEL_PASS 'in log and 'R19_TRAINED_CNN_GOLDEN_PASS 'in (c/'independent.log').read_text()
  for n in ['top.log','top.command.json','independent.log','output.txt','profile_lines.csv','profile_cycles.csv','profile_memory.csv','stage_a_axi.csv']:keep(c/n,variant+'/cnn/'+mode+'/'+n)
  f=fields(next(x for x in log.splitlines()if x.startswith('REPRESENTATIVE_MODEL_PASS ')))
  markers=dict((k,int(v))for k,v in re.findall(r'STAGE_A_(CONFIG_BEGIN|CONFIG_END|READBACK_BEGIN|READBACK_END) clock=(\d+)',log))
  bounds.append(dict(variant=variant,mode=mode,cmdq_cycles=int(f['command_cycles']),dma_setup_transfer_cycles=int(f['preload_dma_window_cycles']),dma_busy_cycles=int(f['preload_dma_busy_cycles']),dma_bytes=int(f['preloaded_spad_bytes']),readback_cycles=markers['READBACK_END']-markers['READBACK_BEGIN'],readback_bytes=3328,full_inference='NOT_MEASURED'))
 for name in ['h32','h32_old']:
  for i in range(12):
   g=d/name/f'stage_{i}_t{i}_golden.memh';o=d/name/f'stage_{i}_t{i}_observed.memh';assert g.read_bytes()==o.read_bytes()
   keep(o,variant+'/'+name+'/'+o.name)
  keep(d/name/'top.log',variant+'/'+name+'/top.log')
 keep(d/'h16/top_session.log',variant+'/h16.log');assert 'H16_INCREMENTAL_TOP_PASS'in(d/'h16/top_session.log').read_text()
 keep(d/'smoke.log',variant+'/seeded20.log');assert 'TEST PASS'in(d/'smoke.log').read_text()
golden=rows(root/'benchmark/research/phase3/model/cnn_transactions.csv')
for v in lines:
 assert [(x['address'],x['data'],x['wstrb'])for x in lines[v]]==[(x['address'],x['golden_payload'],x['wstrb'])for x in golden]
assert sums['baseline']['cnn_both_fused_row_major']['cycles']==12351
assert sums['optimized']['cnn_both_fused_row_major']['cycles']==11376
for name in sums['baseline']:
 b=sums['baseline'][name];o=sums['optimized'][name]
 assert b['read_bytes']==o['read_bytes'] and b['write_bytes']==o['write_bytes']
 if not name.startswith('cnn'):assert b==o
for label in ['directed-final','disabled']:
 for seed in [20261021,20261022,20261023]:
  for prefix,marker in [('directed','PHASE4_WRITEBACK_RTL_PASS'),('random','MATRIX_CORE_RANDOM_PASS cases=18 faults=35'),('opcode-fault','MATRIX_V2_OPCODE_FAULT_PASS')]:
   f=a.runs/label/f'{prefix}-{seed}.log';assert marker in f.read_text()and 'Fatal:'not in f.read_text();keep(f,label+'/'+f.name)
for name in ['canonical-smoke.log','canonical-seeded.log']:
 f=a.runs/name;assert 'TEST PASS'in f.read_text();keep(f,name)
f=a.runs/'compat512/capacity.log';assert 'SPAD_CAPACITY_BOUNDARY_PASS bytes=524288 words_per_bank=32768'in f.read_text();keep(f,'compat512-capacity.log')
lint={}
for variant in ['baseline','optimized']:
 for top in ['top','matrix']:
  name=variant+'-'+top+'.log';f=a.runs/'lint'/name;keep(f,'lint/'+name)
  lint[variant+'-'+top]=dict(collections.Counter(re.findall(r'%Warning-([^:]+):',f.read_text())))
for top in ['top','matrix']:assert lint['baseline-'+top]==lint['optimized-'+top]
js('lint.json',lint);js('boundaries.json',bounds)
abl=[]
for name in sums['baseline']:
 b=sums['baseline'][name];o=sums['optimized'][name]
 abl.append(dict(workload=name,baseline_cycles=b['cycles'],optimized_cycles=o['cycles'],saved=b['cycles']-o['cycles'],reduction_percent=100*(b['cycles']-o['cycles'])/b['cycles'],reads=b['read_bytes'],writes=b['write_bytes'],baseline_useful_mac_per_cycle=b['useful_macs']/b['cycles'],optimized_useful_mac_per_cycle=o['useful_macs']/o['cycles'],golden='PASS'))
with(a.out/'ablation.csv').open('w')as f:
 w=csv.DictWriter(f,fieldnames=list(abl[0]));w.writeheader();w.writerows(abl)
paths=list((root/'rtl').rglob('*.v'))+list((root/'rtl').rglob('*.sv'))
paths+=list((root/'tools/benchmark/phase4').glob('*'))
paths+=[root/x for x in ['dv/block/compute/matrix/tb/phase4_writeback_tasks.svh','dv/block/compute/matrix/tb/tb_ai_tensor_matrix_core_random.sv','dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv','dv/subsystem/top_smoke/fixtures/phase4_writeback_profile.svh','benchmark/research/phase1/manifest.json','benchmark/research/phase3/manifest.json','benchmark/research/phase3/model/cnn_transactions.csv']]
js('manifest.json',dict(status='PASS',baseline_sha='c93ea144713d5fafe2e8a5509029927cd6859e75',research_sha='48345af9c5a4dcabc8fec04999c8edae55dc09c5',candidate='Git commit containing this manifest; source hashes pin measured RTL',artifact_sha256={str(x.relative_to(a.out)):digest(x.read_bytes())for x in sorted(a.out.rglob('*'))if x.is_file()and x.name!='manifest.json'},tools=dict(vcs='V-2023.12-SP1_Full64',verilator='5.052',python='3.12.13'),environment=dict(spad_bytes=131072,banks=4,macs=256,clock_ns=4,clock_is_fmax=False,memory='behavioral SRAM, two-edge scheduler response, AXI testbench backpressure'),source_sha256={str(x.relative_to(root)):digest(x.read_bytes())for x in sorted(paths)if x.is_file()}))
print('PHASE4_GATE2_ARCHIVE_PASS 65 tiles 1040 exact lines; all Golden, fault, regression; no new lint warnings')
