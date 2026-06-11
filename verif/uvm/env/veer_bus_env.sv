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
// veer_bus_env : top-level UVM environment for VeeR EH2 bus/SoC integration.
//
//   - ifu_agent / lmem_agent       : active slave responders (Phase 1)
//   - lsu_mon_agent / sb_mon_agent  : passive monitors
//   - dma_agent (axi4_master_agent) : DMA master, active only when the build
//                                     actually wires it to the port (Phase 2)
//   - scoreboard                    : DMA write/read-back consistency (Phase 2)
//   - cov_*                         : functional coverage per port (Phase 3)
//   - vseqr                         : virtual sequencer for DMA virtual seqs
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_ENV_SV
`define VEER_BUS_ENV_SV

class veer_bus_env extends uvm_env;
  `uvm_component_utils(veer_bus_env)

  veer_bus_cfg cfg;

  axi4_slave_agent  ifu_agent;
  axi4_slave_agent  lmem_agent;
  axi4_slave_agent  lsu_mon_agent;
  axi4_slave_agent  sb_mon_agent;
  axi4_master_agent dma_agent;

  veer_bus_scoreboard scoreboard;
  veer_bus_vseqr      vseqr;

  axi4_cov cov_ifu, cov_lmem, cov_lsu, cov_sb, cov_dma;

  axi4_slave_mem ifu_mem;
  axi4_slave_mem lmem_mem;

  int dma_uvm_master = 0;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Create a slave agent on `vif`, with its own cfg published via config_db.
  function axi4_slave_agent mk_slave(string name, virtual axi4_if vif,
                                     uvm_active_passive_enum act,
                                     axi4_slave_mem mem, string pn);
    axi4_slave_cfg c;
    if (vif == null) begin
      `uvm_warning(get_type_name(),
                   $sformatf("no vif for %s; agent not created", name))
      return null;
    end
    c = axi4_slave_cfg::type_id::create({name, "_cfg"});
    c.vif           = vif;
    c.is_active     = act;
    c.mem           = mem;
    c.port_name     = pn;
    c.policy_enable = cfg.slave_policy_enable;
    c.ar_max_wait   = cfg.slave_max_wait;
    c.r_max_wait    = cfg.slave_max_wait;
    c.aw_max_wait   = cfg.slave_max_wait;
    c.w_max_wait    = cfg.slave_max_wait;
    c.b_max_wait    = cfg.slave_max_wait;
    uvm_config_db#(axi4_slave_cfg)::set(this, name, "cfg", c);
    return axi4_slave_agent::type_id::create(name, this);
  endfunction

  function void build_phase(uvm_phase phase);
    virtual axi4_if ifu_vif, lmem_vif, lsu_vif, sb_vif, dma_vif;
    axi4_master_cfg dcfg;
    uvm_active_passive_enum dma_act;
    super.build_phase(phase);

    if (!uvm_config_db#(veer_bus_cfg)::get(this, "", "cfg", cfg)) begin
      cfg = veer_bus_cfg::type_id::create("cfg");
      `uvm_info(get_type_name(),
                "no veer_bus_cfg in config_db; using defaults", UVM_MEDIUM)
    end
    void'(uvm_config_db#(int)::get(this, "", "dma_uvm_master", dma_uvm_master));

    void'(uvm_config_db#(virtual axi4_if)::get(this, "", "ifu_vif",  ifu_vif));
    void'(uvm_config_db#(virtual axi4_if)::get(this, "", "lmem_vif", lmem_vif));
    void'(uvm_config_db#(virtual axi4_if)::get(this, "", "lsu_vif",  lsu_vif));
    void'(uvm_config_db#(virtual axi4_if)::get(this, "", "sb_vif",   sb_vif));
    void'(uvm_config_db#(virtual axi4_if)::get(this, "", "dma_vif",  dma_vif));

    // Golden images for the active responders.
    ifu_mem  = axi4_slave_mem::type_id::create("ifu_mem");
    lmem_mem = axi4_slave_mem::type_id::create("lmem_mem");
    ifu_mem.load("program.hex");
    lmem_mem.load("program.hex");

    ifu_agent     = mk_slave("ifu_agent",     ifu_vif,  cfg.ifu_slave_active, ifu_mem,  "ifu");
    lmem_agent    = mk_slave("lmem_agent",    lmem_vif, cfg.lsu_slave_active, lmem_mem, "lmem");
    lsu_mon_agent = mk_slave("lsu_mon_agent", lsu_vif,  UVM_PASSIVE,          null,     "lsu");
    sb_mon_agent  = mk_slave("sb_mon_agent",  sb_vif,   UVM_PASSIVE,          null,     "sb");

    // DMA master: only ACTIVE when requested AND the build wires it to the port.
    dma_act = (cfg.dma_master_active == UVM_ACTIVE && dma_uvm_master == 1)
              ? UVM_ACTIVE : UVM_PASSIVE;
    if (dma_vif != null) begin
      dcfg = axi4_master_cfg::type_id::create("dma_cfg");
      dcfg.vif       = dma_vif;
      dcfg.is_active = dma_act;
      dcfg.base_addr = cfg.dma_base;
      dcfg.window    = cfg.dma_window;
      dcfg.port_name = "dma";
      uvm_config_db#(axi4_master_cfg)::set(this, "dma_agent", "cfg", dcfg);
      dma_agent = axi4_master_agent::type_id::create("dma_agent", this);
    end

    scoreboard = veer_bus_scoreboard::type_id::create("scoreboard", this);
    vseqr      = veer_bus_vseqr::type_id::create("vseqr", this);

    if (cfg.enable_cov) begin
      cov_ifu  = axi4_cov::type_id::create("cov_ifu",  this);
      cov_lmem = axi4_cov::type_id::create("cov_lmem", this);
      cov_lsu  = axi4_cov::type_id::create("cov_lsu",  this);
      cov_sb   = axi4_cov::type_id::create("cov_sb",   this);
      cov_dma  = axi4_cov::type_id::create("cov_dma",  this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // DMA monitor feeds the scoreboard.
    if (dma_agent != null)
      dma_agent.ap.connect(scoreboard.dma_imp);

    // Coverage hooks.
    if (cfg.enable_cov) begin
      if (ifu_agent     != null) ifu_agent.ap.connect(cov_ifu.analysis_export);
      if (lmem_agent    != null) lmem_agent.ap.connect(cov_lmem.analysis_export);
      if (lsu_mon_agent != null) lsu_mon_agent.ap.connect(cov_lsu.analysis_export);
      if (sb_mon_agent  != null) sb_mon_agent.ap.connect(cov_sb.analysis_export);
      if (dma_agent     != null) dma_agent.ap.connect(cov_dma.analysis_export);
    end

    // Expose the DMA sequencer to virtual sequences (null if not active).
    if (dma_agent != null && dma_agent.sequencer != null)
      vseqr.dma_seqr = dma_agent.sequencer;
  endfunction

endclass

`endif // VEER_BUS_ENV_SV
