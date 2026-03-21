#!/bin/bash

TEST=${1:-cpu_nop_test}
VERBOSITY=${2:-UVM_MEDIUM}

echo "========================================"
echo " Compiling Synapse32 UVM Testbench"
echo " Test: $TEST"
echo "========================================"

source /home/harshit/Desktop/2025.2/Vivado/settings64.sh

cd /home/harshit/synapse32/uvm

xvlog -sv --include /home/harshit/synapse32/rtl/include \
  /home/harshit/synapse32/rtl/core_modules/pc.v \
  /home/harshit/synapse32/rtl/core_modules/alu.v \
  /home/harshit/synapse32/rtl/core_modules/decoder.v \
  /home/harshit/synapse32/rtl/core_modules/registerfile.v \
  /home/harshit/synapse32/rtl/core_modules/csr_exec.v \
  /home/harshit/synapse32/rtl/core_modules/csr_file.v \
  /home/harshit/synapse32/rtl/core_modules/timer.v \
  /home/harshit/synapse32/rtl/core_modules/interrupt_controller.v \
  /home/harshit/synapse32/rtl/pipeline_stages/IF_ID.v \
  /home/harshit/synapse32/rtl/pipeline_stages/ID_EX.v \
  /home/harshit/synapse32/rtl/pipeline_stages/EX_MEM.v \
  /home/harshit/synapse32/rtl/pipeline_stages/MEM_WB.v \
  /home/harshit/synapse32/rtl/pipeline_stages/forwarding_unit.v \
  /home/harshit/synapse32/rtl/pipeline_stages/load_use_detector.v \
  /home/harshit/synapse32/rtl/pipeline_stages/store_load_detector.v \
  /home/harshit/synapse32/rtl/pipeline_stages/store_load_forward.v \
  /home/harshit/synapse32/rtl/execution_unit.v \
  /home/harshit/synapse32/rtl/memory_unit.v \
  /home/harshit/synapse32/rtl/writeback.v \
  /home/harshit/synapse32/rtl/riscv_cpu.v \
  /home/harshit/synapse32/uvm/interfaces/synapse32_if.sv \
  -L uvm \
  /home/harshit/synapse32/uvm/sequences/cpu_sequence_pkg.sv \
  /home/harshit/synapse32/uvm/agents/cpu_agent_pkg.sv \
  /home/harshit/synapse32/uvm/env/cpu_env_pkg.sv \
  /home/harshit/synapse32/uvm/tests/cpu_test_pkg.sv \
  /home/harshit/synapse32/uvm/tb_top.sv

if [ $? -ne 0 ]; then echo "COMPILE FAILED"; exit 1; fi

xelab -L uvm tb_top -s tb_sim --debug typical \
  --override_timeprecision --timescale 1ns/1ps

if [ $? -ne 0 ]; then echo "ELABORATE FAILED"; exit 1; fi

xsim tb_sim --runall \
  --testplusarg UVM_TESTNAME=$TEST \
  --testplusarg UVM_VERBOSITY=$VERBOSITY \
  --log xsim_${TEST}.log

cat xsim_${TEST}.log
