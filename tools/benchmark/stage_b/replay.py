"""Replay pinned Stage A transactions and estimate a bounded counterfactual.

Observed addresses/clocks are actual; write values are reconstructed from the
bit-exact observed stage snapshot, NOT claimed as a live captured-data trace.
The archived run has successful descriptors and disjoint Matrix destinations.
STRICT always revalidates SRAM; IDEAL_BYPASS fails the parity equivalence gate.
"""
import argparse
import collections
import csv
import gzip
import hashlib
import json
import re
from pathlib import Path
from model import Entry

p=argparse.ArgumentParser()
p.add_argument('--archive',type=Path,default=Path('benchmark/research/stage_a'))
p.add_argument('--out',type=Path,required=True)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=False)

def read_json(path):return json.loads((a.archive/path).read_text())
def gztext(path):return gzip.open(a.archive/path,'rt').read()
def rows(path):return list(csv.DictReader(gzip.open(a.archive/path,'rt')))
def emit(name,value):(a.out/name).write_text(json.dumps(value,indent=2)+'\n')
def csv_save(name,data):
    with (a.out/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(data[0]),lineterminator='\n');w.writeheader();w.writerows(data)

manifest=read_json('h16/workload/manifest.json')
assert read_json('h16/persistent_decode.json')['status']=='PERSISTENT_TOP_DECODE_PASS'
timing=rows('h16/h16_cycles.csv.gz');traffic=rows('h16/h16_traffic.csv.gz')
by_window=collections.defaultdict(list);tr_window=collections.defaultdict(list)
for r in timing:by_window[int(r['window'])].append(r)
for r in traffic:tr_window[int(r['window'])].append(r)
interval={}
for line in gztext('h16/top_session.log.gz').splitlines():
    if line.startswith('R17_DESCRIPTOR_INTERVAL '):
        f=dict(re.findall(r'(\w+)=([^ ]+)',line))
        interval[f['stage'],int(f['local_index'])]=int(f['cycles'])
edge_rows=[];all_cache_reads=[];decode_descriptors=0;requant_descriptors=0
for window,stage in enumerate(manifest['stages']):
    if window==0:continue
    decode_descriptors+=stage['descriptor_count']
    snapshot_words=[int(x,16) for x in gztext(f'h16/workload/stage_{window}_{stage["name"]}_observed.memh.gz').split()]
    golden_words=[int(x,16) for x in gztext(f'h16/workload/stage_{window}_{stage["name"]}_golden.memh.gz').split()]
    assert snapshot_words==golden_words
    assert len(snapshot_words)==1+2*snapshot_words[0]
    memory=dict(zip(snapshot_words[1::2],snapshot_words[2::2]))
    clock={int(r['clock']):r for r in by_window[window]}
    cursor=min(clock);epoch=window;events={};e=Entry();producer=None
    for i,d in enumerate(stage['descriptor_contract']):
        end=cursor+interval[stage['name'],i]
        accesses=[t for t in tr_window[window] if cursor<=int(t['clock'])<end]
        if d['opcode']==0x30:
            e.invalidate();producer=d
            e.begin(d['dst'],d['m']*d['n'],epoch,d['task_id'],d['signal_mask'])
        elif d['opcode']==0x36:
            requant_descriptors+=1
            bound=e.bind(d['src0'],d['k_or_length'],epoch,
                producer['task_id'] if producer else -1,d['wait_mask'],events)
            if bound:
                assert d['k_or_length']==32 and producer['m']==4 and producer['n']==8
                edge=dict(stage=stage['name'],producer=producer['name'],consumer=d['name'],
                    producer_epoch=epoch,event_mask=d['wait_mask']&producer['signal_mask'],
                    base=d['src0'],words=32,committed_mask='ffffffff',reads=0,
                    retained_producer_write_bytes=128,measured_read_service_cycles=0)
            else:edge=None
        for bit in range(16):
            if d['clear_mask']>>bit&1:events.pop(bit,None)
        for t in accesses:
            address=int(t['address'],16);size=int(t['bytes']);clk=int(t['clock'])
            if t['write']=='1':
                if d['opcode']==0x30 and t['engine']=='3' and e.capturing:
                    e.capture(address,[memory[address+j] for j in range(0,size,4)])
                else:e.write(address,size)
            elif d['opcode']==0x36 and t['engine']=='4' and edge is not None:
                index=(address-e.base)//4
                assert e.request(index,'IDEAL_BYPASS')=='REGISTERED_CACHE'
                assert e.response(epoch,False) is None
                assert e.response(epoch,True)==memory[address]
                assert e.response(epoch,True) is None
                req_state=int(clock[clk]['sfu_state']);assert req_state==23
                service=1;cc=clk+1
                while cc in clock and int(clock[cc]['sfu_state'])==24:
                    service+=1;cc+=1
                assert service==3
                all_cache_reads.append(dict(stage=stage['name'],consumer=d['name'],clock=clk,
                    address=f'{address:08x}',cached_word=f'{memory[address]:08x}',
                    service_cycles=service,index=index))
                edge['reads']+=1;edge['measured_read_service_cycles']+=service
        if d['opcode']==0x30:
            e.complete(True);e.retire(d['task_id'],epoch,True)
        elif d['opcode']==0x36 and edge is not None:
            assert edge['reads']==32
            # Independent integer shift/clamp and 4x4 Matrix-A packing; check
            # every hypothetical forwarded output against unchanged Golden.
            packed=[0]*8
            for row in range(4):
                for col in range(8):
                    word=e.data[row*8+col]
                    value=word if word<2**31 else word-2**32
                    value=max(-128,min(127,value >> d['shift']))
                    index=(col//4)*4+row
                    packed[index] |= (value&255) << (8*(col%4))
            assert all(memory[d['dst']+4*i]==word for i,word in enumerate(packed))
            edge_rows.append(edge);e.release()
        # Recorded run: all command completions successful; event producer
        # identity is reconstructed from this serialized successful retirement.
        for bit in range(16):
            if d['signal_mask']>>bit&1:events[bit]=(epoch,d['task_id'])
        cursor=end
    assert cursor==max(clock)+1
assert len(edge_rows)==64 and len(all_cache_reads)==2048
assert sum(r['measured_read_service_cycles'] for r in edge_rows)==6144
assert decode_descriptors==424
csv_save('covered_edges.csv',edge_rows);csv_save('covered_reads.csv',all_cache_reads)
# Model sensitivity: whole-lease hit fractions, not random selection of favorable
# cycles. Fault invalidation cancels pending response and falls back to SRAM.
scenarios=[]
for latency in [1,2,3]:
    for hit_fraction in [0,.25,.5,.75,1]:
        for invalidation in ['none','every_fourth_lease_before_read','every_fourth_lease_after_16_reads']:
            hits=0;leases=0
            for idx in range(64):
                selected=int((idx+1)*hit_fraction)>int(idx*hit_fraction)
                if not selected:continue
                leases+=1
                hits+=0 if invalidation=='every_fourth_lease_before_read' and idx%4==0 else (
                    16 if invalidation=='every_fourth_lease_after_16_reads' and idx%4==0 else 32)
            # Two illustrative clocks per selected lease for bind/release. No
            # miss penalty assumed; sweep separately reports its worst case.
            overhead=2*leases
            saved=hits*(3-latency)-overhead
            scenarios.append(dict(mode='IDEAL_BYPASS_UNAPPROVED',cache_response_clocks=latency,
                target_hit_fraction=hit_fraction,invalidation=invalidation,hits=hits,
                misses=2048-hits,lease_overhead_clocks=overhead,miss_penalty_clocks=0,
                net_estimated_saved_clocks=saved,estimated_decode_clocks=65771-saved,
                estimated_cycles_per_token=(65771-saved)/8,estimated_reduction_percent=100*saved/65771,
                estimated_read_bytes=72448-4*hits,retained_write_bytes=42112,
                rtl_measured=False,gate0_qualified=False))
# Safe implementation option: never bypass checks, no speculative visibility.
scenarios.append(dict(mode='STRICT_DISABLED',cache_response_clocks=3,target_hit_fraction=0,
    invalidation='not_applicable',hits=0,misses=2048,lease_overhead_clocks=0,miss_penalty_clocks=0,
    net_estimated_saved_clocks=0,estimated_decode_clocks=65771,estimated_cycles_per_token=8221.375,
    estimated_reduction_percent=0,estimated_read_bytes=72448,retained_write_bytes=42112,
    rtl_measured=False,gate0_qualified=True))
scenarios.append(dict(mode='STRICT_CHECKED_SHADOW',cache_response_clocks=3,target_hit_fraction=1,
    invalidation='none',hits=0,misses=2048,lease_overhead_clocks=128,miss_penalty_clocks=0,
    net_estimated_saved_clocks=-128,estimated_decode_clocks=65899,estimated_cycles_per_token=8237.375,
    estimated_reduction_percent=-100*128/65771,estimated_read_bytes=72448,retained_write_bytes=42112,
    rtl_measured=False,gate0_qualified=True))
csv_save('latency_hit_invalidation_sweep.csv',scenarios)
miss_penalties=[]
for clocks in [0,1,2]:
    miss_penalties.append(dict(lookup_penalty_per_requant=clocks,requant_descriptors=requant_descriptors,
        added_cycles=clocks*requant_descriptors,scope='modeled all-Requant descriptor lookup overhead, not RTL'))
csv_save('miss_lookup_sweep.csv',miss_penalties)
emit('summary.json',dict(status='MODEL_PASS_GATE0_FAIL',decision='REJECT',
    baseline_decode_cycles=65771,baseline_cycles_per_token=8221.375,
    baseline_read_bytes=72448,baseline_write_bytes=42112,descriptor_count=decode_descriptors,
    requant_descriptor_count=requant_descriptors,eligible_leases=64,eligible_reads=2048,
    eligible_read_bytes=8192,actual_rtl_cache_hits=None,actual_rtl_cache_misses=None,
    strict_removable_reads=0,strict_expected_cycle_saving=0,
    hypothetical_latency1_overhead2_cycles=61803,hypothetical_latency1_overhead2_cycles_per_token=7725.375,
    hypothetical_latency1_overhead2_reduction_percent=100*3968/65771,
    hypothetical_latency2_overhead2_cycles=63851,
    notes=['all savings are serialized trace model estimates, not RTL measurements',
        'IDEAL_BYPASS cannot observe unsignaled SRAM upset and is not ABI-equivalent',
        'no speculative result may commit before original permission/parity checks',
        'STRICT_CHECKED_SHADOW holds service at measured 3 clocks and adds illustrative 2 clocks/lease',
        'reconstructed values from unchanged final observed/Golden snapshots; no live data trace claimed'],
    input_hashes={str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in [
        a.archive/'h16/workload/manifest.json',a.archive/'h16/h16_cycles.csv.gz',
        a.archive/'h16/h16_traffic.csv.gz',a.archive/'h16/top_session.log.gz']}))
print('STAGE_B_MODEL_PASS leases=64 reads=2048 read_bytes=8192 strict_saved_reads=0 gate0=FAIL decision=REJECT')
