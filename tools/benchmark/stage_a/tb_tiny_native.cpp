// Stage A native graph timing; byte-serial TB DMA is explicitly modeled.
#include "Vonnx_sim_top.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <stdexcept>
#include <string>
#include <vector>
static Vonnx_sim_top d;
static uint64_t clocks=0, start_clock=0;
static bool measure=false, dma_service=false;
static std::array<uint64_t,8> phases{};
static uint64_t read_bytes=0,write_bytes=0,dma_load=0,dma_store=0,dma_commands=0;
static std::vector<uint8_t> ddr(16*1024*1024,0);
static void tick(){
 d.clk=0;d.eval();
 if(measure){
  int p=7;
  if(dma_service)p=0;
  else if(d.sa_gm_busy){
   if(d.sa_gm_state==3 || d.sa_gm_state==4)p=1;
   else if(d.sa_gm_state==6)p=2;
   else if(d.sa_gm_state==7)p=3;
   else p=4;
  }else if(d.graph_busy)p=5;
  else p=6;
  ++phases[p];
  read_bytes+=d.sa_read;
  write_bytes+=d.sa_write;
 }
 d.clk=1;d.eval();++clocks;
}
static std::vector<uint8_t> load(const std::string &path){
 std::ifstream in(path,std::ios::binary);
 if(!in)throw std::runtime_error("cannot read "+path);
 return {std::istreambuf_iterator<char>(in),std::istreambuf_iterator<char>()};
}
static uint32_t word(const std::vector<uint8_t>&v,size_t p){
 if(p+4>v.size())throw std::runtime_error("short word");
 return uint32_t(v[p])|(uint32_t(v[p+1])<<8)|(uint32_t(v[p+2])<<16)|(uint32_t(v[p+3])<<24);
}
static void dma(){
 if(!d.dma_cmd_captured)return;
 ++dma_commands;dma_service=true;
 uint32_t addr=d.dma_ddr_addr,spad=d.dma_sram_addr;
 bool store=d.dma_direction;
 uint32_t count=d.dma_strided?d.dma_count:1;
 uint32_t length=d.dma_strided?d.dma_block_len:d.dma_length;
 uint32_t stride=d.dma_strided?d.dma_stride:length;
 for(uint32_t b=0;b<count;++b){
  for(uint32_t i=0;i<length;++i){
   if(addr+i>=ddr.size() || spad+i>=65536)throw std::runtime_error("DMA range");
   if(store){
    d.tb_sram0_rd_en=1;d.tb_sram0_rd_addr=spad+i;tick();d.tb_sram0_rd_en=0;tick();
    ddr[addr+i]=d.tb_sram0_rd_data;++dma_store;
   }else{
    d.tb_sram0_wr_en=1;d.tb_sram0_wr_addr=spad+i;d.tb_sram0_wr_data=ddr[addr+i];tick();d.tb_sram0_wr_en=0;++dma_load;
   }
  }
  addr+=stride;spad+=length;
 }
 d.dma_done_pulse=1;tick();d.dma_done_pulse=0;dma_service=false;
}
int main(int argc,char**argv){
 try{
  Verilated::commandArgs(argc,argv);
  if(argc!=2)throw std::runtime_error("usage: executable graph-directory");
  std::string path=argv[1];auto program=load(path+"/program.bin");auto td=load(path+"/tdesc.bin");auto image=load(path+"/ddr_image.bin");auto golden=load(path+"/golden.bin");
  if(image.size()>ddr.size() || program.size()%16 || td.size()%32)throw std::runtime_error("bad fixture size");
  std::copy(image.begin(),image.end(),ddr.begin());
  d.rst_n=0;d.scheduler_mode=0;d.start_pulse=0;d.prog_wr_en=0;d.tdesc_wr_en=0;d.tb_sram0_wr_en=0;d.tb_sram0_rd_en=0;d.dma_done_pulse=0;
  for(int i=0;i<10;++i)tick();d.rst_n=1;for(int i=0;i<5;++i)tick();
  uint64_t cfg_start=clocks;
  for(size_t p=0;p<program.size();p+=16){d.prog_wr_en=1;d.prog_wr_addr=p/16;for(int w=0;w<4;++w)d.prog_wr_data[w]=word(program,p+w*4);tick();}d.prog_wr_en=0;
  for(size_t p=0;p<td.size();p+=32){d.tdesc_wr_en=1;d.tdesc_wr_addr=p/32;for(int w=0;w<8;++w)d.tdesc_wr_data[w]=word(td,p+w*4);tick();}d.tdesc_wr_en=0;
  uint64_t cfg=clocks-cfg_start;
  d.prog_len=program.size()/16+1;start_clock=clocks;measure=true;d.start_pulse=1;tick();d.start_pulse=0;
  bool done=false;
  for(int timeout=0;timeout<1000000 && !done;++timeout){tick();dma();if(d.graph_status&4)throw std::runtime_error("graph error");done=d.graph_done;}
  measure=false;if(!done)throw std::runtime_error("graph timeout");
  for(size_t i=0;i<golden.size();++i)if(ddr[0x00400000+i]!=golden[i])throw std::runtime_error("Golden mismatch at "+std::to_string(i));
  uint64_t elapsed=clocks-start_clock,sum=0;for(auto n:phases)sum+=n;if(sum!=elapsed)throw std::runtime_error("phase closure");
  printf("TINYNPU_NATIVE_STAGE_A_PASS cycles=%llu configuration=%llu golden=%zu/%zu dma_commands=%llu dma_load_bytes=%llu dma_store_bytes=%llu sram_read_bytes=%llu sram_write_bytes=%llu\n",(unsigned long long)elapsed,(unsigned long long)cfg,golden.size(),golden.size(),(unsigned long long)dma_commands,(unsigned long long)dma_load,(unsigned long long)dma_store,(unsigned long long)read_bytes,(unsigned long long)write_bytes);
  printf("TINYNPU_NATIVE_PHASES dma_emulation=%llu matrix_fetch=%llu matrix_wavefront=%llu matrix_store=%llu matrix_control=%llu graph_other=%llu start_finish=%llu other=%llu total=%llu boundary=start_pulse_to_output_DDR_committed\n",(unsigned long long)phases[0],(unsigned long long)phases[1],(unsigned long long)phases[2],(unsigned long long)phases[3],(unsigned long long)phases[4],(unsigned long long)phases[5],(unsigned long long)phases[6],(unsigned long long)phases[7],(unsigned long long)sum);
  printf("TIMING_CLASS=MIXED_MEASURED_MODELED dma_service=cpp_byte_serial no_external_AXI_timing=1 sram_data_bytes=65536 scratch_bytes=8192 acc_bytes=1024 program_bytes=16384\n");
  d.final();return 0;
 }catch(const std::exception&e){fprintf(stderr,"FAIL: %s\n",e.what());return 1;}
}
