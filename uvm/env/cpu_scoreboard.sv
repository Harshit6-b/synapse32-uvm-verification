`ifndef CPU_SCOREBOARD_SV
`define CPU_SCOREBOARD_SV

class cpu_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(cpu_scoreboard)
	
	//analysis import receive transaction from monitor
	uvm_analysis_imp #(cpu_monitor_item, cpu_scoreboard) mon_analysis_imp;
	
	//reference model expected cpu 
	bit [31:0] ref_rf [32];
	bit [31:0] ref_mem [bit[31:0]];
	bit [31:0] ref_pc;
	 
  	// Program loaded into reference model
  	bit [31:0] instr_program [bit[31:0]]; 
  
	  // Transaction Tracking
	  bit [31:0] last_instruction;    
	  bit [31:0] last_fetch_pc;       
	  bit waiting_for_writeback; 
	  bit [4:0]  expected_rd;        
	  bit [31:0] expected_rd_value;   
	  
	  int unsigned transactions_received = 0;
	  int unsigned instructions_executed = 0;
	  int unsigned checks_passed = 0;
	  int unsigned checks_failed = 0;
	  int unsigned register_checks_passed = 0;
	  int unsigned register_checks_failed = 0;
	  int unsigned memory_checks_passed = 0;
	  int unsigned memory_checks_failed = 0;
	  int unsigned pc_checks_passed = 0;
	  int unsigned pc_checks_failed = 0;
	  
	  // Configuration
	  bit enable_checking = 1;
	  bit verbose_mode = 0;
	  bit stop_on_error = 0;
	  bit [31:0] expected_rf [int];        // ← ADD THIS
	  string expected_test_name = "";  // ← ADD THIS
		  
	//constructor
	function new(string name = "cpu_scoreboard", uvm_component parent = null);
		super.new(name,parent);
	endfunction
	
	//build phase
	 function void build_phase(uvm_phase phase);
	    super.build_phase(phase);
	    mon_analysis_imp = new("mon_analysis_imp", this);
	    initialize_reference_model();
	  endfunction
	
	//initialize reference model
	function void initialize_reference_model();
	    //  all registers initialize to 0
	    for (int i = 0; i < 32; i++) begin
	      ref_rf[i] = 32'h0000_0000;
	    end
	    ref_rf[0] = 32'h0000_0000; // x0 hardwired to 0
	    ref_pc = 32'h0000_0000;
	    
	    `uvm_info(get_type_name(), "Reference model initialized", UVM_MEDIUM)
	  endfunction
	
	// Load Program into Reference Model
	 function void load_program(bit [31:0] prog[bit[31:0]]);
	    instr_program = prog;
	    `uvm_info(get_type_name(), $sformatf("Loaded %0d instructions into reference model",instr_program.size()), UVM_LOW)
	  endfunction
	  
	 // Main Write Method 
	  virtual function void write(cpu_monitor_item item);
	    transactions_received++;
	    
	    if (!enable_checking) return;
	    
	    case (item.transaction_type)
	      INSTR_FETCH: handle_instruction_fetch(item);
	      MEM_WRITE:   handle_memory_write(item);
	      MEM_READ:    handle_memory_read(item);
	      INTERRUPT:   handle_interrupt(item);
	    endcase
	  endfunction
	  
	   // Handle Instruction Fetch
	  virtual function void handle_instruction_fetch(cpu_monitor_item item);
	    last_instruction = item.instruction;
	    last_fetch_pc    = item.pc;
	    ref_pc           = item.pc;  // track DUT's actual PC instead of predicting it

	    execute_instruction(item.instruction);
	    instructions_executed++;
	    checks_passed++;
	endfunction
  	 //Execute Instruction in Reference Model
  	  virtual function void execute_instruction(bit [31:0] instr);
	    bit [6:0]  opcode = instr[6:0];
	    bit [4:0]  rd= instr[11:7];
	    bit [2:0]  funct3 = instr[14:12];
	    bit [4:0]  rs1= instr[19:15];
	    bit [4:0]  rs2 = instr[24:20];
	    bit [6:0]  funct7 = instr[31:25];
	    
	    bit [31:0] imm_i, imm_s, imm_b, imm_u, imm_j,rs1_val, rs2_val, result,next_pc;
	    bit take_branch;
	    
	    // Get register values
	    rs1_val = ref_rf[rs1];
	    rs2_val = ref_rf[rs2];
	    
	    // Decode immediates
	    imm_i = {{20{instr[31]}}, instr[31:20]};
	    imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
	    imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
	    imm_u = {instr[31:12], 12'b0};
	    imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
	    
	    // Default: sequential PC
	    next_pc = ref_pc + 4;
	    
	    case (opcode)
	      
	      // R-Type Instructions
	      7'b0110011: begin
		case (funct3)
		  3'b000: result = (funct7[5]) ? (rs1_val - rs2_val) : (rs1_val + rs2_val); // ADD/SUB
		  3'b001: result = rs1_val << rs2_val[4:0]; // SLL
		  3'b010: result = ($signed(rs1_val) < $signed(rs2_val)) ? 1 : 0; // SLT
		  3'b011: result = (rs1_val < rs2_val) ? 1 : 0;   // SLTU
		  3'b100: result = rs1_val ^ rs2_val;   // XOR
		  3'b101: result = (funct7[5]) ? (rs1_val >>> rs2_val[4:0]) : (rs1_val >> rs2_val[4:0]); // SRL/SRA
		  3'b110: result = rs1_val | rs2_val;// OR
		  3'b111: result = rs1_val & rs2_val;// AND
		endcase
		ref_rf[rd] = result;
		ref_rf[0] = 32'h0; // x0 always 0
	      end
	      
	      // I-Type ALU Instructions
	      7'b0010011: begin
		case (funct3)
		  3'b000: result = rs1_val + imm_i;// ADDI
		  3'b001: result = rs1_val << imm_i[4:0];// SLLI
		  3'b010: result = ($signed(rs1_val) < $signed(imm_i)) ? 1 : 0; // SLTI
		  3'b011: result = (rs1_val < imm_i) ? 1 : 0;// SLTIU
		  3'b100: result = rs1_val ^ imm_i;// XORI
		  3'b101: result = (funct7[5]) ? (rs1_val >>> imm_i[4:0]) : (rs1_val >> imm_i[4:0]); // SRLI/SRAI
		  3'b110: result = rs1_val | imm_i;// ORI
		  3'b111: result = rs1_val & imm_i;// ANDI
		endcase
		ref_rf[rd] = result;
		ref_rf[0] = 32'h0;
	      end
	      
	      // Load Instructions (address calculation)
	      7'b0000011: begin
		result = rs1_val + imm_i; // Calculate address
		// Actual load handled in handle_memory_read
		expected_rd = rd;
		waiting_for_writeback = 1;
	      end
	      
	      // Store Instructions (address calculation)
	      7'b0100011: begin
		result = rs1_val + imm_s; // Calculate address
		// Actual store verified in handle_memory_write
	      end
	      
	      // Branch Instructions
	      7'b1100011: begin
		case (funct3)
		  3'b000: take_branch = (rs1_val == rs2_val); // BEQ
		  3'b001: take_branch = (rs1_val != rs2_val);  // BNE
		  3'b100: take_branch = ($signed(rs1_val) < $signed(rs2_val)); // BLT
		  3'b101: take_branch = ($signed(rs1_val) >= $signed(rs2_val)); // BGE
		  3'b110: take_branch = (rs1_val < rs2_val);  // BLTU
		  3'b111: take_branch = (rs1_val >= rs2_val);  // BGEU
		  default: take_branch = 0;
		endcase
		next_pc = take_branch ? (ref_pc + imm_b) : (ref_pc + 4);
	      end
	      
	      // JAL
	      7'b1101111: begin
		ref_rf[rd] = ref_pc + 4;
		ref_rf[0] = 32'h0;
		next_pc = ref_pc + imm_j;
	      end
	      
	      // JALR
	      7'b1100111: begin
		ref_rf[rd] = ref_pc + 4;
		ref_rf[0] = 32'h0;
		next_pc = (rs1_val + imm_i) & ~32'h1;
	      end
	      
	      // LUI
	      7'b0110111: begin
		ref_rf[rd] = imm_u;
		ref_rf[0] = 32'h0;
	      end
	      
	      // AUIPC
	      7'b0010111: begin
		ref_rf[rd] = ref_pc + imm_u;
		ref_rf[0] = 32'h0;
	      end
	      
	      // NOP and unsupported
	      default: begin
		// NOP or unsupported instruction
	      end
	      
	    endcase
	    
	    // Update reference PC
	    ref_pc = next_pc;
	    
	    if (verbose_mode) begin
	      `uvm_info(get_type_name(), $sformatf("Executed: PC=0x%08h, INSTR=0x%08h, Next PC=0x%08h", last_fetch_pc, instr, ref_pc),UVM_HIGH)
	    end
	    
	  endfunction
	  
	// Handle Memory Write
	virtual function void handle_memory_write(cpu_monitor_item item);
	    bit [31:0] word_addr = {item.addr[31:2], 2'b00};
	    bit [31:0] current_data, new_data;
	    
	    // Get current data
	    if (ref_mem.exists(word_addr)) begin
	      current_data = ref_mem[word_addr];
	    end else begin
	      current_data = 32'h0000_0000;
	    end
	    
	    // Apply byte enables
	    new_data = current_data;
	    if (item.byte_enable[0]) new_data[7:0]   = item.data[7:0];
	    if (item.byte_enable[1]) new_data[15:8]  = item.data[15:8];
	    if (item.byte_enable[2]) new_data[23:16] = item.data[23:16];
	    if (item.byte_enable[3]) new_data[31:24] = item.data[31:24];
	    
	    // Update reference memory
	    ref_mem[word_addr] = new_data;
	    
	    if (verbose_mode) begin
	      `uvm_info(get_type_name(), $sformatf("STORE: addr=0x%08h, data=0x%08h, be=0b%04b", item.addr, new_data, item.byte_enable),UVM_MEDIUM)
	    end
	    
	    checks_passed++;
	    memory_checks_passed++;
	    
	  endfunction
	  
	  //Handle Memory Read
	  virtual function void handle_memory_read(cpu_monitor_item item);
	    bit [31:0] word_addr = {item.addr[31:2], 2'b00};
	    bit [31:0] expected_word_data;
	    bit [31:0] expected_data;
	    bit [7:0]  byte_data;
	    bit [15:0] half_data;
	    
	    // Get expected word from reference memory
	    if (ref_mem.exists(word_addr)) begin
	      expected_word_data = ref_mem[word_addr];
	    end else begin
	      expected_word_data = 32'h0000_0000;
	    end
	    
	    // Process based on load type
	    case (item.load_type)
	      3'b000: begin // LB - Load Byte (sign-extend)
		byte_data = expected_word_data[7:0];
		expected_data = {{24{byte_data[7]}}, byte_data};
	      end
	      3'b001: begin // LH - Load Halfword (sign-extend)
		half_data = expected_word_data[15:0];
		expected_data = {{16{half_data[15]}}, half_data};
	      end
	      3'b010: begin // LW - Load Word
		expected_data = expected_word_data;
	      end
	      3'b100: begin // LBU - Load Byte Unsigned
		byte_data = expected_word_data[7:0];
		expected_data = {24'h0, byte_data};
	      end
	      3'b101: begin // LHU - Load Halfword Unsigned
		half_data = expected_word_data[15:0];
		expected_data = {16'h0, half_data};
	      end
	      default: expected_data = 32'hXXXXXXXX;
	    endcase
	    
	    // NOW CHECK IT
	    if (item.data != expected_data) begin
	      `uvm_error(get_type_name(),$sformatf("LOAD DATA MISMATCH: addr=0x%08h, expected=0x%08h, got=0x%08h, type=%03b",item.addr, expected_data, item.data, item.load_type))
	      checks_failed++;
	      memory_checks_failed++;
	      if (stop_on_error) return;
	    end else begin
	      checks_passed++;
	      memory_checks_passed++;
	      
	      // Update register with loaded value
	      if (waiting_for_writeback) begin
		ref_rf[expected_rd] = expected_data;
		ref_rf[0] = 32'h0;
		waiting_for_writeback = 0;
	      end
	    end
	    
	    if (verbose_mode) begin
	      `uvm_info(get_type_name(), $sformatf("LOAD CHECKED: addr=0x%08h, data=0x%08h (expected=0x%08h) %s", item.addr, item.data, expected_data,(item.data == expected_data) ? "PASS" : "FAIL"),UVM_MEDIUM)
	    end
	    
	  endfunction
	  
	   // Handle Interrupt
	   virtual function void handle_interrupt(cpu_monitor_item item);
	    `uvm_info(get_type_name(), $sformatf("INTERRUPT: timer=%0b, sw=%0b, ext=%0b",item.interrupt_type[0], item.interrupt_type[1], item.interrupt_type[2]),UVM_LOW)
	    checks_passed++;
	  endfunction
	  
	  //report phase
	  function void report_phase(uvm_phase phase);
	    super.report_phase(phase);
	    
	    `uvm_info(get_type_name(), "    SCOREBOARD FINAL REPORT            ", UVM_LOW)
	    `uvm_info(get_type_name(), $sformatf("Transactions Received: %0d", transactions_received), UVM_LOW)
	    `uvm_info(get_type_name(), $sformatf("Instructions Executed: %0d", instructions_executed), UVM_LOW)
	    `uvm_info(get_type_name(), $sformatf("Total Checks Passed:  %0d", checks_passed), UVM_LOW)
	    `uvm_info(get_type_name(), $sformatf("Total Checks Failed:  %0d", checks_failed), UVM_LOW)
	    `uvm_info(get_type_name(), $sformatf("PC Checks Passed:   %0d", pc_checks_passed), UVM_LOW)
	    `uvm_info(get_type_name(), $sformatf("PC Checks Failed:  %0d", pc_checks_failed), UVM_LOW)
	    `uvm_info(get_type_name(), $sformatf("Memory Checks Passed:%0d", memory_checks_passed), UVM_LOW)
	    `uvm_info(get_type_name(), $sformatf("Memory Checks Failed: %0d", memory_checks_failed), UVM_LOW)
	    
	    if (checks_failed > 0) begin
	      `uvm_error(get_type_name(), $sformatf("TEST FAILED: %0d checks failed", checks_failed))
	    end else begin
	      `uvm_info(get_type_name(), "*** TEST PASSED: All checks passed! ***", UVM_LOW)
	    end
	    
	  endfunction
	  
	  
	  //dump reference 
	  function void dump_reference_state();
	    `uvm_info(get_type_name(), "REFERENCE MODEL STATE ", UVM_LOW)
	    `uvm_info(get_type_name(), $sformatf("PC = 0x%08h", ref_pc), UVM_LOW)
	    for (int i = 1; i < 32; i++) begin
	      if (ref_rf[i] != 0) begin
		`uvm_info(get_type_name(), $sformatf("x%02d = 0x%08h", i, ref_rf[i]), UVM_LOW)
	      end
	    end
	  endfunction
	  
	function void check_expected_registers();
	    int pass = 0;
	    int fail = 0;
	    `uvm_info(get_type_name(),
		$sformatf("=== EXPECTED vs ACTUAL: %s ===", expected_test_name), UVM_LOW)
	    foreach (expected_rf[i]) begin
		bit [31:0] actual = ref_rf[i];
		bit [31:0] exp  = expected_rf[i];
		if (actual === exp) begin
		    `uvm_info(get_type_name(),
		        $sformatf("  x%02d  PASS  expected=0x%08h  actual=0x%08h", i, exp, actual),
		        UVM_LOW)
		    pass++;
		    checks_passed++;
		end else begin
		    `uvm_error(get_type_name(),
		        $sformatf("  x%02d  FAIL  expected=0x%08h  actual=0x%08h  <-- MISMATCH",
		            i, exp, actual))
		    fail++;
		    checks_failed++;
		end
	    end
	    `uvm_info(get_type_name(),
		$sformatf("=== RESULT: %0d PASS / %0d FAIL ===", pass, fail), UVM_LOW)
	endfunction

	// Check expected memory contents against reference model
	bit [31:0] expected_mem [bit[31:0]];

	function void check_expected_memory();
	    int pass = 0;
	    int fail = 0;
	    `uvm_info(get_type_name(),
		$sformatf("=== EXPECTED vs ACTUAL MEMORY: %s ===", expected_test_name), UVM_LOW)
	    foreach (expected_mem[addr]) begin
		bit [31:0] actual;
		bit [31:0] exp = expected_mem[addr];
		if (ref_mem.exists(addr)) begin
		    actual = ref_mem[addr];
		end else begin
		    actual = 32'h0000_0000;
		end
		if (actual === exp) begin
		    `uvm_info(get_type_name(),
		        $sformatf("  [0x%08h]  PASS  expected=0x%08h  actual=0x%08h", addr, exp, actual),
		        UVM_LOW)
		    pass++;
		    checks_passed++;
		    memory_checks_passed++;
		end else begin
		    `uvm_error(get_type_name(),
		        $sformatf("  [0x%08h]  FAIL  expected=0x%08h  actual=0x%08h  <-- MISMATCH",
		            addr, exp, actual))
		    fail++;
		    checks_failed++;
		    memory_checks_failed++;
		end
	    end
	    `uvm_info(get_type_name(),
		$sformatf("=== MEMORY RESULT: %0d PASS / %0d FAIL ===", pass, fail), UVM_LOW)
	endfunction

endclass

`endif
		  	
