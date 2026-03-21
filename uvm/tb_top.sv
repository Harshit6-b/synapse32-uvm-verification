
`timescale 1ns/1ps

// Import all packages so the module 
import uvm_pkg::*;
`include "uvm_macros.svh"

import cpu_test_pkg::*;

module tb_top;

 // Clock and Reset
 
  logic clk;
  logic rst;

  // Clock: 100 MHz
  initial clk = 0;
  always #5 clk = ~clk;

  // Reset: assert for 20 cycles, then deassert
  initial begin
    rst = 1'b1;
    repeat(2) @(posedge clk);
    @(negedge clk);   // deassert on negedge to avoid setup issues
    rst = 1'b0;
    `uvm_info("TB_TOP", "Reset deasserted", UVM_LOW)
  end


 // Pass clock and reset into the interface.
 
  synapse32_if dut_if (
    .clk (clk),
    .rst (rst)
  );


  // Connect the riscv_cpu ports directly to the interface signals.
 
  riscv_cpu dut (
    .clk (clk),
    .rst (rst),

    // Instruction memory interface
    .module_instr_in (dut_if.module_instr_in),
    .module_pc_out (dut_if.module_pc_out),

    // Data memory interface
    .module_read_data_in  (dut_if.module_read_data_in),
    .module_wr_data_out  (dut_if.module_wr_data_out),
    .module_mem_wr_en  (dut_if.module_mem_wr_en),
    .module_mem_rd_en  (dut_if.module_mem_rd_en),
    .module_read_addr (dut_if.module_read_addr),
    .module_write_addr (dut_if.module_write_addr),
    .module_write_byte_enable (dut_if.module_write_byte_enable),
    .module_load_type  (dut_if.module_load_type),

    // Interrupt interface
    .timer_interrupt (dut_if.timer_interrupt),
    .software_interrupt (dut_if.software_interrupt),
    .external_interrupt  (dut_if.external_interrupt)
  );


  // UVM Config DB: Push virtual interface to all components that need it.
  // The path "" means: available to ANY component under uvm_test_top.
  // Both the driver and monitor will call:
  //   uvm_config_db#(virtual synapse32_if)::get(this, "", "vif", vif)

  initial begin
    uvm_config_db #(virtual synapse32_if)::set(
      null,           // from: null = top-level (tb_top)
      "uvm_test_top.*", // to: all components under test top
      "vif",          // key name - must match ::get() call
      dut_if          // value: the actual interface instance
    );
  end


  // Waveform Dump 

  initial begin
    $dumpfile("synapse32_tb.vcd");
    $dumpvars(0, tb_top);
  end


  // Prevents infinite simulation if something hangs.
  initial begin
    #1_000_000; // 1 million ns = 1 ms
    `uvm_fatal("TB_TOP", "SIMULATION TIMEOUT - test did not complete in time")
  end

 
  // Start UVM
  // run_test() reads +UVM_TESTNAME from the command line.
  // Example: +UVM_TESTNAME=cpu_nop_test
  // If no +UVM_TESTNAME is given, pass a default as the argument.
  
  initial begin
    run_test("cpu_nop_test"); // default test if +UVM_TESTNAME not provided
  end

endmodule
