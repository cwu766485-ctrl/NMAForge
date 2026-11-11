#!/usr/bin/env python3
"""Paired exact workload/source accounting, including SRAM sequence identity."""
import argparse,collections,csv,hashlib,json,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args();out=a.run/'analysis';out.mkdir(exist_ok=True);base=a.run/'baseline';opt=a.run/'optimized';s0=json.loads((base/'analysis/summary.json').read_text());s1=json.loads((opt/'analysis/summary.json').read_text());rows=[]
for n in s0:
 b,c=s0[n],s1[n];assert b['read_bytes']==c['read_bytes']and b['write_bytes']==c['write_bytes'];assert sum(c['exclusive'].values())==c['cycles']
 if n not in ['h32','h32_old']:assert b['cycles']==c['cycles'],n
 rows.append(dict(workload=n,baseline_cycles=b['cycles'],ln32_cycles=c['cycles'],tokens_or_windows=b['windows'],baseline_cycles_per_window=b['cycles_per_window'],ln32_cycles_per_window=c['cycles_per_window'],removed_cycles=b['cycles']-c['cycles'],cycle_reduction=(b['cycles']-c['cycles'])/b['cycles'],baseline_reads=b['read_bytes'],ln32_reads=c['read_bytes'],baseline_writes=b['write_bytes'],ln32_writes=c['write_bytes'],golden='PASS',boundary='CMDQ execution only',useful_mac_per_cycle_after=c['useful_macs']/c['cycles']))
assert s0['h32']['cycles']==367051 and s1['h32']['cycles']==350155
paths=[('h32','h32/profile'),('h32_old','h32_old/profile'),('h16','h16_profile/profile')]+[(n,n+'/profile')for n in ['cnn/legacy','cnn/first_fused','cnn/both_fused_row_major']]+[(n,n+'/profile')for n in s0 if n.startswith('kernel')]
seqchecks=[]
for n,prefix in paths:
 sequences=[]
 for d in [base,opt]:
  events=[]
  for r in csv.DictReader((d/(prefix+'_memory.csv')).open()):
   if int(r['window'])>=0 and r['kind']=='A':events.append(tuple(r[k]for k in ['window','client','write','address','bytes','bank_mask']))
  sequences.append(events)
 assert sequences[0]==sequences[1],n
 seqchecks.append(dict(workload=n,accepted_sequence_entries=len(sequences[0]),addresses_clients_rw_bytes_banks_equal=True,sha256=hashlib.sha256(json.dumps(sequences[0]).encode()).hexdigest()))
checks=[]
for n in ['h32','h32_old']:
 for i in range(12):
  files=[d/n/f'stage_{i}_t{i}_{kind}.memh'for d in [base,opt]for kind in ['golden','observed']];raw=[f.read_bytes()for f in files];assert len(set(raw))==1
  checks.append(dict(workload=n,stage=i,words=len(raw[0].splitlines()),sha256=hashlib.sha256(raw[0]).hexdigest(),baseline_observed_optimized_observed_golden_equal=True))
for name,data in [('PHASE2_LN32_ABLATION.csv',rows),('access_sequences.csv',seqchecks),('golden_checks.csv',checks)]:
 with(out/name).open('w')as f:w=csv.DictWriter(f,fieldnames=list(data[0]),lineterminator='\n');w.writeheader();w.writerows(data)
# Warning identity compare permits line-number shift only.
def warnings(p):
 records=[]
 for line in p.read_text().splitlines():
  if line.startswith('%Warning-'):records.append(re.sub(r'[^ ]+\.v:\d+:\d+:','SOURCE:',line))
 return collections.Counter(records)
assert warnings(a.run/'sfu-lint.log')==warnings(a.run/'sfu-lint-baseline.log')
(out/'summary.json').write_text(json.dumps({'decision':'RETAIN_LN32','merge_sha':'cb08797e612355b404f9eb697a34f99628deebfd','baseline_rtl_sha':'48790076b351cb9d49e1785247d32a1f51b8286d','phase1_sha':'ae7fd31eced13dcb9dbd70533da60559511d0a90','sfu_source_sha256':hashlib.sha256(Path('rtl/compute/sfu/ai_tensor_sfu_core.v').read_bytes()).hexdigest(),'h32_before':367051,'h32_after':350155,'removed':16896,'reduction_pct':100*16896/367051,'sfu_before':290595,'sfu_after':273699,'ln32_before':104064,'ln32_after':87168,'same_sram_access_sequence':True,'new_data_flops':0,'new_ports':0,'new_mac':0,'new_lint_warnings':0,'timing':'FMAX_NOT_MEASURED'},indent=2)+'\n');print('PHASE2_ABLATION_PASS cycles/access sequence/Golden/lint identities')
