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
// axi4_slave_cfg : per-agent configuration for an AXI4 slave responder.
//-----------------------------------------------------------------------------
`ifndef AXI4_SLAVE_CFG_SV
`define AXI4_SLAVE_CFG_SV

class axi4_slave_cfg extends uvm_object;

  // Active = drive the slave responses; Passive = monitor only.
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // Virtual interface for this port (all ports use the default ID_WIDTH=4).
  virtual axi4_if vif;

  // Golden memory served by an active responder. Shared by reference so a
  // future scoreboard / multiple ports can observe a single image.
  axi4_slave_mem mem;

  // Fixed read latency in clocks from accepting AR to first R beat. Phase 1
  // keeps this at 1, matching the original axi_slv (rvalid <= arvalid).
  int unsigned read_latency = 1;

  // --- Phase 3 response policy -------------------------------------------
  // policy_enable=0 (default): faithful axi_slv reproduction (always-ready,
  // 1-cycle registered read). policy_enable=1: handshake-respecting reactive
  // responder that inserts the wait states below and (optionally) errors.
  bit          policy_enable = 1'b0;
  int unsigned ar_max_wait   = 0;   // idle cycles before asserting ARREADY
  int unsigned r_max_wait    = 0;   // idle cycles before each R beat
  int unsigned aw_max_wait   = 0;   // idle cycles before asserting AWREADY
  int unsigned w_max_wait    = 0;   // idle cycles before each WREADY
  int unsigned b_max_wait    = 0;   // idle cycles before asserting BVALID
  // Percent chance of returning SLVERR per transaction. KEEP 0 when serving a
  // live program (a fetch/load error would derail it); use for targeted tests.
  int unsigned err_rate_pct  = 0;

  // Short tag used in log messages (e.g. "ifu", "lmem").
  string port_name = "axi4";

  `uvm_object_utils_begin(axi4_slave_cfg)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
    `uvm_field_object(mem,           UVM_DEFAULT | UVM_REFERENCE)
    `uvm_field_int(read_latency,     UVM_DEFAULT)
    `uvm_field_int(policy_enable,    UVM_DEFAULT)
    `uvm_field_int(ar_max_wait,      UVM_DEFAULT)
    `uvm_field_int(r_max_wait,       UVM_DEFAULT)
    `uvm_field_int(aw_max_wait,      UVM_DEFAULT)
    `uvm_field_int(w_max_wait,       UVM_DEFAULT)
    `uvm_field_int(b_max_wait,       UVM_DEFAULT)
    `uvm_field_int(err_rate_pct,     UVM_DEFAULT)
    `uvm_field_string(port_name,     UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "axi4_slave_cfg");
    super.new(name);
  endfunction

endclass

`endif // AXI4_SLAVE_CFG_SV
