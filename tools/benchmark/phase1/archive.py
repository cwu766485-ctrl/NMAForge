#!/usr/bin/env python3
"""Publish only allowlisted public evidence, never simulator builds or libraries."""
import argparse,gzip,hashlib,json,shutil,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=Path.cwd();a.out.mkdir(parents=True,exist_ok=True);records=[]
def put(src,rel=None,compress=False):
 assert src.is_file(),src
 rel=Path(rel or src.relative_to(a.run));dst=a.out/rel
 if compress:dst=Path(str(dst)+'.gz')
 dst.parent.mkdir(parents=True,exist_ok=True);raw=src.read_bytes()
 # Public legacy scripts emit literal CRLF in CSV; canonicalize only text CSV.
 if src.suffix=='.csv':raw=raw.replace(b'\r\n',b'\n')
 if compress:
  with dst.open('wb')as f:
   with gzip.GzipFile(filename='',mode='wb',fileobj=f,mtime=0)as z:z.write(raw)
 else:dst.write_bytes(raw)
 records.append(dict(path=str(dst.relative_to(a.out)),sha256=hashlib.sha256(dst.read_bytes()).hexdigest(),uncompressed_sha256=hashlib.sha256(raw).hexdigest(),bytes=dst.stat().st_size,source=str(src)))
for f in (a.run/'analysis').glob('*'):
 if f.is_file():put(f)
for n in ['fp32_quality.json','int8_quality.json','blind_quality.json','h32_int8.json','fp32_state.pt']:put(a.run/'model'/n)
for n in ['train.log','retrain.log','blind-quality.log','int8-quality.log','driver.log','matched-driver.log','matrix-driver.log','static-driver.log','analysis-driver.log','replay.log','smoke.log']:
 if (a.run/n).exists():put(a.run/n,compress=True)
put(a.run/'top/compile.log',compress=True)
for folder in sorted(a.run.glob('kernel_*')):
 for n in ['shape.json','image.memh','golden.memh','top.command.json','top.log','profile_cycles.csv','profile_memory.csv']:
  put(folder/n,compress=n.endswith(('.memh','.csv','.log')))
for mode in ['legacy','first_fused','both_fused_row_major']:
 d=a.run/'cnn'/mode
 for n in ['manifest.json','dma_payload_summary.json','top.command.json','independent.log','top.log','output.txt','model_memory.memh','model_golden.memh','dma_payload.memh','dma_plan.memh','profile_cycles.csv','profile_memory.csv','stage_a_axi.csv']:
  put(d/n,compress=n.endswith(('.log','.memh','.csv','.txt')))
for n in ['h32','h32_old']:
 d=a.run/n
 for f in d.iterdir():
  if f.is_file()and(f.suffix=='.memh' or f.name in ['manifest.json','top.log','top.command.json','profile_cycles.csv','profile_memory.csv']):put(f,compress=f.suffix in ['.memh','.csv','.log'] or f.name=='manifest.json')
for f in (a.run/'h16/workload').iterdir():
 if f.is_file():put(f,compress=True)
for n in ['top_session.log','persistent_decode.json','persistent_decode.csv','opcode_profile.json']:put(a.run/'h16'/n,compress=n.endswith(('.log','.csv')))
for n in ['profile_cycles.csv','profile_memory.csv']:put(a.run/'h16_profile'/n,compress=True)
for f in (a.run/'matched').iterdir():
 if f.is_file() and (f.suffix in ['.json','.csv','.memh','.sv','.cpp'] or f.name.endswith(('_nma.log','_tiny.log')) or f.name=='build_tiny.sh'):put(f,compress=f.suffix in ['.memh','.log','.sv','.cpp','.sh'])
put(a.run/'matrix/matrix_config_comparison.csv')
for f in (a.run/'matrix').glob('depth_*/prefetch_*/cache_*/run.log'):put(f,compress=True)
for n in ['baseline.log','diagnostic_default.log','summary.json']:put(a.run/'static'/n,compress=n.endswith('.log'))
source_files=[*sorted((root/'tools/benchmark/phase1').glob('*')),(root/'dv/subsystem/top_smoke/fixtures/phase1_profile.svh'),root/'dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv',root/'tools/benchmark/stage_c/reference.py',root/'tools/benchmark/stage_c/generate.py',root/'tools/benchmark/stage_c/prepare_bench.py',root/'tools/benchmark/stage_c/bench.py',root/'benchmark/representative/models/r19_trained_digits_3x3_cnn.json',root/'benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json']
manifest={'status':'PHASE1_COMPLETE_DESIGN_PARTIAL','rtl_sha':'48790076b351cb9d49e1785247d32a1f51b8286d','rtl_tree':subprocess.check_output(['git','rev-parse','HEAD:rtl'],text=True).strip(),'report_branch':'feat/phase1-architecture-benchmark','product_rtl_modified':False,'tiny_sha':'8216c22b762011aa20c05fc2768423fd12dda59d','spad_bytes':131072,'banks':4,'macs':256,'simulation_clock_ns':4,'memory':'VCS behavioral dual-port four-bank SRAM; registered2edge sampled scheduler response; no physical macro','tools':{'vcs':'V-2023.12-SP1_Full64','verilator':'5.052','python':'3.12.13','torch':'2.7.1+cpu'},'sources':{str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest()for f in source_files if f.is_file()},'evidence':records,'limits':['No product RTL optimization implemented','No Fmax/PPA/signoff claim','CNN/H32 end-to-end host latency not measured','Common adapter ratios are not native-system speedups','Candidate C not admitted without positive incremental schedule evidence']}
(a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('PHASE1_ARCHIVE_PASS files='+str(len(records))+' bytes='+str(sum(r['bytes'] for r in records)))
