VCS ?= vcs
SIMV ?= simv_dual_clock_shell
COMMAND_PATH_SIMV ?= simv_dual_clock_command_path
SEED ?= 20260929

.PHONY: shell_run command_path_run clean

shell_run:
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps +define+VCS -f cdc_shell.f -top tb_ai_accel_dual_clock_shell -o $(SIMV) -l shell_compile.log
	./$(SIMV) +ntb_random_seed=$(SEED) -l shell_run.log
	grep -q "DUAL CLOCK SHELL PASS" shell_run.log

command_path_run:
	$(VCS) -full64 -sverilog -debug_access+all -timescale=1ns/1ps +define+VCS -f cdc_command_path.f -top tb_ai_accel_dual_clock_command_path -o $(COMMAND_PATH_SIMV) -l command_path_compile.log
	./$(COMMAND_PATH_SIMV) +ntb_random_seed=$(SEED) -l command_path_run.log
	grep -q "DUAL CLOCK COMMAND PATH PASS" command_path_run.log

clean:
	rm -rf $(SIMV) $(SIMV).daidir $(COMMAND_PATH_SIMV) $(COMMAND_PATH_SIMV).daidir csrc *.log *.key DVEfiles ucli.key vc_hdrs.h
