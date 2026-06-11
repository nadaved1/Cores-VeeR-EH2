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
// clk_en_if : carries the four VeeR EH2 bus clock-enable strobes
//             (lsu/ifu/dbg/dma_bus_clk_en). They are tied to 1'b1 today; the
//             clock-ratio sequences (Phase 3) drive them so bus agents can be
//             told to advance stimulus only on the enabled beat.
//-----------------------------------------------------------------------------
`ifndef CLK_EN_IF_SV
`define CLK_EN_IF_SV

interface clk_en_if (
  input logic clk,
  input logic rst_l
);
  logic lsu_bus_clk_en;
  logic ifu_bus_clk_en;
  logic dbg_bus_clk_en;
  logic dma_bus_clk_en;
endinterface

`endif // CLK_EN_IF_SV
