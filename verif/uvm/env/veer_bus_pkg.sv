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
// veer_bus_pkg : single package gathering the VeeR EH2 bus/SoC integration UVM
//                environment. Phase 0 contains the config object, an (empty)
//                env, and the base + smoke tests. Agents, scoreboard, vseqr,
//                sequence libraries and coverage are added in later phases.
//-----------------------------------------------------------------------------
`ifndef VEER_BUS_PKG_SV
`define VEER_BUS_PKG_SV

package veer_bus_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // axi4 slave agent (reactive responder + passive monitor)
  `include "axi4_slave_seq_item.sv"
  `include "axi4_slave_mem.sv"
  `include "axi4_slave_cfg.sv"
  `include "axi4_slave_sequencer.sv"
  `include "axi4_slave_monitor.sv"
  `include "axi4_slave_driver.sv"
  `include "axi4_slave_agent.sv"

  // axi4 master agent (DMA master) + its sequences
  `include "axi4_master_seq_item.sv"
  `include "axi4_master_cfg.sv"
  `include "axi4_master_sequencer.sv"
  `include "axi4_master_driver.sv"
  `include "axi4_master_agent.sv"
  `include "axi4_master_seq_lib.sv"

  // coverage + scoreboard
  `include "axi4_cov.sv"
  `include "veer_bus_scoreboard.sv"

  // environment config, virtual sequencer/sequences, env
  `include "veer_bus_cfg.sv"
  `include "veer_bus_vseqr.sv"
  `include "veer_bus_vseq_lib.sv"
  `include "veer_bus_env.sv"

  // tests
  `include "veer_bus_base_test.sv"
  `include "veer_bus_smoke_test.sv"
  `include "veer_bus_dma_test.sv"
  `include "veer_bus_stress_test.sv"
endpackage

`endif // VEER_BUS_PKG_SV
