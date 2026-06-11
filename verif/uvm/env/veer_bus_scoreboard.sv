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
// veer_bus_scoreboard : DMA memory-consistency checker.
//
// Subscribes to the DMA master monitor. It keeps a byte-level reference image
// of everything the DMA master has WRITTEN, then on every DMA READ compares the
// returned bytes (for addresses it has previously written) against that image.
// This verifies that data pushed through the core's DMA slave port lands in the
// CCM and reads back correctly — the core's DMA-controller/CCM integration.
//
// Addresses never written by the DMA master are skipped (their CCM contents are
// unknown to the scoreboard), so sequences should write-then-read-back to make
// the check fire (see axi4_master_seq_lib).
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_SCOREBOARD_SV
`define VEER_BUS_SCOREBOARD_SV

`uvm_analysis_imp_decl(_dma)

class veer_bus_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(veer_bus_scoreboard)

  uvm_analysis_imp_dma #(axi4_slave_seq_item, veer_bus_scoreboard) dma_imp;

  bit [7:0] ref_mem [bit[31:0]];
  bit       ref_vld [bit[31:0]];

  int unsigned n_writes;
  int unsigned n_reads;
  int unsigned n_bytes_checked;
  int unsigned n_mismatch;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    dma_imp = new("dma_imp", this);
  endfunction

  // Analysis write from the DMA monitor.
  function void write_dma(axi4_slave_seq_item t);
    if (t.is_write) apply_write(t);
    else            check_read(t);
  endfunction

  function void apply_write(axi4_slave_seq_item t);
    int unsigned bytes = (1 << t.size);
    n_writes++;
    for (int b = 0; b < t.data.size(); b++) begin
      bit [31:0] base = t.addr + (b * bytes);
      bit [31:0] wa   = {base[31:3], 3'b0};
      bit [7:0]  st   = (b < t.strb.size()) ? t.strb[b] : 8'hff;
      for (int i = 0; i < 8; i++)
        if (st[i]) begin
          ref_mem[wa + i] = t.data[b][i*8 +: 8];
          ref_vld[wa + i] = 1'b1;
        end
    end
  endfunction

  function void check_read(axi4_slave_seq_item t);
    int unsigned bytes = (1 << t.size);
    n_reads++;
    for (int b = 0; b < t.data.size(); b++) begin
      bit [31:0] base = t.addr + (b * bytes);
      bit [31:0] ra   = {base[31:3], 3'b0};
      for (int i = 0; i < 8; i++)
        if (ref_vld[ra + i]) begin
          bit [7:0] exp = ref_mem[ra + i];
          bit [7:0] act = t.data[b][i*8 +: 8];
          n_bytes_checked++;
          if (exp !== act) begin
            n_mismatch++;
            `uvm_error(get_type_name(),
              $sformatf("DMA read mismatch @0x%08h beat%0d byte%0d: exp=0x%02h act=0x%02h",
                        ra + i, b, i, exp, act))
          end
        end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_type_name(),
      $sformatf("DMA scoreboard: writes=%0d reads=%0d bytes_checked=%0d mismatches=%0d",
                n_writes, n_reads, n_bytes_checked, n_mismatch), UVM_LOW)
    if (n_bytes_checked == 0)
      `uvm_warning(get_type_name(),
        "DMA scoreboard performed no read-back checks (no write-then-read traffic?)")
  endfunction

endclass

`endif // VEER_BUS_SCOREBOARD_SV
