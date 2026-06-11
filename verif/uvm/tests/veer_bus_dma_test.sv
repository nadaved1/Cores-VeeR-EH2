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
// veer_bus_dma_test : Phase 2. Runs the program while the UVM DMA master drives
// write-then-read-back traffic into a CCM scratch window; the scoreboard checks
// the data round-trips. Requires the build to actually own the DMA port:
//   make -f tools/Makefile vcs-uvm UVM_TEST=veer_bus_dma_test UVM_DEFINES=+define+DMA_UVM_MASTER
// Without DMA_UVM_MASTER the DMA master stays passive and the vseq is a no-op.
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_DMA_TEST_SV
`define VEER_BUS_DMA_TEST_SV

class veer_bus_dma_test extends veer_bus_base_test;
  `uvm_component_utils(veer_bus_dma_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void configure_cfg();
    cfg.ifu_slave_active  = UVM_ACTIVE;
    cfg.lsu_slave_active  = UVM_ACTIVE;
    cfg.dma_master_active = UVM_ACTIVE;
    cfg.enable_cov        = 1'b1;
  endfunction

  virtual task stimulus();
    veer_bus_dma_vseq vseq;
    if (env.vseqr.dma_seqr == null) begin
      `uvm_info(get_type_name(),
        "DMA master inactive (build without DMA_UVM_MASTER); no DMA stimulus",
        UVM_LOW)
      return;
    end
    // Issue a bounded, deterministic number of DMA write/read-back pairs. The
    // run holds until these finish even if the program ends first.
    vseq = veer_bus_dma_vseq::type_id::create("dma_vseq");
    vseq.stress    = 1'b0;
    vseq.base_addr = cfg.dma_base;
    vseq.window    = cfg.dma_window;
    vseq.num_txns  = cfg.dma_total_txns;
    `uvm_info(get_type_name(),
      $sformatf("issuing %0d DMA write/read-back pairs", cfg.dma_total_txns), UVM_LOW)
    vseq.start(env.vseqr);
  endtask

endclass

`endif // VEER_BUS_DMA_TEST_SV
