"""Archive only public source/model/Golden and compact simulation evidence."""
import argparse,json,gzip,hashlib,subprocess,csv,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--runs',type=Path,required=True);p.add_argument('--out',type=Path,default=Path('benchmark/research/stage_c'));a=p.parse_args();r=a.runs

def cp(src,dest,compress=False):
 data=src.read_bytes()
 if src.suffix=='.csv':data=data.replace(b'\r\n',b'\n')
 # Normalize whitespace in archived generated harness text only; no semantic edit.
 if src.suffix in ['.sv','.cpp','.sh']:data=('\n'.join(line.rstrip() for line in data.decode().splitlines()).rstrip()+'\n').encode()
 p=a.out/(dest+('.gz' if compress else ''));p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(gzip.compress(data,mtime=0) if compress else data)
def js(dest,v):p=a.out/dest;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2)+'\n')
for f in (r/'final_top/h32').iterdir():
 if f.suffix in ['.memh','.json','.csv','.log'] and f.name!='stdout.log':cp(f,'h32/'+f.name,f.suffix!='.json')
cp(r/'final_top/compile.log','h32/compile.log',True)
for f in (r/'final_top/analysis').iterdir():cp(f,'h32/analysis/'+f.name)
for f in (r/'final_service').iterdir():
 if f.suffix in ['.memh','.json','.sv','.cpp','.sh','.csv','.log'] and f.name!='compile.stdout':cp(f,'matched/'+f.name,f.suffix not in ['.json','.csv','.sv','.cpp','.sh'])
cp(r/'final_service/tiny/compile.log','matched/tiny_compile.log',True)
for f in ['run.log','compile.log','command.json']:cp(r/'tiny_native'/f,'tiny_native/'+f,f.endswith('.log'))
for f in (r/'tiny_native/graph').iterdir():
 if f.is_file():cp(f,'tiny_native/graph/'+f.name,True)
for name in ['contract']:
 for f in ['run.log','compile.log']:cp(r/name/f,name+'/'+f,True)
for mode in ['legacy','first_fused','both_fused_row_major']:
 for f in ['top.log','manifest.json','output.txt','command.json']:cp(r/'cnn'/mode/f,'cnn/'+mode+'/'+f,f.endswith(('.log','.txt')))
for f in ['run.log','compile.log']:cp(r/'common_cnn'/f,'common_cnn/'+f,True)
for f in (r/'common_cnn/workload').iterdir():cp(f,'common_cnn/workload/'+f.name,f.suffix=='.memh')
cp(r/'matrix_config/matrix_config_comparison.csv','matrix/matrix_config_comparison.csv')
for f in (r/'matrix_config').glob('depth_*/prefetch_*/cache_*/*.log'):cp(f,'matrix/'+str(f.relative_to(r/'matrix_config')),True)
cp(r/'gemv/summary_seed_20261110.csv','matrix/gemv_four_way.csv')
for f in (r/'gemv').glob('cache_*/prefetch_*/*.log'):cp(f,'matrix/gemv/'+str(f.relative_to(r/'gemv')),True)
for f in ['nma.log','compile.log']:cp(r/'array_only'/f,'array_only/'+f,True)
for f in ['run.log','compile.log','engine_regression.log']:cp(r/'array_only/tiny'/f,'array_only/tiny_'+f,True)
for f in (r/'array_only/qkv').iterdir():
 if f.is_file():cp(f,'array_only/qkv/'+f.name,f.suffix!='.json')
cp(Path('/tmp/nmaforge-stage-c-cnn-independent.log'),'verification/cnn_independent.log',True)
for f in ['persistent_decode.json','persistent_decode.csv','top_session.log']:cp(r/'h16/session'/f,'h16/'+f,f.endswith('.log'))
for name,src in [('smoke','/tmp/nmaforge-stage-c-smoke.log'),('seeded','/tmp/nmaforge-stage-c-seeded.log'),('train','/tmp/nmaforge-stage-c-disjoint-train.log'),('train_reproduction','/tmp/nmaforge-stage-c-disjoint-reproduce.log')]:cp(Path(src),'verification/'+name+'.log',True)
cp(r/'final_top/scheduling.json','scheduling.json')
# Disclose independent-seed overlap in the superseded IID model. Keep evidence.
import random
m=json.loads((a.out/'models/h32_iid_overlap_int8.json').read_text());rr=random.Random(20261111);train=set()
for _ in range(2048):mode,state=rr.randrange(4),rr.randrange(28);train.add((mode,state))
test={(x[0],x[1]-4) for x in m['heldout']}
js('models/split_audit.json',{'iid_unique_train':len(train),'iid_unique_test':len(test),'iid_shared_initial_states':len(train & test),'iid_quality_status':'INVALID_AS_INDEPENDENT_GENERALIZATION','final_split':'84 train trajectories/28 disjoint test trajectories, mode-stratified','final_train_test_overlap':0,'final_model':'h32_l2_int8.json','stop_rule':'Two directed model fixes: export scale; disjoint trajectory split. No third training tuning round.'})
base='4e65a2ac2fc176acc5621aebec000874f2c5ab24';assert not subprocess.check_output(['git','diff',base,'--','rtl/'])
files=list(Path('tools/benchmark/stage_c').glob('*.py'))+list(Path('tools/benchmark/stage_c').glob('*.sh'))+[Path('dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv')]
js('manifest.json',{'stage':'C','status':'PARTIAL','baseline_sha':base,'rtl_tree':subprocess.check_output(['git','rev-parse',base+':rtl'],text=True).strip(),'product_rtl_changed':False,'abi_changed':False,'a3_transparent_bypass':'REJECT','k64':'PARTIAL_NO_RTL','h32':'FUNCTIONAL_PASS_QUALITY_LIMITED','scheduling':'NO_RTL_ADMITTED','tiny_sha':'8216c22b762011aa20c05fc2768423fd12dda59d','tiny_source_clean':not subprocess.check_output(['git','-C','/tmp/nmaforge-round28-runs/tiny/source','status','--porcelain']), 'new_data_flops':0,'new_metadata_bits':0,'new_mac':0,'new_spad_ports':0,'tools':{'vcs':'V-2023.12-SP1_Full64','verilator':'5.052','training_torch':'2.7.1+cpu','python':'3.12'},'model_sha256':hashlib.sha256((a.out/'models/h32_l2_int8.json').read_bytes()).hexdigest(),'source_hashes':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}})
# Inventory covers archives, including generated Golden/observed hashes, not itself.
js('evidence_sha256.json',{str(f.relative_to(a.out)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(a.out.rglob('*')) if f.is_file() and f.name!='evidence_sha256.json'})
print('STAGE_C_ARCHIVE_PASS')
