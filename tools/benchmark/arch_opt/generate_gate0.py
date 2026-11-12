#!/usr/bin/env python3
"""Build the Gate 0 inventory from checked-in Phase 4 and GEMV evidence.
No RTL is changed and NOT_RUN rows remain explicit.
"""
import csv, json, hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=root/'benchmark/research/arch_opt'; out.mkdir(parents=True, exist_ok=True)
phase4=json.loads((root/'benchmark/research/phase4/baseline/summary.json').read_text())
phase4_opt=json.loads((root/'benchmark/research/phase4/optimized/summary.json').read_text())
rows=[]
def add(workload,shape,variant,status,cycles,macs,reads,writes,mac_cycle,category,source,golden,notes):
 rows.append(dict(workload=workload,shape=shape,variant=variant,status=status,total_cmdq_cycles=cycles,useful_macs=macs,useful_mac_per_cycle=mac_cycle,mac_utilization_pct=(100*mac_cycle/256 if isinstance(mac_cycle,(int,float)) else ''),sfu_cycles='',matrix_operand_fetch='',matrix_operand_wait='',matrix_writeback='',arbitration_stall='',read_bytes=reads,write_bytes=writes,category=category,source=source,golden=golden,notes=notes))
def measured(w,shape,var,key,d,cat,source):
 x=d[key]; e=x['exclusive']; add(w,shape,var,'MEASURED',x['cycles'],x['useful_macs'],x['read_bytes'],x['write_bytes'],x['useful_macs']/x['cycles'],cat,source,'PASS','exclusive state counters close exactly to total')
 rows[-1].update(sfu_cycles=sum(v for k,v in e.items() if k.startswith('sfu_')),matrix_operand_fetch=e.get('matrix_operand_fetch',0),matrix_operand_wait=e.get('matrix_operand_wait',0),matrix_writeback=e.get('matrix_writeback',0),arbitration_stall=x.get('arbitration_wait',0))
# Phase4 approved baseline and candidate, each with explicit source.
measured('CNN','both-fused row-major','approved product', 'cnn_both_fused_row_major',phase4,'CNN','benchmark/research/phase4/baseline/summary.json')
measured('CNN','both-fused row-major','Phase4 candidate','cnn_both_fused_row_major',phase4_opt,'CNN','benchmark/research/phase4/optimized/summary.json')
for key,shape in [('cnn_first_fused','first-fused'),('cnn_legacy','legacy')]:
 measured('CNN',shape,'approved product',key,phase4,'CNN','benchmark/research/phase4/baseline/summary.json')
 measured('CNN',shape,'Phase4 candidate',key,phase4_opt,'CNN','benchmark/research/phase4/optimized/summary.json')
for key,shape in [('kernel_30_4_4_32','4x4x32 GEMM'),('kernel_30_16_16_16','16x16x16 GEMM'),('kernel_30_32_32_64','32x32x64 GEMM')]:
 measured('GEMM',shape,'Phase4 candidate',key,phase4_opt,'GEMM','benchmark/research/phase4/optimized/summary.json')
for key,shape in [('kernel_52_1_16_32','M1 product 0x52, K32'),('kernel_52_4_16_32','M4 product 0x52, K32'),('kernel_52_8_16_32','M8 product 0x52, K32')]:
 measured('GEMV',shape,'Phase4 candidate',key,phase4_opt,'GEMV','benchmark/research/phase4/optimized/summary.json')
# Product evidence from the dedicated seeded matrix campaign: not Phase4 candidate tree, so separate provenance.
# Keep the exact tested shapes and source hash instead of relabeling them as the Phase4 Top run.
for shape,cycles,macs,reads,writes,arb in [('M1 1x13x17',75,221,304,None,12),('M4 4x16x32',202,2048,640,256,22),('M8 8x16x19',154,2432,560,512,25),('M16 16x16x65',630,16640,2368,1024,66)]:
 add('GEMV',shape,'product seeded matrix campaign','MEASURED',cycles,macs,reads,writes,macs/cycles,'GEMV','benchmark/representative/round29/matrix/gemv.log.gz','PASS','independent product Matrix core run; separate from Phase4 Top replay')
 rows[-1]['arbitration_stall']=arb
# H16/H32 authoritative persistent replay.
for key,shape in [('h16','8-token persistent decode'),('h32','8-token persistent decode')]: measured('Transformer',shape,'Phase4 candidate',key,phase4_opt,'Transformer','benchmark/research/phase4/optimized/summary.json')
# Exact requested matrix/GEMV coverage that is absent from the authoritative Top inventory.
for m in [1,4,8,16]:
 for k in [32,64,128]:
  shape=f'M{m} K{k} (N=16 exact product Top)'
  if not any(r['workload']=='GEMV' and r['shape'].startswith(f'M{m} ') and f'K{k}' in r['shape'] for r in rows):
   add('GEMV',shape,'requested Gate0 matrix','NOT_RUN','','','','','','GEMV','','','No exact product Top row in checked-in Phase4 evidence')
# Requested 16x16x16 etc are covered; add a clearly marked K128 GEMM gap.
add('GEMM','4x4x128 requested','requested Gate0 matrix','NOT_RUN','','','','','','GEMM','','','No exact product Top row in checked-in Phase4 evidence')
add('GEMM','16x16x128 requested','requested Gate0 matrix','NOT_RUN','','','','','','GEMM','','','No exact product Top row in checked-in Phase4 evidence')
add('GEMM','32x32x128 requested','requested Gate0 matrix','NOT_RUN','','','','','','GEMM','','','No exact product Top row in checked-in Phase4 evidence')
fields=list(rows[0])
with (out/'baseline_bottlenecks.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(rows)
# Ranking uses only measured, exclusive counters and keeps model/isolated evidence separate.
rank=[
 dict(rank=1,candidate='SFU arithmetic/FSM scheduling',evidence='H32 SFU exclusive 273699/350155 cycles (78.1651%); fetch response 134144 and pipeline wait 15059',removable_cycles='NOT_PROVEN',expected_gain='NOT_RUN',hardware_cost='Candidate A: local registered scheduling; Candidate B: lease/ownership protocol',risk='HIGH: fault/coherence/permission semantics',decision='REWORK',source='benchmark/research/phase4/optimized/summary.json; docs/research/phase4/PHASE4_SFU_FAULT_SAFE_PIPELINE.md'),
 dict(rank=2,candidate='Matrix operand wait / prefetch',evidence='H32 matrix operand wait 14600; 32x32x64 GEMM operand wait 312; seeded GEMV shows prefetch_wait/arbiter stalls',removable_cycles='Requires closed-loop model',expected_gain='NOT_RUN',hardware_cost='Existing cache/prefetch scheduling; no new port admitted',risk='MEDIUM-HIGH: bank arbitration and fault drain',decision='REWORK',source='benchmark/research/phase4/optimized/summary.json; benchmark/representative/round29/matrix/gemv.log.gz'),
 dict(rank=3,candidate='Shape-adaptive GEMV mapping',evidence='Product seeded M1 1x13x17 75 cycles and M4 4x16x32 202; research SPAD wrapper M1/M4 1.1181x/1.0434x; M8/M16 no gain in wrapper',removable_cycles='Measured only for listed shapes',expected_gain='M1/M4 positive in separate campaigns; not unified Top',hardware_cost='Potential control/mux/accumulator state; no product RTL change',risk='HIGH: ABI/top integration, tails and backpressure',decision='REWORK',source='benchmark/representative/round29/matrix/gemv.log.gz; benchmark/shape_adaptive_spad_ablation.csv'),
 dict(rank=4,candidate='CNN writeback (already implemented Phase4)',evidence='11376 candidate vs 12351 approved; 975 cycles / 7.8941%; 1040 line Golden PASS',removable_cycles='Measured 975',expected_gain='7.8941%',hardware_cost='197 declared bits, no port/MAC/ABI',risk='LOW-MEDIUM: lifecycle regression retained',decision='RETAIN_AS_PR_CANDIDATE',source='benchmark/research/phase4/ablation.csv'),
 dict(rank=5,candidate='CNN DMA/output boundary',evidence='DMA 3019 setup+transfer and 4992 output readback are separately measured; full host timeline absent',removable_cycles='NOT_RUN',expected_gain='NOT_RUN',hardware_cost='Existing DMA/endpoint; no free transfer',risk='MEDIUM: endpoint/accounting',decision='REWORK',source='benchmark/research/phase4/boundaries.json')]
with (out/'architecture_opportunity_ranking.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rank[0]));w.writeheader();w.writerows(rank)
manifest=dict(status='PASS_GATE0_INVENTORY',approved_product_sha='c93ea144713d5fafe2e8a5509029927cd6859e75',phase4_candidate_sha='b1dd75b8d1b6bb0465bdb3452df556a7919f7c4d',phase4_candidate_rtl_sha='b1dd75b8d1b6bb0465bdb3452df556a7919f7c4d',vcs='V-2023.12-SP1_Full64',verilator='5.052',python='3.12.13',spad='128 KiB, four banks',macs=256,simulation_clock='4 ns behavioral simulation; not Fmax',golden='Phase4 exact 1040 CNN lines; H16/H32 strict tensors/logits/KV; Matrix/GEMV independent signed Golden',reproduction=['python3.12 tools/benchmark/phase4/validate.py','python3.12 tools/benchmark/arch_opt/generate_gate0.py'],artifacts={})
for p in [out/'baseline_bottlenecks.csv',out/'architecture_opportunity_ranking.csv']:
 manifest['artifacts'][p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'GATE0_INVENTORY_PASS rows={len(rows)} measured={sum(r["status"]=="MEASURED" for r in rows)} not_run={sum(r["status"]=="NOT_RUN" for r in rows)}')
