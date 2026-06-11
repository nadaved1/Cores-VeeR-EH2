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
// veer_bus_cfg : top-level environment configuration object.
//
// Phase 0 carries only the active/passive knobs for the (not-yet-built) agents.
// Later phases add error-injection rates, wait-state policy, address windows,
// and coverage enables.
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_CFG_SV
`define VEER_BUS_CFG_SV

class veer_bus_cfg extends uvm_object;

  // Agent activity. From Phase 1 the IFU and LSU-external slave responders are
  // ACTIVE (they replace the static axi_slv leaves and serve the bus, so they
  // are required for any program to run). SB stays monitor-only; the DMA master
  // agent becomes active in Phase 2 (today the RTL DMA loopback drives it).
  uvm_active_passive_enum ifu_slave_active  = UVM_ACTIVE;
  uvm_active_passive_enum lsu_slave_active  = UVM_ACTIVE;
  uvm_active_passive_enum sb_slave_active   = UVM_PASSIVE;
  uvm_active_passive_enum dma_master_active = UVM_PASSIVE;

  // Phase 3: build functional coverage collectors on each monitored port.
  bit enable_cov = 1'b0;

  // Slave responder policy knobs (forwarded to the IFU/LSU slave cfgs). 0 keeps
  // the faithful axi_slv behaviour; >0 enables wait states under policy mode.
  bit          slave_policy_enable = 1'b0;
  int unsigned slave_max_wait      = 0;

  // DMA master scratch window (a CCM region the DMA master writes/reads).
  bit [31:0] dma_base   = `RV_DCCM_SADR;
  bit [31:0] dma_window = 32'h400;

  `uvm_object_utils_begin(veer_bus_cfg)
    `uvm_field_enum(uvm_active_passive_enum, ifu_slave_active, UVM_DEFAULT)
    `uvm_field_enum(uvm_active_passive_enum, lsu_slave_active, UVM_DEFAULT)
    `uvm_field_enum(uvm_active_passive_enum, sb_slave_active,  UVM_DEFAULT)
    `uvm_field_enum(uvm_active_passive_enum, dma_master_active, UVM_DEFAULT)
    `uvm_field_int(enable_cov,          UVM_DEFAULT)
    `uvm_field_int(slave_policy_enable, UVM_DEFAULT)
    `uvm_field_int(slave_max_wait,      UVM_DEFAULT)
    `uvm_field_int(dma_base,            UVM_DEFAULT)
    `uvm_field_int(dma_window,          UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "veer_bus_cfg");
    super.new(name);
  endfunction

endclass

`endif // VEER_BUS_CFG_SV
