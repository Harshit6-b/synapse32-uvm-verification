`ifndef CPU_TEST_SV
`define CPU_TEST_SV

class cpu_base_test extends uvm_test;
  `uvm_component_utils(cpu_base_test)

  cpu_env env;

  function new(string name = "cpu_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = cpu_env::type_id::create("env", this);
    `uvm_info(get_type_name(), "Base test build phase complete", UVM_MEDIUM)
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "cpu_base_test started");
    `uvm_info(get_type_name(), "Base test run phase - no sequences to run", UVM_LOW)
    phase.drop_objection(this, "cpu_base_test finished");
  endtask

endclass


// NOP TEST — sends 10 NOPs, observes fetch pipeline
class cpu_nop_test extends cpu_base_test;
  `uvm_component_utils(cpu_nop_test)

  function new(string name = "cpu_nop_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    cpu_program_sequence seq;
    bit [31:0] ref_prog [bit[31:0]];

    phase.raise_objection(this, "cpu_nop_test started");
    `uvm_info(get_type_name(), "=== NOP TEST STARTED ===", UVM_LOW)

    seq = cpu_program_sequence::type_id::create("nop_seq");
    seq.instructions = new[10];
    for (int i = 0; i < 10; i++) begin
      seq.instructions[i] = 32'h00000013;
      ref_prog[i*4]        = 32'h00000013;
    end

    env.scoreboard.load_program(ref_prog);
    seq.start(env.agent.sequencer);

    #200;
    `uvm_info(get_type_name(), "=== NOP TEST COMPLETE ===", UVM_LOW)
    phase.drop_objection(this, "cpu_nop_test finished");
  endtask

endclass


// ALU TEST — ADDI, ADD, SUB, AND, OR with expected vs actual register check
class cpu_alu_test extends cpu_base_test;
  `uvm_component_utils(cpu_alu_test)

  function new(string name = "cpu_alu_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    cpu_program_sequence seq;
    bit [31:0] ref_prog [bit[31:0]];

    phase.raise_objection(this, "cpu_alu_test started");
    `uvm_info(get_type_name(), "=== ALU TEST STARTED ===", UVM_LOW)

    seq = cpu_program_sequence::type_id::create("alu_seq");
    seq.instructions = new[6];
    seq.instructions[0] = 32'h00500093; // ADDI x1, x0, 5   → x1 = 5
    seq.instructions[1] = 32'h00A00113; // ADDI x2, x0, 10  → x2 = 10
    seq.instructions[2] = 32'h002081B3; // ADD  x3, x1, x2  → x3 = 15
    seq.instructions[3] = 32'h40208233; // SUB  x4, x2, x1  → x4 = -5
    seq.instructions[4] = 32'h0020F2B3; // AND  x5, x1, x2  → x5 = 0
    seq.instructions[5] = 32'h0020E333; // OR   x6, x1, x2  → x6 = 15

    foreach (seq.instructions[i])
      ref_prog[i*4] = seq.instructions[i];
    env.scoreboard.load_program(ref_prog);

    // Golden reference — what the CPU SHOULD produce
    env.scoreboard.expected_test_name = "ALU TEST";
    env.scoreboard.expected_rf[1] = 32'h00000005; // x1 = 5
    env.scoreboard.expected_rf[2] = 32'h0000000A; // x2 = 10
    env.scoreboard.expected_rf[3] = 32'h0000000F; // x3 = 15
    env.scoreboard.expected_rf[4] = 32'hFFFFFFFB; // x4 = 5  (SUB 10-5)
    env.scoreboard.expected_rf[5] = 32'h00000000; // x5 = 0  (AND 5&10)
    env.scoreboard.expected_rf[6] = 32'h0000000F; // x6 = 15 (OR  5|10)

    seq.start(env.agent.sequencer);
    #200;

    // This is what proves correctness — expected vs actual side by side
    env.scoreboard.check_expected_registers();

    `uvm_info(get_type_name(), "=== ALU TEST COMPLETE ===", UVM_LOW)
    env.scoreboard.dump_reference_state();
    phase.drop_objection(this, "cpu_alu_test finished");
  endtask

endclass  // ← only ONE endclass here, the stray second one is removed

class cpu_fibonacci_test extends cpu_base_test;
  `uvm_component_utils(cpu_fibonacci_test)

  function new(string name = "cpu_fibonacci_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    cpu_program_sequence seq;
    bit [31:0] ref_prog [bit[31:0]];

    phase.raise_objection(this, "cpu_fibonacci_test started");
    `uvm_info(get_type_name(), "=== FIBONACCI TEST STARTED ===", UVM_LOW)

    seq = cpu_program_sequence::type_id::create("fib_seq");
    seq.instructions = new[9];  // one extra instruction

	// ADDI x1, x0, 1       → x1 = 1
	seq.instructions[0] = 32'h00100093;
	// ADDI x2, x0, 1       → x2 = 1
	seq.instructions[1] = 32'h00100113;
	// ADDI x3, x0, 6       → x3 = 6 (loop counter)
	seq.instructions[2] = 32'h00600193;
	// ADD  x4, x1, x2      → x4 = x1 + x2  (next fib)
	seq.instructions[3] = 32'h00208233;
	// ADD  x5, x0, x2      → x5 = x2  (save old x2 before overwriting)
	seq.instructions[4] = 32'h00010293;  // ADDI x5, x2, 0  → x5 = x2 (save old x2)
	seq.instructions[5] = 32'h00400133;  // ADD  x2, x0, x4 → x2 = x4 (keep this)
	seq.instructions[6] = 32'h00028093;  // ADDI x1, x5, 0  → x1 = x5 (restore old x2)
	seq.instructions[7] = 32'hFFF18193;  // ADDI x3, x3, -1 (keep this)
	seq.instructions[8] = 32'hFE0196E3;  // BNE  x3, x0, -20 (fixed offset)

    foreach (seq.instructions[i])
      ref_prog[i*4] = seq.instructions[i];
    env.scoreboard.load_program(ref_prog);

    env.scoreboard.expected_test_name = "FIBONACCI TEST";
    env.scoreboard.expected_rf[1] = 32'h0000000D; // x1 = 13 = F(7)
    env.scoreboard.expected_rf[2] = 32'h00000015; // x2 = 21 = F(8)
    env.scoreboard.expected_rf[3] = 32'h00000000; // x3 = 0  (loop done)
    env.scoreboard.expected_rf[4] = 32'h00000015; // x4 = 21 (last sum)

    seq.start(env.agent.sequencer);
    #500;

    env.scoreboard.check_expected_registers();
    `uvm_info(get_type_name(), "=== FIBONACCI TEST COMPLETE ===", UVM_LOW)
    env.scoreboard.dump_reference_state();
    phase.drop_objection(this, "cpu_fibonacci_test finished");
  endtask

endclass

// STORE TEST — SW, SH, SB with expected memory verification
class cpu_memory_test extends cpu_base_test;
  `uvm_component_utils(cpu_memory_test)

  function new(string name = "cpu_memory_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    cpu_program_sequence seq;
    bit [31:0] ref_prog [bit[31:0]];

    phase.raise_objection(this, "cpu_memory_test started");
    `uvm_info(get_type_name(), "=== MEMORY TEST STARTED ===", UVM_LOW)

    seq = cpu_program_sequence::type_id::create("mem_seq");
    seq.instructions = new[21];

    // --- Register setup ---
    // ADDI x1, x0, 256       → x1 = 0x100 (base address)
    seq.instructions[0] = 32'h10000093;
    // LUI x2 , 0x12345        → x2 = 0x12345000
    seq.instructions[1] = 32'h12345137;
     // ADDI x2, x2, 0x678   → x2 = 0x12345678  (word test value)
    seq.instructions[2] = 32'h67810113;
    // LUI  x4, 1           → x4 = 0x00001000
    seq.instructions[3] = 32'h00001237;
    // ADDI x4, x4, 0x234   → x4 = 0x00001234  (halfword test value)
    seq.instructions[4] = 32'h23420213;
    // ADDI x6, x0, 66      → x6 = 0x42        (byte test value)
    seq.instructions[5] = 32'h04200313;

    
        // SW x2, 0(x1)
    seq.instructions[6]  = 32'h0020A023;
    // NOP (let store complete)
    seq.instructions[7]  = 32'h00000013;
    // NOP
    seq.instructions[8]  = 32'h00000013;
    // LW x3, 0(x1)
    seq.instructions[9]  = 32'h0000A183;

    // SH x4, 4(x1)
    seq.instructions[10] = 32'h0040A223;
    // NOP
    seq.instructions[11] = 32'h00000013;
    // NOP
    seq.instructions[12] = 32'h00000013;
    // LH x5, 4(x1)
    seq.instructions[13] = 32'h0040A283;

    // SB x6, 8(x1)
    seq.instructions[14] = 32'h0060A423;
    // NOP
    seq.instructions[15] = 32'h00000013;
    // NOP
    seq.instructions[16] = 32'h00000013;
    // LB x7, 8(x1)
    seq.instructions[17] = 32'h0080A383;

    // flush NOPs
    seq.instructions[18] = 32'h00000013;
    seq.instructions[19] = 32'h00000013;
    seq.instructions[20] = 32'h00000013;

    foreach (seq.instructions[i])
      ref_prog[i*4] = seq.instructions[i];
    env.scoreboard.load_program(ref_prog);

    // ──  expected values ────────────────────────────────
    env.scoreboard.expected_test_name = "MEMORY TEST";

    // Register setup results
    env.scoreboard.expected_rf[1] = 32'h00000100; // x1 = 256
    env.scoreboard.expected_rf[2] = 32'h12345678; // x2 = word value
    env.scoreboard.expected_rf[4] = 32'h00001234; // x4 = halfword value
    env.scoreboard.expected_rf[6] = 32'h00000042; // x6 = byte value

    // Load results — these prove store+load round trip worked
    env.scoreboard.expected_rf[3] = 32'h12345678; // x3 = LW → must match SW
    env.scoreboard.expected_rf[5] = 32'h00001234; // x5 = LH → must match SH
    env.scoreboard.expected_rf[7] = 32'h00000042; // x7 = LB → must match SB

    seq.start(env.agent.sequencer);
    #300;  // extra time for memory ops through pipeline

    env.scoreboard.check_expected_registers();
    `uvm_info(get_type_name(), "=== MEMORY TEST COMPLETE ===", UVM_LOW)
    env.scoreboard.dump_reference_state();
    phase.drop_objection(this, "cpu_memory_test finished");
  endtask

endclass

`endif
