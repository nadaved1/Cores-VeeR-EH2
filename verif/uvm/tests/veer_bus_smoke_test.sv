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
// veer_bus_smoke_test : Phase 0 default test.
//
// Runs a program to completion with all bus agents passive and the static RTL
// slaves serving the bus. Proves the UVM build/elaboration/run path works
// alongside the existing DUT and trace infrastructure. This is the default
// +UVM_TESTNAME for the *-uvm Makefile targets.
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_SMOKE_TEST_SV
`define VEER_BUS_SMOKE_TEST_SV

class veer_bus_smoke_test extends veer_bus_base_test;
  `uvm_component_utils(veer_bus_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Phase 1: the IFU and LSU-external slaves are active UVM responders (they
  // replace the static axi_slv leaves and serve the program). SB and DMA stay
  // passively monitored; the DMA loopback path is unchanged.
  virtual function void configure_cfg();
    cfg.ifu_slave_active = UVM_ACTIVE;
    cfg.lsu_slave_active = UVM_ACTIVE;
  endfunction

endclass

`endif // VEER_BUS_SMOKE_TEST_SV
