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
// axi4_slave_mem : byte-addressable golden memory backing a slave responder.
//
// Behaviour is a 1:1 port of the proven testbench/ahb_sif.sv `axi_slv` memory:
//   - reads return the full 8-byte word at the 8-aligned address (AxSIZE is not
//     used to mask the read; the master extracts the bytes it needs);
//   - writes apply WSTRB byte enables at the 8-aligned address;
//   - unwritten locations read as 0 (2-state `bit`).
// Preloaded from program.hex via $readmemh, exactly as `axi_slv.mem` was.
//-----------------------------------------------------------------------------
`ifndef AXI4_SLAVE_MEM_SV
`define AXI4_SLAVE_MEM_SV

class axi4_slave_mem extends uvm_object;

  bit [7:0] mem [bit[31:0]];

  `uvm_object_utils(axi4_slave_mem)

  function new(string name = "axi4_slave_mem");
    super.new(name);
  endfunction

  // Load a Verilog hex image (objcopy -O verilog byte format), same call the
  // original testbench used: $readmemh("program.hex", lmem.mem).
  function void load(string filename);
    $readmemh(filename, mem);
  endfunction

  // 64-bit read of the 8-aligned word containing `addr`.
  function bit [63:0] read64(bit [31:0] addr);
    bit [31:0] a = {addr[31:3], 3'b0};
    return {mem[a+7], mem[a+6], mem[a+5], mem[a+4],
            mem[a+3], mem[a+2], mem[a+1], mem[a+0]};
  endfunction

  // 64-bit strobed write to the 8-aligned word containing `addr`.
  function void write64(bit [31:0] addr, bit [63:0] data, bit [7:0] strb);
    bit [31:0] a = {addr[31:3], 3'b0};
    if (strb[7]) mem[a+7] = data[63:56];
    if (strb[6]) mem[a+6] = data[55:48];
    if (strb[5]) mem[a+5] = data[47:40];
    if (strb[4]) mem[a+4] = data[39:32];
    if (strb[3]) mem[a+3] = data[31:24];
    if (strb[2]) mem[a+2] = data[23:16];
    if (strb[1]) mem[a+1] = data[15:08];
    if (strb[0]) mem[a+0] = data[07:00];
  endfunction

endclass

`endif // AXI4_SLAVE_MEM_SV
