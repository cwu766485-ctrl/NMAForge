"""Generate common raw-INT8 kernels and two matched memory-service harnesses."""
import argparse,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);root=Path(__file__).resolve().parents[3];model=json.loads((root/'benchmark/research/stage_c/models/h32_l2_int8.json').read_text())
items=[]
for m,n,k in [(16,16,16),(16,16,32),(32,32,64),(1,16,32)]:
 aa=[[(r*3+i*2+1)%9-4 for i in range(k)] for r in range(m)];bb=[[(i*2-c*3+5)%9-4 for c in range(n)] for i in range(k)];items.append((f'gemm_{m}_{n}_{k}',aa,bb))
# Same actual trained weights and independent first-token intermediate operands.
import sys;sys.path.insert(0,str(root/'tools/benchmark/stage_c'));from reference import cache_new,one
r=one(model,cache_new(model),model['prompt'][0],0);l=model['layers'][0]
for name,x,w in [('q',r['layers'][0]['input'],l['weights']['wq']),('k',r['layers'][0]['input'],l['weights']['wk']),('v',r['layers'][0]['input'],l['weights']['wv']),('ffn_up',r['layers'][0]['ln1_i8'],l['weights']['wup']),('ffn_down',r['layers'][0]['gelu_i8'],l['weights']['wdown'])]:items.append(('h32_'+name,[x]+[[0]*len(x) for _ in range(3)],w))
meta=[]
for name,aa,bb in items:
 m,k,n=len(aa),len(aa[0]),len(bb[0]);flat=[v for row in aa+bb for v in row];out=[sum(aa[r][i]*bb[i][c] for i in range(k)) for r in range(m) for c in range(n)]
 (a.out/(name+'.memh')).write_text(''.join(f'{v:08x}\n' for v in [m,n,k])+''.join(f'{v&255:02x}\n' for v in flat));(a.out/(name+'_golden.memh')).write_text(''.join(f'{v&0xffffffff:08x}\n' for v in out));meta.append({'id':name,'m':m,'n':n,'k':k,'a_sha256':hashlib.sha256(bytes(v&255 for row in aa for v in row)).hexdigest(),'b_sha256':hashlib.sha256(bytes(v&255 for row in bb for v in row)).hexdigest(),'golden_sha256':hashlib.sha256(b''.join(int(v).to_bytes(4,'little',signed=True) for v in out)).hexdigest()})
(a.out/'fixtures.json').write_text(json.dumps(meta,indent=2)+'\n')
# NMA harness derived from the previously reviewed array test, exact same array.
s=(root/'tools/benchmark/stage_a/tb_matched_array.sv').read_text().replace('tb_stage_a_matched_array','tb_stage_c_matched_service').replace('reg [7:0] shared[0:319];','reg [31:0] shared_image[0:20000];\nreg [7:0] shared[0:20000];\ninteger shared_m,shared_n,shared_k,memory_read_cycles,memory_write_cycles,memory_read_bytes,memory_write_bytes;')
s=s.replace('shared[row*16+k]','shared[row*shared_k+k]').replace('shared[64+k*16+col]','shared[shared_m*shared_k+k*shared_n+col]')
s=s.replace('start=total_clock;tiles=0;checks=0;','start=total_clock;tiles=0;checks=0;memory_read_cycles=0;memory_write_cycles=0;memory_read_bytes=0;memory_write_bytes=0;')
key='   clear=1;load=0;mac=0;@(negedge clk);clear=0;'
s=s.replace(key,'''   // Common single-outstanding 128-bit service: one issue + two response
   // clocks per padded operand line. No overlapping compute in this adapter.
   repeat(3*(k+k)) @(negedge clk);
   memory_read_cycles=memory_read_cycles+3*(k+k);
   memory_read_bytes=memory_read_bytes+16*(k+k);
'''+key)
s=s.replace('  end\n  if(total_clock-start!=tiles*(k+2))','   repeat(64) @(negedge clk);\n   memory_write_cycles=memory_write_cycles+64;memory_write_bytes=memory_write_bytes+1024;\n  end\n  if(total_clock-start!=tiles*(k+2)+memory_read_cycles+memory_write_cycles)')
s=s.replace('  $display("NMA_MATCHED_ARRAY_PASS','  $display("STAGE_C_SERVICE phases_read=%0d phases_write=%0d read_bytes=%0d write_bytes=%0d total=%0d",memory_read_cycles,memory_write_cycles,memory_read_bytes,memory_write_bytes,total_clock-start);\n  $display("NMA_MATCHED_ARRAY_PASS')
a0=s.index(' if($value$plusargs("SHARED_OPERANDS');b0=s.index(' $finish;',a0)
s=s[:a0]+''' if(!$value$plusargs("SHARED_OPERANDS=%s",path))$fatal(1,"fixture required");
 if(!$value$plusargs("SHARED_OUTPUT=%s",output_path))$fatal(1,"output required");
 $readmemh(path,shared_image);shared_m=shared_image[0];shared_n=shared_image[1];shared_k=shared_image[2];
 for(integer i=0;i<shared_m*shared_k+shared_k*shared_n;i=i+1)shared[i]=shared_image[i+3];
 out_fd=$fopen(output_path,"w");shared_mode=1;run(shared_m,shared_n,shared_k);$fclose(out_fd);
'''+s[b0:]
s=s.replace('integer shared_m,shared_n,shared_k,','reg [7:0] serviced_a[0:4095],serviced_b[0:4095];\ninteger shared_m,shared_n,shared_k,')
s=s.replace('operand_a(tr+i,kk):0','serviced_a[i*shared_k+kk]:0').replace('operand_b(kk,tc+i):0','serviced_b[kk*16+i]:0')
s=s.replace('   repeat(3*(k+k)) @(negedge clk);','''   for(integer kk_line=0;kk_line<k;kk_line=kk_line+1)begin
    repeat(3)@(negedge clk);
    for(integer lane=0;lane<16;lane=lane+1)
     serviced_a[lane*k+kk_line]=(tr+lane<m)?operand_a(tr+lane,kk_line):0;
   end
   for(integer kk_line=0;kk_line<k;kk_line=kk_line+1)begin
    repeat(3)@(negedge clk);
    for(integer lane=0;lane<16;lane=lane+1)
     serviced_b[kk_line*16+lane]=(tc+lane<n)?operand_b(kk_line,tc+lane):0;
   end''')
s=s.replace('reg [7:0] serviced_a[0:4095],serviced_b[0:4095];','reg [7:0] serviced_a[0:4095],serviced_b[0:4095];\nreg [31:0] committed_output[0:16383];')
s=s.replace('if(shared_mode)$fdisplay(out_fd,"%08h",accum[(r*16+c)*64+:32]);','')
s=s.replace('   repeat(64) @(negedge clk);','''   for(integer line=0;line<64;line=line+1)begin
    @(negedge clk);
    for(integer lane=0;lane<4;lane=lane+1)begin
     committed_output[line*4+lane]=accum[(line*4+lane)*64+:32];
     if((tr+(line*4+lane)/16<m)&&(tc+(line*4+lane)%16<n))
      $fdisplay(out_fd,"%08h",committed_output[line*4+lane]);
    end
   end''')
s=s.replace('NMA_MATCHED_ARRAY_PASS','NMA_MATCHED_SERVICE_PASS').replace('boundary=preloaded_host_to_stable_raw_accumulator transfer=NA dispatch=NA writeback=NA','boundary=common_clocked_service dispatch=NA')
(a.out/'tb_service.sv').write_text(s)
# Tiny uses unchanged pinned systolic_array through engine_tb_top.
s=(root/'benchmark/tinynpu/tb_matched_gemm.cpp').read_text().replace('static std::vector<int8_t> shared_a, shared_b;','static std::vector<int8_t> shared_a, shared_b;\nstatic int shared_m,shared_n,shared_k;')
s=s.replace('shared_a[row * 16 + k]','shared_a[row * shared_k + k]').replace('shared_b[k * 16 + col]','shared_b[k * shared_n + col]')
s=s.replace('uint64_t start_cycle = 0;','uint64_t start_cycle = 0; uint64_t memory_read_cycles=0,memory_write_cycles=0;')
s=s.replace('            clear_cycles += 2;','''            for(int line=0;line<k+k;++line) {tick();tick();tick();}
            memory_read_cycles+=3*(k+k);
            clear_cycles += 2;''')
s=s.replace('        }\n    }\n\n    const uint64_t elapsed', '''            for(int line=0;line<64;++line)tick();
            memory_write_cycles+=64;
        }
    }

    const uint64_t elapsed''')
s=s.replace('inclusive_cycles != clear_cycles + feed_cycles + drain_cycles','inclusive_cycles != clear_cycles + feed_cycles + drain_cycles + memory_read_cycles + memory_write_cycles')
s=s.replace('    const int useful_macs', '''    std::printf("STAGE_C_SERVICE phases_read=%llu phases_write=%llu read_bytes=%llu write_bytes=%llu total=%llu\\n",(unsigned long long)memory_read_cycles,(unsigned long long)memory_write_cycles,(unsigned long long)(memory_read_cycles/3*16),(unsigned long long)(memory_write_cycles*16),(unsigned long long)inclusive_cycles);
    const int useful_macs''')
a0=s.index('        for (int i=0; i<320;');b0=s.index('    if (!run_gemm(16, 16, 16)',a0)
s=s[:a0]+'''        stream >> std::hex >> shared_m >> shared_n >> shared_k;
        for (int i=0; i<shared_m*shared_k+shared_k*shared_n; ++i) {
            if (!(stream >> std::hex >> value) || value>255) return EXIT_FAILURE;
            if(i<shared_m*shared_k)shared_a.push_back(static_cast<int8_t>(value));
            else shared_b.push_back(static_cast<int8_t>(value));
        }
        return run_gemm(shared_m,shared_n,shared_k,3) ? EXIT_SUCCESS : EXIT_FAILURE;
    }
'''+s[b0:];s=s.replace('static int shared_m,shared_n,shared_k;','static int shared_m,shared_n,shared_k;\nstatic std::vector<int8_t> serviced_a,serviced_b;')
s=s.replace('            for(int line=0;line<k+k;++line) {tick();tick();tick();}','''            serviced_a.assign(16*k,0);serviced_b.assign(k*16,0);
            for(int kk=0;kk<k;++kk) {tick();tick();tick();
             for(int lane=0;lane<16;++lane)if(tile_row+lane<m)serviced_a[lane*k+kk]=operand_a(tile_row+lane,kk,workload);
            }
            for(int kk=0;kk<k;++kk) {tick();tick();tick();
             for(int lane=0;lane<16;++lane)if(tile_col+lane<n)serviced_b[kk*16+lane]=operand_b(kk,tile_col+lane,workload);
            }''')
s=s.replace('operand_a(tile_row + row, k_base + local_k, workload)','serviced_a[row*k+k_base+local_k]').replace('operand_b(k_base + local_k, tile_col + col, workload)','serviced_b[(k_base+local_k)*16+col]')
s=s.replace('static std::vector<int8_t> serviced_a,serviced_b;','static std::vector<int8_t> serviced_a,serviced_b;\nstatic std::vector<int32_t> committed_output;')
s=s.replace('    const uint64_t inclusive_start = cycles;','    committed_output.assign(m*n,0);\n    const uint64_t inclusive_start = cycles;')
s=s.replace('            for(int line=0;line<64;++line)tick();','''            for(int line=0;line<64;++line){tick();
             for(int lane=0;lane<4;++lane){int r=(line*4+lane)/16,c=(line*4+lane)%16;
              if(tile_row+r<m && tile_col+c<n)committed_output[(tile_row+r)*n+tile_col+c]=actual[(tile_row+r)*n+tile_col+c];
             }
            }''')
s=s.replace('    const uint64_t elapsed = cycles - start_cycle;','    actual=committed_output;\n    const uint64_t elapsed = cycles - start_cycle;')
s=s.replace('TINYNPU_ARRAY_PHASES','TINYNPU_SERVICE_PHASES').replace('boundary=array_only','boundary=common_clocked_service').replace('transfer=NA dispatch=NA writeback=NA','dispatch=NA')
(a.out/'tb_service.cpp').write_text(s)
# Reuse full known source list but build the candidate C++ harness in new output.
s=(root/'benchmark/tinynpu/run_tinynpu_gemm.sh').read_text().replace('REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"','REPO_ROOT="'+str(root)+'"').replace('"$SCRIPT_DIR/tb_matched_gemm.cpp"','"'+str(a.out/'tb_service.cpp')+'"');a0=s.index('"$OBJ/Vengine_tb_top" | tee');s=s[:a0];(a.out/'build_tiny.sh').write_text(s)
print('STAGE_C_BENCH_PREPARE_PASS fixtures',len(items))
