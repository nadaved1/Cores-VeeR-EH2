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
// axi4_cov : functional coverage collector. One instance subscribes to one
// port's monitor (via uvm_subscriber::write) and samples a covergroup over the
// reconstructed transactions: direction, burst type, length, size, response,
// and address region, plus a few crosses.
//-----------------------------------------------------------------------------
`ifndef AXI4_COV_SV
`define AXI4_COV_SV

class axi4_cov extends uvm_subscriber #(axi4_slave_seq_item);
  `uvm_component_utils(axi4_cov)

  typedef enum { RGN_ICCM, RGN_DCCM, RGN_EXT, RGN_MBOX, RGN_OTHER } region_e;

  // Sampled fields.
  bit       s_wr;
  bit [1:0] s_burst;
  bit [7:0] s_len;
  bit [2:0] s_size;
  bit [1:0] s_resp;
  region_e  s_rgn;

  covergroup cg;
    option.per_instance = 1;

    cp_dir: coverpoint s_wr        { bins rd = {0}; bins wr = {1}; }
    cp_burst: coverpoint s_burst   { bins fixed = {0}; bins incr = {1}; bins wrap = {2}; }
    cp_len: coverpoint s_len       { bins l1 = {0}; bins l2 = {1}; bins l4 = {3};
                                     bins l8 = {7}; bins other = default; }
    cp_size: coverpoint s_size     { bins b1 = {0}; bins b2 = {1}; bins b4 = {2}; bins b8 = {3}; }
    cp_resp: coverpoint s_resp     { bins okay = {0}; bins exokay = {1};
                                     bins slverr = {2}; bins decerr = {3}; }
    cp_region: coverpoint s_rgn;

    x_burst_len:   cross cp_burst, cp_len;
    x_region_resp: cross cp_region, cp_resp;
    x_dir_burst:   cross cp_dir, cp_burst;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  function region_e region_of(bit [31:0] a);
`ifdef RV_ICCM_ENABLE
    if (a >= `RV_ICCM_SADR && a <= `RV_ICCM_EADR) return RGN_ICCM;
`endif
`ifdef RV_DCCM_ENABLE
    if (a >= `RV_DCCM_SADR && a <= `RV_DCCM_EADR) return RGN_DCCM;
`endif
    if (a == 32'hD0580000) return RGN_MBOX;
    if (a < 32'hC000_0000) return RGN_EXT;
    return RGN_OTHER;
  endfunction

  function void write(axi4_slave_seq_item t);
    s_wr    = t.is_write;
    s_burst = t.burst;
    s_len   = t.len;
    s_size  = t.size;
    s_resp  = t.resp;
    s_rgn   = region_of(t.addr);
    cg.sample();
  endfunction

endclass

`endif // AXI4_COV_SV
