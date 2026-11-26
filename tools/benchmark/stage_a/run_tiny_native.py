"""Build an instrumented COPY of the pinned Tiny graph wrapper; source stays intact."""
import argparse, hashlib, json, os, shlex, subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--verilator',required=True);a=p.parse_args()
sha='8216c22b762011aa20c05fc2768423fd12dda59d'
assert subprocess.check_output(['git','-C',str(a.source),'rev-parse','HEAD'],text=True).strip()==sha
assert not subprocess.check_output(['git','-C',str(a.source),'status','--porcelain'],text=True).strip(), 'Tiny source must be clean'
assert not a.out.exists(), 'Use a fresh output directory'
a.out.mkdir(parents=True)
original=a.source/'sim/verilator/onnx_sim_top.sv';s=original.read_text()
assert s.count('    output wire                graph_busy\n') == 1
assert s.count('    assign graph_done    = gp_done;') == 1
s=s.replace('    output wire                graph_busy\n','    output wire                graph_busy,\n    output wire sa_gm_busy, output wire [3:0] sa_gm_state,\n    output wire sa_read, output wire sa_write\n')
s=s.replace('    assign graph_done    = gp_done;','    assign sa_gm_busy=gm_busy;\n    assign sa_gm_state=u_gemm_ctrl.state;\n    assign sa_read=s0_a_en;\n    assign sa_write=s0_b_en && s0_b_we;\n    assign graph_done    = gp_done;')
wrapper=a.out/'onnx_sim_top.sv';wrapper.write_text(s)
# Reuse the canonical ordered source list, replace only wrapper/harness/build dir.
script=Path('benchmark/tinynpu/run_tinynpu_cnn.sh').read_text();start=script.index('    "$VERILATOR" --cc');end=script.index(' > "$OUT_DIR/compile.log"',start)
command=script[start:end].replace('\\\n',' ')
variables={'VERILATOR':a.verilator,'RTL':str(a.source/'rtl'),'SIM':str(a.source/'sim/verilator'),'OBJ':str(a.out/'obj')}
command=command.replace('"$SIM/tb_onnx_cnn_smoke.cpp"',shlex.quote(str(Path('tools/benchmark/stage_a/tb_tiny_native.cpp').resolve())))
command=command.replace('"$SIM/onnx_sim_top.sv"',shlex.quote(str(wrapper)))
for k,v in variables.items():command=command.replace('"$'+k+'"',shlex.quote(v)).replace('$'+k+'/',v+'/')
command=command.replace('"${JOBS:-4}"','2')
cmd=shlex.split(command)
# Public compile command recorded without credentials or environment dumps.
(a.out/'command.json').write_text(json.dumps({'source_sha':sha,'wrapper_original_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'wrapper_instrumented_sha256':hashlib.sha256(wrapper.read_bytes()).hexdigest(),'argv':cmd},indent=2)+'\n')
with (a.out/'compile.log').open('w') as out:subprocess.run(cmd,check=True,stdout=out,stderr=subprocess.STDOUT)
graph=a.out/'graph';subprocess.run([os.environ.get('STAGE_A_PYTHON','python3.12'),str(a.source/'python/onnx_compiler/compile.py'),'--model',str(a.source/'models/conv1x_mini.onnx'),'--outdir',str(graph)],check=True)
with (a.out/'run.log').open('w') as out:subprocess.run([str(a.out/'obj/Vonnx_sim_top'),str(graph)],check=True,stdout=out,stderr=subprocess.STDOUT)
print((a.out/'run.log').read_text())
