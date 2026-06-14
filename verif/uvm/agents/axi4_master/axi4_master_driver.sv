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
// axi4_master_driver : AXI4 master driving the core's DMA slave port. One
// transaction at a time (single outstanding), respecting all handshakes and
// optionally inserting master-side RREADY/BREADY back-pressure.
//-----------------------------------------------------------------------------
`ifndef AXI4_MASTER_DRIVER_SV
`define AXI4_MASTER_DRIVER_SV

class axi4_master_driver extends uvm_driver #(axi4_master_seq_item);
  `uvm_component_utils(axi4_master_driver)

  axi4_master_cfg cfg;
  virtual axi4_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi4_master_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "axi4_master_cfg not set")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    reset_signals();
    // Wait until out of reset before issuing traffic.
    while (vif.rst_l !== 1'b1) @(posedge vif.clk);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.is_write) do_write(req);
      else             do_read(req);
      seq_item_port.item_done();
    end
  endtask

  function void reset_signals();
    vif.awvalid = 1'b0; vif.wvalid = 1'b0; vif.bready = 1'b0;
    vif.arvalid = 1'b0; vif.rready = 1'b0; vif.wlast = 1'b0;
    vif.awid = '0; vif.awaddr = '0; vif.awlen = '0; vif.awsize = '0;
    vif.awburst = '0; vif.awregion = '0; vif.awlock = '0; vif.awcache = '0;
    vif.awprot = '0; vif.awqos = '0;
    vif.wdata = '0; vif.wstrb = '0;
    vif.arid = '0; vif.araddr = '0; vif.arlen = '0; vif.arsize = '0;
    vif.arburst = '0; vif.arregion = '0; vif.arlock = '0; vif.arcache = '0;
    vif.arprot = '0; vif.arqos = '0;
  endfunction

  task do_write(axi4_master_seq_item tr);
    // Write address phase.
    @(posedge vif.clk);
    vif.awvalid <= 1'b1; vif.awid <= tr.id; vif.awaddr <= tr.addr;
    vif.awlen <= tr.len; vif.awsize <= tr.size; vif.awburst <= tr.burst;
    do @(posedge vif.clk); while (vif.awready !== 1'b1);
    vif.awvalid <= 1'b0;
    // Write data phase.
    for (int b = 0; b <= tr.len; b++) begin
      vif.wvalid <= 1'b1;
      vif.wdata  <= tr.data[b];
      vif.wstrb  <= tr.strb[b];
      vif.wlast  <= (b == tr.len);
      do @(posedge vif.clk); while (vif.wready !== 1'b1);
    end
    vif.wvalid <= 1'b0; vif.wlast <= 1'b0;
    // Write response (with optional back-pressure).
    vif.bready <= 1'b0;
    repeat (tr.wr_backpressure) @(posedge vif.clk);
    vif.bready <= 1'b1;
    do @(posedge vif.clk); while (vif.bvalid !== 1'b1);
    tr.resp = vif.bresp;
    vif.bready <= 1'b0;
  endtask

  task do_read(axi4_master_seq_item tr);
    @(posedge vif.clk);
    vif.arvalid <= 1'b1; vif.arid <= tr.id; vif.araddr <= tr.addr;
    vif.arlen <= tr.len; vif.arsize <= tr.size; vif.arburst <= tr.burst;
    do @(posedge vif.clk); while (vif.arready !== 1'b1);
    vif.arvalid <= 1'b0;
    tr.rdata = new[tr.len + 1];
    // Accept beats until the slave asserts RLAST. The DMA slave port is
    // single-beat (rlast=1 on the only beat), so terminating on RLAST — rather
    // than blindly waiting for tr.len+1 beats — keeps the master from hanging if
    // it is ever handed a (DUT-unsupported) burst request.
    for (int b = 0; b <= tr.len; b++) begin
      // RREADY back-pressure before accepting each beat.
      vif.rready <= 1'b0;
      repeat (tr.rd_backpressure) @(posedge vif.clk);
      vif.rready <= 1'b1;
      do @(posedge vif.clk); while (vif.rvalid !== 1'b1);
      tr.rdata[b] = vif.rdata;
      tr.resp     = vif.rresp;
      if (vif.rlast === 1'b1) begin
        if (b != tr.len)
          `uvm_warning(get_type_name(),
                       $sformatf("read @0x%08h ended on RLAST at beat %0d of %0d (DMA slave is single-beat)",
                                 tr.addr, b, tr.len))
        break;
      end
    end
    vif.rready <= 1'b0;
  endtask

endclass

`endif // AXI4_MASTER_DRIVER_SV
