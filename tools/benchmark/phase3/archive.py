#!/usr/bin/env python3
"""Allowlisted public evidence only; never copy VCS products or private libraries."""
import argparse, gzip, hashlib, json, re, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--tiny-source',type=Path,required=True);a=p.parse_args()
OUT=ROOT/'benchmark/research/phase3'; OUT.mkdir(parents=True,exist_ok=True)
def digest(b):return hashlib.sha256(b).hexdigest()
def js(rel,data):
 f=OUT/rel;f.parent.mkdir(parents=True,exist_ok=True);f.write_text(json.dumps(data,indent=2)+'\n')
def copy(src,rel,compress=False):
 data=src.read_bytes()
 # Tool banners are public run output, never license keys/server environment.
 assert not re.search(rb'(?im)^\s*(?:SERVER\s|VENDOR\s|INCREMENT\s|SNPSLMD_LICENSE_FILE=|LM_LICENSE_FILE=)',data),src
 f=OUT/(rel+('.gz'if compress else''));f.parent.mkdir(parents=True,exist_ok=True)
 f.write_bytes(gzip.compress(data,mtime=0)if compress else data)
def git(*args,cwd=ROOT):return subprocess.check_output(['git',*args],cwd=cwd).decode().strip()
base='c93ea144713d5fafe2e8a5509029927cd6859e75';phase2='20bd47ca714551607268d62a74e2c507fbadc7c4'
assert git('diff',base,'--','rtl')==''
assert git('rev-parse',base+':rtl')==git('rev-parse',phase2+':rtl')
assert git('status','--short',cwd=a.tiny_source)==''
assert git('rev-parse','HEAD',cwd=a.tiny_source)=='8216c22b762011aa20c05fc2768423fd12dda59d'
for f in sorted((a.run/'model').iterdir()):
 if f.suffix in ['.csv','.json']:copy(f,'model/'+f.name)
for f in sorted((a.run/'baseline/analysis').iterdir()):
 if f.suffix in ['.csv','.json']:copy(f,'baseline/analysis/'+f.name)
phase2summary=json.loads((ROOT/'benchmark/research/phase2/optimized/analysis/summary.json').read_text())
assert json.loads((a.run/'baseline/analysis/summary.json').read_text())==phase2summary
# Reuse immutable public Phase2 raw traces only after byte-for-byte calibration
# against this fresh merged-HEAD replay. Store both hashes and reference paths.
ledger=[]
for f in sorted((ROOT/'benchmark/research/phase2/optimized').rglob('*.gz')):
 rel=f.relative_to(ROOT/'benchmark/research/phase2/optimized')
 if not (f.name.endswith(('_cycles.csv.gz','_memory.csv.gz','_golden.memh.gz','_observed.memh.gz'))):continue
 fresh=a.run/'baseline'/str(rel)[:-3]
 assert fresh.exists(),fresh
 old=gzip.decompress(f.read_bytes());new=fresh.read_bytes();assert old==new,rel
 ledger.append(dict(reference=str(f.relative_to(ROOT)),fresh_relative=str(fresh.relative_to(a.run)),fresh_sha256=digest(new),reference_uncompressed_sha256=digest(old),result='PASS'))
assert len(ledger)>=60
js('metadata/fresh_replay_ledger.json',ledger)
for rel in ['review/ln32/run.log','review/ln32/compile.log','review/fault-run.log','review/fault-compile.log','review/lint.log','baseline/smoke.log','baseline/top/compile.log','baseline-driver.log','baseline-analysis.log','review-driver.log','model-driver.log','phase2-validation.log']:
 copy(a.run/rel,'logs/'+rel,True)
for rel in ['review/ln32/oracle.json','review/pr4.json']:
 copy(a.run/rel,'metadata/'+Path(rel).name)
for rel in ['mean.txt','variance.txt','vectors.txt']:
 copy(a.run/'review/ln32'/rel,'directed/'+rel,True)
for f in sorted((a.run/'baseline').rglob('*.log')):
 if f.parent==a.run/'baseline' or 'top' in f.parts:continue
 if f.name in ['top.log','top_session.log','independent.log']:
  copy(f,'logs/'+str(f.relative_to(a.run)),True)
# Pin every product RTL file and the exact checked-in model/test/flow inputs.
files=list((ROOT/'rtl').rglob('*.v'))+list((ROOT/'rtl').rglob('*.sv'))
files+=list((ROOT/'tools/benchmark/phase3').glob('*.py'))+list((ROOT/'tools/benchmark/phase3').glob('*.sh'))
files+=[ROOT/'dv/block/compute/sfu/tb/tb_phase3_fault_contract.sv']
for rel in json.loads((ROOT/'benchmark/research/phase2/metadata/source_sha256.json').read_text()):files.append(ROOT/rel)
js('metadata/source_sha256.json',{str(f.relative_to(ROOT)):digest(f.read_bytes())for f in sorted(set(files))})
tiny_paths=['rtl/top.sv','rtl/ops/layernorm_engine.sv','rtl/ops/gelu_lut.sv','rtl/ops/softmax_engine.sv','sim/verilator/gpt2_block_top.sv','sim/verilator/integration_top.sv','sim/verilator/onnx_sim_top.sv']
js('metadata/tiny_source_sha256.json',{rel:digest((a.tiny_source/rel).read_bytes())for rel in tiny_paths})
remotes=git('ls-remote','origin','refs/heads/main','refs/heads/nmaforge')
assert base+'\trefs/heads/nmaforge' in remotes
js('manifest.json',dict(status='RESEARCH_PARTIAL_STOP_AFTER_GATES_0_2',product_merge_sha=base,reviewed_phase2_sha=phase2,measured_rtl_tree=git('rev-parse',base+':rtl'),research_branch='feat/phase3-throughput',product_rtl_changed=False,pr='https://github.com/cwu766485-ctrl/NMAForge/pull/4',remote_product_verified=True,remote_snapshot=remotes.splitlines(),tinynpu_sha=git('rev-parse','HEAD',cwd=a.tiny_source),tools=dict(vcs='V-2023.12-SP1_Full64',verilator='5.052',python='3.12.13'),memory=dict(spad_bytes=131072,banks=4,words_per_bank=8192,clock_ns=4,response_edges=2,scheduler_admissions_per_edge=1),scope='Measured unmodified merged RTL replay; conditional transaction models, no Phase3 optimized RTL or synthesis; historical Tiny adapter results only',quality='Qualified synthetic period3 H32; blind FP32/INT8 accuracy100%, lag3 rule baseline100%; not pretrained language model',golden_reference='benchmark/research/phase2/optimized',model_source='tools/benchmark/phase3/model.py'))
js('sha256.json',{str(f.relative_to(OUT)):digest(f.read_bytes())for f in sorted(OUT.rglob('*'))if f.is_file()and f!=OUT/'sha256.json'})
print('PHASE3_ARCHIVE_PASS public allowlist, identical fresh traces/Golden and RTL, remote product verified')
