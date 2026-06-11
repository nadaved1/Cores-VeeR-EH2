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
// axi4_slave_driver : reactive AXI4 slave responder.
//
// Phase 1 reproduces the proven testbench/ahb_sif.sv `axi_slv` behaviour exactly
// — only re-homed onto a UVM agent and a class-based golden memory model:
//   - AR/AW/W ready are tied high (the model never back-pressures);
//   - reads have one cycle of latency: data is fetched on the negedge after AR
//     and RVALID is registered on the next posedge (rvalid <= arvalid);
//   - writes apply WSTRB on the negedge the AW/W are seen (single beat);
//   - RRESP/BRESP are OKAY, RLAST is always 1 (single-beat, in line with the
//     EH2 IFU/LSU bus interface which issues single 64-bit beats).
//
// This guarantees the program runs to completion served entirely by UVM. The
// handshake-respecting / wait-state / error-injecting modes arrive in Phase 3;
// the cfg.read_latency knob is retained for that.
//-----------------------------------------------------------------------------
`ifndef AXI4_SLAVE_DRIVER_SV
`define AXI4_SLAVE_DRIVER_SV

class axi4_slave_driver extends uvm_driver #(axi4_slave_seq_item);
  `uvm_component_utils(axi4_slave_driver)

  axi4_slave_cfg  cfg;
  virtual axi4_if vif;
  axi4_slave_mem  mem;

  bit [63:0] memdata;   // read-data pipeline register (mirrors axi_slv.memdata)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi4_slave_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "axi4_slave_cfg not set")
    vif = cfg.vif;
    mem = cfg.mem;
    if (mem == null)
      `uvm_fatal(get_type_name(), "axi4_slave_cfg.mem is null")
  endfunction

  task run_phase(uvm_phase phase);
    if (!cfg.policy_enable) faithful_mode();
    else                    policy_mode();
  endtask

  // ===================================================================== //
  // Faithful mode: 1:1 reproduction of axi_slv (Phase 1 default).         //
  // ===================================================================== //
  task faithful_mode();
    // Static slave-sourced signals (held for the whole run, like axi_slv).
    vif.arready <= 1'b1;
    vif.awready <= 1'b1;
    vif.wready  <= 1'b1;
    vif.rresp   <= 2'b00;
    vif.bresp   <= 2'b00;
    vif.rlast   <= 1'b1;
    vif.rvalid  <= 1'b0;
    vif.bvalid  <= 1'b0;
    vif.rid     <= '0;
    vif.bid     <= '0;
    vif.rdata   <= '0;

    fork
      mem_access();        // negedge: fetch read data / apply writes
      response_regs();     // posedge: register RVALID/BVALID/RDATA/ids
    join
  endtask

  // Negedge data path (axi_slv: always @(negedge aclk)).
  task mem_access();
    forever begin
      @(negedge vif.clk);
      if (vif.arvalid)
        memdata = mem.read64(vif.araddr);
      if (vif.awvalid)
        mem.write64(vif.awaddr, vif.wdata, vif.wstrb);
    end
  endtask

  // Posedge response registers (axi_slv: always @(posedge aclk or negedge rst)).
  task response_regs();
    forever begin
      @(posedge vif.clk or negedge vif.rst_l);
      if (!vif.rst_l) begin
        vif.rvalid <= 1'b0;
        vif.bvalid <= 1'b0;
      end
      else begin
        vif.bid    <= vif.awid;
        vif.rid    <= vif.arid;
        vif.rvalid <= vif.arvalid;
        vif.bvalid <= vif.awvalid;
        vif.rdata  <= memdata;
      end
    end
  endtask

  // ===================================================================== //
  // Policy mode: handshake-respecting reactive responder with wait states //
  // and optional error injection (Phase 3). Single-outstanding per channel //
  // — the master just sees a slower slave; functionally still correct.     //
  // ===================================================================== //
  function int unsigned rand_wait(int unsigned m);
    return (m == 0) ? 0 : ($urandom % (m + 1));
  endfunction

  function bit [1:0] gen_resp();
    if (cfg.err_rate_pct > 0 && ($urandom % 100) < cfg.err_rate_pct)
      return 2'b10;  // SLVERR
    return 2'b00;    // OKAY
  endfunction

  task policy_mode();
    vif.arready <= 1'b0; vif.rvalid <= 1'b0; vif.rlast <= 1'b0;
    vif.awready <= 1'b0; vif.wready <= 1'b0; vif.bvalid <= 1'b0;
    vif.rresp <= 2'b0; vif.bresp <= 2'b0; vif.rid <= '0; vif.bid <= '0;
    fork
      read_policy();
      write_policy();
    join
  endtask

  task read_policy();
    forever begin
      bit [31:0] araddr; int unsigned arid, arlen, arsize, arburst;
      bit [1:0]  rsp;
      // Wait for AR, then insert ARREADY wait states.
      vif.arready <= 1'b0;
      while (!(vif.rst_l && vif.arvalid)) @(posedge vif.clk);
      repeat (rand_wait(cfg.ar_max_wait)) @(posedge vif.clk);
      vif.arready <= 1'b1;
      @(posedge vif.clk);
      araddr = vif.araddr; arid = vif.arid; arlen = vif.arlen;
      arsize = vif.arsize; arburst = vif.arburst;
      vif.arready <= 1'b0;
      rsp = gen_resp();
      // Drive R beats.
      for (int b = 0; b <= arlen; b++) begin
        bit [31:0] ba = araddr + (b * (1 << arsize));
        repeat (rand_wait(cfg.r_max_wait)) @(posedge vif.clk);
        vif.rvalid <= 1'b1;
        vif.rid    <= arid;
        vif.rdata  <= mem.read64(ba);
        vif.rresp  <= rsp;
        vif.rlast  <= (b == arlen);
        do @(posedge vif.clk); while (vif.rready !== 1'b1);
      end
      vif.rvalid <= 1'b0; vif.rlast <= 1'b0;
    end
  endtask

  task write_policy();
    forever begin
      bit [31:0] awaddr; int unsigned awid, awlen, awsize;
      bit [31:0] ba; bit last; bit [1:0] rsp;
      vif.awready <= 1'b0; vif.wready <= 1'b0; vif.bvalid <= 1'b0;
      while (!(vif.rst_l && vif.awvalid)) @(posedge vif.clk);
      repeat (rand_wait(cfg.aw_max_wait)) @(posedge vif.clk);
      vif.awready <= 1'b1;
      @(posedge vif.clk);
      awaddr = vif.awaddr; awid = vif.awid; awlen = vif.awlen; awsize = vif.awsize;
      vif.awready <= 1'b0;
      // Accept W beats.
      ba = awaddr; last = 1'b0;
      while (!last) begin
        repeat (rand_wait(cfg.w_max_wait)) @(posedge vif.clk);
        vif.wready <= 1'b1;
        do @(posedge vif.clk); while (vif.wvalid !== 1'b1);
        mem.write64(ba, vif.wdata, vif.wstrb);
        ba   = ba + (1 << awsize);
        last = vif.wlast;
        vif.wready <= 1'b0;
      end
      // Write response.
      rsp = gen_resp();
      repeat (rand_wait(cfg.b_max_wait)) @(posedge vif.clk);
      vif.bvalid <= 1'b1; vif.bid <= awid; vif.bresp <= rsp;
      do @(posedge vif.clk); while (vif.bready !== 1'b1);
      vif.bvalid <= 1'b0;
    end
  endtask

endclass

`endif // AXI4_SLAVE_DRIVER_SV
