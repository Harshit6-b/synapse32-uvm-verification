
`ifndef CPU_ENV_PKG_SV
`define CPU_ENV_PKG_SV

package cpu_env_pkg;
  
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  // Import agent package (contains agent, driver, monitor, sequencer)
  import cpu_agent_pkg::*;
  
  // Include environment files
  `include "cpu_scoreboard.sv"
  `include "cpu_env.sv"
  
endpackage

`endif 
