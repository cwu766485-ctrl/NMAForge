"""Validate archived identities, exact Golden, exclusive timing and fair endpoints."""
import csv,gzip,hashlib,json,subprocess
from pathlib import Path
r=Path('benchmark/research/stage_c');m=json.loads((r/'manifest.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();read=lambda p:gzip.decompress(p.read_bytes()).decode()
for rel,digest in json.loads((r/'evidence_sha256.json').read_text()).items():assert sha(r/rel)==digest,rel
for rel,digest in m['source_hashes'].items():assert sha(Path(rel))==digest,rel
assert not subprocess.check_output(['git','diff',m['baseline_sha'],'--','rtl/'])
model=json.loads((r/'models/h32_l2_int8.json').read_text());assert model['shape']=={'hidden':32,'layers':2,'heads':2,'head_dim':16,'context':16,'ffn':128,'vocab':32};assert model['training']['train_test_trajectory_overlap']==0
assert sha(r/'models/h32_l2_int8.json')==m['model_sha256']
train=read(r/'verification/train.log.gz');repeat=read(r/'verification/train_reproduction.log.gz');assert m['model_sha256'] in train and m['model_sha256'] in repeat
q=json.loads((r/'models/quality.json').read_text());assert q['predictions']==3072 and q['accuracy']<.04 # guards against publishing the overlap result
summary=json.loads((r/'h32/analysis/summary.json').read_text());assert summary['decode']['cycles']==367788 and summary['memory']['high_water_bytes']==79872
for row in csv.DictReader((r/'h32/analysis/tokens.csv').open()):
 i=int(row['stage']);assert sum(int(row[k]) for k in ['matrix_exclusive','sfu_exclusive','kv_exclusive','control_exclusive'])==int(row['cycles'])
 assert read(r/f'h32/stage_{i}_t{i}_golden.memh.gz')==read(r/f'h32/stage_{i}_t{i}_observed.memh.gz')
assert len(list(csv.DictReader((r/'matrix/matrix_config_comparison.csv').open())))==5
assert len(list(csv.DictReader((r/'matrix/gemv_four_way.csv').open())))==16
for row in json.loads((r/'matched/matched.json').read_text()):assert row['golden']=='PASS' and row['system_speedup'] is None and row['classification']=='MATCHED_ADAPTER_MODEL'
assert len(json.loads((r/'matched/matched.json').read_text()))==9
for name in ['smoke','seeded']:assert 'TEST PASS' in read(r/f'verification/{name}.log.gz')
assert 'STAGE_B_GATE0_RTL_PASS' in read(r/'contract/run.log.gz')
assert '=== ALL ENGINE TESTS PASSED ===' in read(r/'array_only/tiny_engine_regression.log.gz')
for mode,cycles in [('legacy',65429),('first_fused',22983),('both_fused_row_major',12351)]:assert f'command_cycles={cycles} ' in read(r/f'cnn/{mode}/top.log.gz')
assert json.loads((r/'h16/persistent_decode.json').read_text())['total_decode_cycles']==65771
print('STAGE_C_VALIDATE_PASS status=PARTIAL product_rtl_changed=0 h32_snapshots=12 matched_service=9 model_disjoint=1')
