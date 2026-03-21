// uvm/agents/cpu/cpu_sequencer.sv
`ifndef CPU_SEQUENCER_SV
`define CPU_SEQUENCER_SV

class cpu_sequencer extends uvm_sequencer #(cpu_seq_item);
  
  `uvm_component_utils(cpu_sequencer)
  
  function new(string name = "cpu_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  // That's it! The base class does everything else.
  
endclass

`endif // CPU_SEQUENCER_SV
