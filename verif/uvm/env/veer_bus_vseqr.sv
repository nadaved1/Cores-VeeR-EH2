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
// veer_bus_vseqr : virtual sequencer holding handles to the leaf sequencers a
// virtual sequence coordinates. Today that is just the DMA master sequencer
// (null when the DMA master is not active).
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_VSEQR_SV
`define VEER_BUS_VSEQR_SV

class veer_bus_vseqr extends uvm_sequencer;
  `uvm_component_utils(veer_bus_vseqr)

  axi4_master_sequencer dma_seqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif // VEER_BUS_VSEQR_SV
