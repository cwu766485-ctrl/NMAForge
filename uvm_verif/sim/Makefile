# Run from uvm_verif/sim on the Linux/VCS environment.
UVM_TEST ?= ai_version_smoke_test
VCS_UVM  ?= vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS

.PHONY: uvm_compile uvm_run uvm_smoke clean
uvm_compile:
	rm -rf simv_uvm simv_uvm.daidir csrc
	$(VCS_UVM) -top tb_ai_accel_uvm -f ai_accel_uvm.f -o simv_uvm -l uvm_compile.log

uvm_run: uvm_compile
	./simv_uvm +UVM_TESTNAME=$(UVM_TEST) -l uvm_run.log

uvm_smoke: uvm_run

clean:
	rm -rf csrc simv_uvm* *.log ucli.key *.vpd vc_hdrs.h DVE* novas* *.daidir *.vdb *.key
