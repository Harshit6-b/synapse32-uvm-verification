`ifndef CPU_MONITOR_SV
`define CPU_MONITOR_SV

class cpu_monitor extends uvm_monitor;

	`uvm_component_utils(cpu_monitor)
	virtual synapse32_if vif;
	
	//port sends observed transactions to scoreboard
	uvm_analysis_port #(cpu_monitor_item)mon_analysis_port;
	
	//statics what dut does
	int unsigned instructions_fetched = 0;
	int unsigned memory_reads = 0;
	int unsigned memory_writes = 0;
	int unsigned interrupts_seen =0;
	
	//constructor
	function new (string name = "cpu_monitor", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		//get virtual interface
		if (!uvm_config_db#(virtual synapse32_if)::get(this,"","vif",vif)) begin
			`uvm_fatal(get_type_name(), "Failed to get virtual interface from config DB")
		end
		
		//create analysis port 
		mon_analysis_port = new("mon_analysis_port", this);
		
		`uvm_info(get_type_name(), "Monitor build phase complete", UVM_MEDIUM) 
	
	endfunction
	
	//run phase main monitoring activity
	
	task run_phase(uvm_phase phase);
		`uvm_info(get_type_name(), "Staring monitor run phase", UVM_LOW)
		
		fork
			monitor_instruction_fetch();
			monitor_memory_operations();
			monitor_interrupts();
		join_none
	
	endtask
	
	//monitor instruction fetches
	task monitor_instruction_fetch();
		cpu_monitor_item item;
		
		forever begin 
			@(vif.monitor_cb);
			
			//detect instruction fetch by pc changes or valid instruction present
			if(vif.module_instr_in != 32'h0000_0013 || vif.module_pc_out != 0) begin
			
        			item = cpu_monitor_item::type_id::create("item");
        			item.transaction_type = INSTR_FETCH;
        			item.pc = vif.module_pc_out;
        			item.instruction = vif.module_instr_in;
        			item.timestamp = $time;
        
        			instructions_fetched++;
        
        			`uvm_info(get_type_name(),$sformatf("FETCH: PC=0x%08h, INSTR=0x%08h", item.pc, item.instruction),UVM_HIGH)
        
        			// Send to scoreboard via analysis port
        			mon_analysis_port.write(item);
      			end
   		 end
  	endtask
	
	
	// monitor memory operations
	task monitor_memory_operations();
		cpu_monitor_item item;
		
		forever begin
			@(vif.monitor_cb);
			
			//detect memory write
			if (vif.module_mem_wr_en) begin
				item = cpu_monitor_item::type_id::create("item");
				item.transaction_type = MEM_WRITE;
				item.addr = vif.module_write_addr;
				item.data = vif.module_wr_data_out;
				item.byte_enable = vif.module_write_byte_enable;
				item.timestamp = $time;
				
				memory_writes++;
				
        			`uvm_info(get_type_name(),$sformatf("STORE: addr=0x%08h, data=0x%08h, be=0b%04b",item.addr, item.data, item.byte_enable),UVM_MEDIUM)
        
        			mon_analysis_port.write(item);
			end
     			//detect memory read
     			if(vif.module_mem_rd_en) begin
     				item = cpu_monitor_item::type_id::create("item");
     				item.transaction_type = MEM_READ;
     				item.addr = vif.module_read_addr;
     				item.data = vif.module_read_data_in;
     				item.load_type = vif.module_load_type;
     				item.timestamp = $time;
     				
     				memory_reads++;
     				
     				 `uvm_info(get_type_name(),$sformatf("LOAD: addr=0x%08h, data=0x%08h, type=%0d", item.addr, item.data, item.load_type),UVM_MEDIUM)
        
        			mon_analysis_port.write(item);
      			end
    		end
  	endtask
  	
  	//monitor interrupts
  	task monitor_interrupts();
  		cpu_monitor_item item;
  		forever begin 
  			@(vif.monitor_cb);
  			
  			//detect interrupt assertion
  			if (vif.timer_interrupt || vif.software_interrupt ||vif.external_interrupt) begin
  			
  				item = cpu_monitor_item::type_id::create("item");
        			item.transaction_type = INTERRUPT;
        			item.interrupt_type = {vif.external_interrupt, vif.software_interrupt, vif.timer_interrupt};
        			item.timestamp = $time;
        
        			interrupts_seen++;
     				
     				`uvm_info(get_type_name(),$sformatf("INTERRUPT: timer=%0b, sw=%0b, ext=%0b",vif.timer_interrupt, vif.software_interrupt,vif.external_interrupt),UVM_LOW)
        
        			mon_analysis_port.write(item);
      			end
    		end
  	endtask

	//report phase 
	function void report_phase(uvm_phase phase);
    		super.report_phase(phase);
    
    		`uvm_info(get_type_name(), "=== MONITOR STATISTICS ===", UVM_LOW)
    		`uvm_info(get_type_name(), $sformatf("Instructions Fetched: %0d", instructions_fetched), UVM_LOW)
    		`uvm_info(get_type_name(), $sformatf("Memory Reads:   %0d", memory_reads), UVM_LOW)
    		`uvm_info(get_type_name(), $sformatf("Memory Writes:   %0d", memory_writes), UVM_LOW)
    		`uvm_info(get_type_name(), $sformatf("Interrupts Seen:   %0d", interrupts_seen), UVM_LOW)
  	endfunction
  
endclass

`endif 
     			
