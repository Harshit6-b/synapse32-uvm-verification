
`ifndef CPU_ENV_SV
`define CPU_ENV_SV

class cpu_env extends uvm_env;  
  `uvm_component_utils(cpu_env)
  
   // Environment Components
  cpu_agent      agent;
  cpu_scoreboard scoreboard;
  // Configuration
  bit enable_scoreboard = 1;  // Enable/disable scoreboard
  
  // Constructor
  function new(string name = "cpu_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  //Create all components
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Create agent (always needed)
    agent = cpu_agent::type_id::create("agent", this);
    
    // Create scoreboard (if enabled)
    if (enable_scoreboard) begin
      scoreboard = cpu_scoreboard::type_id::create("scoreboard", this);
      `uvm_info(get_type_name(), "Scoreboard enabled", UVM_MEDIUM)
    end else begin
      `uvm_info(get_type_name(), "Scoreboard disabled", UVM_MEDIUM)
    end
    
    `uvm_info(get_type_name(), "Environment build phase complete", UVM_MEDIUM)
  endfunction
  
  // Wire components together
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect monitor's analysis port to scoreboard
    if (enable_scoreboard && scoreboard != null) begin
      agent.mon_analysis_port.connect(scoreboard.mon_analysis_imp);
      `uvm_info(get_type_name(), "Connected monitor to scoreboard", UVM_MEDIUM)
    end
    
  endfunction
  
  //  Report configuration
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    
    `uvm_info(get_type_name(), "=== ENVIRONMENT CONFIGURATION ===", UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Agent: %s", 
              (agent != null) ? "PRESENT" : "MISSING"), UVM_LOW)
    `uvm_info(get_type_name(), $sformatf("Scoreboard: %s", 
              (scoreboard != null) ? "ENABLED" : "DISABLED"), UVM_LOW)
    `uvm_info(get_type_name(), "=================================", UVM_LOW)
  endfunction
  
endclass

`endif 
