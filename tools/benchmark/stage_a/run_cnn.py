"""Replay the trained CNN's existing mappings with passive phase/AXI observation."""
import argparse,json,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--simv',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
py=sys.executable
a.out.mkdir(parents=True,exist_ok=True)
for mode,count in [('legacy',4),('first_fused',3),('both_fused_row_major',2)]:
 out=a.out/mode;out.mkdir(exist_ok=False)
 with (out/'generator.log').open('w') as f:
  subprocess.run([py,'benchmark/representative/generate_trained_3x3_cnn_workload.py','--model','benchmark/representative/models/r19_trained_digits_3x3_cnn.json','--fusion-mode',mode,'--out-dir',str(out)],check=True,stdout=f,stderr=subprocess.STDOUT)
 with (out/'payload.log').open('w') as f:
  subprocess.run([py,'benchmark/representative/prepare_cnn_dma_payload.py','--memory-image',str(out/'model_memory.memh'),'--out-dir',str(out)],check=True,stdout=f,stderr=subprocess.STDOUT)
 cmd=[str(a.simv),'+ntb_random_seed=20261109','+AI_RANDOM_CASES=0','+AI_SEED=20261109','+ACLK_PERIOD_NS=4','+AI_REPRESENTATIVE_MODEL','+AI_REPRESENTATIVE_DMA_PRELOAD',
      '+AI_REPRESENTATIVE_DMA_PAYLOAD='+str(out/'dma_payload.memh'),'+AI_REPRESENTATIVE_DMA_PLAN='+str(out/'dma_plan.memh'),'+AI_REPRESENTATIVE_MEMORY='+str(out/'model_memory.memh'),'+AI_REPRESENTATIVE_GOLDEN='+str(out/'model_golden.memh'),
      '+AI_REPRESENTATIVE_DESC_BASE=106496','+AI_REPRESENTATIVE_CPL_BASE=107008','+AI_REPRESENTATIVE_DESC_COUNT='+str(count),'+AI_REPRESENTATIVE_USEFUL_MACS=570164',
      '+AI_REPRESENTATIVE_DUMP_FILE='+str(out/'output.txt'),'+AI_REPRESENTATIVE_DUMP_A_BASE=102400','+AI_REPRESENTATIVE_DUMP_A_WORDS=832','+AI_REPRESENTATIVE_DUMP_B_BASE=0','+AI_REPRESENTATIVE_DUMP_B_WORDS=0',
      '+STAGE_A_PROFILE='+str(out/'profile')]
 (out/'command.json').write_text(json.dumps(cmd,indent=2)+'\n')
 with (out/'top.log').open('w') as f:subprocess.run(cmd,check=True,stdout=f,stderr=subprocess.STDOUT)
 assert 'REPRESENTATIVE_MODEL_PASS' in (out/'top.log').read_text()
 print(mode,'PASS')
