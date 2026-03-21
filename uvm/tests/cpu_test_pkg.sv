`ifndef CPU_TEST_PKG_SV
`define CPU_TEST_PKG_SV

package cpu_test_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import cpu_sequences_pkg::*;
  import cpu_agent_pkg::*;
  import cpu_env_pkg::*;

  `include "cpu_test.sv"

endpackage

`endif
