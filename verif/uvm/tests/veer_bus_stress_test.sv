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
// veer_bus_stress_test : Phase 3. Runs the program under adversarial bus
// conditions — the IFU/LSU slave responders insert randomized wait states
// (handshake-respecting policy mode) and the DMA master hammers the DMA port
// with back-pressured bursts. Functional coverage is enabled. Multi-seed:
//   make -f tools/Makefile vcs-uvm UVM_TEST=veer_bus_stress_test \
//        UVM_DEFINES=+define+DMA_UVM_MASTER run_arg="+ntb_random_seed=<N>"
//
// Note: slave error injection (err_rate_pct) is intentionally left at 0 here —
// a fetch/load error would derail the running program. It is exercised by
// targeted negative tests, not against a live program.
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_STRESS_TEST_SV
`define VEER_BUS_STRESS_TEST_SV

class veer_bus_stress_test extends veer_bus_base_test;
  `uvm_component_utils(veer_bus_stress_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void configure_cfg();
    cfg.ifu_slave_active    = UVM_ACTIVE;
    cfg.lsu_slave_active    = UVM_ACTIVE;
    cfg.dma_master_active   = UVM_ACTIVE;
    cfg.enable_cov          = 1'b1;
    // Handshake-respecting slave responders with wait states.
    cfg.slave_policy_enable = 1'b1;
    cfg.slave_max_wait      = 4;
  endfunction

  virtual task stimulus();
    if (env.vseqr.dma_seqr == null) begin
      `uvm_info(get_type_name(),
        "DMA master inactive (build without DMA_UVM_MASTER); slave wait-state stress only",
        UVM_LOW)
      return;
    end
    forever begin
      veer_bus_dma_vseq vseq = veer_bus_dma_vseq::type_id::create("dma_stress_vseq");
      vseq.stress    = 1'b1;
      vseq.base_addr = cfg.dma_base;
      vseq.window    = cfg.dma_window;
      vseq.num_txns  = 32;
      vseq.start(env.vseqr);
    end
  endtask

endclass

`endif // VEER_BUS_STRESS_TEST_SV
