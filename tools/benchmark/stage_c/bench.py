"""Run common cycle-level service ablation; never a native-system speedup."""
import json,subprocess,argparse,os,re,csv,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);a=p.parse_args();rows=[]
for f in json.loads((a.run/'fixtures.json').read_text()):
 name=f['id'];operand=a.run/(name+'.memh');expected=(a.run/(name+'_golden.memh')).read_text().split();stats={}
 for design in ['nma','tiny']:
  output=a.run/(name+'_'+design+'.memh');log=a.run/(name+'_'+design+'.log')
  cmd=[str(a.run/'simv'),'+SHARED_OPERANDS='+str(operand),'+SHARED_OUTPUT='+str(output)] if design=='nma' else [str(a.run/'tiny/obj/Vengine_tb_top')]
  env={**os.environ,'SHARED_OPERANDS':str(operand),'SHARED_OUTPUT':str(output)}
  with log.open('w') as out:subprocess.run(cmd,env=env,stdout=out,stderr=subprocess.STDOUT,check=True)
  # SV emits tile-major, Tiny emits row-major: canonicalize before comparing.
  actual=output.read_text().split()
  if design=='nma':
   canonical=[None]*(f['m']*f['n']);idx=0
   for tr in range(0,f['m'],16):
    for tc in range(0,f['n'],16):
     for r in range(tr,min(tr+16,f['m'])):
      for c in range(tc,min(tc+16,f['n'])):canonical[r*f['n']+c]=actual[idx];idx+=1
   actual=canonical
  assert actual==expected,(name,design)
  line=next(x for x in log.read_text().splitlines() if x.startswith('STAGE_C_SERVICE '));stats[design]={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',line)}
 assert stats['nma']['read_bytes']==stats['tiny']['read_bytes'] and stats['nma']['write_bytes']==stats['tiny']['write_bytes']
 rows.append({**f,'classification':'MATCHED_ADAPTER_MODEL','boundary':'common preloaded backing store -> clocked operand service -> raw accumulator output service; no native controller/DMA/graph','nma_cycles':stats['nma']['total'],'tiny_cycles':stats['tiny']['total'],'adapter_cycle_ratio':stats['tiny']['total']/stats['nma']['total'],'system_speedup':None,'read_bytes_each':stats['nma']['read_bytes'],'write_bytes_each':stats['nma']['write_bytes'],'read_service_cycles_each':stats['nma']['phases_read'],'write_service_cycles_each':stats['nma']['phases_write'],'nma_array_cycles':stats['nma']['total']-stats['nma']['phases_read']-stats['nma']['phases_write'],'tiny_array_cycles':stats['tiny']['total']-stats['tiny']['phases_read']-stats['tiny']['phases_write'],'golden':'PASS','numeric':'signed INT8 product; exact unsaturated INT32 sum, no overflow; no scale/nonlinearity','nma_mac':256,'tiny_mac':256,'service_bytes':16,'read_response_after_issue_cycles':2,'outstanding':1,'service_capacity_bytes':131072,'native_nma_sram_bytes':131072,'native_tiny_sram_bytes':65536})
(a.run/'matched.json').write_text(json.dumps(rows,indent=2)+'\n')
with (a.run/'matched.csv').open('w') as out:
 w=csv.DictWriter(out,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
print('MATCHED_SERVICE_PASS',len(rows));print([(x['id'],x['nma_cycles'],x['tiny_cycles']) for x in rows])
