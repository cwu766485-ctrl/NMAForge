"""Collect Stage B model and public unchanged-RTL evidence; fresh destination only."""
import argparse
import gzip
import hashlib
import json
import subprocess
from pathlib import Path

p=argparse.ArgumentParser()
p.add_argument('--inputs',type=Path,required=True)
p.add_argument('--out',type=Path,default=Path('benchmark/research/stage_b'))
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)
inputs={k:Path(v) for k,v in json.loads(a.inputs.read_text()).items()}

def digest(data):return hashlib.sha256(data).hexdigest()
def save(path,data):
    dest=a.out/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
def js(path,data):save(path,(json.dumps(data,indent=2)+'\n').encode())
def copy(source,dest,compress=False):
    data=source.read_bytes()
    if source.suffix=='.csv':data=data.replace(b'\r\n',b'\n')
    save(dest+('.gz' if compress else ''),gzip.compress(data,mtime=0) if compress else data)

for f in inputs['model'].iterdir():
    if f.suffix in ('.csv','.json'):copy(f,'model/'+f.name)
for f in inputs['analysis'].iterdir():
    if f.suffix in ('.csv','.json'):copy(f,'baseline/analysis/'+f.name)
for name in ['top_session.log','persistent_decode.json','persistent_decode.csv','opcode_profile.csv','opcode_profile.json']:
    copy(inputs['baseline']/'session'/name,'baseline/h16/'+name,name.endswith('.log'))
for f in (inputs['baseline']/'session/workload').iterdir():
    if f.suffix in ('.memh','.json'):copy(f,'baseline/h16/workload/'+f.name,f.suffix=='.memh')
for f in inputs['baseline'].glob('h16_*.csv'):copy(f,'baseline/h16/'+f.name,True)
copy(inputs['baseline']/'compile.log','baseline/h16/compile.log',True)
for name in ['contract','sfu','matrix']:
    for kind in ['run.log','compile.log']:copy(inputs[name]/kind,name+'/'+kind,True)
for mode in ['legacy','first_fused','both_fused_row_major']:
    for name in ['top.log','manifest.json','output.txt','command.json']:
        copy(inputs['cnn']/mode/name,'baseline/cnn/'+mode+'/'+name,name.endswith(('.log','.txt')))
copy(inputs['smoke'],'baseline/ai_smoke.log',True)
copy(inputs['model_tests'],'model/tests.log',True)
js('collection_inputs.json',{k:str(v) for k,v in inputs.items()})
# Verify all eight persistent token metrics and full output snapshots match Stage A.
old=json.loads(Path('benchmark/research/stage_a/h16/persistent_decode.json').read_text())
new=json.loads((inputs['baseline']/'session/persistent_decode.json').read_text())
assert old['steps']==new['steps']
assert new['total_decode_cycles']==65771
checks=[]
for f in sorted((inputs['baseline']/'session/workload').glob('*_observed.memh')):
    previous=gzip.decompress((Path('benchmark/research/stage_a/h16/workload')/(f.name+'.gz')).read_bytes())
    assert f.read_bytes()==previous
    checks.append(dict(path=f.name,stage_a_sha256=digest(previous),stage_b_sha256=digest(f.read_bytes()),equal=True))
js('baseline/same_golden.json',dict(status='PASS',token_metrics_identical=True,stage_snapshots=checks))
source_paths=list(Path('tools/benchmark/stage_b').glob('*.py'))+list(Path('tools/benchmark/stage_b').glob('*.sv'))+list(Path('tools/benchmark/stage_b').glob('*.sh'))
rtl_sources=['rtl/memory/ai_scratchpad.v','rtl/memory/ai_spad_protection.v','rtl/memory/ai_spad_arbiter.v',
 'rtl/top/fabric/memory/ai_accel_memory_fabric.v','rtl/top/fabric/memory/ai_accel_spad_subsystem.v',
 'rtl/top/fabric/memory/ai_spad_response_demux.v','rtl/top/fabric/compute/ai_compute_spad_mux.v',
 'rtl/compute/sfu/ai_tensor_sfu_core.v','rtl/compute/matrix/ai_tensor_matrix_core.v',
 'rtl/control/queue/ai_parallel_compute_dispatcher.v']
base='1b455b355c8604272cbc49a81f5564db9a4e4f05'
assert not subprocess.check_output(['git','diff',base,'--','rtl/'])
js('manifest.json',dict(schema=1,stage='B',decision='REJECT',gate0='FAIL_TRANSPARENT_BYPASS_PARITY_EQUIVALENCE',
 baseline_commit=base,baseline_rtl_tree=subprocess.check_output(['git','rev-parse',base+':rtl'],text=True).strip(),
 product_rtl_changed=False,cache_rtl_implemented=False,abi_changed=False,
 actual_added_data_flops=0,actual_added_metadata_bits=0,
 candidate_branch='experiment/stage-b-matrix-requant',
 tools=dict(vcs='V-2023.12-SP1_Full64',python='3.12',mapped_synthesis='NOT_RUN_NO_CANDIDATE_RTL'),
 source_hashes={str(f):digest(f.read_bytes()) for f in sorted(source_paths+list(map(Path,rtl_sources)))},
 artifacts={str(f.relative_to(a.out)):digest(f.read_bytes()) for f in sorted(a.out.rglob('*')) if f.is_file()},
 results=dict(full_decode_cycles=65771,cycles_per_token=8221.375,read_bytes=72448,write_bytes=42112,
  descriptor_count=424,cache_hits_rtl=None,cache_misses_rtl=None,b2_rtl_cycles=None,b2_rtl_golden='NOT_RUN_GATE0_FAILED'),
 scope='Gate 0 failure analysis plus independent model; no enabled B2 performance or PPA claim'))
print('STAGE_B_ARCHIVE_PASS same 8 token metrics and 9 full stage Golden snapshots; no product RTL delta')
