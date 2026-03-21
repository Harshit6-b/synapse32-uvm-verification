`ifndef CPU_MONITOR_ITEM_SV
`define CPU_MONITOR_ITEM_SV

//transaction types observed by monitor
typedef enum {
	INSTR_FETCH,
	MEM_READ,
	MEM_WRITE,
	INTERRUPT
} transaction_type_e;
class cpu_monitor_item extends uvm_sequence_item;
	
	transaction_type_e transaction_type;
	time timestamp;
	
	//instruction fetch fields
	bit [31:0] pc;
	bit [31:0] instruction;
	
	//memory operation field
	bit [31:0] addr;
	bit [31:0] data;
	bit [3:0] byte_enable;
	bit [2:0] load_type;
	
	//interrupt fields
	bit [2:0] interrupt_type;
	
	//uvm automation 
	`uvm_object_utils_begin(cpu_monitor_item)
    		`uvm_field_enum(transaction_type_e, transaction_type, UVM_ALL_ON)
    		`uvm_field_int(timestamp, UVM_ALL_ON | UVM_TIME)
    		`uvm_field_int(pc, UVM_ALL_ON | UVM_HEX)
    		`uvm_field_int(instruction, UVM_ALL_ON | UVM_HEX)
    		`uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
    		`uvm_field_int(data, UVM_ALL_ON | UVM_HEX)
    		`uvm_field_int(byte_enable, UVM_ALL_ON)
    		`uvm_field_int(load_type, UVM_ALL_ON)
    		`uvm_field_int(interrupt_type, UVM_ALL_ON)
  	`uvm_object_utils_end
  	
  	//constructor 
  	function new(string name = "cpu_monitor_item");
  		super.new(name);
  	endfunction
  	
  	function string convert2string();
    		string s;
    
   		 s = $sformatf("[@%0t] ", timestamp);
    
    		case (transaction_type)
     			 INSTR_FETCH: 
        			s = {s, $sformatf("FETCH PC=0x%08h INSTR=0x%08h", pc, instruction)};
      
      			MEM_READ:
       				 s = {s, $sformatf("LOAD addr=0x%08h data=0x%08h type=%0d",addr, data, load_type)};
      
      			MEM_WRITE:
        			s = {s, $sformatf("STORE addr=0x%08h data=0x%08h be=0b%04b", addr, data, byte_enable)};
      
      			INTERRUPT:
        			s = {s, $sformatf("IRQ [ext=%0b sw=%0b timer=%0b]", interrupt_type[2], interrupt_type[1], interrupt_type[0])};
    		endcase
    
    		return s;
  	endfunction
  
endclass

`endif 
  
