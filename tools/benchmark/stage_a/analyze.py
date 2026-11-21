"""Stage A: derive closed cycle partitions, traffic bounds and memory budgets.

Only observed cycles/accepted traffic are measured; forwarding benefits are
explicit optimistic bounds, never optimization results.
"""
import argparse, collections, csv, gzip, hashlib, json, math, re, subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--cnn',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)

def save(name,value): (a.out/name).write_text(json.dumps(value,indent=2)+'\n')
def csv_save(name,rows):
 with (a.out/name).open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def fields(line):return dict(re.findall(r'(\w+)=([^ ]+)',line))
phase_names=['matrix_initial_fetch','matrix_prepare_execute','matrix_writeback','matrix_prefetch_wait','matrix_lifecycle','sfu_fetch_states','sfu_writeback','sfu_arithmetic_cache_control','sfu_lifecycle','kv_busy','other_engine','completion_request_no_engine','descriptor_request_no_engine','no_engine_control_response_dispatch']
manifest=json.loads((a.run/'session/workload/manifest.json').read_text());log=(a.run/'session/top_session.log').read_text();stages=manifest['stages'];timing=list(csv.DictReader((a.run/'h16_cycles.csv').open()));traffic=list(csv.DictReader((a.run/'h16_traffic.csv').open()))
by_window=collections.defaultdict(list);tr_window=collections.defaultdict(list)
for row in timing:by_window[int(row['window'])].append(row)
for row in traffic:tr_window[int(row['window'])].append(row)
parts=[];token_rows=[];group_rows=[];bounds=[]
intervals={}
for line in log.splitlines():
 if line.startswith('R17_DESCRIPTOR_INTERVAL '):
  f=fields(line);intervals[(f['stage'],int(f['local_index']))]=int(f['cycles'])
for win,stage in enumerate(stages):
 rows=by_window[win];counts=collections.Counter(int(x['phase']) for x in rows)
 marker=next(x for x in log.splitlines() if x.startswith('INCREMENTAL_H16_STAGE_PASS ') and 'stage='+stage['name']+' ' in x);profile=fields(marker)
 assert len(rows)==int(profile['cycles']),(stage['name'],len(rows),profile['cycles'])
 for phase,name in enumerate(phase_names):parts.append(dict(workload='h16',stage=stage['name'],phase=name,cycles=counts[phase]))
 reads=sum(int(x['bytes']) for x in tr_window[win] if x['write']=='0');writes=sum(int(x['bytes']) for x in tr_window[win] if x['write']=='1')
 assert reads==int(profile['spad_read_bytes']) and writes==int(profile['spad_write_bytes'])
 token_rows.append(dict(stage=stage['name'],cycles=len(rows),useful_macs=stage['useful_macs'],useful_mac_per_cycle=stage['useful_macs']/len(rows),read_bytes=reads,write_bytes=writes,
 scalar_admission_stall=sum(int(x['scalar_stall']) for x in rows),banked_admission_stall=sum(int(x['banked_stall']) for x in rows),line_admission_stall=sum(int(x['line_stall']) for x in rows),dma_busy=sum(int(x['dma_busy']) for x in rows)))
 clock_rows={int(r['clock']):r for r in rows}
 ds=stage['descriptor_contract']
 for i,d in enumerate(ds):
  name=d['name'].removeprefix(stage['name']+'_')
  if name.startswith(('q_h','k_h','v_h')):group='QKV'
  elif name.startswith('kv_'):group='KV_materialization'
  elif name.startswith(('qk_','causal_softmax','prob_','av_')):group='Attention_score_softmax_AV'
  elif name.startswith(('wo_','head_merge')):group='Output_projection_merge'
  elif name.startswith(('residual','layernorm')):group='Residual_LayerNorm'
  elif name.startswith(('ffn','gelu')):group='FFN'
  elif name.startswith('logits'):group='LM_head'
  else:group='Other'
  group_rows.append(dict(stage=stage['name'],index=i,name=d['name'],group=group,opcode=hex(d['opcode']),cycles=intervals[(stage['name'],i)]))
 # Candidate edges use only the explicitly serialized descriptor list.
 for i,consumer in enumerate(ds):
  if consumer['opcode'] not in [0x36,0x38]:continue
  length=consumer['k_or_length'];base=consumer['src0'];end=base+4*length
  producers=[]
  for d in ds[:i]:
   if d['opcode'] in [0x30,0x34,0x35,0x38]:
    n=(d['m']*d['n']) if d['opcode']==0x30 else d['k_or_length']
    if d['dst']<end and base<d['dst']+n*4:producers.append(d)
  if not producers:continue
  producer=producers[-1];pop=producer['opcode'];cop=consumer['opcode']
  producer_names='+'.join(d['name'] for d in producers)
  kind='LN_to_Requant' if pop==0x38 else 'Residual_to_LN' if cop==0x38 and pop==0x34 else 'Matrix_to_Requant' if pop==0x30 and cop==0x36 else 'SFU_to_Requant'
  # Reads attributed by address and consumer engine: stage tensors are distinct;
  # producer writes remain mandatory. LN cache already removes extra X passes.
  matching=[t for t in tr_window[win] if t['engine']=='4' and t['write']=='0' and base<=int(t['address'],16)<end and int(clock_rows[int(t['clock'])]['sfu_opcode'])==cop]
  read_bytes=sum(int(t['bytes']) for t in matching)
  if read_bytes==0:continue
  # Count the accepted request plus the following WAIT states from actual
  # sampled clocks. This remains an optimistic zero-cost replacement bound:
  # any cache lookup/handshake/replay cost must be subtracted later.
  service_cycles=0
  for request in matching:
   clk=int(request['clock']);req_state=int(clock_rows[clk]['sfu_state'])
   assert req_state in [23,32],req_state
   service_cycles+=1;clk+=1
   while clk in clock_rows and int(clock_rows[clk]['sfu_state'])==req_state+1:
    service_cycles+=1;clk+=1
  assert service_cycles==3*len(matching),service_cycles
  bounds.append(dict(stage=stage['name'],edge=kind,consumer=consumer['name'],producer=producer_names,tensor_bytes=4*length,accepted_read_bytes=read_bytes,accepted_reads=len(matching),optimistic_removed_read_service_cycles=service_cycles,retained_write_bytes=4*length,scope='trace-derived optimistic upper bound; no RTL result'))
assert sum(x['cycles'] for x in token_rows[1:])==65771
csv_save('exclusive_phases.csv',parts);csv_save('workload_counters.csv',token_rows);csv_save('transformer_groups.csv',group_rows);csv_save('forwarding_bounds.csv',bounds)
summary={}
for label,source in [('decode',parts[14:]),('prefill',parts[:14])]:
 c=collections.Counter()
 for row in source:c[row['phase']]+=row['cycles']
 summary[label]=dict(c)
summary['trace_validation']='PASS exclusive rows close to existing timing; accepted bytes close to existing counters'
summary['decode_forwarding_bounds']={}
for kind in sorted({x['edge']for x in bounds}):
 selected=[x for x in bounds if x['stage']!='prefill_kv_0_3' and x['edge']==kind]
 summary['decode_forwarding_bounds'][kind]={k:sum(x[k]for x in selected)for k in ['accepted_reads','accepted_read_bytes','optimistic_removed_read_service_cycles']}
save('bottleneck_summary.json',summary)
# Exact padded STORAGE budget for a specified hypothetical decoder, no train/run claim.
# Retain every current padded 4-row INT32 output, allocate per-token temporaries
# once and reuse only between completed tokens. FFN expansion fixed to 4H.
budgets=[]
for h,l,c,v in [(16,1,8,32),(32,2,16,32),(64,2,16,32),(64,2,32,32)]:
 heads=2;ff=4*h
 items={
  'token_position_embeddings_i8':(v+c)*h,
  'qkv_out_ffn_weights_i8':l*(4*h*h+2*h*ff),
  'lm_head_i8':h*v,
  'gamma_beta_i32':l*2*2*h*4,
  'kv_cache_i8':l*2*c*h,
  # QKV raw and requant, score/prob INT32 and prob INT8, AV raw/requant,
  # per-head projected INT32, merged+2residual+2LN raw, both LN packed,
  # FFN up/GELU/down raw + GELU packed, logits INT32.
  'qkv_int32_and_packed':3*(4*h*4+4*h),
  'score_prob_int32_and_packed':heads*(2*4*c*4+4*c),
  'av_raw_and_packed':4*h*4+4*h,
  'head_projections_int32':heads*4*h*4,
  'merged_residual_ln_int32':5*4*h*4,
  'ln_packed':2*4*h,
  'ffn_raw_gelu_down_and_packed':2*4*ff*4+4*h*4+4*ff,
  'input_int32_and_packed':4*h*4+4*h,
  'logits_int32':4*v*4,
  'kv_readback_and_packing_workspaces':2*l*c*h+2*4*c+2*4*h,
  'cmdq_128x64':128*64,'cplq_128x16':128*16,
 }
 # Each declared region has 16-byte base alignment; plus 4KiB guards/metadata.
 items={k:(n+15)//16*16 for k,n in items.items()};items['guard_metadata_reserve']=4096
 total=sum(items.values())
 budgets.append(dict(hidden=h,layers=l,context=c,vocabulary=v,heads=heads,ffn=ff,storage_bytes=items,total_bytes=total,capacity_bytes=131072,margin_bytes=131072-total,
  fits_128k=total<=131072,policy='all weights + KV resident; completed-token/layer temporary reuse; no inter-token retained intermediate observability; align each region16; graph not implemented',execution_status='NOT_IMPLEMENTED_NOT_TRAINED' if h!=16 else 'hypothetical_4H_FFN_not_current_H16_FFN'))
save('larger_model_budget.json',budgets)
# Current actual tensor/storage high water; mapper uses physical padded shapes.
tensors=manifest['tensors'];actual=[]
for name,t in tensors.items():
 size=math.prod(t['shape'])*(4 if t['dtype']=='i32' else 1)
 actual.append(dict(name=name,address=t['address'],bytes=size,end=t['address']+size,dtype=t['dtype'],layout=t['layout']))
assert max(t['end'] for t in actual)==69568
csv_save('current_tensor_allocations.csv',actual)
save('current_memory.json',dict(tensor_bytes=sum(t['bytes']for t in actual),tensor_high_water=69568,descriptor_base=manifest['descriptor_base'],completion_base=manifest['completion_base'],reserved_completion_end=manifest['completion_base']+128*16,capacity=131072,
 initial_image_sha256=digest(a.run/'session/workload/initial_memory.memh'),note='monotonic allocation retains all eight stages, unlike hypothetical reused budget'))
# CNN: independently verify output readback/postprocess and phase closure.
import time,numpy as np
cnn_rows=[]
for mode in ['legacy','first_fused','both_fused_row_major']:
 folder=a.cnn/mode;txt=(folder/'top.log').read_text();line=next(x for x in txt.splitlines()if x.startswith('REPRESENTATIVE_MODEL_PASS '));d=fields(line)
 sample_rows=list(csv.DictReader((folder/'profile_cycles.csv').open()));assert len(sample_rows)==int(d['command_cycles'])
 for idx,name in enumerate(phase_names):parts.append(dict(workload='cnn_'+mode,stage='cmdq',phase=name,cycles=sum(int(r['phase'])==idx for r in sample_rows)))
 vals=[int(ln.split()[2],16)for ln in (folder/'output.txt').read_text().splitlines()];assert len(vals)==832
 raw=bytes(v>>(8*i)&255 for v in vals for i in range(4));out=np.frombuffer(raw,dtype=np.int8).reshape(208,16)
 times=[];pred=None
 for i in range(101):
  t=time.perf_counter_ns();scores=out[:196,:10].astype(np.int64).sum(axis=0);pred=int(np.argmax(scores));dt=time.perf_counter_ns()-t
  if i:times.append(dt)
 meta=json.loads((folder/'manifest.json').read_text());assert pred==meta['predicted_label']==meta['true_label']
 begins={k:int(v)for k,v in re.findall(r'STAGE_A_(CONFIG_BEGIN|CONFIG_END|READBACK_BEGIN|READBACK_END) clock=(\d+)',txt)}
 assert begins['READBACK_END']-begins['READBACK_BEGIN']==4992
 cnn_rows.append(dict(mode=mode,cycles=int(d['command_cycles']),dma_window=int(d['preload_dma_window_cycles']),dma_busy=int(d['preload_dma_busy_cycles']),dma_bytes=int(d['preloaded_spad_bytes']),configuration_cycles=begins['CONFIG_END']-begins['CONFIG_BEGIN'],output_readback_cycles=4992,output_readback_bytes=3328,spad_read=int(d['spad_read_bytes']),spad_write=int(d['spad_write_bytes']),useful_macs=570164,useful_mac_per_cycle=570164/int(d['command_cycles']),host_im2col_seconds=meta['host_im2col_seconds'],postprocess_median_ns=int(np.median(times)),prediction=pred,output_sha256=hashlib.sha256(raw).hexdigest()))
assert len({x['output_sha256']for x in cnn_rows})==1
csv_save('cnn_accounting.csv',cnn_rows);csv_save('exclusive_phases.csv',parts)
print('STAGE_A_ANALYSIS_PASS phases/bytes/Golden/readback closed; hypothetical budgets explicit')
