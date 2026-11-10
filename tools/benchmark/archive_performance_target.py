"""Archive public paired performance evidence and shared trained QKV fixtures."""
import argparse,csv,gzip,hashlib,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args();out=Path('benchmark/representative/performance_target');out.mkdir(parents=True,exist_ok=True)
def save(src,dst):
 d=out/dst;d.parent.mkdir(parents=True,exist_ok=True);b=(a.run/src).read_bytes()
 if d.suffix=='.gz':b=gzip.compress(b,mtime=0)
 elif d.suffix=='.csv':b=b.replace(b'\r\n',b'\n')
 d.write_bytes(b)
rows=[]
base=list(csv.DictReader((a.run/'base/session/persistent_decode.csv').open()))
for variant in ['base','residual','final']:
 for name in ['persistent_decode.csv','persistent_decode.json','opcode_profile.csv','opcode_profile.json']:
  save(variant+'/session/'+name,variant+'/'+name)
 save(variant+'/session/top_session.log',variant+'/session.log.gz');save(variant+'/compile.log',variant+'/compile.log.gz')
 cases=list(csv.DictReader((a.run/variant/'session/persistent_decode.csv').open()))
 for b,c in zip(base,cases):
  for k in ['top_logits_sha256','top_kv_physical_sha256','expected_kv_physical_sha256']:assert b[k]==c[k]
 total=sum(int(x['cycles']) for x in cases)
 rows.append({'variant':variant,'decode_cycles':total,'cycles_per_token':total/8,'spad_read_bytes':sum(int(x['spad_read_bytes']) for x in cases),'spad_write_bytes':sum(int(x['spad_write_bytes']) for x in cases),'golden':'PASS hashes identical'})
for src,dst in [('cnn.log','cnn.log.gz'),('mini/run.log','mini.log.gz'),('final_smoke.log','validation/smoke.log.gz'),('final_seeded.log','validation/seeded.log.gz'),('final_sfu/run.log','validation/sfu_seed_20261109.log.gz'),('sfu_two_seeds/seed_20261110/run.log','validation/sfu_seed_20261110.log.gz'),('sfu_two_seeds/seed_20261111/run.log','validation/sfu_seed_20261111.log.gz'),('final_lint.log','validation/lint.log.gz'),('divider/run.log','validation/divider.log.gz'),('matrix/gemm.log','matrix/gemm.log.gz'),('matrix/gemv.log','matrix/gemv.log.gz'),('matrix/run.log','matrix/regress.log.gz'),('tiny/run.log','tiny/gemm.log.gz')]:save(src,dst)
for src in sorted((a.run/'qkv').iterdir()):
 if src.suffix in ['.json','.memh','.log']:save(str(src.relative_to(a.run)),'qkv/'+src.name)
with (out/'decode_ablation.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
m={'baseline_sha':'5f5291f057aad3ab5ab0a6c73aed1bbb064e5038','rtl_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'tinynpu_sha':'8216c22b762011aa20c05fc2768423fd12dda59d','status':'DESIGN_PARTIAL','comparison':'shared trained Q/K/V raw integer projection; host quantization reference; unmatched controller/memory endpoints','decode':rows,'tools':{'VCS':'V-2023.12-SP1_Full64','Verilator':'5.052','Python':'3.12.13'},'artifacts':{str(p.relative_to(out)):{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(out.rglob('*')) if p.is_file() and p.name!='manifest.json'}}
(out/'manifest.json').write_text(json.dumps(m,indent=2)+'\n');print('PERFORMANCE_TARGET_ARCHIVE_PASS')
