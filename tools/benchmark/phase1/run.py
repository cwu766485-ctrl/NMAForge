#!/usr/bin/env python3
"""Phase1 passive production-top runs; unchanged product RTL and fixed operands."""
import argparse,json,subprocess,sys,os
from pathlib import Path
root=Path(__file__).resolve().parents[3];sys.path[:0]=[str(root/'sw/tools'),str(root/'tools/benchmark/stage_c')]
from cimforge_mapper import Descriptor,_pack_matrix_a_physical,_pack_matrix_b_physical,pack_i8
from generate_h16_incremental_decode import write_pairs
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--model',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);sim=a.out/'top/simv';py=sys.executable

def execute(cmd,log,marker):
 log.parent.mkdir(parents=True,exist_ok=True)
 (log.with_suffix('.command.json')).write_text(json.dumps([str(x) for x in cmd],indent=2)+'\n')
 with log.open('w') as f:subprocess.run([str(x) for x in cmd],stdout=f,stderr=subprocess.STDOUT,check=True)
 text=log.read_text();assert marker in text and 'Fatal:' not in text and 'TEST FAIL' not in text,(log,marker)

def profile_wrapper(name):
 d=a.out/name;d.mkdir(parents=True,exist_ok=True);wrapper=d/'simv_wrapper'
 wrapper.write_text('#!/bin/sh\nexec "'+str(sim)+'" +PHASE1_PROFILE="'+str(d/'profile')+'" +STAGE_A_PROFILE="'+str(d/'stage_a')+'" "$@"\n');wrapper.chmod(0o755);return wrapper

# Fixed shape kernels through real CMDQ/SPAD/0x30 or dense product0x52.
# Keep the original reference rows and add the missing K/M sweep used by the
# architecture plan.  These are all product descriptors, not core-only tests.
cases = [(0x30,4,4,32),(0x30,16,16,16),(0x30,16,16,32),
         (0x30,32,32,64),(0x30,16,16,128)]
cases += [(0x52,m,16,k) for m in [1,4,8,16] for k in [16,32,64,128]]
for op,m,n,k in cases:
 name=f'kernel_{op:02x}_{m}_{n}_{k}';d=a.out/name;d.mkdir(exist_ok=True)
 aa=[[(r*3+i*2+1)%9-4 for i in range(k)] for r in range(m)];bb=[[(i*2-c*3+5)%9-4 for c in range(n)] for i in range(k)]
 if op==0x30:
  av=_pack_matrix_a_physical(aa,((m+15)//16)*16);bv=_pack_matrix_b_physical(bb)
 else:
  av=[pack_i8(row[i:i+4]) for row in aa for i in range(0,k,4)];bv=[pack_i8(row[i:i+4]) for row in bb for i in range(0,n,4)]
 gold={0x9000+4*(r*n+c):sum(aa[r][i]*bb[i][c] for i in range(k)) for r in range(m) for c in range(n)}
 desc=Descriptor(name,0x7100,op,0x1000,0x4000,0x9000,m=m,n=n,k_or_length=k if op==0x52 else k//4,aux0=0 if op==0x52 else 1,batch_count=0 if op==0x52 else 1,head_count=0 if op==0x52 else 1)
 image={0x1000+4*i:v for i,v in enumerate(av)};image.update({0x4000+4*i:v for i,v in enumerate(bv)});image.update({x:0xa55aa55a for x in gold});image.update({0x1a000+4*i:v for i,v in enumerate(desc.words())})
 write_pairs(d/'image.memh',image);write_pairs(d/'golden.memh',gold)
 (d/'shape.json').write_text(json.dumps(dict(opcode=op,m=m,n=n,k=k,useful_macs=m*n*k),indent=2)+'\n')
 cmd=[sim,'+AI_REPRESENTATIVE_MODEL','+AI_RANDOM_CASES=0','+AI_SEED=20261112','+ACLK_PERIOD_NS=4',
 '+AI_REPRESENTATIVE_MEMORY='+str(d/'image.memh'),'+AI_REPRESENTATIVE_GOLDEN='+str(d/'golden.memh'),'+AI_REPRESENTATIVE_DESC_BASE=106496','+AI_REPRESENTATIVE_CPL_BASE=107008','+AI_REPRESENTATIVE_DESC_COUNT=1','+AI_REPRESENTATIVE_USEFUL_MACS='+str(m*n*k),'+PHASE1_PROFILE='+str(d/'profile'),'+STAGE_A_PROFILE='+str(d/'stage_a')]
 execute(cmd,d/'top.log','REPRESENTATIVE_MODEL_PASS');print(name,'PASS',flush=True)
# Inject observation plusargs into existing independent drivers.
cnnwrap=profile_wrapper('cnn_profile');execute([py,'tools/benchmark/stage_a/run_cnn.py','--simv',cnnwrap,'--out',a.out/'cnn'],a.out/'cnn-driver.log','both_fused_row_major PASS')
# run_cnn shares prefix across invocations; preserve each trace separately by replaying command with per-case prefixes.
for mode in ['legacy','first_fused','both_fused_row_major']:
 d=a.out/'cnn'/mode;cmd=json.loads((d/'command.json').read_text());cmd[0]=str(sim);cmd=[x if not x.startswith('+STAGE_A_PROFILE=') else '+STAGE_A_PROFILE='+str(d/'stage_a') for x in cmd];cmd+=['+PHASE1_PROFILE='+str(d/'profile')]
 execute(cmd,d/'top.log','REPRESENTATIVE_MODEL_PASS');execute([py,'benchmark/representative/verify_trained_3x3_cnn_workload.py','--workload-dir',d],d/'independent.log','R19_TRAINED_CNN_GOLDEN_PASS')
w=profile_wrapper('h16_profile');execute([py,'sw/tools/run_tiny_gpt2_persistent_session.py','--model','benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json','--simv',w,'--out',a.out/'h16','--seed','20261123','--steps','8'],a.out/'h16-driver.log','TINY_GPT2_PERSISTENT_TOP_PASS')
for label,model in [('h32_old',root/'benchmark/research/stage_c/models/h32_l2_int8.json'),('h32',a.model)]:
 d=a.out/label
 execute([py,'tools/benchmark/stage_c/generate.py','--model',model,'--out',d],a.out/(label+'-generator.log'),'H32_GENERATOR_PASS')
 # Correct historical hardcoded metadata at the new runner boundary.
 man=json.loads((d/'manifest.json').read_text());man['source_rtl_tree']=subprocess.check_output(['git','rev-parse','HEAD:rtl'],text=True).strip();man['rtl_source_sha']='48790076b351cb9d49e1785247d32a1f51b8286d';(d/'manifest.json').write_text(json.dumps(man,indent=2)+'\n')
 execute([sim,'+AI_STAGE_C_TRANSFORMER','+AI_STAGE_C_DIR='+str(d),'+AI_STAGE_C_STAGES=12','+STAGE_A_PROFILE='+str(d/'stage_a'),'+PHASE1_PROFILE='+str(d/'profile'),'+AI_RANDOM_CASES=0','+AI_SEED=20261112','+ACLK_PERIOD_NS=4'],d/'top.log','STAGE_C_TOP_PASS');print(label,'PASS',flush=True)
execute([sim,'+AI_RANDOM_CASES=20','+AI_SEED=12345'],a.out/'smoke.log','TEST PASS')
print('PHASE1_TOP_RUN_PASS',flush=True)
