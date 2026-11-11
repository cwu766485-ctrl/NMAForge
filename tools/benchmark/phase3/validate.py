#!/usr/bin/env python3
"""Public evidence checks without EDA or a network connection."""
import csv,gzip,hashlib,io,json
from pathlib import Path
R=Path(__file__).resolve().parents[3];B=R/'benchmark/research/phase3'
def js(p):return json.loads(p.read_text())
def read(p):return gzip.decompress(p.read_bytes())if p.suffix=='.gz'else p.read_bytes()
def rows(p):return list(csv.DictReader(io.StringIO(read(p).decode())))
def sha(b):return hashlib.sha256(b).hexdigest()
for rel,h in js(B/'sha256.json').items():assert sha((B/rel).read_bytes())==h,rel
for rel,h in js(B/'metadata/source_sha256.json').items():assert sha((R/rel).read_bytes())==h,rel
m=js(B/'manifest.json');assert not m['product_rtl_changed']
assert m['product_merge_sha']=='c93ea144713d5fafe2e8a5509029927cd6859e75'
assert m['measured_rtl_tree']=='fe0e999fa187c4ed52a512d27509d5922e6137eb'
assert js(B/'metadata/pr4.json')['state']=='MERGED'
assert js(B/'metadata/pr4.json')['mergeCommit']['oid']==m['product_merge_sha']
for r in js(B/'metadata/fresh_replay_ledger.json'):
 assert r['result']=='PASS'and sha(read(R/r['reference']))==r['fresh_sha256']==r['reference_uncompressed_sha256']
s=js(B/'baseline/analysis/summary.json')
assert s==js(R/'benchmark/research/phase2/optimized/analysis/summary.json')
assert (s['h32']['cycles'],s['h16']['cycles'],s['cnn_both_fused_row_major']['cycles'])==(350155,65771,12351)
for name,r in s.items():assert sum(r['exclusive'].values())==r['cycles'],name
ln=read(B/'logs/review/ln32/run.log.gz').decode()
for marker in ['PHASE2_LN32_DIRECTED_PASS vectors=41 faults=11 reset_abort_watchdog=27','PHASE2_LN32_MEAN_PASS cases=1231','PHASE2_LN32_VARIANCE_PASS cases=1208']:assert marker in ln,marker
fault=read(B/'logs/review/fault-run.log.gz').decode()
for marker in ['PHASE3_FAULT_CONTRACT_PASS','committed_words=1 error=5 suffix_preserved=3','mask=0010 aggregate_error=1','scalar_allowed=4 line_allowed=0']:assert marker in fault,marker
for p in (B/'logs').rglob('*.log.gz'):
 log=read(p).decode();assert 'Fatal:'not in log and 'TEST FAIL'not in log,p
lint=read(B/'logs/review/lint.log.gz').decode()
assert '%Warning-LATCH'not in lint and '%Warning-UNOPTFLAT'not in lint
assert lint.count('%Warning-WIDTHTRUNC:')==6 and lint.count('%Warning-WIDTHEXPAND:')==10
assert 'TEST PASS'in read(B/'logs/baseline/smoke.log.gz').decode()
assert 'PHASE2_TOP_REPLAY_PASS'in read(B/'logs/baseline-driver.log.gz').decode()
cal=rows(B/'model/sfu_calibration.csv');assert len(cal)==448
assert all(r['observed']==r['scalar_fsm_replay']and r['match']=='True'for r in cal)
sfu=js(B/'model/sfu_summary.json');assert sfu['calibrated_all_segments']==672
assert sfu['decision']=='STOP_SFU_CANDIDATE_FAULT_CONTRACT_NOT_PROVEN'
for r in sfu['models']:
 assert not r['rtl_admitted'] and r['predicted_full_decode']==76456+r['modeled_sfu_cycles']
 if r['memory']=='scalar4B':assert r['predicted_full_decode']==200139 and r['fault_contract']=='NOT_PROVEN'
 if r['memory']=='current_scalar_fsm_unchanged':assert r['predicted_full_decode']==350155
for r in rows(B/'model/sfu_resource_bounds.csv'):assert int(r['scheduled_cycles'])>=int(r['resource_lower_bound'])
service=js(B/'model/sfu_service_contract.json');assert service['sfu_denied_issue_slots']==1568 and service['matrix_and_sfu_busy']==0
cn=js(B/'model/cnn_summary.json');assert cn['pack_cycles']==4160 and cn['actual_write_arbiter_wait']==0
pref=next(r for r in cn['models']if r['postprocess_lanes']==4 and r['buffers']==2)
assert pref['predicted_cmdq']==11376 and pref['saved']==975 and pref['new_buffer_bits']==128 and pref['new_arithmetic_lanes']==0
assert len(rows(B/'model/cnn_tiles.csv'))==65
assert len(rows(B/'model/cnn_model_invariants.csv'))==1560
assert all(r['result']=='PASS'for r in rows(B/'model/cnn_model_invariants.csv'))
# Recheck every retimed line against the independent, immutable CNN Golden.
g=[int(x,16)for x in read(R/'benchmark/research/phase1/cnn/both_fused_row_major/model_golden.memh.gz').split()];gold=dict(zip(g[1::2],g[2::2]))
t=rows(B/'model/cnn_transactions.csv');assert len(t)==1040
for n,r in enumerate(t):
 addr=int(r['address'],16);payload=sum(gold[addr+4*i]<<(32*i)for i in range(4))
 assert int(r['ordinal'])==n and int(r['golden_payload'],16)==payload and r['wstrb']=='ffff'and r['bytes']=='16'
 assert r['observed_tile_edge']==r['baseline_replay_edge']
 assert int(r['two_buffer_model_edge'])==4+int(r['line'])*4
matched=js(R/'benchmark/research/phase2/matched/matched.json')
assert len(matched)==12 and all(r['golden']=='PASS'and r['system_speedup']is None for r in matched)
print('PHASE3_PUBLIC_EVIDENCE_PASS hashes/fresh-replay/Golden/faults/models/bounds; no candidate RTL admitted')
