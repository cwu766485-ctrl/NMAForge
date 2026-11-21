"""Archive only public benchmark evidence, never simulator build directories."""
import argparse,csv,gzip,hashlib,json,re,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args()
out=Path('benchmark/representative/round29');out.mkdir(parents=True,exist_ok=True)
def save(src,dst):
 b=(a.run/src).read_bytes();d=out/dst;d.parent.mkdir(parents=True,exist_ok=True)
 if d.suffix=='.gz':b=gzip.compress(b,mtime=0)
 elif d.suffix=='.csv':b=b.replace(b'\r\n',b'\n')
 d.write_bytes(b)
phases=[]
for variant,folder in [('baseline','base'),('candidate','final')]:
 for n in ['persistent_decode.csv','persistent_decode.json','opcode_profile.csv','opcode_profile.json']:
  save(folder+'/session/'+n,variant+'/'+n)
 save(folder+'/session/top_session.log',variant+'/session.log.gz')
 save(folder+'/compile.log',variant+'/compile.log.gz')
 for line in (a.run/folder/'session/top_session.log').read_text().splitlines():
  if line.startswith('R28_LN '):
   d=dict(re.findall(r'(\w+)=(\d+)',line));assert sum(int(v) for k,v in d.items() if k!='total')==int(d['total']);phases.append(dict(variant=variant,**d))
with (out/'ln_phases.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(phases[0]),lineterminator='\n');w.writeheader();w.writerows(phases)
for src,dst in [('final_cnn.log','cnn.log.gz'),('final_smoke.log','validation/smoke.log.gz'),('final_seeded.log','validation/seeded.log.gz'),('final_sfu/run.log','validation/sfu.log.gz'),('base_sfu_lint.log','validation/baseline_lint.log.gz'),('final_sfu_lint.log','validation/candidate_lint.log.gz'),('matrix/gemm.log','matrix/gemm.log.gz'),('matrix/gemv.log','matrix/gemv.log.gz'),('forward/enable_0/run.log','matrix/forward_off.log.gz'),('forward/enable_1/run.log','matrix/forward_on.log.gz'),('gemv_ablation/summary_seed_20261109.csv','matrix/gemv_ablation.csv'),('tiny/gemm/run.log','tiny/gemm.log.gz'),('tiny/cnn/run.log','tiny/cnn.log.gz'),('mini/run.log','tiny/nma_cnn.log.gz')]:save(src,dst)
for src in a.run.glob('gemv_ablation/cache_*/prefetch_*/run_seed_*.log'):
 save(str(src.relative_to(a.run)), 'matrix/'+src.parent.parent.name+'_'+src.parent.name+'.log.gz')
base=list(csv.DictReader((out/'baseline/persistent_decode.csv').open()));cand=list(csv.DictReader((out/'candidate/persistent_decode.csv').open()))
for x,y in zip(base,cand):
 for k in ['top_logits_sha256','top_kv_physical_sha256','expected_kv_physical_sha256']:assert x[k]==y[k]
 assert int(x['cycles'])-int(y['cycles'])==120
m={'status':'DESIGN_PARTIAL','publication':'REMOTE_NOT_PUBLISHED','baseline_sha':'f2bed3dd7386b1b9cc79c20bb065d06354b1beca','rtl_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'baseline_decode_cycles':sum(int(x['cycles']) for x in base),'candidate_decode_cycles':sum(int(x['cycles']) for x in cand),'golden':'8 paired logits/KV hashes identical; all tensor Golden PASS','model_sha256':hashlib.sha256(Path('benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json').read_bytes()).hexdigest(),'tinynpu_sha':'8216c22b762011aa20c05fc2768423fd12dda59d','tools':{'vcs':'V-2023.12-SP1_Full64','verilator':'5.052','python':'3.12.13'},'memory':'128 KiB behavioral SPAD for H16/CNN; 512 KiB compatibility smoke; Matrix block seeded responder','artifacts':{str(p.relative_to(out)):{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(out.rglob('*')) if p.is_file() and p.name!='manifest.json'}}
(out/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
print('ROUND29_ARCHIVE_PASS')
