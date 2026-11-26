"""Validate both raw RTL outputs and shared host quantization against reference."""
import argparse,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args()
result=[]
for op in 'qkv':
 d=json.loads((a.run/(op+'.json')).read_text());expected=[v&0xffffffff for row in d['raw'] for v in row]
 for design in ['nma','tiny']:
  path=a.run/(design+'_'+op+'.memh');values=[int(v,16) for v in path.read_text().split()]
  if values!=expected:raise SystemExit(design+' '+op+' raw mismatch')
  signed=[v if v<2**31 else v-2**32 for v in values]
  q=[min(127,max(-128,v>>d['shift'])) for v in signed]
  if q!=[v for row in d['quantized'] for v in row]:raise SystemExit('host quantization mismatch')
  result.append({'design':design,'projection':op,'raw_words':len(values),'golden':'PASS','raw_output_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'quantization':'shared host reference; excluded from RTL timing'})
(a.run/'paired_validation.json').write_text(json.dumps(result,indent=2)+'\n')
print('SHARED_H16_QKV_PASS raw_words_per_design=192')
