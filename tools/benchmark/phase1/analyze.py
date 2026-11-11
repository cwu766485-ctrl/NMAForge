#!/usr/bin/env python3
"""Close exclusive windows, request/response ledgers and accepted data bytes."""
import argparse,collections,csv,json,re,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
names=['matrix_tile_setup','matrix_operand_fetch','matrix_operand_wait','matrix_compute','matrix_writeback','matrix_completion','sfu_fetch_issue','sfu_fetch_response','sfu_arithmetic_control','sfu_pipeline_wait','sfu_writeback','sfu_completion','other_engine','completion_no_engine','descriptor_no_engine','dispatch_control']
fields=lambda s:dict(re.findall(r'(\w+)=([^ ]+)',s))
workloads=[];bucket_rows=[];spad_rows=[];opcode_rows=[];state_rows=[];client_rows=[];ledger_rows=[]
paths=[(d.name,d/'profile',d/'top.log') for d in sorted(a.run.glob('kernel_*'))]+[(f'cnn_{m}',a.run/'cnn'/m/'profile',a.run/'cnn'/m/'top.log') for m in ['legacy','first_fused','both_fused_row_major']]+[('h16',a.run/'h16_profile/profile',a.run/'h16/top_session.log')]+[(n,a.run/n/'profile',a.run/n/'top.log') for n in ['h32_old','h32']]
for name,prefix,logfile in paths:
 cr=list(csv.DictReader(Path(str(prefix)+'_cycles.csv').open()));mr=list(csv.DictReader(Path(str(prefix)+'_memory.csv').open()));log=logfile.read_text();windows=collections.defaultdict(list)
 for r in cr:windows[int(r['window'])].append({k:int(v) for k,v in r.items()})
 # Response timing is measured from acceptance to sampled valid edge, not FIFO residence guess.
 queue=collections.defaultdict(collections.deque);lat=collections.Counter();traffic=collections.Counter();byw=collections.defaultdict(collections.Counter)
 for r in mr:
  clk=int(r['clock']);client=int(r['client']);win=int(r['window']);assert int(r['error'])==0,(name,'fault in measured success run',r)
  if r['kind']=='A':
   size=int(r['bytes']);wr=int(r['write']);traffic[client,'write' if wr else 'read']+=size
   if win>=0:byw[win][('write' if wr else 'read')+str(client)]+=size;byw[win]['accept'+str(client)]+=1
   if not wr:queue[client].append(clk)
  else:
   assert queue[client],(name,'orphan response',r)
   delay=clk-queue[client].popleft();lat[client,delay]+=1
   assert delay==2,(name,'unexpected observed response latency',r,delay)
 assert not any(queue.values()),(name,'undrained ledger')
 markers=[fields(l) for l in log.splitlines() if l.startswith(('REPRESENTATIVE_MODEL_PASS ','INCREMENTAL_H16_STAGE_PASS ','STAGE_C_STAGE_PASS '))]
 assert len(markers)==len(windows),(name,len(markers),len(windows))
 for (client,delay),n in lat.items():ledger_rows.append(dict(workload=name,client=client,sampled_response_latency=delay,responses=n,scope='all traced scheduler requests including window=-1 preload/checker',orphan_responses=0,undrained_reads=0))
 for win,rs in windows.items():
  marker=markers[win];cycles=int(marker.get('cycles',marker.get('command_cycles',0)));assert cycles==len(rs),(name,win,cycles,len(rs))
  counts=collections.Counter(r['bucket'] for r in rs);assert sum(counts.values())==cycles
  read=int(marker['spad_read_bytes']);write=int(marker['spad_write_bytes'])
  # Data clients only. Descriptor and completion traffic is separately charged.
  mem=byw[win];assert sum(mem['read'+str(c)] for c in [2,3,5])==read,(name,win,'read')
  assert sum(mem['write'+str(c)] for c in [2,3,5])==write,(name,win,'write')
  useful=int(marker.get('useful_macs',0))
  if name.startswith('kernel_'):useful=json.loads((prefix.parent/'shape.json').read_text())['useful_macs']
  elif name in ['h32','h32_old']:useful=2*(4*32*32+2*32*128+2*32*(win+1))+32*32
  accepted=collections.Counter();reqwait=collections.Counter();contention=collections.Counter();pair=collections.Counter()
  for r in rs:
   req,acc=r['request_mask'],r['accept_mask']
   for c in range(8):
    if acc>>c&1:accepted[c]+=1
    if req>>c&1 and not(acc>>c&1):reqwait[c]+=1
    if req>>c&1:
     for other in range(c+1,8):
      if req>>other&1:pair[c,other]+=1
   if bin(req).count('1')>1:contention['multi_request_cycles']+=1
  workloads.append(dict(workload=name,window=win,kind='decode' if (name.startswith('h32') and win>=4) or(name=='h16' and win>=1) else 'prefill' if name.startswith('h') else 'kernel',cycles=cycles,useful_macs=useful,useful_mac_per_cycle=useful/cycles,useful_array_utilization=useful/(256*cycles),mac_active_utilization=useful/(256*counts[3]) if counts[3] else 0,read_bytes=read,write_bytes=write,prefetch_compute_overlap=sum(r['prefetch_overlap'] for r in rs),max_outstanding=max(r['outstanding'] for r in rs),multi_request_cycles=contention['multi_request_cycles'],arbitration_wait=sum(reqwait.values()),descriptor_read_bytes=mem['read0'],completion_write_bytes=mem['write1']))
  for c in range(6):client_rows.append(dict(workload=name,window=win,client=c,accepted_requests=mem['accept'+str(c)],read_bytes=mem['read'+str(c)],write_bytes=mem['write'+str(c)]))
  for i,n in enumerate(names):bucket_rows.append(dict(workload=name,window=win,bucket=n,cycles=counts[i]))
  for c in range(8):spad_rows.append(dict(workload=name,window=win,request_form=c,wait_cycles=reqwait[c],accepted_requests=accepted[c],pair_contention=json.dumps({str(k):v for k,v in pair.items() if c in k})))
  ops=collections.Counter(r['sfu_opcode'] for r in rs if r['sfu_busy']);states=collections.Counter((r['sfu_opcode'],r['sfu_state']) for r in rs if r['sfu_busy'])
  for op,n in ops.items():opcode_rows.append(dict(workload=name,window=win,opcode=hex(op),cycles=n))
  for (op,st),n in states.items():state_rows.append(dict(workload=name,window=win,opcode=hex(op),state=st,cycles=n))
 for (client,delay),n in lat.items():spad_rows.append(dict(workload=name,window='all',request_form='response_client'+str(client),wait_cycles='NA',accepted_requests=n,pair_contention='measured_latency_cycles='+str(delay)))
for file,data in [('workloads.csv',workloads),('exclusive.csv',bucket_rows),('spad.csv',spad_rows),('sfu_opcodes.csv',opcode_rows),('sfu_states.csv',state_rows),('clients.csv',client_rows),('responses.csv',ledger_rows)]:
 with (a.out/file).open('w') as f:w=csv.DictWriter(f,fieldnames=list(data[0]),lineterminator='\n');w.writeheader();w.writerows(data)
summary={}
for name in sorted({r['workload'] for r in workloads}):
 rows=[r for r in workloads if r['workload']==name and (not name.startswith('h') or r['kind']=='decode')];wins={r['window'] for r in rows};cnt=collections.Counter()
 for r in bucket_rows:
  if r['workload']==name and r['window'] in wins:cnt[r['bucket']]+=r['cycles']
 total={k:sum(r[k] for r in rows) for k in ['cycles','useful_macs','read_bytes','write_bytes','prefetch_compute_overlap','multi_request_cycles','arbitration_wait']};total.update(windows=len(rows),cycles_per_window=total['cycles']/len(rows),exclusive=dict(cnt));assert sum(cnt.values())==total['cycles'];summary[name]=total
(a.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print('PHASE1_ATTRIBUTION_PASS workloads='+str(len(summary)));print(json.dumps(summary,indent=2))
