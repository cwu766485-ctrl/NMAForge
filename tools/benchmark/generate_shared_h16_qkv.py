"""Export trained H16 prefill Q/K/V projection operands for both RTL harnesses.

Raw dot products are RTL checked; post-dot shift/clamp is a common HOST reference.
"""
import argparse,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'sw/tools'))
from reference_tiny_gpt2_int8 import word_input,matvec,requant
p=argparse.ArgumentParser();p.add_argument('--model',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
m=json.loads(a.model.read_text());a.out.mkdir(parents=True,exist_ok=True)
x=[word_input(m,t,i) for i,t in enumerate([0,14,20,29])]
for op in 'qkv':
 b=m['weights']['w'+op];raw=[matvec(v,b) for v in x];quant=[requant(matvec(v,b,m['gemm_shifts']['qkv']),0) for v in x]
 (a.out/(op+'.memh')).write_text(''.join('%02x\n'%(v&255) for row in x+b for v in row))
 (a.out/(op+'.json')).write_text(json.dumps({'a':x,'b':b,'raw':raw,'quantized':quant,'shift':m['gemm_shifts']['qkv']},indent=2)+'\n')
print('SHARED_H16_QKV_GENERATED shapes=3x4x16x16')
