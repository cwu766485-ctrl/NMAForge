from pathlib import Path
import csv,json,re,gzip,hashlib,subprocess,shutil
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--root',type=Path,default=Path.cwd())
parser.add_argument('--run',type=Path,required=True)
args=parser.parse_args()
root=args.root;run=args.run;out=root/'benchmark/representative/round28'
out.mkdir(parents=True,exist_ok=True)
def copy(src,dst):
 p=out/dst;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(run/src,p)
 if p.suffix=='.csv':p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n'))
def log(src,dst):
 p=out/dst;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(gzip.compress((run/src).read_bytes(),mtime=0))
for phase in ['base','opt']:
 for name in ['persistent_decode.csv','persistent_decode.json','opcode_profile.csv','opcode_profile.json']:
  copy(f'{phase}/session/{name}',f'{phase}/{name}')
 log(f'{phase}/session/top_session.log',f'{phase}/top_session.log.gz')
 log(f'{phase}/compile.log',f'{phase}/compile.log.gz')
rows=[]
for phase in ['base','opt']:
 for i,line in enumerate((run/f'{phase}/session/top_session.log').read_text().splitlines()):
  if line.startswith('R28_LN '):
   d=dict(re.findall(r'(\w+)=(\d+)',line));assert sum(int(v) for k,v in d.items() if k!='total')==int(d['total']);rows.append(dict(variant=phase,command=len([x for x in rows if x['variant']==phase]),**d))
with (out/'layernorm_phases.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
rows=[]
for p in sorted((run/'matched').glob('*/run.log')):
 for line in p.read_text().splitlines():
  if line.startswith('MATRIX_CORE_CASE_PASS') or line.startswith('MATRIX_CORE_PROFILE'):
   rows.append(dict(config=p.parent.name,kind=line.split()[0],**dict(re.findall(r'(\w+)=([^ ]+)',line))))
 log(str(p.relative_to(run)),f'matrix/{p.parent.name}.log.gz')
fields=list(dict.fromkeys(k for r in rows for k in r))
with (out/'matrix_ablation.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');w.writeheader();w.writerows(rows)
for src,dst in [('cnn/top.log','cnn/top.log.gz'),('cnn/manifest.json','cnn/manifest.json'),('sfu/run.log','validation/sfu.log.gz'),('seeded.log','validation/seeded.log.gz'),('opt_smoke.log','validation/smoke.log.gz'),('tiny/gemm/run.log','tiny/gemm.log.gz'),('tiny/cnn/run.log','tiny/cnn.log.gz'),('mini/run.log','tiny/nma_cnn.log.gz'),('product_gemv.log','matrix/product_gemv.log.gz'),('forward/enable_0/run.log','matrix/forward_off.log.gz'),('forward/enable_1/run.log','matrix/forward_on.log.gz')]:
 if dst.endswith('.gz'):log(src,dst)
 else:copy(src,dst)
summary={'status':'DESIGN_PARTIAL','baseline_source':'800c5b0ab1f0b9de5937c65e7c5f57b6d6fbc92c','candidate_rtl_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'research_source':'3ec0be579c6847d4ae707a30e5e30ccd64ab0813','tinynpu_source':'8216c22b762011aa20c05fc2768423fd12dda59d','model_sha256':hashlib.sha256((root/'benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json').read_bytes()).hexdigest(),'decode_baseline':72238,'decode_candidate':70318,'mean_before':9029.75,'mean_after':8789.75,'savings_percent':1920/72238*100,'golden':'8 paired logits/KV hashes equal; all tensor golden checks PASS','tools':{'vcs':'V-2023.12-SP1_Full64','verilator':subprocess.check_output(['/tmp/nmaforge_verilator_5.052/bin/verilator','--version'],text=True).strip()},'environment':'behavioral SPAD; 128 KiB H16/CNN/mini; default 512 KiB smoke; simulation period is not Fmax','artifacts':{str(p.relative_to(out)):{'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(out.rglob('*')) if p.is_file() and p.name!='manifest.json'}}
(out/'manifest.json').write_text(json.dumps(summary,indent=2)+'\n')
print('ROUND28_ARCHIVE_PASS phases=%d matrix_rows=%d'%(len(list(csv.DictReader((out/'layernorm_phases.csv').open()))),len(rows)))
