
`default_nettype wire 

interface synapse32_if (input wire logic clk, input wire logic rst);
  
  // ========================================
  // Instruction Memory Interface
  // ========================================
  logic [31:0] module_instr_in;      // TB → CPU (instruction from memory)
  logic [31:0] module_pc_out;        // CPU → TB (PC for instruction fetch)
  
  // ========================================
  // Data Memory Interface
  // ========================================
  logic [31:0] module_read_data_in;        // TB → CPU (read data from memory)
  logic [31:0] module_wr_data_out;         // CPU → TB (write data to memory)
  logic        module_mem_wr_en;           // CPU → TB (write enable)
  logic        module_mem_rd_en;           // CPU → TB (read enable)
  logic [31:0] module_read_addr;           // CPU → TB (read address)
  logic [31:0] module_write_addr;          // CPU → TB (write address)
  logic [3:0]  module_write_byte_enable;   // CPU → TB (byte enable for writes)
  logic [2:0]  module_load_type;           // CPU → TB (load type: byte/half/word)
  
  // ========================================
  // Interrupt Interface
  // ========================================
  logic timer_interrupt;       // TB → CPU
  logic software_interrupt;    // TB → CPU
  logic external_interrupt;    // TB → CPU
  
  // ========================================
  // Driver Clocking Block
  // (TB acts as instruction/data memory + interrupt controller)
  // ========================================
  clocking driver_cb @(posedge clk);
    default input #1step output #1step;
    input  #0 module_pc_out;           // sample immediately at posedge
    input  #0 module_read_addr;        // ← key: sample at posedge not before
    input  #0 module_mem_rd_en;
    input  #0 module_mem_wr_en;
    input  #0 module_write_addr;
    input  #0 module_wr_data_out;
    input  #0 module_write_byte_enable;
    input  #0 module_load_type;
    output module_instr_in;
    output module_read_data_in;
    output timer_interrupt;
    output software_interrupt;
    output external_interrupt;
  endclocking
  
  // ========================================
  // Monitor Clocking Block
  // (Passive observation of all signals)
  // ========================================
  clocking monitor_cb @(posedge clk);
    input module_instr_in;
    input module_pc_out;
    input module_read_data_in;
    input module_wr_data_out;
    input module_mem_wr_en;
    input module_mem_rd_en;
    input module_read_addr;
    input module_write_addr;
    input module_write_byte_enable;
    input module_load_type;
    input timer_interrupt;
    input software_interrupt;
    input external_interrupt;
  endclocking
  
  // ========================================
  // Modports
  // ========================================
  modport driver_mp  (clocking driver_cb,  input clk, rst);
  modport monitor_mp (clocking monitor_cb, input clk, rst);
  
endinterface

`default_nettype wire
