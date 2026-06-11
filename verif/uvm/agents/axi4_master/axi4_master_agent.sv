// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Western Digital Corporation or its affiliates.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
//-----------------------------------------------------------------------------
// axi4_master_agent : DMA master. Active mode drives the DMA slave port; the
// monitor (always built, reusing the generic axi4_slave_monitor) observes the
// port and feeds the scoreboard / coverage via its analysis port.
//-----------------------------------------------------------------------------
`ifndef AXI4_MASTER_AGENT_SV
`define AXI4_MASTER_AGENT_SV

class axi4_master_agent extends uvm_agent;
  `uvm_component_utils(axi4_master_agent)

  axi4_master_cfg       cfg;
  axi4_master_driver    driver;
  axi4_master_sequencer sequencer;
  axi4_slave_monitor    monitor;     // generic bus observer

  uvm_analysis_port #(axi4_slave_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    axi4_slave_cfg mcfg;
    super.build_phase(phase);
    if (!uvm_config_db#(axi4_master_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "axi4_master_cfg not set")

    // The generic monitor expects an axi4_slave_cfg carrying the vif.
    mcfg = axi4_slave_cfg::type_id::create("mon_cfg");
    mcfg.vif       = cfg.vif;
    mcfg.is_active = UVM_PASSIVE;
    mcfg.port_name = cfg.port_name;
    uvm_config_db#(axi4_slave_cfg)::set(this, "monitor", "cfg", mcfg);

    monitor = axi4_slave_monitor::type_id::create("monitor", this);
    ap = monitor.ap;

    if (cfg.is_active == UVM_ACTIVE) begin
      uvm_config_db#(axi4_master_cfg)::set(this, "driver", "cfg", cfg);
      driver    = axi4_master_driver::type_id::create("driver", this);
      sequencer = axi4_master_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction

endclass

`endif // AXI4_MASTER_AGENT_SV
