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
// axi4_slave_seq_item : a completed AXI4 transaction observed/served at a slave
// port. Produced by the monitor (for coverage/scoreboard) and used by the
// reactive driver to record what it served. One item == one full burst.
//-----------------------------------------------------------------------------
`ifndef AXI4_SLAVE_SEQ_ITEM_SV
`define AXI4_SLAVE_SEQ_ITEM_SV

class axi4_slave_seq_item extends uvm_sequence_item;

  bit          is_write;     // 1 = write burst, 0 = read burst
  bit [31:0]   addr;         // start address (from AW/AR)
  int unsigned id;           // AWID / ARID
  bit [7:0]    len;          // AxLEN (beats - 1)
  bit [2:0]    size;         // AxSIZE
  bit [1:0]    burst;        // AxBURST
  bit [63:0]   data  [$];    // one entry per beat (W or R data)
  bit [7:0]    strb  [$];    // one entry per beat (writes only)
  bit [1:0]    resp;         // BRESP (writes) or the RRESP of the last beat

  `uvm_object_utils_begin(axi4_slave_seq_item)
    `uvm_field_int(is_write, UVM_DEFAULT)
    `uvm_field_int(addr,     UVM_DEFAULT)
    `uvm_field_int(id,       UVM_DEFAULT)
    `uvm_field_int(len,      UVM_DEFAULT)
    `uvm_field_int(size,     UVM_DEFAULT)
    `uvm_field_int(burst,    UVM_DEFAULT)
    `uvm_field_queue_int(data, UVM_DEFAULT | UVM_HEX)
    `uvm_field_queue_int(strb, UVM_DEFAULT | UVM_HEX)
    `uvm_field_int(resp,     UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "axi4_slave_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%08h id=%0d len=%0d size=%0d burst=%0d beats=%0d resp=%0d",
                     is_write ? "WR" : "RD", addr, id, len, size, burst,
                     is_write ? data.size() : data.size(), resp);
  endfunction

endclass

`endif // AXI4_SLAVE_SEQ_ITEM_SV
