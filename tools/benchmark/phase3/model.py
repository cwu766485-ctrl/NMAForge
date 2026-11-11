#!/usr/bin/env python3
"""Trace-calibrated bounded SFU and CNN transaction models. No product RTL."""
import argparse, collections, csv, gzip, io, json, math, random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
P = argparse.ArgumentParser()
P.add_argument('--out', type=Path, required=True)
a = P.parse_args(); a.out.mkdir(parents=True, exist_ok=True)
TRACE = ROOT / 'benchmark/research/phase2/optimized'

def rows(p):
    return list(csv.DictReader(io.StringIO(gzip.decompress(p.read_bytes()).decode())))
def save(name, data):
    with (a.out/name).open('w') as f:
        w=csv.DictWriter(f,fieldnames=list(data[0]),lineterminator='\n'); w.writeheader(); w.writerows(data)
def js(name, data): (a.out/name).write_text(json.dumps(data,indent=2)+'\n')

def pipeline(reads, writes, lanes, depth, blocked, line=False, reduction=False):
    """Two 4-element groups; one shared memory admission/edge; registered ALU.

    reads[e] lists each required scalar address (no removed/reused reads).
    writes[e] is address or None (pack/phase reduction). Four-element group
    packed output commits after all 4 calculations, otherwise ordered words.
    Line option gathers each operand stream in a group (reorders reads), uses
    only fully aligned contiguous four-word lines; other requests are scalar.
    This explicitly changes request granularity and is NOT fault-admitted.
    """
    n=len(reads); ng=(n+3)//4; nxt=0; committed=0; tags={}; seen=set()
    alu={}; results=set(); reduced=set(); next_reduce=0; readq={}; writepos=collections.Counter(); events=[]
    clk=0; maxlive=0; maxtags=0; services=0
    for g in range(ng):
        es=list(range(g*4,min(n,g*4+4))); units=[]
        if line:
            for operand in range(len(reads[es[0]])):
                inds=[(e,operand) for e in es]
                addrs=[reads[e][operand] for e in es]
                if len(es)==4 and addrs[0]%16==0 and addrs==list(range(addrs[0],addrs[0]+16,4)):
                    units.append(tuple(inds))
                else: units.extend((i,) for i in inds)
        else:
            units=[((e,k),) for e in es for k in range(len(reads[e]))]
        readq[g]=collections.deque(units)
    while committed<ng:
        assert clk<100000
        for t,(due,inds) in list(tags.items()):
            if due==clk:
                seen.update(inds); del tags[t]
                events.append((clk,'response',len(inds)))
        # A result captured on this edge cannot also be accepted by SRAM on
        # this edge. Retire only results stable since a previous edge.
        stable_results=set(results)
        for e,due in list(alu.items()):
            if due<=clk:
                results.add(e); del alu[e]
                events.append((clk,'arithmetic_complete',e))
        # One existing 64-bit reduction adder, original element order.
        # No uncharged 2/4-input reduction tree is assumed.
        if reduction and next_reduce in stable_results:
            reduced.add(next_reduce); next_reduce+=1
            events.append((clk,'ordered_reduce',next_reduce-1))
        # Initiation interval 1 per lane; compute consumes registered operands.
        eligible=[e for e in range(committed*4,min(n,(committed+2)*4))
                  if e not in alu and e not in results and all((e,k) in seen for k in range(len(reads[e])))]
        for e in eligible[:lanes]:
            alu[e]=clk+depth; events.append((clk,'arithmetic_issue',e))
        g=committed; es=list(range(g*4,min(n,g*4+4)))
        outs=[e for e in es if writes[e] is not None]
        head=outs[writepos[g]] if writepos[g]<len(outs) else None
        # A packed word/reduction waits for the whole current group.
        group_ready=all(e in (reduced if reduction else stable_results) for e in es)
        if not outs and group_ready:
            committed+=1
        elif clk not in blocked:
            if head is not None and head in stable_results and (len(outs)>1 or group_ready):
                writepos[g]+=1; services+=1; events.append((clk,'write_commit',writes[head]))
                if writepos[g]==len(outs):committed+=1
            elif len(tags)<4:
                readygroups=[k for k in range(committed,min(ng,committed+2))if readq[k]]
                if readygroups:
                    k=readygroups[0]; inds=readq[k].popleft()
                    tags[nxt]=(clk+2,inds); nxt+=1; services+=1
                    events.append((clk,'read_accept',len(inds)))
        if committed>g:
            for e in es:
                results.discard(e); reduced.discard(e)
                for k in range(len(reads[e])):seen.discard((e,k))
        maxlive=max(maxlive,len({e//4 for e,_ in seen}|{e//4 for e in alu}))
        maxtags=max(maxtags,len(tags)); assert maxlive<=2 and maxtags<=4
        clk+=1
    assert not tags and not alu
    assert all(not q for q in readq.values())
    assert sum(v for _,e,v in events if e=='read_accept')==sum(len(x)for x in reads)
    assert [v for _,e,v in events if e=='write_commit']==[x for x in writes if x is not None]
    if reduction:assert next_reduce==n
    return dict(cycles=clk+1,services=services,max_live_groups=maxlive,max_read_tags=maxtags,events=events)

cr=rows(TRACE/'h32/profile_cycles.csv.gz'); mr=rows(TRACE/'h32/profile_memory.csv.gz')
manifest=json.loads((TRACE/'h32/manifest.json').read_text())
byclock={int(r['clock']):r for r in cr}; accepted=collections.defaultdict(list)
pending=collections.defaultdict(collections.deque); paired={}; delays=collections.Counter()
for r in mr:
    clk=int(r['clock']); client=int(r['client'])
    assert int(r['error'])==0
    if r['kind']=='A':
        accepted[clk].append(r)
        if r['write']=='0':pending[client].append(clk)
    else:
        assert pending[client]
        start=pending[client].popleft(); paired[start]=clk; delays[clk-start]+=1
        assert clk-start==2
assert not any(pending.values())
segments=[]; cur=[]
for r in cr:
    if r['sfu_busy']=='1':
        cur.append(r)
        if r['sfu_state']=='28':segments.append(cur);cur=[]
assert not cur
expected=[(s['index'],d) for s in manifest['stages']for d in s['descriptor_contract'] if 0x32<=d['opcode']<=0x39]
assert len(expected)==len(segments)
READ_STATES={1,3,5,10,18,20,23,25,32,36,39}
WAIT_STATES={2,4,6,11,19,21,24,26,33,37,40}
WRITE_STATES={9,27}
state_counts=collections.Counter(); issue_gaps=collections.Counter(); descrows=[]; variants=collections.Counter(); phase_rows=[]; calibration=[]

# Each scalar replay token is request/read-response latency, write, or one
# captured arithmetic/control edge. Memory wait states collapse only when
# independently checked against the actual two-edge response ledger.
def replay(seg, blocked, memory):
    tokens=[]
    for r in seg:
        c=int(r['clock']); st=int(r['sfu_state']); ms=memory.get(c,[])
        if st in READ_STATES:
            if ms:
                assert len(ms)==1 and ms[0]['write']=='0' and paired[c]==c+2
                assert all(int(byclock[c+i]['sfu_state']) in WAIT_STATES for i in [1,2])
                tokens.append('read')
        elif st in WAIT_STATES:pass
        elif st in WRITE_STATES:
            if ms:assert len(ms)==1 and ms[0]['write']=='1';tokens.append('write')
        else:tokens.append('tick')
    t=0
    for token in tokens:
        if token!='tick':
            while t in blocked:t+=1
        t+=3 if token=='read' else 1
    assert t==len(seg),(seg[0],t,len(seg))
    return t

for (win,d),seg in zip(expected,segments):
    assert int(seg[0]['window'])==win and int(seg[0]['sfu_opcode'])==d['opcode']
    start=int(seg[0]['clock']); clocks={int(r['clock'])for r in seg}
    blocked={int(r['clock'])-start for r in seg if int(r['accept_mask'])&~4}
    # Filter core memory by the SFU's actual request-state addresses. Matrix
    # bias uses same scalar client tag, so success counts must match states.
    memory={c:[m for m in accepted[c]if m['client']=='2'] for c in clocks}
    for r in seg:
        st=int(r['sfu_state']); c=int(r['clock'])
        if memory[c]:assert st in READ_STATES|WRITE_STATES,('shared owner ambiguity',r,memory[c])
    observed=replay(seg,blocked,memory)
    if win<4:continue
    op=d['opcode']; n=d['k_or_length']; packet=[]
    calibration.append(dict(window=win,name=d['name'],opcode=hex(op),observed=observed,scalar_fsm_replay=observed,match=True))
    for r in seg:
        st=int(r['sfu_state']);state_counts[op,st]+=1
    read_times=[c for c in sorted(clocks)if memory[c]and memory[c][0]['write']=='0']
    for x,y in zip(read_times,read_times[1:]):issue_gaps[op,y-x]+=1
    # Gather scalar successful read/write address sequence and classify phases.
    allreads=[(int(byclock[c]['sfu_state']),int(m['address'],16))for c in sorted(clocks)for m in memory[c]if m['write']=='0']
    allwrites=[int(m['address'],16)for c in sorted(clocks)for m in memory[c]if m['write']=='1']
    if op==0x39:
        for lanes in [1,2,4]:
            for mode in ['scalar4B','line16B_hypothetical']:variants[lanes,mode]+=observed
        descrows.append(dict(window=win,name=d['name'],opcode=hex(op),length=n,observed=observed,reads=len(allreads),writes=len(allwrites),scope='softmax unchanged; iterative divider retained'))
        continue
    if op==0x38:
        assert n==32
        phases=[('mean',[(x,)for st,x in allreads if st==32],[None]*n,1),
                ('variance',[(x,)for st,x in allreads if st==36],[None]*n,2),
                ('affine',[tuple(x for st,x in allreads[2*n+i*3:2*n+(i+1)*3])for i in range(n)],allwrites,3)]
        assert [st for st,x in allreads[:n]]==[32]*n
        assert [st for st,x in allreads[n:2*n]]==[36]*n
        assert [st for st,x in allreads[2*n:]]==[x for _ in range(n)for x in [18,20,39]]
        # Existing exact mean/variance division, sqrt and reciprocal occupancy;
        # barrier at completion of each reduction remains mandatory.
        fixed=sum(1 for r in seg if int(r['sfu_state'])in [12,14,15,16,17,34])
    else:
        assert op in [0x34,0x35,0x36]
        arity=2 if op==0x34 else 1
        rs=[tuple(x for _,x in allreads[i*arity:(i+1)*arity])for i in range(n)]
        assert len(allreads)==n*arity
        if op==0x36 and d['flags']&16:
            ws=[None]*n
            for i,x in enumerate(allwrites):ws[min(i*4+3,n-1)]=x
        else:assert len(allwrites)==n;ws=allwrites
        phases=[('vector',rs,ws,2 if op==0x35 else 1)]; fixed=0
    # End-to-end numeric contract is inherited, not a model of new arithmetic.
    for lanes in [1,2,4]:
        for mode in ['scalar4B','line16B_hypothetical']:
            t=0; service=0
            for phase,rs,ws,depth in phases:
                local_blocked={x-t for x in blocked if x>=t}
                result=pipeline(rs,ws,lanes,depth,local_blocked,line=mode.startswith('line'),reduction=phase in ['mean','variance'])
                # Response address checks: every original read represented
                # once; line gather uses identical words but new ordering.
                assert sum(len(x)for x in rs)>0
                t+=result['cycles'];service+=result['services']
                phase_rows.append(dict(window=win,name=d['name'],phase=phase,lanes=lanes,memory=mode,model_cycles=result['cycles'],read_words=sum(len(x)for x in rs),write_words=sum(x is not None for x in ws),service_slots=result['services'],max_live_groups=result['max_live_groups'],max_read_tags=result['max_read_tags']))
                if win==4 and d['name']=='L0_gelu' and lanes==4 and mode.startswith('line'):
                    save('sfu_sample_schedule.csv',[dict(cycle=c,event=e,value=v)for c,e,v in result['events']])
            t+=fixed+1 # retain iterative reduction barrier and terminal edge
            variants[lanes,mode]+=t
    descrows.append(dict(window=win,name=d['name'],opcode=hex(op),length=n,observed=observed,reads=len(allreads),writes=len(allwrites),scope='conditional bounded pipeline model; fault contract not proved'))

full=sum(1 for r in cr if int(r['window'])>=4); assert full==350155
sfu=sum(r['observed']for r in descrows); assert sfu==273699
models=[]
for (lanes,mode),busy in sorted(variants.items()):
    predicted=full-sfu+busy
    models.append(dict(lanes=lanes,memory=mode,measured_full_decode=full,modeled_sfu_cycles=busy,predicted_full_decode=predicted,saved=full-predicted,reduction_pct=100*(full-predicted)/full,meets_cycle_target=predicted<=full*.8,fault_contract='NOT_PROVEN',rtl_admitted=False))
for lanes in [1,2,4]:
    models.append(dict(lanes=lanes,memory='current_scalar_fsm_unchanged',measured_full_decode=full,modeled_sfu_cycles=sfu,predicted_full_decode=full,saved=0,reduction_pct=0.0,meets_cycle_target=False,fault_contract='UNCHANGED_BY_IDENTITY',rtl_admitted=False))
save('sfu_models.csv',models);save('sfu_calibration.csv',calibration);save('sfu_descriptors.csv',descrows);save('sfu_phases.csv',phase_rows)
save('sfu_states.csv',[dict(opcode=hex(op),state=st,cycles=count)for(op,st),count in sorted(state_counts.items())])
save('sfu_issue_gaps.csv',[dict(opcode=hex(op),accepted_read_delta=gap,count=count)for(op,gap),count in sorted(issue_gaps.items())])
# Independent resource lower bounds, not full-decode timing predictions.
# Registered dependency/barrier latency and control must be added by scheduling.
bounds=[]
for r in phase_rows:
    reduction=r['phase'] in ['mean','variance']
    # Residual has two reads/element; use descriptor length, not read count.
    length=next(d['length']for d in descrows if d['window']==r['window'] and d['name']==r['name'])
    arithmetic=length if reduction else math.ceil(length/r['lanes'])
    lower=max(r['service_slots'],arithmetic)
    assert r['model_cycles']>=lower
    bounds.append(dict(window=r['window'],name=r['name'],phase=r['phase'],lanes=r['lanes'],memory=r['memory'],memory_admission_lower_bound=r['service_slots'],arithmetic_issue_lower_bound=arithmetic,resource_lower_bound=lower,scheduled_cycles=r['model_cycles'],scope='phase only; excludes barriers/fixed SFU work/non-SFU; no fault admission'))
save('sfu_resource_bounds.csv',bounds)
decode=[r for r in cr if int(r['window'])>=4]
js('sfu_service_contract.json',dict(clock_ns=4,spad_bytes=131072,banks=4,scheduler_admissions_per_edge=1,scalar_bytes=4,line_bytes=16,response_edges=2,current_sfu_interface='scalar only',sfu_denied_issue_slots=sum(bool(int(r['request_mask'])&4) and not(int(r['accept_mask'])&4)for r in decode),matrix_and_sfu_busy=sum(r['matrix_busy']=='1' and r['sfu_busy']=='1'for r in decode),response_histogram_scope='entire H32 trace including prefill and checker, all clients'))
js('sfu_summary.json',dict(baseline=full,sfu=sfu,non_sfu=full-sfu,scalar_replay_descriptors=len(calibration),calibrated_all_segments=len(segments),response_latency_histogram=dict(delays),models=models,decision='STOP_SFU_CANDIDATE_FAULT_CONTRACT_NOT_PROVEN',limitations=['Model lanes have independent integer ALUs, registered latency; arithmetic assumed exact, not newly verified RTL.','Other client service slots fixed from trace; no closed-loop rescheduling of command or arbiter.','Line changes operand-read order/granularity; existing aggregated permission/error semantics fail counterexamples.','Earlier read faults need ordered retirement and drain/epoch review; no relaxed fault mode.']))

# CNN packing/commit model. Keep 16-byte transactions, order and per-tile
# accumulator lifetime. Four existing postprocess lanes build 4 bytes/edge.
def cnn_tile(lines,lanes=4,buffers=1,blocked=frozenset(),bad=-1,abort=-1,reset=-1):
    chunks=(16+lanes-1)//lanes; producer=0; progress=0; head=0; queue=[]; clk=0; events=[]; terminal='success'; payload_stalled=None
    while head<lines:
        if clk==reset:terminal='reset';queue=[];break
        if clk==abort:terminal='abort';queue=[];break
        committing=queue and queue[0][1]==chunks and clk not in blocked
        # On a head fault suppress both younger commit and next tile launch.
        if committing:
            idx=queue[0][0];assert idx==head
            events.append((clk,'write_attempt',idx))
            if idx==bad:terminal='protection';queue=[];break
            queue.pop(0);head+=1
        # Existing FSM spends commit edge idle. Candidate second buffer permits
        # pack next line while writing the stable older buffer in FIFO order.
        if buffers==1 and committing:pass
        elif producer<lines:
            if progress==0 and len(queue)<buffers:queue.append([producer,0])
            active=next((q for q in queue if q[0]==producer and q[1]<chunks),None)
            if active is not None:
                active[1]+=1;events.append((clk,'pack',producer))
                progress+=1
                if progress==chunks:producer+=1;progress=0
        if queue and queue[0][1]==chunks and clk in blocked:
            payload=(queue[0][0],queue[0][1])
            if payload_stalled is not None:assert payload_stalled==payload
            payload_stalled=payload
        else:payload_stalled=None
        assert len(queue)<=buffers
        clk+=1; assert clk<100000
    return dict(cycles=clk,committed=head,terminal=terminal,events=events)

cc=rows(TRACE/'cnn/both_fused_row_major/profile_cycles.csv.gz'); cm=rows(TRACE/'cnn/both_fused_row_major/profile_memory.csv.gz')
write_windows=[];cur=[]
for r in cc:
    if r['matrix_state']=='9':cur.append(r)
    elif cur:write_windows.append(cur);cur=[]
assert not cur and len(write_windows)==65
writes={int(r['clock']):r for r in cm if r['kind']=='A'and r['client']=='2'and r['write']=='1'and int(r['window'])>=0}
cnrows=[]; cq=collections.Counter()
for i,seg in enumerate(write_windows):
    accepted_here=[writes[int(r['clock'])]for r in seg if int(r['clock'])in writes]
    assert len(seg)==80 and len(accepted_here)==16
    assert [j for j,r in enumerate(seg)if int(r['clock'])in writes]==list(range(4,80,5))
    assert all(int(w['bytes'])==16 and int(w['address'],16)%16==0 and w['bank_mask']=='15'for w in accepted_here)
    base=cnn_tile(16); assert base['cycles']==80
    row=dict(tile=i,baseline_write_cycles=80,pack_work_cycles=64,accepted_line_writes=16,actual_arbiter_wait=0)
    for lanes in [4,8,16]:
        for buffers in [1,2]:
            result=cnn_tile(16,lanes,buffers);cq[lanes,buffers]+=result['cycles'];row[f'model_lanes{lanes}_buffers{buffers}']=result['cycles']
    cnrows.append(row)
assert len(writes)==1040
# Retime the independently checked Golden payloads; do not manufacture another
# numerical reference or claim this validates a yet-unwritten hardware packer.
gold_raw=gzip.decompress((ROOT/'benchmark/research/phase1/cnn/both_fused_row_major/model_golden.memh.gz').read_bytes())
gold_words=[int(x,16)for x in gold_raw.split()]
assert len(gold_words)==1+2*gold_words[0]
gold=dict(zip(gold_words[1::2],gold_words[2::2])); transactions=[]
for tile,seg in enumerate(write_windows):
    schedules={buffers:[t for t,e,v in cnn_tile(16,4,buffers)['events']if e=='write_attempt']for buffers in [1,2]}
    line=0
    for r in seg:
        c=int(r['clock'])
        if c not in writes:continue
        address=int(writes[c]['address'],16)
        payload=sum(gold[address+4*i]<<(32*i)for i in range(4))
        transactions.append(dict(ordinal=len(transactions),tile=tile,line=line,address=f'{address:08x}',bytes=16,wstrb='ffff',golden_payload=f'{payload:032x}',observed_tile_edge=c-int(seg[0]['clock']),baseline_replay_edge=schedules[1][line],two_buffer_model_edge=schedules[2][line]))
        assert transactions[-1]['observed_tile_edge']==transactions[-1]['baseline_replay_edge']
        line+=1
save('cnn_transactions.csv',transactions)
cmodels=[]
for (lanes,buffers),cycles in sorted(cq.items()):
    predicted=12351-5200+cycles
    cmodels.append(dict(postprocess_lanes=lanes,buffers=buffers,measured_cmdq=12351,modeled_writeback=cycles,predicted_cmdq=predicted,saved=12351-predicted,reduction_pct=100*(12351-predicted)/12351,new_arithmetic_lanes=lanes-4,new_buffer_bits=(buffers-1)*128))
# Deterministic stall/fault/abort/reset transaction invariants, model only.
rng=random.Random(20261113);tests=[]
for seed in range(8):
    blocked={c for c in range(300)if rng.randrange(4)==0}
    for bad in range(-1,16):
        b=cnn_tile(16,4,1,blocked,bad); c=cnn_tile(16,4,2,blocked,bad)
        assert b['committed']==c['committed']==(16 if bad<0 else bad)
        assert b['terminal']==c['terminal']
        for result in [b,c]:
            attempts=[v for t,e,v in result['events']if e=='write_attempt']
            assert attempts==list(range(16 if bad<0 else bad+1))
        tests.append(dict(seed=seed,event='protection_at_line_'+str(bad),baseline_prefix=b['committed'],model_prefix=c['committed'],result='PASS'))
    for kind in ['abort','reset']:
        for at in range(1,90):
            c=cnn_tile(16,4,2,blocked,**{kind:at})
            attempts=[v for t,e,v in c['events']if e=='write_attempt']
            assert attempts==list(range(c['committed']))
            assert all(t<at for t,e,v in c['events']if e=='write_attempt') if c['terminal']==kind else True
            tests.append(dict(seed=seed,event=kind+'_at_'+str(at),baseline_prefix='TIME_MOVES_WITH_SCHEDULE',model_prefix=c['committed'],result='PASS'))
save('cnn_tiles.csv',cnrows);save('cnn_models.csv',cmodels);save('cnn_model_invariants.csv',tests)
sample=cnn_tile(16,4,2);save('cnn_sample_schedule.csv',[dict(cycle=c,event=e,line=v)for c,e,v in sample['events']])
js('cnn_summary.json',dict(baseline_cmdq=12351,writeback=5200,pack_cycles=4160,accepted_writes=1040,write_bytes=16640,tiles=65,actual_write_arbiter_wait=0,models=cmodels,model_invariant_cases=len(tests),preferred='four existing postprocess lanes; two ordered 128-bit buffers; per-tile drain barrier',decision='FEASIBLE_MODEL_ONLY_NO_RTL_THIS_ROUND',fault_scope='Request payload/order/granularity preserved by abstract FIFO model; actual RTL abort/watchdog/error priorities not yet proved.'))
print('PHASE3_MODEL_PASS scalar replay / bounded scheduling / CNN packing invariants')
print(json.dumps(dict(sfu=models,cnn=cmodels),indent=2))
