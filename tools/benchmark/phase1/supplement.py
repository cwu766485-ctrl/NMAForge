#!/usr/bin/env python3
"""Additional boundary/quality/static inventories; no product modifications."""
import argparse,collections,csv,hashlib,json,re,sys,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args();out=a.run/'analysis';out.mkdir(exist_ok=True)
def save(n,d):
 with (out/n).open('w') as f:
  w=csv.DictWriter(f,fieldnames=list(d[0]),lineterminator='\n');w.writeheader();w.writerows(d)
fields=lambda s:dict(re.findall(r'(\w+)=([^ ]+)',s))
import numpy as np
rows=[]
for mode in ['legacy','first_fused','both_fused_row_major']:
 d=a.run/'cnn'/mode;log=(d/'top.log').read_text();m=fields(next(l for l in log.splitlines() if l.startswith('REPRESENTATIVE_MODEL_PASS ')));meta=json.loads((d/'manifest.json').read_text())
 markers={k:int(v) for k,v in re.findall(r'STAGE_A_(CONFIG_BEGIN|CONFIG_END|READBACK_BEGIN|READBACK_END) clock=(\d+)',log)}
 assert markers['READBACK_END']-markers['READBACK_BEGIN']==4992
 values=[int(l.split()[2],16) for l in (d/'output.txt').read_text().splitlines()];assert len(values)==832
 raw=bytes(v>>(8*i)&255 for v in values for i in range(4));x=np.frombuffer(raw,dtype=np.int8).reshape(208,16);times=[]
 for i in range(101):
  t=time.perf_counter_ns();pred=int(x[:196,:10].astype(np.int64).sum(axis=0).argmax());dt=time.perf_counter_ns()-t
  if i:times.append(dt)
 assert pred==meta['predicted_label']==meta['true_label']
 rows.append(dict(mode=mode,command_cycles=int(m['command_cycles']),dma_preload_cycles=int(m['preload_dma_window_cycles']),dma_busy_cycles=int(m['preload_dma_busy_cycles']),dma_payload_bytes=int(m['preloaded_spad_bytes']),configuration_cycles=markers['CONFIG_END']-markers['CONFIG_BEGIN'],output_readback_cycles=4992,output_readback_bytes=3328,host_preprocess_seconds=meta['host_im2col_seconds'],host_gap_argmax_median_ns=int(np.median(times)),host_environment=sys.version,output_sha256=hashlib.sha256(raw).hexdigest(),prediction=pred,full_inference_latency='NOT_MEASURED',layout='host Im2col + native operand pack; in-timer0x53 row-major stores'))
assert len({r['output_sha256'] for r in rows})==1
save('cnn_boundary.csv',rows)
# Retain every warning identity, with explicit non-signoff disposition.
s=json.loads((a.run/'static/summary.json').read_text());warnings=[]
for line in s['findings']:
 m=re.match(r'%Warning-(\w+): (.+?):(\d+):(\d+): (.*)',line);kind,file,ln,col,msg=m.groups();file=file.split('/rtl/')[-1]
 if kind=='LATCH':cl='DIAGNOSTIC_TEMP_DEFAULT_REMOVES_WARNING';action='Default local candidate; prove equivalence before admitting fix; nine output warnings may be propagated block analysis'
 elif kind=='UNOPTFLAT':cl='STRUCTURAL_DEPENDENCY_SUSPECT_NOT_WAIVED';action='Split selection from ready/protection/response fanout, check bit-level acyclicity and unchanged fault delivery'
 elif kind=='PINMISSING':cl='OPTIONAL_CDC_PATH_INTERFACE_GAP';action='Tie or connect dependency load/seed after CDC contract review; path not instantiated by product top'
 elif kind=='CASEINCOMPLETE':
  cl='EXPLICIT_DEFAULT_READ_OR_SEQUENTIAL_HOLD' if 'regs' in file else 'ILLEGAL_STATE_RECOVERY_GAP'
  action='Check unknown/misaligned address rejection and intentional register holds' if 'regs' in file else 'Add error recovery only after fault/abort/accepted-read drain review'
 elif '/fp/' in '/'+file+'/':cl='OPTIONAL_FP_NUMERIC_WIDTH_REVIEW';action='Check exponent signedness, bounds, rounding; benchmark does not validate optional FP numeric corners'
 elif 'matrix' in file:cl='PARAMETER_INDEX_OR_BOOLEAN_WIDTH_REVIEW';action='Prove legal parameter range and index bounds; explicit sizing/casts in future patch, no blanket waiver'
 elif 'dma' in file:cl='TRANSFER_ID_BURST_WIDTH_REVIEW';action='Prove slot/pointer, beat and4KiB-boundary limits across elaborations'
 elif 'scratchpad' in file or 'pipeline' in file or 'kv_' in file or 'cnn/' in file:cl='ADDRESS_INDEX_RANGE_REVIEW';action='Prove capacity/address intermediate bounds before truncation; exercise boundary and overflow errors'
 else:cl='ARITHMETIC_OR_CONTROL_WIDTH_REVIEW';action='Review signed extension and counter/address sizing under SPEC; no automatic acceptance'
 warnings.append(dict(kind=kind,file='rtl/'+file,line=ln,column=col,message=msg,classification=cl,disposition=action,status='OPEN_SCOPED_REVIEW'))
save('static_warning_inventory.csv',warnings)
# Summarize direct pipeline states and cycle bounds; not performance claims.
states=collections.Counter()
for r in csv.DictReader((out/'sfu_states.csv').open()):
 if r['workload']=='h32' and int(r['window'])>=4:states[int(r['opcode'],16),int(r['state'])]+=int(r['cycles'])
ln_wait=states[0x38,35]+states[0x38,13]
summary=json.loads((out/'summary.json').read_text());h=summary['h32']
(out/'candidate_bounds.json').write_text(json.dumps({'length32_mean_variance_wait':ln_wait,'length32_layernorm_descriptors':states[0x38,28],'ideal_removed_cycles':ln_wait,'baseline_decode_cycles':h['cycles'],'ideal_cycle_reduction_fraction':ln_wait/h['cycles'],'ideal_cycles_after':h['cycles']-ln_wait,'ideal_cycles_per_token_after':(h['cycles']-ln_wait)/8,'estimated_incremental_buffer_bits':0,'status':'ANALYTIC_BOUND_NOT_RTL_RESULT','matrix_prefetch_wait':sum(1 for r in csv.DictReader((a.run/'kernel_30_32_32_64/profile_cycles.csv').open()) if r['matrix_busy']=='1' and r['matrix_state']=='14'),'second_candidate':'C_EARLIER_PREFETCH_DEFER_NOT_ADMITTED_WITHOUT_POSITIVE_INCREMENTAL_MODEL'},indent=2)+'\n')
# Independently compare exact observed/golden files, not log markers alone.
checks=[]
for name in ['h32','h32_old']:
 d=a.run/name
 for i in range(12):
  gold=d/f'stage_{i}_t{i}_golden.memh';obs=d/f'stage_{i}_t{i}_observed.memh';assert gold.read_bytes()==obs.read_bytes()
  checks.append(dict(workload=name,stage=i,golden_words=len(gold.read_text().splitlines()),golden_sha256=hashlib.sha256(gold.read_bytes()).hexdigest(),observed_sha256=hashlib.sha256(obs.read_bytes()).hexdigest(),status='PASS'))
save('golden_checks.csv',checks)
print('PHASE1_SUPPLEMENT_PASS cnn boundaries/static inventory/candidate bounds/H32 independent byte compare')
