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
// veer_bus_dma_vseq : virtual sequence that drives DMA master traffic on the
// DMA sequencer while the program runs. No-op (with a note) when the DMA master
// is not active (i.e. DMA_UVM_MASTER was not compiled in), so the same test
// works in either build.
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_VSEQ_LIB_SV
`define VEER_BUS_VSEQ_LIB_SV

class veer_bus_dma_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(veer_bus_dma_vseq)
  `uvm_declare_p_sequencer(veer_bus_vseqr)

  bit          stress    = 1'b0;
  bit [31:0]   base_addr = `RV_DCCM_SADR;
  bit [31:0]   window    = 32'h400;
  int unsigned num_txns  = 16;

  function new(string name = "veer_bus_dma_vseq");
    super.new(name);
  endfunction

  task body();
    if (p_sequencer.dma_seqr == null) begin
      `uvm_info(get_type_name(),
        "DMA master not active (build without DMA_UVM_MASTER); skipping DMA traffic",
        UVM_LOW)
      return;
    end
    if (stress) begin
      dma_stress_seq s = dma_stress_seq::type_id::create("dma_stress");
      s.base_addr = base_addr; s.window = window; s.num_txns = num_txns;
      s.use_backpressure = 1'b1;
      s.start(p_sequencer.dma_seqr);
    end
    else begin
      dma_write_read_seq s = dma_write_read_seq::type_id::create("dma_wr_rd");
      s.base_addr = base_addr; s.window = window; s.num_txns = num_txns;
      s.use_backpressure = 1'b0;
      s.start(p_sequencer.dma_seqr);
    end
  endtask

endclass

`endif // VEER_BUS_VSEQ_LIB_SV
