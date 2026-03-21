//uvm/sequence/cpu_base_sequence.sv
`ifndef CPU_BASE_SEQUENCE_SV
`define CPU_BASE_SEQUENCE_SV

class cpu_base_sequence extends uvm_sequence #(cpu_seq_item);
	
	`uvm_object_utils(cpu_base_sequence)

	function new(string name = "cpu_base_sequence");
		super.new(name);
	endfunction

	//prebody : runs before main sequence 
	virtual task pre_body();
		if (starting_phase != null) begin
			starting_phase.raise_objection(this, "Starting cpu_base_sequence");
		end
	endtask

	//post-body: runs after main sequence 
	virtual task post_body();
		if (starting_phase != null )begin 
			starting_phase.drop_objection(this, "Finishing cpu_base_sequence");
		end
	endtask 

endclass
// A sequence that sends a fixed array of instructions
class cpu_program_sequence extends cpu_base_sequence;
  `uvm_object_utils(cpu_program_sequence)

  // Set this before calling start()
  bit [31:0] instructions [];

  function new(string name = "cpu_program_sequence");
    super.new(name);
  endfunction

  virtual task body();
    cpu_seq_item req;

    foreach (instructions[i]) begin
      req = cpu_seq_item::type_id::create($sformatf("req_%0d", i));
      start_item(req);
      req.instruction        = instructions[i];
      req.read_data          = 0;
      req.timer_interrupt    = 0;
      req.software_interrupt = 0;
      req.external_interrupt = 0;
      finish_item(req);

      `uvm_info(get_type_name(),
        $sformatf("Sent [%0d] PC=0x%08h INSTR=0x%08h", i, i*4, instructions[i]),
        UVM_MEDIUM)
    end
  endtask

endclass
`endif 
