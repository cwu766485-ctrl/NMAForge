VCS_HOME ?= /opt/Synopsys/vcs/V-2023.12-SP1
.PHONY: all adapter clean
all:
	cd ../../../.. && $(VCS_HOME)/bin/vcs -full64 -sverilog -timescale=1ns/1ps -f dv/research/dams_svse/files.f -top tb_dams_svse -o /tmp/dams_svse_simv
	/tmp/dams_svse_simv

adapter:
	cd ../../../.. && $(VCS_HOME)/bin/vcs -full64 -sverilog -timescale=1ns/1ps \
		rtl/compute/common/ai_unsigned_divider.v rtl/compute/common/ai_integer_sqrt.v \
		rtl/compute/sfu/ai_tensor_sfu_math.v rtl/compute/sfu/ai_tensor_sfu_core.v \
		rtl/research/ai_streaming_sfu.sv rtl/research/ai_streaming_sfu_spad_adapter.sv \
		dv/research/dams_svse/tb_svse_product_adapter.sv -top tb_svse_product_adapter \
		-o /tmp/svse_product_adapter_simv
	/tmp/svse_product_adapter_simv
clean:
	rm -rf simv simv.daidir csrc ucli.key
