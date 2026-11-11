#!/usr/bin/env python3
"""Bounded scalar read/retirement protocol study, NOT a product SFU simulator.

One shared scheduler admission/edge, two-edge read response, one arithmetic
lane, four live word entries. Checks permission/parity at actual scalar access.
Competing client requests are generated in closed loop (next release depends on
its last grant); this is an illustrative RR arbiter, not the whole RTL dispatcher.
"""
import argparse, hashlib, itertools, json
from pathlib import Path
P=argparse.ArgumentParser();P.add_argument('--out',type=Path,required=True);a=P.parse_args();a.out.mkdir(parents=True,exist_ok=True)

def simulate(pipeline=True, ordered=True, n=4, parity=-1, deny_read=-1, deny_write=-1,
             competitor=0, stop=None, stop_cycle=10000, mutate=None, revoke=None):
    mem=[10+i for i in range(n)];output=[];events=[];pending=[];slots={}
    issued=0;retired=0;cycle=0;rr=0;other_due=0;other_count=0
    fault_seen=False;halt=None;done=0;epoch=17;maximum=0;accepted_reads=[]
    while cycle<500:
        # Concurrent host/debug writer uses its existing independent port.
        if mutate and cycle==mutate[0]:mem[mutate[1]]=mutate[2];events.append([cycle,'host_write',mutate[1],mutate[2]])
        if revoke is not None and cycle>=revoke:deny_read=1
        if stop and cycle==stop_cycle:
            halt=stop;slots.clear();events.append([cycle,stop,epoch])
            if stop=='reset':epoch+=1
        for due,i,e,value,error in list(pending):
            if due!=cycle:continue
            pending.remove((due,i,e,value,error));events.append([cycle,'response',i,e,error])
            if halt or e!=epoch:continue
            if error:
                slots[i]=dict(error=error,ready=cycle+1)
                fault_seen=True
                if not ordered:halt=error;slots.clear()
            else:
                # registered capture -> scalar arithmetic -> stable result
                slots[i]=dict(error=None,ready=cycle+2,value=value)
        if not halt and retired in slots and slots[retired]['ready']<=cycle and slots[retired]['error']:
            halt=slots[retired]['error'];slots.clear();events.append([cycle,'ordered_fault',retired,halt])
        req=None
        if not halt:
            if retired in slots and slots[retired]['ready']<=cycle:req=('write',retired)
            elif not fault_seen and issued<n and issued-retired<(4 if pipeline else 1):req=('read',issued)
        other=competitor>0 and cycle>=other_due and other_count<12
        # Closed-loop two-client round robin, at most one service per edge.
        client=(rr if req and other else 0 if req else 1 if other else None)
        if client==1:
            other_count+=1;other_due=cycle+competitor;rr=0
            events.append([cycle,'competing_grant',other_count])
        elif client==0:
            rr=1;kind,i=req
            if kind=='read':
                err='protection'if i==deny_read else 'parity'if i==parity else None
                accepted_reads.append(i);events.append([cycle,'read',i,epoch,mem[i],err,4])
                pending.append((cycle+2,i,epoch,mem[i],err));issued+=1
            else:
                if i==deny_write:
                    halt='write_protection';slots.clear();events.append([cycle,'write_denied',i])
                else:
                    assert i==len(output) and slots[i]['error']is None
                    output.append(slots.pop(i)['value']);retired+=1;events.append([cycle,'write',i,output[-1]])
        maximum=max(maximum,issued-retired)
        assert maximum<= (4 if pipeline else 1)
        if (halt or retired==n)and not pending:
            done+=1;events.append([cycle,'completion',halt or 'success',epoch]);break
        cycle+=1
    assert done==1 and not pending and cycle<500
    assert accepted_reads==list(range(len(accepted_reads))) # no duplicates/reorder
    if halt in ['parity','protection','write_protection']:
        fault_index=parity if halt=='parity'else deny_read if halt=='protection'else deny_write
        assert len(output)<=fault_index
    assert all(x[-1]==4 for x in events if x[1]=='read') # no aggregate line access
    completion=[e for e in events if e[1]=='completion'];assert len(completion)==1
    return dict(cycles=cycle+1,output=output,error=halt or 'success',read_indices=accepted_reads,
                max_live=maximum,competing_grants=other_count,events=events)

# Original Phase3 adjacent-region containment counterexample, scalar access stays.
regions=[(0x100,0x108),(0x108,0x110)]
allow=lambda addr,size:any(lo<=addr and addr+size<=hi for lo,hi in regions)
assert all(allow(0x100+4*i,4)for i in range(4)) and not allow(0x100,16)

# Round1: eager aggregate error loses the original legal output prefix.
scalar=simulate(pipeline=False,parity=1)
naive=simulate(ordered=False,parity=1)
assert scalar['output']==[10] and naive['output']==[]

# Round2: per-word ordered errors fix prefix for immutable, disjoint buffers.
count=0;examples=[]
for n,period in itertools.product([1,2,4,8],[0,1,2,4]):
    cases=[(-1,-1,-1)]+[(i,-1,-1)for i in range(n)]+[(-1,i,-1)for i in range(n)]+[(-1,-1,i)for i in range(n)]
    for parity,rd,wr in cases:
        args=dict(n=n,parity=parity,deny_read=rd,deny_write=wr,competitor=period)
        b=simulate(pipeline=False,**args);o=simulate(**args)
        assert (b['output'],b['error'])==(o['output'],o['error'])
        if parity>=0:assert len(o['output'])==parity
        if rd>=0:assert len(o['output'])==rd
        if wr>=0:assert len(o['output'])==wr
        count+=1
        if n==8 and parity==rd==wr==-1:examples.append(dict(competitor_period=period,scalar_cycles=b['cycles'],pipeline_cycles=o['cycles'],scope='8 immutable toy words; NOT H32 prediction'))
# Bounded abort/watchdog/reset drain and next descriptor epoch isolation.
recovery=0
for kind,cycle,period in itertools.product(['abort','watchdog','reset'],range(1,32),[0,1,3]):
    o=simulate(n=8,stop=kind,stop_cycle=cycle,competitor=period)
    stop_events=[e for e in o['events']if e[1]==kind]
    if stop_events:
        assert not any(e[1]in['read','write']and e[0]>=cycle for e in o['events'])
        assert o['events'][-1][0]>=max([e[0]for e in o['events']if e[1]=='response']or[cycle])
    recovery+=1
# Ordered retirement cannot restore the time at which data/parity/permission
# was sampled. Search and retain concrete unrestricted-coherence counterexamples.
coherence=[]
for kind in ['host_write','permission_revoke']:
    found=None
    for cycle in range(1,15):
        kw=dict(mutate=(cycle,1,999))if kind=='host_write'else dict(revoke=cycle)
        b=simulate(pipeline=False,**kw);o=simulate(**kw)
        if (b['output'],b['error'])!=(o['output'],o['error']):
            found=dict(kind=kind,event_cycle=cycle,baseline=b,candidate=o);break
    assert found;coherence.append(found)
result=dict(status='REJECT_UNRESTRICTED_PIPELINE_NO_RTL_ADMISSION',targeted_rounds=2,
 immutable_disjoint_cases=count,recovery_cases=recovery,
 scalar_word_parity_prefix=scalar['output'],naive_error_prefix=naive['output'],
 scalar_adjacent_regions_allowed=4,line_allowed=False,
 ordered_fault_repair='bounded immutable/disjoint toy protocol PASS, not full RTL proof',
 illustrative_closed_loop=examples,coherence_counterexamples=coherence,
 h32_incremental_safe_speedup='NOT_PROVEN',
 omitted_proofs=['actual multi-client RTL arbiter/dispatcher refinement','SFU numerical dependencies/pack prefix and in-place aliasing','top reset response flush and tagless route refinement','concurrent protection/parity writes and read-side externally visible errors','watchdog wall-clock priority refinement'],
 source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
(a.out/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
print('PHASE4_SFU_PROTOCOL_PASS bounded_cases=%d recovery=%d; unrestricted candidate REJECT after two rounds'%(count,recovery))
