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
// axi4_master_cfg : per-agent configuration for the DMA master agent.
//-----------------------------------------------------------------------------
`ifndef AXI4_MASTER_CFG_SV
`define AXI4_MASTER_CFG_SV

class axi4_master_cfg extends uvm_object;

  // Active = drive the DMA slave port; Passive = monitor only (the RTL DMA
  // loopback drives the port when DMA_UVM_MASTER is not compiled in).
  uvm_active_passive_enum is_active = UVM_PASSIVE;

  virtual axi4_if vif;

  // Address window the DMA master is allowed to target (a CCM scratch region).
  // Defaults to the start of DCCM; tests can narrow it.
  bit [31:0] base_addr = `RV_DCCM_SADR;
  bit [31:0] window    = 32'h0000_0400;   // 1 KB scratch

  string port_name = "dma";

  `uvm_object_utils_begin(axi4_master_cfg)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
    `uvm_field_int(base_addr,  UVM_DEFAULT)
    `uvm_field_int(window,     UVM_DEFAULT)
    `uvm_field_string(port_name, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "axi4_master_cfg");
    super.new(name);
  endfunction

endclass

`endif // AXI4_MASTER_CFG_SV
