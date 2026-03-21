//==============================================================================
// cpu_fibonacci_sequence.sv
// Loads and runs a Fibonacci program on the Synapse32 RISC-V CPU
//
// RISC-V Assembly Program:
//
//   # Compute first 8 Fibonacci numbers
//   # Store results in memory starting at 0x2000
//
//   ADDI x1, x0, 0       # x1 = 0 (fib[0])
//   ADDI x2, x0, 1       # x2 = 1 (fib[1])
//   ADDI x3, x0, 8       # x3 = 8 (counter - how many to compute)
//   ADDI x4, x0, 0       # x4 = 0 (loop index)
//   LUI  x5, 0x2          # x5 = 0x2000 (base address for storing results)
//
// loop:
//   SW   x1, 0(x5)        # store current fib number to memory
//   ADD  x6, x1, x2       # x6 = x1 + x2 (next fib)
//   ADD  x1, x2, x0       # x1 = x2 (shift)
//   ADD  x2, x6, x0       # x2 = x6 (shift)
//   ADDI x4, x4, 1        # x4++ (increment index)
//   ADDI x5, x5, 4        # x5 += 4 (next memory address)
//   BNE  x4, x3, loop     # if x4 != x3, branch back to loop
//
// end:
//   NOP                   # done
//   NOP
//
// Expected results in memory (0x2000 onwards):
//   0x2000 = 0  (fib[0])
//   0x2004 = 1  (fib[1])
//   0x2008 = 1  (fib[2])
//   0x200C = 2  (fib[3])
//   0x2010 = 3  (fib[4])
//   0x2014 = 5  (fib[5])
//   0x2018 = 8  (fib[6])
//   0x201C = 13 (fib[7])
//==============================================================================

`ifndef CPU_FIBONACCI_SEQUENCE_SV
`define CPU_FIBONACCI_SEQUENCE_SV

class cpu_fibonacci_sequence extends cpu_base_sequence;
  `uvm_object_utils(cpu_fibonacci_sequence)

  function new(string name = "cpu_fibonacci_sequence");
    super.new(name);
  endfunction

  virtual task body();
    cpu_seq_item req;

    // ----------------------------------------------------------------
    // Fibonacci RISC-V machine code
    // Each entry: {pc_offset, instruction}
    // ----------------------------------------------------------------
    bit [31:0] fib_instructions [15];

    // ADDI x1, x0, 0      → x1 = 0
    fib_instructions[0]  = 32'h00000093;
    // ADDI x2, x0, 1      → x2 = 1
    fib_instructions[1]  = 32'h00100113;
    // ADDI x3, x0, 8      → x3 = 8 (loop count)
    fib_instructions[2]  = 32'h00800193;
    // ADDI x4, x0, 0      → x4 = 0 (index)
    fib_instructions[3]  = 32'h00000213;
    // LUI  x5, 0x2         → x5 = 0x2000 (store base address)
    fib_instructions[4]  = 32'h000022B7;

    // --- loop starts at PC 0x14 ---
    // SW   x1, 0(x5)       → mem[x5] = x1
    fib_instructions[5]  = 32'h0012A023;
    // ADD  x6, x1, x2      → x6 = x1 + x2
    fib_instructions[6]  = 32'h00208333;
    // ADD  x1, x2, x0      → x1 = x2
    fib_instructions[7]  = 32'h000100B3;
    // ADD  x2, x6, x0      → x2 = x6
    fib_instructions[8]  = 32'h00030133;
    // ADDI x4, x4, 1       → x4++
    fib_instructions[9]  = 32'h00120213;  // ADDI x4, x4, 1
    // ADDI x5, x5, 4       → x5 += 4
    fib_instructions[10] = 32'h00428293;
    // BNE  x4, x3, -28     → branch back to loop (offset = -28 = 0xFFFFFFE4)
    // BNE encoding: imm[12|10:5] rs2 rs1 001 imm[4:1|11] 1100011
    // offset = -28 = 0xFFFFFFE4
    // imm[12]=1, imm[11]=1, imm[10:5]=111111, imm[4:1]=0010
    fib_instructions[11] = 32'hFE321CE3;

    // --- end ---
    // NOP
    fib_instructions[12] = 32'h00000013;
    // NOP
    fib_instructions[13] = 32'h00000013;
    // NOP
    fib_instructions[14] = 32'h00000013;

    `uvm_info(get_type_name(),
      "=== FIBONACCI SEQUENCE: Loading program ===", UVM_LOW)

    // Send each instruction as a sequence item to the driver
    foreach (fib_instructions[i]) begin
      req = cpu_seq_item::type_id::create($sformatf("req_%0d", i));

      start_item(req);

      req.instruction = fib_instructions[i];
      req.read_data   = 32'h0;  // no reads in this program
      req.pc          = i * 4;  // PC increments by 4 each instruction

      // No interrupts
      req.timer_interrupt    = 0;
      req.software_interrupt = 0;
      req.external_interrupt = 0;

      finish_item(req);

      `uvm_info(get_type_name(),
        $sformatf("Sent instruction [%0d]: PC=0x%08h INSTR=0x%08h",
          i, i*4, fib_instructions[i]),
        UVM_MEDIUM)
    end

    `uvm_info(get_type_name(),
      "=== FIBONACCI SEQUENCE: All instructions sent ===", UVM_LOW)

  endtask

endclass

`endif // CPU_FIBONACCI_SEQUENCE_SV
