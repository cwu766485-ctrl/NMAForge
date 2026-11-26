"""Archive public Stage A observations; never archive tool binaries or libraries.

Run from the repository root. --inputs maps logical names to fresh run paths.
The manifest pins the reviewed RTL tree independently of later evidence commits.
"""
import argparse
import csv
import gzip
import hashlib
import json
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--inputs', type=Path, required=True)
p.add_argument('--out', type=Path, default=Path('benchmark/research/stage_a'))
a = p.parse_args()
inputs = {k: Path(v) for k, v in json.loads(a.inputs.read_text()).items()}
a.out.mkdir(parents=True, exist_ok=False)

def digest(data):
    return hashlib.sha256(data).hexdigest()

def save(path, data):
    dest = a.out / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)

def copy(src, dst, compress=False):
    data = src.read_bytes()
    if src.suffix == '.csv':
        data = data.replace(b'\r\n', b'\n')
    save(dst + ('.gz' if compress else ''), gzip.compress(data, mtime=0) if compress else data)

def js(path, value):
    save(path, (json.dumps(value, indent=2) + '\n').encode())

for f in inputs['analysis'].iterdir():
    if f.suffix in ('.json', '.csv'):
        copy(f, 'analysis/' + f.name)
for f in inputs['nma'].glob('h16_*.csv'):
    copy(f, 'h16/' + f.name, True)
for name in ['top_session.log', 'persistent_decode.json', 'persistent_decode.csv',
             'opcode_profile.json', 'opcode_profile.csv', 'generator.log']:
    copy(inputs['nma'] / 'session' / name, 'h16/' + name, name.endswith('.log'))
for f in (inputs['nma'] / 'session/workload').iterdir():
    if f.suffix in ('.memh', '.json'):
        copy(f, 'h16/workload/' + f.name, f.suffix == '.memh')
copy(inputs['nma'] / 'compile.log', 'validation/h16_compile.log', True)
copy(inputs['quality'], 'h16/heldout_quality.json')
for mode in ['legacy', 'first_fused', 'both_fused_row_major']:
    for f in (inputs['cnn'] / mode).iterdir():
        if f.suffix in ('.json', '.log', '.txt', '.csv', '.memh'):
            copy(f, 'cnn/' + mode + '/' + f.name, f.suffix != '.json')
for name in ['run.log', 'compile.log', 'command.json']:
    copy(inputs['tiny'] / name, 'tiny_native/' + name, name.endswith('.log'))
# Generated third-party graph binaries stay outside this repository; record
# exact compiler products and source-model hashes for regeneration instead.
tiny_source = inputs['tiny_source']
js('tiny_native/graph_hashes.json', {
    f.name: {'bytes': f.stat().st_size, 'sha256': digest(f.read_bytes())}
    for f in sorted((inputs['tiny'] / 'graph').iterdir()) if f.is_file()})
copy(inputs['tiny'] / 'graph/manifest.json', 'tiny_native/graph_manifest.json')
for key, dst in [('array_log', 'arrays/nma.log'), ('array_compile', 'validation/array_compile.log'),
                 ('smoke', 'validation/ai_smoke.log'), ('seeded', 'validation/ai_run_seed12345.log'),
                 ('upstream_replay', 'tiny_native/upstream_replay.log')]:
    copy(inputs[key], dst, True)
for name in ['run.log', 'engine_regression.log', 'compile.log']:
    copy(inputs['tiny_array'] / name, 'arrays/tiny_' + name, True)
for f in inputs['qkv'].iterdir():
    if f.suffix in ('.log', '.memh', '.json'):
        copy(f, 'qkv/' + f.name, f.suffix == '.log')
for enable in [0, 1]:
    copy(inputs['forward'] / f'enable_{enable}/run.log', f'forward/enable_{enable}.log', True)
copy(inputs['common_cnn'] / 'run.log', 'common_cnn/nma.log', True)
for f in (inputs['common_cnn'] / 'workload').iterdir():
    if f.suffix in ('.json', '.memh'):
        copy(f, 'common_cnn/' + f.name, f.suffix == '.memh')
copy(inputs['related'], 'related_work_metadata.json')
# Portable run provenance: absolute paths describe this execution, not credentials.
js('collection_inputs.json', {k: str(v) for k, v in inputs.items()})

reviewed = 'da5a6691c7582d54c7a2da643e01d296f8da2d68'
rtl_tree = subprocess.check_output(['git', 'rev-parse', reviewed + ':rtl'], text=True).strip()
assert not subprocess.check_output(['git', 'diff', reviewed, '--', 'rtl/'])
source_paths = [Path('docs/spec/SFU_NUMERIC_CONTRACT_ZH.md'),
    Path('sw/tools/reference_tiny_gpt2_int8.py'), Path('sw/tools/generate_h16_incremental_decode.py'),
    Path('benchmark/representative/generate_trained_3x3_cnn_workload.py'),
    Path('benchmark/tinynpu/generate_nma_cnn_workload.py'),
    Path('benchmark/tinynpu/tb_matched_gemm.cpp'),
    Path('rtl/compute/matrix/ai_tensor_matrix_array.sv'),
    Path('dv/subsystem/top_smoke/tb/tb_ai_accel_smoke.sv'),
    Path('dv/subsystem/top_smoke/fixtures/stage_a_profile.svh')]
source_paths += sorted(Path('tools/benchmark/stage_a').glob('*.*'))
models = [Path('benchmark/representative/models/r19_trained_digits_3x3_cnn.json'),
    Path('benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json')]
# Serialize the EXACT signed-remainder fixtures shared by SV and C++.
def rem(x, y):
    return x - (abs(x) // y * (1 if x >= 0 else -1)) * y
arrays = []
for m, n, k, nma, tiny in [(16,16,16,18,54), (16,16,32,34,102), (32,32,64,264,792)]:
    aa = bytes((rem(r*3+kk*2+1,9)-4)&255 for r in range(m) for kk in range(k))
    bb = bytes((rem(kk*2-c*3+5,9)-4)&255 for kk in range(k) for c in range(n))
    def signed(v): return v if v < 128 else v-256
    output = b''.join(sum(signed(aa[r*k+kk])*signed(bb[kk*n+c]) for kk in range(k)).to_bytes(4,'little',signed=True)
        for r in range(m) for c in range(n))
    arrays.append(dict(id=f'gemm_{m}_{n}_{k}', classification='MATCHED_COMPUTE',
        shape_mnk=[m,n,k], nma_cycles=nma, tiny_cycles=tiny, cycle_ratio=tiny/nma,
        ratio_scope='array_only', system_speedup=None,
        boundary='inclusive accumulator clear + operand feed from preloaded host arrays to stable raw accumulator',
        operand_a_sha256=digest(aa), operand_b_sha256=digest(bb), golden_sha256=digest(output),
        serialization='row-major signed INT8 bytes; Golden row-major little-endian signed INT32',
        arithmetic='signed INT8 product, exact integer sum; no shift/bias/activation/quantization; no overflow on fixtures',
        memory='no clocked SRAM, descriptor, DMA, or output memory commit on either side; transfer/writeback NA',
        golden_tolerance=0))
cnn_meta=json.loads((inputs['cnn']/'both_fused_row_major/manifest.json').read_text())
manifest = dict(schema_version=1, stage='A_ONLY', freeze_status='DESIGN_PARTIAL',
    nmaforge=dict(reviewed_head=reviewed, latest_product_rtl_commit='b2b3b0b5942f9218ed574a04e946104109dc2c99', rtl_tree_git=rtl_tree,
        branch='nmaforge', product_rtl_changed=False, array='16x16 INT8 / 256 MAC',
        spad=dict(research_bytes=131072, compatibility_bytes=524288, banks=4, word_bits=32,
            ports='one host/debug A and one scheduler B per bank; shared scheduler admission',
            scalar_bytes_per_admission=4, banked_or_line_bytes_per_admission=16,
            read_latency_cycles=2, note='registered behavioral RAM; not SRAM macro timing; scalar read service observed 3 cycles'),
        dma='128-bit AXI4, 64-bit address, 4-bit ID; testbench memory responder',
        matrix_defaults=dict(MAX_OUTSTANDING_READS=4, ENABLE_A_TILE_CACHE=1, ENABLE_NEXT_K_PREFETCH=1,
            ENABLE_GEMV_B_TILE_CACHE=1, ENABLE_ELASTIC_TILE_FORWARDING=1)),
    tinynpu=dict(repository='harishsg993010/tiny-NPU', sha='8216c22b762011aa20c05fc2768423fd12dda59d',
        native_data_sram_bytes=65536, native_data_sram_width_bits=8,
        native_data_ports='synchronous read A and write B, byte-wide; wrapper arbitrates TB DMA and graph accesses',
        native_read_latency_cycles=1, scratch_bytes=8192, accumulator_bytes=1024,
        program_bytes=16384, tensor_table_bytes=8192,
        model_sha256=digest((tiny_source/'models/conv1x_mini.onnx').read_bytes()),
        dma_model='C++ byte-serial load/store, not AXI RTL; 1 cycle/load byte, 2/store byte + completion pulse',
        source_dirty_paths=subprocess.check_output(['git','-C',str(tiny_source),'status','--porcelain'],text=True).splitlines()),
    clocks=dict(nma_h16_cnn_simulation_period_ns=4, common_cnn_simulation_period_ns=10,
        nma_direct_array_period_ns=10, tiny_verilator='edge-counted tick; no achieved physical frequency',
        cross_design_comparison='cycles only; equal-frequency assumption for array ratio only',
        asic_target_mhz=400, asic_target_period_ns=2.5, achieved_fmax_mhz=None,
        historical_correction='4 ns is 250 MHz, not 400 MHz'),
    numerics=dict(normative_contract='docs/spec/SFU_NUMERIC_CONTRACT_ZH.md',
        shift='arithmetic right shift, negative toward minus infinity', division='signed trunc toward zero; variance unsigned floor',
        sqrt='integer floor', saturation='sat32 at specified matrix/LN/residual stages; requant sat8[-128,127]',
        softmax='deterministic Q15 PWL exponent and floor division; not real-valued exact exp',
        gelu='existing Q8.8 piecewise integer approximation, not IEEE GELU',
        cnn_input='np.rint(patches*127), clip[-127,127]; conv1 shift9/ReLU; conv2 shift7/sat8',
        layernorm='mean trunc0; floor variance; isqrt(var+eps); floor(2^30/root); gamma sat32 before reciprocal multiply, beta then sat32',
        common_cnn='pinned Tiny compiler rounding/bias order emulated by existing NMA mapper; 4-byte output equality',
        golden_tolerance=0),
    source_hashes={str(f):digest(f.read_bytes()) for f in source_paths},
    model_hashes={str(f):digest(f.read_bytes()) for f in models},
    cnn_deployed_weights_sha256=cnn_meta['deployed_weight_sha256'],
    cnn_dataset_sha256=cnn_meta['dataset_sha256'],
    comparisons=arrays + [dict(id='trained_qkv', classification='MATCHED_COMPUTE', shape_mnk=[4,16,16],
        projections=['q','k','v'], nma_cycles_per_projection=18,tiny_cycles_per_projection=54,
        cycle_ratio=3.0, ratio_scope='array_only', system_speedup=None,
        fixtures='qkv/{q,k,v}.json and .memh; paired_validation.json pins raw output hashes',
        boundary='same inclusive direct-array boundary; host common requant excluded',golden_words_per_design=192),
        dict(id='controller_memory', classification='MATCHED_CONTROLLER_MEMORY',status='NOT_RUN',
            cycle_ratio=None,system_speedup=None,reason='no common clocked memory/commit adapter'),
        dict(id='native_complete_host_path',classification='NATIVE_END_TO_END',status='NOT_MEASURED',
            cycle_ratio=None,system_speedup=None,reason='host pack/descriptor/readback segments not fully timed on both designs'),
        dict(id='conv1x_native_graph',classification='MIXED_MEASURED_MODELED',nma_cmdq_cycles=1874,
            nma_host_layout_model_cycles=1080,tiny_start_to_committed_cycles=4742,
            cycle_ratio=None,system_speedup=None,
            reason='NMA preloaded SPAD CMDQ vs Tiny native graph plus byte-serial C++ DMA, differing capacity/traffic/layout/commit boundaries'),
        dict(id='trained_570164_cnn_cross_design',classification='NOT_COMPARABLE',cycle_ratio=None,system_speedup=None,
            reason='no Tiny mapping of the complete trained graph; NMA internal mapping ablation only'),
        dict(id='full_h16_cross_design',classification='NOT_COMPARABLE',cycle_ratio=None,system_speedup=None,
            reason='Tiny full identical Post-LN integer architecture/quantization/weights/KV graph not mapped')],
    h16=dict(total_decode_cycles=65771, cycles_per_token=8221.375, read_bytes=72448,write_bytes=42112,
        useful_macs=18240, prefill_cycles=2728,prefill_scope='QKV and KV population for 4 tokens only; not full prefill',
        execution='8 teacher-forced tokens; preloaded host embeddings; one initial reset, persistent KV ring8; 53 descriptors/token',
        arithmetic_reference='sw/tools/reference_tiny_gpt2_int8.py',
        host_costs_correction='raw persistent_decode.json contains stale no-host-embedding wording; generator calls embedding_input and preloads embeddings',
        quality=json.loads(inputs['quality'].read_text())['heldout_quality']),
    unmeasured=dict(physical_bank_conflicts='admission stalls are not bank conflict counts',
        external_dram_wire_bytes='AXI payload only; no DRAM PHY/protocol overhead model',
        host_packing_seconds=None, host_descriptor_build_seconds=None, fmax=None, area=None,power=None),
    policy=dict(forbid_system_ratio_classes=['MIXED_MEASURED_MODELED','NOT_COMPARABLE'],
        matched_compute_ratio_scope='array_only', missing_values='null/NA with reason, never zero'),
    artifact_hashes={str(f.relative_to(a.out)):digest(f.read_bytes()) for f in sorted(a.out.rglob('*')) if f.is_file()})
js('manifest.json',manifest)
print('STAGE_A_PUBLIC_ARCHIVE_CREATED', a.out)
