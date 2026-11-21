"""Reconcile passive exclusive clocks, accepted bytes, output Golden and descriptor intervals."""
import argparse,json,csv,re,collections,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
m=json.loads((a.run/'manifest.json').read_text());log=(a.run/'top.log').read_text();assert 'STAGE_C_TOP_PASS' in log
fields=lambda l:dict(re.findall(r'(\w+)=([^ ]+)',l))
profiles={int(fields(l)['index']):fields(l) for l in log.splitlines() if l.startswith('STAGE_C_STAGE_PASS ')}
cycles=collections.defaultdict(list);traffic=collections.defaultdict(list)
for row in csv.DictReader((a.run/'profile_cycles.csv').open()):cycles[int(row['window'])].append(row)
for row in csv.DictReader((a.run/'profile_traffic.csv').open()):traffic[int(row['window'])].append(row)
rows=[];phase=[];state=[];intervals=collections.defaultdict(int)
for l in log.splitlines():
 if l.startswith('R17_DESCRIPTOR_INTERVAL '):
  d=fields(l);intervals[int(d['stage'][1:])]+=int(d['cycles'])
for i,st in enumerate(m['stages']):
 pr=profiles[i];cr=cycles[i];tr=traffic[i];part=collections.Counter(int(x['phase']) for x in cr);read=sum(int(x['bytes']) for x in tr if x['write']=='0');write=sum(int(x['bytes']) for x in tr if x['write']=='1');assert read==int(pr['spad_read_bytes']) and write==int(pr['spad_write_bytes']);assert len(cr)==int(pr['cycles'])==intervals[i]
 golden=a.run/f'stage_{i}_t{i}_golden.memh';observed=a.run/f'stage_{i}_t{i}_observed.memh';assert golden.read_bytes()==observed.read_bytes()
 matrix=sum(v for k,v in part.items() if k<=4);sfu=sum(v for k,v in part.items() if 5<=k<=8);kv=part[9];ctrl=sum(v for k,v in part.items() if k>=10);assert matrix+sfu+kv+ctrl==len(cr)
 useful=m['shape']['layers']*(4*32*32+2*32*128+2*32*(i+1))+32*32
 rows.append({'stage':i,'kind':st['kind'],'cycles':len(cr),'matrix_exclusive':matrix,'sfu_exclusive':sfu,'kv_exclusive':kv,'control_exclusive':ctrl,'read_bytes':read,'write_bytes':write,'descriptors':st['descriptors'],'golden_words':st['golden_words'],'useful_macs':useful,'useful_mac_per_cycle':useful/len(cr),'scalar_admission_stall':sum(int(x['scalar_stall']) for x in cr),'banked_admission_stall':sum(int(x['banked_stall']) for x in cr),'line_admission_stall':sum(int(x['line_stall']) for x in cr),'observed_sha256':hashlib.sha256(observed.read_bytes()).hexdigest()})
 for k,v in sorted(part.items()):phase.append({'stage':i,'kind':st['kind'],'phase':k,'cycles':v})
 states=collections.Counter((int(x['sfu_opcode']),int(x['sfu_state'])) for x in cr if 5<=int(x['phase'])<=8)
 for (op,stt),n in sorted(states.items()):state.append({'stage':i,'kind':st['kind'],'opcode':hex(op),'state':stt,'cycles':n})
for name,data in [('tokens.csv',rows),('exclusive_phases.csv',phase),('sfu_states.csv',state)]:
 with (a.out/name).open('w') as f:w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
def totals(kind):
 rs=[r for r in rows if r['kind']==kind];out={k:sum(r[k] for r in rs) for k in ['cycles','matrix_exclusive','sfu_exclusive','kv_exclusive','control_exclusive','read_bytes','write_bytes','descriptors','golden_words','useful_macs','scalar_admission_stall','banked_admission_stall','line_admission_stall']};out['tokens']=len(rs);out['cycles_per_token']=out['cycles']/len(rs);return out
summary={'status':'PASS_SCOPED','model_sha256':m['model_sha256'],'memory':m['memory'],'prefill':totals('prefill'),'decode':totals('decode'),'session_reset_between_tokens':False,'all_intermediate_logits_kv_golden':'PASS','timing_boundary':'sum of12 CMDQ doorbell windows to last committed completion; excludes initial host SPAD preload, queue setup, Golden readback, interbatch host service, embedding/token selection','clock_ns':4,'physical_fmax':'NOT_MEASURED','limitations':['8 teacher-forced decode tokens after4 true full-graph prefill tokens','context16 slots0..11 only; ring wrap not covered','128KiB behavioral four-bank SPAD; no physical macro timing','padded4rows physically computed; row0 is logical token']}
(a.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
