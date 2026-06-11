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
// axi4_if : parameterized AXI4 interface for the VeeR EH2 bus/SoC integration
//           UVM environment. One instance is bound to each external AXI port
//           (IFU/LSU/SB masters, DMA slave). The signal set is the superset
//           used by the core; ports that don't drive the full AXI4 sideband
//           (e.g. the DMA slave: no region/lock/cache/qos) simply leave those
//           fields tied off at the bind site.
//
// The interface is kept VIP-compatible (flat signals + modports) so a
// commercial AXI VIP can be substituted later without touching the env.
//-----------------------------------------------------------------------------
`ifndef AXI4_IF_SV
`define AXI4_IF_SV

interface axi4_if #(
  parameter int ID_WIDTH   = 4,
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 64
) (
  input logic clk,
  input logic rst_l
);
  localparam int STRB_WIDTH = DATA_WIDTH/8;

  // Write address channel
  logic                   awvalid;
  logic                   awready;
  logic [ID_WIDTH-1:0]    awid;
  logic [ADDR_WIDTH-1:0]  awaddr;
  logic [3:0]             awregion;
  logic [7:0]             awlen;
  logic [2:0]             awsize;
  logic [1:0]             awburst;
  logic                   awlock;
  logic [3:0]             awcache;
  logic [2:0]             awprot;
  logic [3:0]             awqos;

  // Write data channel
  logic                   wvalid;
  logic                   wready;
  logic [DATA_WIDTH-1:0]  wdata;
  logic [STRB_WIDTH-1:0]  wstrb;
  logic                   wlast;

  // Write response channel
  logic                   bvalid;
  logic                   bready;
  logic [1:0]             bresp;
  logic [ID_WIDTH-1:0]    bid;

  // Read address channel
  logic                   arvalid;
  logic                   arready;
  logic [ID_WIDTH-1:0]    arid;
  logic [ADDR_WIDTH-1:0]  araddr;
  logic [3:0]             arregion;
  logic [7:0]             arlen;
  logic [2:0]             arsize;
  logic [1:0]             arburst;
  logic                   arlock;
  logic [3:0]             arcache;
  logic [2:0]             arprot;
  logic [3:0]             arqos;

  // Read data channel
  logic                   rvalid;
  logic                   rready;
  logic [ID_WIDTH-1:0]    rid;
  logic [DATA_WIDTH-1:0]  rdata;
  logic [1:0]             rresp;
  logic                   rlast;

  // Passive monitor: observes every signal. Used by all monitors (Phase 0+).
  modport passive_mon (
    input clk, rst_l,
    input awvalid, awready, awid, awaddr, awregion, awlen, awsize, awburst,
          awlock, awcache, awprot, awqos,
    input wvalid, wready, wdata, wstrb, wlast,
    input bvalid, bready, bresp, bid,
    input arvalid, arready, arid, araddr, arregion, arlen, arsize, arburst,
          arlock, arcache, arprot, arqos,
    input rvalid, rready, rid, rdata, rresp, rlast
  );

  // Slave-driver: drives slave-sourced signals, observes master-sourced ones.
  // Used by the IFU/LSU/SB slave responder agents (Phase 1+).
  modport slave_drv (
    input  clk, rst_l,
    input  awvalid, awid, awaddr, awregion, awlen, awsize, awburst, awlock,
           awcache, awprot, awqos,
    input  wvalid, wdata, wstrb, wlast,
    input  bready,
    input  arvalid, arid, araddr, arregion, arlen, arsize, arburst, arlock,
           arcache, arprot, arqos,
    input  rready,
    output awready, wready, bvalid, bresp, bid, arready, rvalid, rid, rdata,
           rresp, rlast
  );

  // Master-driver: drives master-sourced signals. Used by the DMA master agent
  // (Phase 2+) that drives the core's DMA slave port.
  modport master_drv (
    input  clk, rst_l,
    input  awready, wready, bvalid, bresp, bid, arready, rvalid, rid, rdata,
           rresp, rlast,
    output awvalid, awid, awaddr, awregion, awlen, awsize, awburst, awlock,
           awcache, awprot, awqos,
    output wvalid, wdata, wstrb, wlast,
    output bready,
    output arvalid, arid, araddr, arregion, arlen, arsize, arburst, arlock,
           arcache, arprot, arqos,
    output rready
  );
endinterface

`endif // AXI4_IF_SV
