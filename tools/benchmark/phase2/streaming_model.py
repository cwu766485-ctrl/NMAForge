#!/usr/bin/env python3
"""Cycle-edge replay and bounded two-group requant scheduler, no product RTL.

Response records and original per-descriptor port contention are explicit.
All requests remain scalar4B; no cache or memory port bypass is modeled.
"""
import argparse,collections,csv,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,required=True);p.add_argument('--optimized',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
def read(p):return list(csv.DictReader(p.open()))
# Run a true edge-by-edge bounded pipeline. Two groups, max4 read ownership tags.
# group raw32x4 buffer, results quantized into4byte output. No2nd port.
def simulate(n,packed,blocked,depth=4,latency=2):
 groups=[list(range(i,min(i+(4 if packed else 1),n)))for i in range(0,n,4 if packed else 1)]
 next_read=0;next_commit=0;response={};inflight={};arith={};writes=[];events=[];clk=0;maxflight=0;maxgroups=0
 while next_commit<len(groups):
  assert clk<200000
  for i,t in list(inflight.items()):
   if t==clk:response[i]=clk;arith[i]=clk+1;del inflight[i];events.append((clk,'response',i))
  # A register separates SRAM response selection from requant/output packing.
  ready=all(i in arith and arith[i]<clk for i in groups[next_commit])
  if clk not in blocked:
   if ready:
    writes.append(clk);events.append((clk,'write_commit',next_commit))
    for i in groups[next_commit]:del arith[i];del response[i]
    next_commit+=1
   elif next_read<n and len(inflight)<depth:
    read_group=next_read//(4 if packed else 1)
    if read_group<next_commit+2:
     inflight[next_read]=clk+latency;events.append((clk,'read_accept',next_read));next_read+=1
  maxflight=max(maxflight,len(inflight));maxgroups=max(maxgroups,(next_read+(3 if packed else 0))//(4 if packed else 1)-next_commit);clk+=1
 assert next_read==n and not inflight
 assert len(writes)==len(groups)
 return {'cycles':clk+1,'read_requests':n,'write_requests':len(groups),'max_outstanding':maxflight,'max_groups':maxgroups,'read_latency':latency,'events':events,'bandwidth_lower_bound':n+len(groups)}
def replay_sequential(n,packed,blocked):
 state='request';idx=0;clock=0;response_at=-1
 while True:
  if state=='request' and clock not in blocked:response_at=clock+2;state='response'
  elif state=='response' and clock==response_at:
   if not packed or idx%4==3 or idx==n-1:state='write'
   else:idx+=1;state='request'
  elif state=='write' and clock not in blocked:
   if idx==n-1:state='done'
   else:idx+=1;state='request'
  elif state=='done':return clock+1
  clock+=1
  assert clock<200000

rows=[];summary={};numeric_checks=[]
for label,base in [('phase1',a.baseline),('ln32',a.optimized)]:
 cr=read(base/'h32/profile_cycles.csv');mr=read(base/'h32/profile_memory.csv');manifest=json.loads((base/'h32/manifest.json').read_text());byclock={int(r['clock']):r for r in cr};admissions=collections.defaultdict(list)
 pending=collections.defaultdict(collections.deque);pair={}
 for r in mr:
  c=int(r['clock']);cl=int(r['client'])
  if r['kind']=='A':
   if r['write']=='0':pending[cl].append(c)
   if int(r['window'])>=0:admissions[c].append(r)
  else:
   q=pending[cl].popleft();assert c-q==2;pair[q]=c
 assert not any(pending.values())
 segments=[];current=[]
 for r in cr:
  if r['sfu_busy']=='1':
   current.append(r)
   if r['sfu_state']=='28':segments.append(current);current=[]
 assert not current
 expected=[(s['index'],d)for s in manifest['stages']for d in s['descriptor_contract']if d['opcode']in range(0x32,0x3a)]
 assert len(expected)==len(segments),(len(expected),len(segments))
 total_removed=0;total_base=0;read_gap=collections.Counter()
 for (win,d),seg in zip(expected,segments):
  assert int(seg[0]['window'])==win and int(seg[0]['sfu_opcode'])==d['opcode']
  if win<4 or d['opcode']!=0x36:continue
  clocks=[int(r['clock'])for r in seg];start=clocks[0];readat=[];writeat=[];blocked=set()
  for r in seg:
   c=int(r['clock']);req=int(r['request_mask']);acc=int(r['accept_mask'])
   # Replay other actual arbiter acceptances as blocked service slots. Absolute
   # trace contention is not a closed-loop rescheduling proof.
   if acc & ~(1<<2):blocked.add(c-start)
   for m in admissions[c]:
    if int(m['client'])==2:
     if m['write']=='0':readat.append(c);assert pair[c]==c+2
     else:writeat.append(c)
  n=d['k_or_length'];packed=bool(d['flags']&16);
  assert d['dst']+(n if packed else n*4)<=d['src0'] or d['src0']+n*4<=d['dst'],('alias requires fallback',d)
  goldfile=base/'h32'/f'stage_{win}_t{win}_golden.memh';words=goldfile.read_text().split();assert int(words[0],16)==len(words[1:])//2
  image={int(words[i],16):int(words[i+1],16) for i in range(1,len(words),2)}
  predicted={}
  for i in range(n):
   raw=image[d['src0']+4*i];signed=raw if raw<2**31 else raw-2**32;value=max(-128,min(127,signed>>d['shift']))
   if packed:
    ordinal=i//4
    if d['flags']&32:
     row,col=divmod(i,d['n']);ordinal=((row//4)*(d['n']//4)+col//4)*4+row%4
    addr=d['dst']+4*ordinal;predicted[addr]=predicted.get(addr,0)|((value&255)<<(8*(i%4)))
   else:predicted[d['dst']+4*i]=value&0xffffffff
  assert all(image[addr]==v for addr,v in predicted.items()),('model requant Golden',d)
  numeric_checks.append({'baseline':label,'window':win,'name':d['name'],'checked_output_words':len(predicted),'golden':'PASS'})
  assert len(readat)==n;assert len(writeat)==((n+3)//4 if packed else n)
  for c1,c2 in zip(readat,readat[1:]):read_gap[c2-c1]+=1
  # Baseline replay is exact event residence, separately from proposed model.
  assert len(seg)==clocks[-1]-start+1
  for c in readat:assert byclock[c+1]['sfu_state']=='24' and byclock[c+2]['sfu_state']=='24'
  assert replay_sequential(n,packed,blocked)==len(seg),(d['name'],replay_sequential(n,packed,blocked),len(seg))
  model=simulate(n,packed,blocked);isolated=simulate(n,packed,set());row=dict(baseline=label,window=win,name=d['name'],length=n,packed=int(packed),observed_busy_cycles=len(seg),observed_read_requests=n,observed_write_requests=len(writeat),measured_two_edge_read_response=1,observed_port_blocked_slots=len(blocked),baseline_replay_cycles=len(seg),modeled_cycles=model['cycles'],no_contention_cycles=isolated['cycles'],bandwidth_lower_bound=model['bandwidth_lower_bound'],candidate_savings=len(seg)-model['cycles'],max_outstanding=model['max_outstanding'],max_live_groups=model['max_groups'])
  rows.append(row);total_removed+=row['candidate_savings'];total_base+=len(seg)
  if label=='ln32' and len([r for r in rows if r['baseline']=='ln32'])==1:
   with(a.out/'sample_schedule.csv').open('w')as f:
    w=csv.writer(f,lineterminator='\n');w.writerow(['cycle','event','ordinal']);w.writerows(model['events'])
 full=sum(1 for r in cr if int(r['window'])>=4)
 summary[label]={'full_decode_cycles':full,'requant_busy_cycles':total_base,'modeled_saved_cycles':total_removed,'predicted_full_decode_cycles':full-total_removed,'predicted_cycles_per_token':(full-total_removed)/8,'predicted_incremental_reduction':total_removed/full,'read_issue_delta_histogram':dict(read_gap),'model_scope':'trace-conditioned scalar requant only; all other descriptors/control fixed; not RTL or closed-loop arbiter proof'}
# Depth and latency sensitivities demonstrate mandatory latency/bandwidth tradeoff.
sensitivity=[]
for depth in [1,2,4]:
 for lat in [2,3,4]:
  r=simulate(128,True,set(),depth,lat);r.pop('events');sensitivity.append(dict(length=128,packed=1,depth=depth,latency=lat,**r))
# Ordered-fault contract model: reads are prefetched but errors commit in group
# order; accepted earlier output prefix retained. Reset drops epoch. This tests
# the intended model invariant, not actual product RTL error behavior.
faults=[]
def fault_replay(n,packed,bad_read=None,bad_write=None,reset_at=None,abort_at=None):
 width=4 if packed else 1;ng=(n+width-1)//width
 issued=0;commit=0;clock=0;tags={};seen=set();error_groups=set();bad_group=None;terminal=None;writes=[];discarded=0
 while clock<10000:
  for i,t in list(tags.items()):
   if t==clock:
    del tags[i]
    if terminal is None:
     seen.add(i)
     if i==bad_read:error_groups.add(i//width)
    else:discarded+=1
  if reset_at==clock:terminal='reset';discarded+=len(tags);tags.clear()
  if abort_at==clock:terminal='abort'
  if terminal is None:
   if commit<ng and all(i in seen for i in range(commit*width,min(n,(commit+1)*width))):
    if commit in error_groups or commit==bad_write:terminal='fault';bad_group=commit
    else:writes.append(commit);commit+=1
   elif issued<n and len(tags)<4 and issued//width<commit+2:
    tags[issued]=clock+2;issued+=1
  if terminal is None and commit==ng:terminal='success'
  if terminal is not None and not tags:break
  clock+=1
 assert clock<10000 and not tags
 assert writes==list(range(len(writes)))
 if bad_group is not None:assert all(x<bad_group for x in writes)
 if terminal=='reset':assert reset_at is not None
 return dict(length=n,packed=int(packed),fault_read=-1 if bad_read is None else bad_read,fault_write=-1 if bad_write is None else bad_write,reset_cycle=-1 if reset_at is None else reset_at,abort_cycle=-1 if abort_at is None else abort_at,accepted_prefix_groups=len(writes),terminal=terminal,terminal_completion_count=0 if terminal=='reset' else 1,remaining_tags=len(tags),discarded_responses=discarded)
for n,packed in [(64,True),(128,True),(32,False)]:
 for bad in range(n):faults.append(fault_replay(n,packed,bad_read=bad))
 for bad in range((n+3)//4 if packed else n):faults.append(fault_replay(n,packed,bad_write=bad))
 for t in range(1,10):
  faults.append(fault_replay(n,packed,reset_at=t));faults.append(fault_replay(n,packed,abort_at=t))
summary['cost']={'raw_group_buffers_bits':256,'packed_output_buffers_bits':64,'read_tags_bits':4*(16+2+1+1),'group_metadata_estimate_bits':2*(16+4+4+1+1+1),'epoch_and_control_estimate_bits':64,'estimated_total_bits':518,'no_new_port':True,'no_new_mac':True,'muxes':'registered4way raw selection,2way group output and per-byte pack enables; existing requant arithmetic','estimate_not_synthesis':True}
summary['decision']='MODEL_BENEFIT_SHOWN_NOT_RTL_ADMITTED_PENDING_FAULT_TIMING_REVIEW'
summary['fault_model_cases']=len(faults)
summary['unresolved_contract']=['Earlier reads can observe a different time-varying SRAM parity/permission/Host-write state; all checks retained but exact historical observation time is not proved equivalent','Input/output alias requires fallback; no bypass cache or shortened required INT32 producer lifetime','Trace-conditioned contention assumes other client schedule fixed; request rescheduling changes round-robin phase and descriptor overlap','Prefetched errors must be latched and retired in original group order; reset/abort must drain/discard epoch without duplicate completion','Read-time fault checks occur on actual new request/response; no output published before dependency and response validation; private protection configuration changes during lease require contract']
for name,data in [('descriptors.csv',rows),('sensitivity.csv',sensitivity),('fault_model.csv',faults),('numeric_checks.csv',numeric_checks)]:
 with(a.out/name).open('w')as f:w=csv.DictWriter(f,fieldnames=list(data[0]),lineterminator='\n');w.writeheader();w.writerows(data)
(a.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print('PHASE2_STREAMING_MODEL_PASS');print(json.dumps(summary,indent=2))
