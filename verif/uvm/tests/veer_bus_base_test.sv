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
// veer_bus_base_test : common base for all bus/SoC integration tests.
//
// Builds the env and runs the loaded program (program.hex) to completion. The
// run_phase objection is held until tb_uvm_top signals end-of-test via
// veer_eot_if, then released so UVM ends cleanly and prints its report. A
// TEST_FAILED / timeout is reported as a UVM_ERROR.
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_BASE_TEST_SV
`define VEER_BUS_BASE_TEST_SV

class veer_bus_base_test extends uvm_test;
  `uvm_component_utils(veer_bus_base_test)

  veer_bus_env        env;
  veer_bus_cfg        cfg;
  virtual veer_eot_if eot_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = veer_bus_cfg::type_id::create("cfg");
    configure_cfg();
    uvm_config_db#(veer_bus_cfg)::set(this, "env", "cfg", cfg);
    env = veer_bus_env::type_id::create("env", this);

    if (!uvm_config_db#(virtual veer_eot_if)::get(this, "", "eot_vif", eot_vif))
      `uvm_fatal(get_type_name(), "veer_eot_if not found in config_db")
  endfunction

  // Hook for derived tests to tweak the env configuration before build.
  virtual function void configure_cfg();
    // Base: leave defaults (all agents passive; static RTL slaves serve the bus).
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this, "running program.hex");
    `uvm_info(get_type_name(), "waiting for program end-of-test signal", UVM_LOW)
    // Wait for BOTH the program to finish AND any background bus stimulus to
    // complete, so DMA/stress traffic is not truncated when a short program
    // (e.g. hello_world) signals end-of-test early. stimulus() must be bounded.
    fork
      wait (eot_vif.seen == 1'b1);
      stimulus();
    join
    if (eot_vif.pass)
      `uvm_info(get_type_name(), "program signalled TEST_PASSED", UVM_LOW)
    else
      `uvm_error(get_type_name(), "program signalled TEST_FAILED or hit timeout")
    phase.drop_objection(this, "program complete");
  endtask

  // Concurrent bus stimulus hook. Base does nothing (slaves serve the program).
  virtual task stimulus();
  endtask

endclass

`endif // VEER_BUS_BASE_TEST_SV
