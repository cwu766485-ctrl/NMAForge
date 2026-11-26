"""Independent lifetime/partial-sum check using the frozen trained CNN sample."""
import json,hashlib,argparse,importlib.util
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parents[3]
modelp=root/'benchmark/representative/models/r19_trained_digits_3x3_cnn.json';m=json.loads(modelp.read_text())
# Read the actual frozen packed ACT1 Golden instead of retraining/changing data.
f=root/'benchmark/representative/round25/cnn/model_golden.memh'
if not f.exists():f=root/'benchmark/research/stage_b/baseline/cnn/both_fused_row_major/model_golden.memh'
if not f.exists():
 import subprocess,sys
 subprocess.run([sys.executable,str(root/'benchmark/representative/generate_trained_3x3_cnn_workload.py'),'--model',str(modelp),'--fusion-mode','both_fused_row_major','--out-dir',str(a.out/'cnn')],check=True)
 f=a.out/'cnn/model_golden.memh'
v=[int(x,16) for x in f.read_text().split()];words=dict(zip(v[1::2],v[2::2]));hidden=np.zeros((208,64),dtype=np.int64)
for tile in range(13):
 for rg in range(4):
  for kg in range(16):
   for rr in range(4):
    idx=tile*256+rg*64+kg*4+rr;word=words[0x10000+idx*4]
    for b in range(4):
     val=(word>>(8*b))&255;hidden[tile*16+rg*4+rr,kg*4+b]=val-256 if val>=128 else val
w=np.array(m['weights_int8']['conv2_k64_n16'],dtype=np.int64);full=hidden@w;shift=m['quantization']['conv2_shift'];parts=[hidden[:,i:i+16]@w[i:i+16] for i in range(0,64,16)]
acc=np.zeros_like(full);lifetime=[]
for t in range(13):
 for k in range(4):
  acc[t*16:(t+1)*16]+=parts[k][t*16:(t+1)*16]
  lifetime.append({'row_tile':t,'k16':k,'clear_allowed':k==0,'postprocess_allowed':k==3,'activation_live_bytes':256,'pingpong_bytes':512,'consumer_accumulator_live_bytes':2048,'producer_switch_clobbers_consumer_accumulator':k<3})
assert np.array_equal(acc,full)
out=np.clip(acc>>shift,-128,127);expected=np.array([((words[0x19000+(r*4+c//4)*4]>>(8*(c%4)))&255) for r in range(208) for c in range(16)]).reshape(208,16);expected=np.where(expected>=128,expected-256,expected);assert np.array_equal(out,expected)
wrong=np.clip(sum(np.clip(x>>shift,-128,127) for x in parts),-128,127)
report={'status':'PARTIAL','exact_partial_sum_golden':True,'words':3328,'premature_quantization_mismatches':int(np.sum(out!=wrong)),'model_sha256':hashlib.sha256(modelp.read_bytes()).hexdigest(),'golden_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'hidden_sha256':hashlib.sha256(hidden.astype('i1').tobytes()).hexdigest(),'output_sha256':hashlib.sha256(out.astype('i1').tobytes()).hexdigest(),'existing_int8_buffer_bytes':512,'full_row_tile_activation_bytes':1024,'consumer_accumulator_context_bytes':2048,'rows_fit_in_one_256_byte_bank_at_K64':4,'array_contexts':1,'new_rtl':False,'lifetime':lifetime}
(a.out/'k64.json').write_text(json.dumps(report,indent=2)+'\n');print('K64_REFERENCE_PASS',report['premature_quantization_mismatches'])
