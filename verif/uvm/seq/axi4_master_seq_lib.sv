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
// axi4_master_seq_lib : DMA master sequences. Each issues write-then-read-back
// pairs to the same address so the scoreboard can verify the data round-trips
// through the core's DMA controller and CCM.
//-----------------------------------------------------------------------------
`ifndef AXI4_MASTER_SEQ_LIB_SV
`define AXI4_MASTER_SEQ_LIB_SV

// Base: targets a CCM scratch window; subclasses choose burst/back-pressure.
class axi4_master_base_seq extends uvm_sequence #(axi4_master_seq_item);
  `uvm_object_utils(axi4_master_base_seq)

  rand bit [31:0]   base_addr;
  rand bit [31:0]   window;
  rand int unsigned num_txns;
  rand bit          use_backpressure;

  constraint c_defaults {
    soft window           == 32'h400;
    soft num_txns         inside {[8:32]};
    soft use_backpressure == 1'b0;
  }

  function new(string name = "axi4_master_base_seq");
    super.new(name);
  endfunction

  // One write-then-read-back pair to `addr`, `len`+1 beats of `1<<size` bytes.
  task wr_rd_pair(bit [31:0] addr, bit [7:0] len, bit [2:0] size);
    axi4_master_seq_item wr, rd;
    int unsigned bp_rd = use_backpressure ? ($urandom % 4) : 0;
    int unsigned bp_wr = use_backpressure ? ($urandom % 4) : 0;

    wr = axi4_master_seq_item::type_id::create("dma_wr");
    start_item(wr);
    if (!wr.randomize() with {
          is_write == 1; addr == local::addr; len == local::len;
          size == local::size; burst == 2'b01;
          rd_backpressure == 0; wr_backpressure == local::bp_wr;
        })
      `uvm_error(get_type_name(), "dma write randomize failed")
    finish_item(wr);

    rd = axi4_master_seq_item::type_id::create("dma_rd");
    start_item(rd);
    if (!rd.randomize() with {
          is_write == 0; addr == local::addr; len == local::len;
          size == local::size; burst == 2'b01;
          rd_backpressure == local::bp_rd; wr_backpressure == 0;
        })
      `uvm_error(get_type_name(), "dma read randomize failed")
    finish_item(rd);
  endtask

  // Pick an 8-byte-aligned address whose burst fits inside the window.
  function bit [31:0] pick_addr(bit [7:0] len);
    int unsigned beats = len + 1;
    int unsigned span  = beats * 8;
    int unsigned slots = (window > span) ? ((window - span) / 8) : 0;
    return base_addr + (($urandom % (slots + 1)) * 8);
  endfunction
endclass


// Plain write/read-back traffic, single- and multi-beat, no back-pressure.
class dma_write_read_seq extends axi4_master_base_seq;
  `uvm_object_utils(dma_write_read_seq)

  function new(string name = "dma_write_read_seq");
    super.new(name);
  endfunction

  task body();
    bit [7:0] lens[] = '{0, 1, 3, 7};
    repeat (num_txns) begin
      bit [7:0]  len  = lens[$urandom % lens.size()];
      bit [31:0] addr = pick_addr(len);
      wr_rd_pair(addr, len, 3'd3);   // 64-bit beats
    end
  endtask
endclass


// Stress variant: enables RREADY/BREADY back-pressure and longer bursts.
class dma_stress_seq extends axi4_master_base_seq;
  `uvm_object_utils(dma_stress_seq)

  constraint c_stress {
    soft use_backpressure == 1'b1;
    soft num_txns inside {[16:64]};
  }

  function new(string name = "dma_stress_seq");
    super.new(name);
  endfunction

  task body();
    bit [7:0] lens[] = '{1, 3, 7};
    repeat (num_txns) begin
      bit [7:0]  len  = lens[$urandom % lens.size()];
      bit [31:0] addr = pick_addr(len);
      wr_rd_pair(addr, len, 3'd3);
    end
  endtask
endclass

`endif // AXI4_MASTER_SEQ_LIB_SV
