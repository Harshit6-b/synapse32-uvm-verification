`ifndef CPU_DRIVER_SV
`define CPU_DRIVER_SV

class cpu_driver extends uvm_driver #(cpu_seq_item);
	`uvm_component_utils(cpu_driver)

	//virtual interface to dut
	virtual synapse32_if vif;

	//memory models
	bit [31:0] instr_mem [bit[31:0]];
	bit [31:0] data_mem[bit[31:0]];

	//configuration
	int unsigned program_length;
	bit [31:0] start_pc = 32'h0000_0000;

	//statistics 
	int unsigned instructions_loaded = 0;

	//constructor
	function new(string name = "cpu_driver", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	//build phase - get virtual interface
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		if (!uvm_config_db#(virtual synapse32_if)::get(this, "","vif", vif)) begin
			`uvm_fatal(get_type_name(), "Failed to get virtual interface from config DB")
		end
		
		`uvm_info(get_type_name(), "Driver build phase complete", UVM_MEDIUM)
	endfunction

	//connect phase 
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		//initialize some default memory values
		initialize_data_memory();
		
		`uvm_info(get_type_name(), "Driver connect phase complete", UVM_MEDIUM)
	endfunction

	//run phase 
	task run_phase(uvm_phase phase);
		
		`uvm_info(get_type_name(), "Starting driver run phase", UVM_LOW)
		
		//Fork parallel process
		fork
			handle_instruction_fetch(); //must respond to fetch requests
			handle_data_memory(); // must respond to memory operrations
			monitor_activity(); //driver stats (optional)
		join_none  //don't wait - let phase objections control lifetime

		//instruction loading runs in foreground 
		//blocks until all sequences complete , then exits naturally 
		drive_instructions();

		`uvm_info(get_type_name(), "Driver: All instructions loaded, memory servicing continues", UVM_MEDIUM)
	endtask

	//process 1 : drive instructions from sequences
	task drive_instructions();
		cpu_seq_item req;
		bit [31:0] current_pc;
		
		forever begin
			//get next sequence item from sequencer 
			seq_item_port.get_next_item(req);
			
			//determine pc for this instruction
			current_pc = start_pc + (instructions_loaded * 4);
			
			//load instruction into memory 
			instr_mem[current_pc] = req.instruction;

			instructions_loaded++;

			`uvm_info(get_type_name(), $sformatf("loaded instruction #%0d : PC=0x%08h, INSTR=0x%08h (%s)", instructions_loaded, current_pc, req.instruction, decode_instruction(req.instruction)),UVM_MEDIUM)

			//signal completion to sequencer
			seq_item_port.item_done();

			// optional : add small delay between instruction loads
			repeat(1) @(vif.driver_cb);
		end
	endtask

	// process 2: handle instruction fetch
	task handle_instruction_fetch();
		bit [31:0] fetch_addr;
		bit [31:0] fetch_data;

		forever begin 
			@(vif.driver_cb);
			fetch_addr = vif.module_pc_out;

			//checks if instrustion exists in memory 
			if (instr_mem.exists(fetch_addr)) begin
				fetch_data = instr_mem[fetch_addr];

				`uvm_info(get_type_name(),  $sformatf("IF: addr=0x%08h -> instr=0x%08h", fetch_addr, fetch_data),UVM_HIGH)
			end else begin
				// Return NOP (ADDI x0, x0, 0) for unmapped addresses
				fetch_data = 32'h0000_0013;
        
				`uvm_info(get_type_name(), $sformatf("IF: addr=0x%08h -> NOP (unmapped)", fetch_addr),UVM_HIGH)
			end
			
			//drive instruction data on next clock
			vif.driver_cb.module_instr_in <= fetch_data;
		end
	endtask

	//process 3: handle data memory operation
	// Replace the entire handle_data_memory task with this
// Replace the entire handle_data_memory task with this
	task handle_data_memory();
	    bit [31:0] mem_addr;
	    bit [31:0] mem_wdata;
	    bit [3:0]  byte_en;

	    forever begin
		@(vif.driver_cb);

		byte_en = vif.module_write_byte_enable;

		// ── Handle store ─────────────────────────────────────
		if (vif.module_mem_wr_en) begin
		    mem_addr  = vif.module_write_addr;
		    mem_wdata = vif.module_wr_data_out;
		    handle_store(mem_addr, mem_wdata, byte_en);
		end

		// ── Always drive read data every cycle ───────────────
		// The CPU latches module_read_data_in on the same cycle
		// it presents the address, so we must always have valid
		// data ready — not just when mem_rd_en is high.
		begin
		    automatic bit [31:0] rd_addr = vif.module_read_addr;
		    automatic bit [31:0] wa      = {rd_addr[31:2], 2'b00};
		    automatic bit [31:0] rd_data = data_mem.exists(wa) ? data_mem[wa] : 32'h0;

		    vif.module_read_data_in = rd_data;

		    if (vif.module_mem_rd_en)
		        `uvm_info(get_type_name(),
		            $sformatf("LOAD: addr=0x%08h data=0x%08h", rd_addr, rd_data),
		            UVM_MEDIUM)
		end
	    end
	endtask	//handle store operation with byte enable 
	function void handle_store(bit [31:0] addr, bit [31:0] wdata, bit [3:0] byte_en);
		bit [31:0] word_addr;
		bit [31:0] current_data;
		bit [31:0] new_data;
		
		//word-align address
		word_addr = {addr[31:2] , 2'b00};
		//get current data if it exists 
		if (data_mem.exists(word_addr)) begin
			current_data = data_mem[word_addr];
		end else begin
			current_data = 32'h0000_0000;
		end
		
		//apply byte enables
		new_data = current_data;
		if(byte_en[0]) new_data[7:0] = wdata[7:0];
		if(byte_en[1]) new_data[15:8] = wdata[15:8];
		if(byte_en[2]) new_data[23:16] = wdata[23:16];
		if(byte_en[3]) new_data[31:24] = wdata[31:24];
		
		//write to memory 
		data_mem[word_addr] = new_data;
		
		 `uvm_info(get_type_name(),
    $sformatf("DEBUG STORE: word_addr=0x%08h data_mem_size=%0d",
        word_addr, data_mem.num()), UVM_LOW)
	endfunction
	
	//handle load operations with byte enable
	function bit [31:0] handle_load(bit [31:0] addr, bit [3:0] byte_en);
		bit [31:0] word_addr;
		bit [31:0] word_data;
		bit [31:0] result;
		
		//word-align address
		word_addr = {addr[31:2], 2'b00};
		
		//get data from memory 
		if (data_mem.exists(word_addr)) begin
			word_data = data_mem[word_addr];
		end else begin
			word_data = 32'h0000_0000;
			`uvm_info(get_type_name(), $sformatf("LOAD from unmapped addr = 0x%08h, returning 0" , addr), UVM_HIGH)
		end
		
		//For simplicity , return full word 
		// (in real implementation, you'd handle LB, LH, LBU, LHU based on byte_en)
		result = word_data;
		
		`uvm_info(get_type_name(), $sformatf("LOAD: addr= 0x%08h",addr,result), UVM_MEDIUM)
		
		return result;
		
	endfunction
	
	//process 4 :monitor driver activity not dut activity 
	task monitor_activity();
		automatic int cycle_count =0 ;
		forever begin
			@(vif.driver_cb);
			cycle_count++;
			
			//report driver statistics every 1000 cycles
			if (cycle_count % 1000 == 0 ) begin
				`uvm_info(get_type_name(), $sformatf("Driver Activity: %0d cycles, %0d instructions loaded", cycle_count, instructions_loaded), UVM_LOW)
			end
		end
	endtask
	
	//helper : initialize data memory with test values 
	function void initialize_data_memory();
	    // Start with empty memory — tests will populate it via SW instructions
	    data_mem.delete();
	    `uvm_info(get_type_name(), "Data memory cleared", UVM_MEDIUM)
	endfunction
		
	// decode instruction fro logging 
	function string decode_instruction(bit [31:0] instr);
		bit [6:0] opcode;
		string result;
		
		opcode = instr[6:0];
		
		case (opcode)
			7'b0110011 : result = "R-TYPE";
			7'b0010011 : result = "I-TYPE";
			7'b0000011: result = "LOAD";
      			7'b0100011: result = "STORE";
      			7'b1100011: result = "BRANCH";
      			7'b1101111: result = "JAL";
      			7'b1100111: result = "JALR";
      			7'b0110111: result = "LUI";
      			7'b0010111: result = "AUIPC";
      			default:    result = "UNKNOWN";
      		endcase
      		
      		return result;
      	endfunction 
      	
      	//report phase
      	function void report_phase(uvm_phase phase);
    		super.report_phase(phase);
    
    		`uvm_info(get_type_name(), "=== DRIVER STATISTICS ===", UVM_LOW)
    		`uvm_info(get_type_name(), $sformatf("Instructions Loaded: %0d", instructions_loaded), UVM_LOW)
    		`uvm_info(get_type_name(), $sformatf("Instr Mem Size:      %0d entries", instr_mem.size()), UVM_LOW)
    		`uvm_info(get_type_name(), $sformatf("Data Mem Size:       %0d entries", data_mem.size()), UVM_LOW)
    		`uvm_info(get_type_name(), "Note: Memory read/write counts are in the monitor", UVM_LOW)
    	endfunction
  
endclass
`endif	
	
	
