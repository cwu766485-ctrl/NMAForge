#!/usr/bin/env python3
"""Archive public Gate 0/1 logs, identities and exact workload checks (no EDA DBs)."""
import argparse, collections, csv, gzip, hashlib, json, re, subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--diagnostics',type=Path,required=True);a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
rows=[]
def archive(source,rel):
 data=source.read_bytes()
 if source.suffix==".csv":data=data.replace(b"\r\n",b"\n")
 dst=a.out/rel;dst.parent.mkdir(parents=True,exist_ok=True)
 dst.write_bytes(gzip.compress(data,mtime=0) if rel.endswith('.gz') else data)
 return sha(dst.read_bytes())
def test(name,config,source,marker,detail):
 text=source.read_text();assert marker in text and 'Fatal:' not in text and 'TEST FAIL' not in text,(name,source)
 rel='logs/'+name+'.log.gz';digest=archive(source,rel)
 rows.append(dict(configuration=config,test=name,result='PASS',detail=detail,evidence=rel,evidence_sha256=digest))
for depth in (8192,32768):
 cfg=f'4x{depth}x32 ({depth*16//1024}KiB)'
 test('smoke_'+str(depth),cfg,a.run/f'top_{depth}/smoke.log','\nTEST PASS\n','20 seeded random cases; all engines; 0x52/0x53; reset/abort/backpressure')
 test('boundary_'+str(depth),cfg,a.run/f'top_{depth}/boundary.log','SPAD_CAPACITY_BOUNDARY_PASS','first/last word/line, OOB, alignment, DMA crossing/drain/recovery, CMDQ/CPLQ')
 archive(a.run/f'top_{depth}/compile.log',f'logs/compile_{depth}.log.gz')
for name,rel,marker,detail in [
 ('dma_stress','dma_stress.log','\nTEST PASS\n','8 read/8 write AXI error injections and drain'),
 ('fault','fault/run.log','STAGE_B_GATE0_RTL_PASS','normal/parity/protection/denied-write/recovery; 8192 words/bank'),
 ('protection','protection/run.log','SPAD_PROTECTION_TEST_PASS','25 directed +512 randomized'),
 ('arbiter','arbiter/run.log','SPAD arbiter protection-error response alignment PASS','RR/ownership/parity/control priority'),
 ('digits','digits/run.log','DIGITS_INFERENCE_PASS','360 samples; 46 descriptors; hidden and logits Golden'),
 ('h16','h16/top_session.log','H16_INCREMENTAL_TOP_PASS','8 persistent decode tokens; logits/KV/intermediate Golden'),
 ('h32','h32/h32/top.log','STAGE_C_TOP_PASS','4 prefill+8 persistent decode; 92928 Golden words'),
 ('mini10dataset','mini10dataset-driver.log','NMA_TRAINED_CNN_TOP_DATASET_PASS','396 samples; independent per-layer Golden'),
]:test(name,'128KiB',a.run/rel,marker,detail)
for mode,cycles in [('legacy',65429),('first_fused',22983),('both_fused_row_major',12351)]:
 test('cnn_'+mode,'128KiB',a.run/f'cnn/{mode}/top.log',f'command_cycles={cycles} ',f'570164 useful MAC;20800 Golden words;CMDQ cycles={cycles}')
 test('cnn_independent_'+mode,'software',a.run/f'cnn/{mode}/independent_golden.log','R19_TRAINED_CNN_GOLDEN_PASS','independent physical layout and integer Golden')
archive(a.diagnostics/'mini/run.log','logs/conv1x_mini.log.gz')
archive(a.diagnostics/'mini/workload/nma_cnn_manifest.json','mini/manifest.json')
# All dataset runs have independent output/intermediate checks; keep their logs.
for f in sorted((a.run/'mini10dataset/logs').glob('*.log')):
 archive(f,'mini10dataset/logs/'+f.name+'.gz')
for item in json.loads((a.run/'geometry/results.json').read_text()):
 name=item['test'];rel=f'geometry/{name}.log.gz';digest=archive(a.run/f'geometry/{name}/run.log',rel)
 rows.append(dict(configuration='geometry',test=name,result='PASS',detail=item['expected']+' (VCS fatal exit may be zero)',evidence=rel,evidence_sha256=digest))
archive(a.run/'allocator.log','logs/allocator.log.gz')
# Keep exact semantic fixture identities without committing large simulator outputs.
fixture_hashes={}
for root in [a.run/'h16/workload',a.run/'h32/h32']:
 for f in sorted(root.glob('*.memh')):fixture_hashes[str(f.relative_to(a.run))]=sha(f.read_bytes())
for root in [a.run/'h16/workload',a.run/'h32/h32']:
 for g in sorted(root.glob('*_golden.memh')):
  o=g.with_name(g.name.replace('_golden.memh','_observed.memh'))
  assert g.read_bytes()==o.read_bytes(),str(g)
for rel in ['h16/persistent_decode.json','h16/persistent_decode.csv','h16/workload/manifest.json',
 'h32/analysis/summary.json','h32/analysis/tokens.csv','h32/h32/manifest.json',
 'digits/golden.json','digits/workload/digits_workload.json',
 'mini10dataset/nma_tiny_cnn_demo_top_summary.json','mini10dataset/nma_tiny_cnn_demo_top_results.csv',
 'mini10dataset/workloads/sample_000/layout.memh',
 'geometry/results.json']:
 f=a.run/rel
 if f.exists():archive(f,rel)
for mode in ['legacy','first_fused','both_fused_row_major']:
 for name in ['manifest.json','model_memory.memh','model_golden.memh']:
  f=a.run/f'cnn/{mode}/{name}';fixture_hashes[f'cnn/{mode}/{name}']=sha(f.read_bytes())
  if name.endswith('.json'):archive(f,f'cnn/{mode}/{name}')
archive(a.run/'source.diff','diagnostics/tested_source.diff.gz')
# Original failures are evidence, never overwritten or classified as PASS.
for name,rel in [('baseline_smoke','baseline/smoke.log'),('runner_short_watchdog','final/cnn/legacy/top.log'),('lint_baseline','baseline/verilator.log'),('lint_candidate','verilator-final.log')]:
 archive(a.diagnostics/rel,'diagnostics/'+name+'.log.gz')
warning_counts=lambda f:dict(collections.Counter(re.findall(r'%Warning-([A-Z0-9_]+)',f.read_text())))
wb=warning_counts(a.diagnostics/'baseline/verilator.log');wc=warning_counts(a.diagnostics/'verilator-final.log');assert wb==wc
sources=[Path(x) for x in subprocess.check_output(['git','diff','--name-only','95c4387bb0ac57ff4fa427fd3c1202320ad0940b'],text=True).splitlines() if x.startswith(('rtl/','sw/','dv/','fpga/','benchmark/digits/','benchmark/tinynpu/'))]
sources+=list(Path('tools/benchmark/spad128').glob('*'))+[Path('sw/tools/spad_memory_planner.py'),Path('fpga/xczu15eg/scripts/spad_config.tcl')]
manifest=dict(status='GATE_0_1_PASS_SCOPED',baseline='95c4387bb0ac57ff4fa427fd3c1202320ad0940b',branch='feat/spad-128k-closure',date='2026-11-11 Asia/Singapore',source_commit_at_archive=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),source_sha256={str(f):sha(f.read_bytes()) for f in sorted(set(sources)) if f.is_file()},fixtures_sha256=fixture_hashes,tool={'vcs':'V-2023.12-SP1_Full64','verilator':'5.052','python':'3.12'},static_warnings_baseline=wb,static_warnings_candidate=wc,static_status='UNCHANGED_WARNINGS_NOT_SIGNOFF',ppa='NOT_RUN',gate2='DEFERRED_ARCHITECTURE_REVIEW',tiny_source_sha='8216c22b762011aa20c05fc2768423fd12dda59d',system_speedup='NOT_CLAIMED')
(a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
with (a.out/'regression.csv').open('w') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator="\n");w.writeheader();w.writerows(rows)
(a.out/'evidence_sha256.json').write_text(json.dumps({str(f.relative_to(a.out)):sha(f.read_bytes()) for f in sorted(a.out.rglob('*')) if f.is_file() and f.name!='evidence_sha256.json'},indent=2)+'\n')
print('SPAD128_ARCHIVE_PASS tests='+str(len(rows)))
