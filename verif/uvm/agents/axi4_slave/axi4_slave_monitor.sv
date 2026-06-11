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
// axi4_slave_monitor : passive observer of one AXI4 port. Reconstructs read and
// write bursts from channel handshakes and publishes them on an analysis port
// (consumed by the scoreboard in Phase 2 and coverage in Phase 3).
//
// In-order reconstruction (matches the in-order RTL slaves and the EH2 bus
// usage): read beats are attributed to the oldest outstanding AR, write data to
// the oldest outstanding AW. This holds for the current single-region setup; a
// per-ID reorder model can replace it later if needed.
//-----------------------------------------------------------------------------
`ifndef AXI4_SLAVE_MONITOR_SV
`define AXI4_SLAVE_MONITOR_SV

class axi4_slave_monitor extends uvm_monitor;
  `uvm_component_utils(axi4_slave_monitor)

  axi4_slave_cfg cfg;
  virtual axi4_if vif;

  uvm_analysis_port #(axi4_slave_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi4_slave_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "axi4_slave_cfg not set")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    fork
      collect_reads();
      collect_writes();
    join
  endtask

  // ----- read channel ------------------------------------------------------
  task collect_reads();
    axi4_slave_seq_item ar_q[$];
    forever begin
      @(posedge vif.clk);
      if (!vif.rst_l) begin
        ar_q.delete();
        continue;
      end
      // accept a new read address
      if (vif.arvalid && vif.arready) begin
        axi4_slave_seq_item tr = axi4_slave_seq_item::type_id::create("rd");
        tr.is_write = 0;
        tr.addr  = vif.araddr;
        tr.id    = vif.arid;
        tr.len   = vif.arlen;
        tr.size  = vif.arsize;
        tr.burst = vif.arburst;
        ar_q.push_back(tr);
      end
      // a read data beat for the oldest outstanding AR
      if (vif.rvalid && vif.rready && ar_q.size() > 0) begin
        ar_q[0].data.push_back(vif.rdata);
        ar_q[0].resp = vif.rresp;
        if (vif.rlast) begin
          axi4_slave_seq_item done = ar_q.pop_front();
          ap.write(done);
        end
      end
    end
  endtask

  // ----- write channels -----------------------------------------------------
  task collect_writes();
    axi4_slave_seq_item aw_q[$];
    axi4_slave_seq_item cur;     // burst currently collecting W data
    forever begin
      @(posedge vif.clk);
      if (!vif.rst_l) begin
        aw_q.delete();
        cur = null;
        continue;
      end
      if (vif.awvalid && vif.awready) begin
        axi4_slave_seq_item tr = axi4_slave_seq_item::type_id::create("wr");
        tr.is_write = 1;
        tr.addr  = vif.awaddr;
        tr.id    = vif.awid;
        tr.len   = vif.awlen;
        tr.size  = vif.awsize;
        tr.burst = vif.awburst;
        aw_q.push_back(tr);
      end
      if (vif.wvalid && vif.wready) begin
        if (cur == null && aw_q.size() > 0)
          cur = aw_q[0];
        if (cur != null) begin
          cur.data.push_back(vif.wdata);
          cur.strb.push_back(vif.wstrb);
        end
      end
      // write response completes the oldest write
      if (vif.bvalid && vif.bready && aw_q.size() > 0) begin
        axi4_slave_seq_item done = aw_q.pop_front();
        done.resp = vif.bresp;
        cur = null;
        ap.write(done);
      end
    end
  endtask

endclass

`endif // AXI4_SLAVE_MONITOR_SV
