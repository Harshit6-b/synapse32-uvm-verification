`ifndef CPU_SEQ_ITEM_SV
`define CPU_SEQ_ITEM_SV

class cpu_seq_item extends uvm_sequence_item;

	//first we make the wires that we need 
	//transaction fields
	//instruction memory response
	rand bit [31:0] instruction;

	//Data memory response
	rand bit [31:0] read_data;

	//Interrupts
	rand bit timer_interrupt;
	rand bit software_interrupt;
	rand bit external_interrupt;

	//constraints
	constraint defaults_no_interrupts{
		timer_interrupt == 0;
		software_interrupt == 0;
		external_interrupt ==0;
	}
	
	//now we register these wires as we will see the their info on the terminal so we need it
	//uvm automation marcos
	`uvm_object_utils_begin(cpu_seq_item)
		`uvm_field_int(instruction,UVM_ALL_ON)
		`uvm_field_int(read_data,UVM_ALL_ON)
		`uvm_field_int(timer_interrupt,UVM_ALL_ON)
		`uvm_field_int(software_interrupt,UVM_ALL_ON)
		`uvm_field_int(external_interrupt,UVM_ALL_ON)
	`uvm_object_utils_end

	//constructor claing the constructor for parent class
	function new(string name = "cpu_seq_item");
		super.new(name);
	endfunction
	
	function void set_instruction(bit [31:0] instr);
		instruction = instr;
	endfunction

	function void set_read_data(bit [31:0] data);
		read_data = data;
	endfunction 

	function void set_intterrupt(bit timer =0, bit sw = 0, bit ext = 0);
		timer_interrupt = timer;
		software_interrupt = sw;
		external_interrupt = ext;
	endfunction

	//convert to string for debugging
	 function string convert2string();
	    string s;
	    s = super.convert2string();
	    s = {s, $sformatf("\n  instruction     = 0x%08h", instruction)};
	    s = {s, $sformatf("\n  read_data       = 0x%08h", read_data)};
	    s = {s, $sformatf("\n  timer_interrupt = %0b", timer_interrupt)};
	    s = {s, $sformatf("\n  sw_interrupt    = %0b", software_interrupt)};
	    s = {s, $sformatf("\n  ext_interrupt   = %0b", external_interrupt)};
	    return s;
	endfunction
endclass

`endif //CPU_SEQ_ITEM_SV
