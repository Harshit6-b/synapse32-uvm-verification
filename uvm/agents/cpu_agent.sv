`ifndef CPU_AGENT_SV
`define CPU_AGENT_SV

class cpu_agent extends uvm_agent;
	`uvm_component_utils(cpu_agent)
	
	cpu_sequencer sequencer;
	cpu_driver driver;
	cpu_monitor monitor;
	
	//analysis port from monitor
	uvm_analysis_port #(cpu_monitor_item) mon_analysis_port;
	
	//configuration
	//agent can be active (has driver+equencer) or passive monitor only 
	uvm_active_passive_enum is_active = UVM_ACTIVE;
	
	//constructor
	function new(string name = "cpu_agent", uvm_component parent = null);
		super.new(name, parent);
	endfunction
	
	//build phase  create all components
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		//creating a monitor
		monitor = cpu_monitor::type_id::create("monitor", this);
		//create driver and sequencer only if agent is active
		if (is_active == UVM_ACTIVE) begin 
			sequencer = cpu_sequencer::type_id::create("sequencer", this);
			driver = cpu_driver::type_id::create("driver", this);
			
			`uvm_info(get_type_name(), "Agent is ACTIVE (has driver+ sequencer)", UVM_MEDIUM)
			end else begin
			`uvm_info(get_type_name(), "Agent is PASSIVE (monitor only)", UVM_MEDIUM)
		end
	endfunction
	
	//connect phase wire component together
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		
		//connect monitor's analysis port to agent
		mon_analysis_port = monitor.mon_analysis_port;
		
		//connect driver to sequencer 
		if(is_active== UVM_ACTIVE) begin
			driver.seq_item_port.connect(sequencer.seq_item_export);
			`uvm_info(get_type_name(), "Connected driver to sequencer", UVM_MEDIUM)
		end
	endfunction
	
	//report agent configuration
	 function void end_of_elaboration_phase(uvm_phase phase);
   		 super.end_of_elaboration_phase(phase);
    
    		`uvm_info(get_type_name(), "=== AGENT CONFIGURATION ===", UVM_LOW)
    		`uvm_info(get_type_name(), $sformatf("Mode: %s", 
              (is_active == UVM_ACTIVE) ? "ACTIVE" : "PASSIVE"), UVM_LOW)
   		`uvm_info(get_type_name(), $sformatf("Monitor: %s", 
              (monitor != null) ? "PRESENT" : "MISSING"), UVM_LOW)
    		`uvm_info(get_type_name(), $sformatf("Driver: %s", 
              (driver != null) ? "PRESENT" : "MISSING"), UVM_LOW)
   		`uvm_info(get_type_name(), $sformatf("Sequencer: %s", 
              (sequencer != null) ? "PRESENT" : "MISSING"), UVM_LOW)
  	endfunction
  
endclass

`endif 
