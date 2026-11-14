VCS_HOME ?= /opt/Synopsys/vcs/V-2023.12-SP1
.PHONY: all clean
all:
	cd ../../../.. && $(VCS_HOME)/bin/vcs -full64 -sverilog -timescale=1ns/1ps -f dv/research/dams_svse/files.f -top tb_dams_svse -o /tmp/dams_svse_simv
	/tmp/dams_svse_simv
clean:
	rm -rf simv simv.daidir csrc ucli.key
