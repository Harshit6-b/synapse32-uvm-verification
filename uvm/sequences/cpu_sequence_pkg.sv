
`ifndef CPU_SEQUENCES_PKG_SV
`define CPU_SEQUENCES_PKG_SV

package cpu_sequences_pkg;
  
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  // Include sequence files
  `include "cpu_seq_item.sv"
  `include "cpu_base_sequence.sv"
//  `include "cpu_fibonacci_sequence.sv"
  
endpackage

`endif 
