
`ifndef CPU_AGENT_PKG_SV
`define CPU_AGENT_PKG_SV

package cpu_agent_pkg;
  
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  // Import sequences package (for cpu_seq_item)
  import cpu_sequences_pkg::*;
  
  // Include agent component files
  `include "cpu_monitor_item.sv"
  `include "cpu_monitor.sv"
  `include "cpu_sequencer.sv"
  `include "cpu_driver.sv"
  `include "cpu_agent.sv"
  
endpackage

`endif 
