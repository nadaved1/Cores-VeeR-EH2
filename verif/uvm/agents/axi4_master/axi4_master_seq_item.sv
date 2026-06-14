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
// axi4_master_seq_item : one AXI4 transaction driven by the DMA master agent
// into the core's DMA slave port. Randomizable; the captured response/read data
// is filled back in by the driver.
//-----------------------------------------------------------------------------
`ifndef AXI4_MASTER_SEQ_ITEM_SV
`define AXI4_MASTER_SEQ_ITEM_SV

class axi4_master_seq_item extends uvm_sequence_item;

  rand bit          is_write;
  rand bit [31:0]   addr;
  rand bit [0:0]    id;          // DMA_BUS_TAG = 1
  rand bit [7:0]    len;         // AxLEN (beats - 1)
  rand bit [2:0]    size;        // AxSIZE
  rand bit [1:0]    burst;       // 0=FIXED, 1=INCR
  rand bit [63:0]   data [];     // write data, one per beat
  rand bit [7:0]    strb [];     // write strobes, one per beat

  // Master rready/bready back-pressure: idle cycles inserted before accepting
  // each read-data beat / the write response. 0 = no back-pressure.
  rand int unsigned rd_backpressure;
  rand int unsigned wr_backpressure;

  // Captured response.
  bit [1:0]         resp;        // BRESP (write) or last RRESP (read)
  bit [63:0]        rdata [];    // read data, one per beat

  constraint c_size  { size <= 3; }                 // up to 64-bit beats
  constraint c_burst { burst inside {2'b00, 2'b01}; } // FIXED or INCR
  constraint c_len   { len inside {0, 1, 3, 7}; }   // 1..8 beats
  constraint c_align { (addr & ((1 << size) - 1)) == 0; } // size-aligned
  constraint c_bp    { rd_backpressure <= 4; wr_backpressure <= 4; }
  // Size the write-data arrays in BOTH directions. A read carries no write
  // data, so its arrays must be pinned to 0 — otherwise these rand dynamic
  // arrays are unconstrained for reads and the solver may pick an enormous
  // size (CNST-LASW warning + severe slowdown).
  constraint c_data  {
    data.size() == (is_write ? (len + 1) : 0);
    strb.size() == (is_write ? (len + 1) : 0);
  }

  `uvm_object_utils_begin(axi4_master_seq_item)
    `uvm_field_int(is_write,        UVM_DEFAULT)
    `uvm_field_int(addr,            UVM_DEFAULT)
    `uvm_field_int(id,              UVM_DEFAULT)
    `uvm_field_int(len,             UVM_DEFAULT)
    `uvm_field_int(size,            UVM_DEFAULT)
    `uvm_field_int(burst,           UVM_DEFAULT)
    `uvm_field_array_int(data,      UVM_DEFAULT | UVM_HEX)
    `uvm_field_array_int(strb,      UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(rd_backpressure, UVM_DEFAULT)
    `uvm_field_int(wr_backpressure, UVM_DEFAULT)
    `uvm_field_int(resp,            UVM_DEFAULT)
    `uvm_field_array_int(rdata,     UVM_DEFAULT | UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "axi4_master_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("DMA %s addr=0x%08h id=%0d len=%0d size=%0d burst=%0d resp=%0d",
                     is_write ? "WR" : "RD", addr, id, len, size, burst, resp);
  endfunction

endclass

`endif // AXI4_MASTER_SEQ_ITEM_SV
