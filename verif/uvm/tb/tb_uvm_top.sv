// SPDX-License-Identifier: Apache-2.0
// Copyright 2019,2020,2026 Western Digital Corporation or its affiliates.
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
// tb_uvm_top : UVM top for the VeeR EH2 bus/SoC integration environment.
//
// This is the UVM-flow counterpart of testbench/tb_top.sv (which is left
// untouched and remains the Verilator/directed-test top). It mirrors tb_top:
// same DUT instance, program preload, trace/console logging, and (for Phase 0)
// the same static RTL bus slaves so a program runs to completion exactly as
// before. On top of that it:
//   - instantiates one axi4_if per external AXI port (IFU/LSU/SB/DMA), a
//     clk_en_if, and a veer_eot_if, all published to the UVM config DB;
//   - replaces the program's $finish-on-mailbox with a veer_eot_if hand-off so
//     the UVM test ends its run_phase cleanly and a full UVM report is printed;
//   - calls run_test() so +UVM_TESTNAME selects the test.
//
// The top-level instance name differs from tb_top, so the TOP / RV_TOP /
// CPU_TOP hierarchy macros (baked to tb_top.* in common_defines.vh) are
// redefined here before any hierarchical reference.
//-----------------------------------------------------------------------------

`ifdef UVM
`undef TOP
`define TOP tb_uvm_top
`endif

module tb_uvm_top;

`ifdef UVM
    import uvm_pkg::*;
    import veer_bus_pkg::*;
`include "uvm_macros.svh"
`endif

    bit                         core_clk;
    logic                       rst_l;
    logic                       porst_l;
    logic                       nmi_int;

    logic        [31:0]         reset_vector;
    logic        [31:0]         nmi_vector;
    logic        [31:1]         jtag_id;

// AHB
    logic        [31:0]         ic_haddr;
    logic        [2:0]          ic_hburst;
    logic        [3:0]          ic_hprot;
    logic        [2:0]          ic_hsize;
    logic        [1:0]          ic_htrans;
    logic                       ic_hwrite;
    logic        [63:0]         ic_hrdata;
    logic                       ic_hready;
    logic                       ic_hresp;

    logic        [31:0]         lsu_haddr;
    logic        [2:0]          lsu_hburst;
    logic        [3:0]          lsu_hprot;
    logic        [2:0]          lsu_hsize;
    logic        [1:0]          lsu_htrans;
    logic                       lsu_hwrite;
    logic        [63:0]         lsu_hrdata;
    logic        [63:0]         lsu_hwdata;
    logic                       lsu_hready;
    logic                       lsu_hresp;

    logic [`RV_NUM_THREADS-1:0][63:0]    trace_rv_i_insn_ip;
    logic [`RV_NUM_THREADS-1:0][63:0]    trace_rv_i_address_ip;
    logic [`RV_NUM_THREADS-1:0][1:0]     trace_rv_i_valid_ip;
    logic [`RV_NUM_THREADS-1:0][1:0]     trace_rv_i_exception_ip;
    logic [`RV_NUM_THREADS-1:0][4:0]     trace_rv_i_ecause_ip;
    logic [`RV_NUM_THREADS-1:0][1:0]     trace_rv_i_interrupt_ip;
    logic [`RV_NUM_THREADS-1:0][31:0]    trace_rv_i_tval_ip;

    logic                       o_debug_mode_status;


    logic                       jtag_tdo;
    logic                       o_cpu_halt_ack;
    logic                       o_cpu_halt_status;
    logic                       o_cpu_run_ack;

    logic                       mailbox_write;
    logic        [63:0]         dma_hrdata;
    logic        [63:0]         dma_hwdata;
    logic                       dma_hready;
    logic                       dma_hresp;

    logic                       mpc_debug_halt_req;
    logic                       mpc_debug_run_req;
    logic                       mpc_reset_run_req;
    logic                       mpc_debug_halt_ack;
    logic                       mpc_debug_run_ack;
    logic                       debug_brkpt_status;

    bit        [31:0]           cycleCnt;
    logic                       mailbox_data_val;

    wire                        dma_hready_out;
    int                         commit_count[2];

    logic [1:0]                 wb_valid;
    logic [1:0][4:0]            wb_dest;
    logic [1:0][31:0]           wb_data;
    logic [1:0]                 wb_tid;

   //-------------------------- LSU AXI signals--------------------------
   // AXI Write Channels
    wire                        lsu_axi_awvalid;
    wire                        lsu_axi_awready;
    wire [`RV_LSU_BUS_TAG-1:0]  lsu_axi_awid;
    wire [31:0]                 lsu_axi_awaddr;
    wire [3:0]                  lsu_axi_awregion;
    wire [7:0]                  lsu_axi_awlen;
    wire [2:0]                  lsu_axi_awsize;
    wire [1:0]                  lsu_axi_awburst;
    wire                        lsu_axi_awlock;
    wire [3:0]                  lsu_axi_awcache;
    wire [2:0]                  lsu_axi_awprot;
    wire [3:0]                  lsu_axi_awqos;

    wire                        lsu_axi_wvalid;
    wire                        lsu_axi_wready;
    wire [63:0]                 lsu_axi_wdata;
    wire [7:0]                  lsu_axi_wstrb;
    wire                        lsu_axi_wlast;

    wire                        lsu_axi_bvalid;
    wire                        lsu_axi_bready;
    wire [1:0]                  lsu_axi_bresp;
    wire [`RV_LSU_BUS_TAG-1:0]  lsu_axi_bid;

    // AXI Read Channels
    wire                        lsu_axi_arvalid;
    wire                        lsu_axi_arready;
    wire [`RV_LSU_BUS_TAG-1:0]  lsu_axi_arid;
    wire [31:0]                 lsu_axi_araddr;
    wire [3:0]                  lsu_axi_arregion;
    wire [7:0]                  lsu_axi_arlen;
    wire [2:0]                  lsu_axi_arsize;
    wire [1:0]                  lsu_axi_arburst;
    wire                        lsu_axi_arlock;
    wire [3:0]                  lsu_axi_arcache;
    wire [2:0]                  lsu_axi_arprot;
    wire [3:0]                  lsu_axi_arqos;

    wire                        lsu_axi_rvalid;
    wire                        lsu_axi_rready;
    wire [`RV_LSU_BUS_TAG-1:0]  lsu_axi_rid;
    wire [63:0]                 lsu_axi_rdata;
    wire [1:0]                  lsu_axi_rresp;
    wire                        lsu_axi_rlast;

    //-------------------------- IFU AXI signals--------------------------
    // AXI Write Channels
    wire                        ifu_axi_awvalid;
    wire                        ifu_axi_awready;
    wire [`RV_IFU_BUS_TAG-1:0]  ifu_axi_awid;
    wire [31:0]                 ifu_axi_awaddr;
    wire [3:0]                  ifu_axi_awregion;
    wire [7:0]                  ifu_axi_awlen;
    wire [2:0]                  ifu_axi_awsize;
    wire [1:0]                  ifu_axi_awburst;
    wire                        ifu_axi_awlock;
    wire [3:0]                  ifu_axi_awcache;
    wire [2:0]                  ifu_axi_awprot;
    wire [3:0]                  ifu_axi_awqos;

    wire                        ifu_axi_wvalid;
    wire                        ifu_axi_wready;
    wire [63:0]                 ifu_axi_wdata;
    wire [7:0]                  ifu_axi_wstrb;
    wire                        ifu_axi_wlast;

    wire                        ifu_axi_bvalid;
    wire                        ifu_axi_bready;
    wire [1:0]                  ifu_axi_bresp;
    wire [`RV_IFU_BUS_TAG-1:0]  ifu_axi_bid;

    // AXI Read Channels
    wire                        ifu_axi_arvalid;
    wire                        ifu_axi_arready;
    wire [`RV_IFU_BUS_TAG-1:0]  ifu_axi_arid;
    wire [31:0]                 ifu_axi_araddr;
    wire [3:0]                  ifu_axi_arregion;
    wire [7:0]                  ifu_axi_arlen;
    wire [2:0]                  ifu_axi_arsize;
    wire [1:0]                  ifu_axi_arburst;
    wire                        ifu_axi_arlock;
    wire [3:0]                  ifu_axi_arcache;
    wire [2:0]                  ifu_axi_arprot;
    wire [3:0]                  ifu_axi_arqos;

    wire                        ifu_axi_rvalid;
    wire                        ifu_axi_rready;
    wire [`RV_IFU_BUS_TAG-1:0]  ifu_axi_rid;
    wire [63:0]                 ifu_axi_rdata;
    wire [1:0]                  ifu_axi_rresp;
    wire                        ifu_axi_rlast;

    //-------------------------- SB AXI signals--------------------------
    // AXI Write Channels
    wire                        sb_axi_awvalid;
    wire                        sb_axi_awready;
    wire [`RV_SB_BUS_TAG-1:0]   sb_axi_awid;
    wire [31:0]                 sb_axi_awaddr;
    wire [3:0]                  sb_axi_awregion;
    wire [7:0]                  sb_axi_awlen;
    wire [2:0]                  sb_axi_awsize;
    wire [1:0]                  sb_axi_awburst;
    wire                        sb_axi_awlock;
    wire [3:0]                  sb_axi_awcache;
    wire [2:0]                  sb_axi_awprot;
    wire [3:0]                  sb_axi_awqos;

    wire                        sb_axi_wvalid;
    wire                        sb_axi_wready;
    wire [63:0]                 sb_axi_wdata;
    wire [7:0]                  sb_axi_wstrb;
    wire                        sb_axi_wlast;

    wire                        sb_axi_bvalid;
    wire                        sb_axi_bready;
    wire [1:0]                  sb_axi_bresp;
    wire [`RV_SB_BUS_TAG-1:0]   sb_axi_bid;

    // AXI Read Channels
    wire                        sb_axi_arvalid;
    wire                        sb_axi_arready;
    wire [`RV_SB_BUS_TAG-1:0]   sb_axi_arid;
    wire [31:0]                 sb_axi_araddr;
    wire [3:0]                  sb_axi_arregion;
    wire [7:0]                  sb_axi_arlen;
    wire [2:0]                  sb_axi_arsize;
    wire [1:0]                  sb_axi_arburst;
    wire                        sb_axi_arlock;
    wire [3:0]                  sb_axi_arcache;
    wire [2:0]                  sb_axi_arprot;
    wire [3:0]                  sb_axi_arqos;

    wire                        sb_axi_rvalid;
    wire                        sb_axi_rready;
    wire [`RV_SB_BUS_TAG-1:0]   sb_axi_rid;
    wire [63:0]                 sb_axi_rdata;
    wire [1:0]                  sb_axi_rresp;
    wire                        sb_axi_rlast;

   //-------------------------- DMA AXI signals--------------------------
   // AXI Write Channels
    wire                        dma_axi_awvalid;
    wire                        dma_axi_awready;
    wire [`RV_DMA_BUS_TAG-1:0]  dma_axi_awid;
    wire [31:0]                 dma_axi_awaddr;
    wire [2:0]                  dma_axi_awsize;
    wire [2:0]                  dma_axi_awprot;
    wire [7:0]                  dma_axi_awlen;
    wire [1:0]                  dma_axi_awburst;


    wire                        dma_axi_wvalid;
    wire                        dma_axi_wready;
    wire [63:0]                 dma_axi_wdata;
    wire [7:0]                  dma_axi_wstrb;
    wire                        dma_axi_wlast;

    wire                        dma_axi_bvalid;
    wire                        dma_axi_bready;
    wire [1:0]                  dma_axi_bresp;
    wire [`RV_DMA_BUS_TAG-1:0]  dma_axi_bid;

    // AXI Read Channels
    wire                        dma_axi_arvalid;
    wire                        dma_axi_arready;
    wire [`RV_DMA_BUS_TAG-1:0]  dma_axi_arid;
    wire [31:0]                 dma_axi_araddr;
    wire [2:0]                  dma_axi_arsize;
    wire [2:0]                  dma_axi_arprot;
    wire [7:0]                  dma_axi_arlen;
    wire [1:0]                  dma_axi_arburst;

    wire                        dma_axi_rvalid;
    wire                        dma_axi_rready;
    wire [`RV_DMA_BUS_TAG-1:0]  dma_axi_rid;
    wire [63:0]                 dma_axi_rdata;
    wire [1:0]                  dma_axi_rresp;
    wire                        dma_axi_rlast;

    wire                        lmem_axi_arvalid;
    wire                        lmem_axi_arready;

    wire                        lmem_axi_rvalid;
    wire [`RV_LSU_BUS_TAG-1:0]  lmem_axi_rid;
    wire [1:0]                  lmem_axi_rresp;
    wire [63:0]                 lmem_axi_rdata;
    wire                        lmem_axi_rlast;
    wire                        lmem_axi_rready;

    wire                        lmem_axi_awvalid;
    wire                        lmem_axi_awready;

    wire                        lmem_axi_wvalid;
    wire                        lmem_axi_wready;

    wire [1:0]                  lmem_axi_bresp;
    wire                        lmem_axi_bvalid;
    wire [`RV_LSU_BUS_TAG-1:0]  lmem_axi_bid;
    wire                        lmem_axi_bready;

    // Bridge port-s1 nets (the bridge's view of the DMA port). Connected to the
    // DMA port in loopback mode, or tied to accept-and-drop in DMA_UVM_MASTER.
    wire                        b_dma_awvalid;
    wire                        b_dma_awready;
    wire                        b_dma_wvalid;
    wire                        b_dma_wready;
    wire                        b_dma_bvalid;
    wire                        b_dma_bready;
    wire [1:0]                  b_dma_bresp;
    wire                        b_dma_arvalid;
    wire                        b_dma_arready;
    wire                        b_dma_rvalid;
    wire                        b_dma_rready;
    wire [1:0]                  b_dma_rresp;
    wire [63:0]                 b_dma_rdata;
    wire                        b_dma_rlast;


    string                      abi_reg[32]; // ABI register names
    wire[63:0]                  WriteData;
    wire                        tck, tms, tdi, tdo, trstn, srstn;
    wire [31:0]                 minstret[2], mcycle[2];

    // Backing image of program.hex for the ICCM/DCCM preload tasks. In the
    // original tb_top these reads came from the axi_slv lmem/imem memories;
    // those leaves are now UVM responders, so the preload uses this local copy
    // (imem and lmem were always loaded with the same program.hex).
    bit [7:0]                   hexmem [bit[31:0]];

`define DEC rvtop.veer.dec

    // Mailbox pass/fail/console status. In Phase 1 the static axi_slv `lmem` is
    // replaced by a UVM responder, so for the AXI4 build the mailbox is decoded
    // directly from the bus — identical semantics to axi_slv (a write to
    // MAILBOX_ADDR while out of reset). lmem_axi_awvalid is the bridge's
    // external-mem write-valid; the payload comes from the LSU master signals.
    // The AHB-Lite build still uses its ahb_sif `lmem` model.
`ifdef RV_BUILD_AXI4
    assign mailbox_write = lmem_axi_awvalid && (lsu_axi_awaddr == 32'hD0580000) && rst_l;
    assign WriteData     = lsu_axi_wdata;
`else
    assign mailbox_write = lmem.mailbox_write;
    assign WriteData     = lmem.WriteData;
`endif
    assign mailbox_data_val = WriteData[7:0] > 8'h5 && WriteData[7:0] < 8'h7f;

    assign minstret[0] = `DEC.tlu.tlumt[0].tlu.minstretl;
    assign mcycle[0]   = `DEC.tlu.tlumt[0].tlu.mcyclel;
    assign minstret[1] = `DEC.tlu.tlumt[`RV_NUM_THREADS-1].tlu.minstretl;
    assign mcycle[1]   = `DEC.tlu.tlumt[`RV_NUM_THREADS-1].tlu.mcyclel;


    parameter MAX_CYCLES = 10_000_000;

    integer fd, tp, el;

    always @(negedge core_clk) begin
        cycleCnt <= cycleCnt+1;
        // Test timeout monitor. $finish here is the hard backstop for a hung
        // run; it also flags the UVM test (eot) so the report still fires when
        // the program completes normally below.
        if(cycleCnt == MAX_CYCLES) begin
            $display ("Hit max cycle count (%0d) .. stopping",cycleCnt);
            eot.pass <= 1'b0;
            eot.seen <= 1'b1;
            $finish;
        end
        // console Monitor
        if( mailbox_data_val & mailbox_write) begin
            $fwrite(fd,"%c", WriteData[7:0]);
            $write("%c", WriteData[7:0]);
        end
        // End Of test monitor. Unlike tb_top, we do NOT $finish here: we hand
        // off to the UVM test via veer_eot_if so run_phase ends cleanly and a
        // full UVM report (incl. scoreboard verdict in later phases) prints.
        if(mailbox_write && WriteData[7:0] == 8'hff) begin
            $display("TEST_PASSED");
            $display("\nFinished hart0 : minstret = %0d, mcycle = %0d", minstret[0],mcycle[0]);
            if(`RV_NUM_THREADS == 2)
                $display("Finished hart1 : minstret = %0d, mcycle = %0d", minstret[1], mcycle[1]);
            $display("See \"exec.log\" for execution trace with register updates..\n");
            eot.pass <= 1'b1;
            eot.seen <= 1'b1;
        end
        else if(mailbox_write && WriteData[7:0] == 8'h1) begin
            $display("TEST_FAILED");
            eot.pass <= 1'b0;
            eot.seen <= 1'b1;
        end
    end


    // trace monitor
    always @(posedge core_clk) begin
         wb_valid[1:0]  <= '{`DEC.dec_i1_wen_wb,   `DEC.dec_i0_wen_wb};
         wb_dest        <= '{`DEC.dec_i1_waddr_wb, `DEC.dec_i0_waddr_wb};
         wb_data        <= '{`DEC.dec_i1_wdata_wb, `DEC.dec_i0_wdata_wb};
         wb_tid         <= '{`DEC.dec_i1_tid_wb,   `DEC.dec_i0_tid_wb};
         for(int t=0; t<`RV_NUM_THREADS; t++) begin
             if (trace_rv_i_valid_ip[t] !== 0) begin
                $fwrite(tp,"t%0d %b,%h,%h,%0h,%0h,3,%b,%h,%h,%b\n",t, trace_rv_i_valid_ip[t], trace_rv_i_address_ip[t][63:32], trace_rv_i_address_ip[t][31:0],
                       trace_rv_i_insn_ip[t][63:32], trace_rv_i_insn_ip[t][31:0],trace_rv_i_exception_ip[t],trace_rv_i_ecause_ip[t],
                       trace_rv_i_tval_ip[t],trace_rv_i_interrupt_ip[t]);
                // Basic trace - no exception register updates
                // #1 0 ee000000 b0201073 c 0b02       00000000
                for (int i=0; i<2; i++)
                    if (trace_rv_i_valid_ip[t][i]==1) begin
                        bit i0;
                        i0 = i != 0 || trace_rv_i_valid_ip[t]!=3 && wb_tid[1] == t && wb_valid[1];
                        commit_count[t]++;
                        $fwrite (el, "%10d : %8s %0d %h %h%13s ; %s\n",cycleCnt, $sformatf("#%0d",commit_count[t]), t,
                                trace_rv_i_address_ip[t][31+i*32 -:32], trace_rv_i_insn_ip[t][31+i*32-:32],
                                (wb_dest[i0] !=0 && wb_valid[i0]) ?  $sformatf("%s=%h", abi_reg[wb_dest[i0]], wb_data[i0]) : "             ",
                                dasm(trace_rv_i_insn_ip[t][31+i*32 -:32], trace_rv_i_address_ip[t][31+i*32-:32], wb_dest[i0] & {5{wb_valid[i0]}}, wb_data[i0], t)
                                );
                    end
            end
            if(`DEC.dec_nonblock_load_wen[t]) begin
                $fwrite (el, "%10d : %10d%22s=%h ; nbL\n", cycleCnt, `DEC.lsu_nonblock_load_data_tid, abi_reg[`DEC.dec_nonblock_load_waddr[t]], `DEC.lsu_nonblock_load_data);
                tb_uvm_top.gpr[t][`DEC.dec_nonblock_load_waddr[t]] = `DEC.lsu_nonblock_load_data;
            end
        end
        if(`DEC.exu_div_wren) begin
            $fwrite (el, "%10d : %10d%22s=%h ; nbD\n", cycleCnt, `DEC.div_tid_wb, abi_reg[`DEC.div_waddr_wb], `DEC.exu_div_result);
            tb_uvm_top.gpr[`DEC.div_tid_wb][`DEC.div_waddr_wb] = `DEC.exu_div_result;
        end
    end


    initial begin
        abi_reg[0] = "zero";
        abi_reg[1] = "ra";
        abi_reg[2] = "sp";
        abi_reg[3] = "gp";
        abi_reg[4] = "tp";
        abi_reg[5] = "t0";
        abi_reg[6] = "t1";
        abi_reg[7] = "t2";
        abi_reg[8] = "s0";
        abi_reg[9] = "s1";
        abi_reg[10] = "a0";
        abi_reg[11] = "a1";
        abi_reg[12] = "a2";
        abi_reg[13] = "a3";
        abi_reg[14] = "a4";
        abi_reg[15] = "a5";
        abi_reg[16] = "a6";
        abi_reg[17] = "a7";
        abi_reg[18] = "s2";
        abi_reg[19] = "s3";
        abi_reg[20] = "s4";
        abi_reg[21] = "s5";
        abi_reg[22] = "s6";
        abi_reg[23] = "s7";
        abi_reg[24] = "s8";
        abi_reg[25] = "s9";
        abi_reg[26] = "s10";
        abi_reg[27] = "s11";
        abi_reg[28] = "t3";
        abi_reg[29] = "t4";
        abi_reg[30] = "t5";
        abi_reg[31] = "t6";
    // tie offs
        jtag_id[31:28] = 4'b1;
        jtag_id[27:12] = '0;
        jtag_id[11:1]  = 11'h45;
        reset_vector = 32'h0;
        nmi_vector   = 32'hee000000;
        nmi_int   = 0;

        $readmemh("program.hex",  hexmem);
`ifdef RV_BUILD_AHB_LITE
        // AHB-Lite build still serves the bus from the ahb_sif imem/lmem models.
        $readmemh("program.hex",  lmem.mem);
        $readmemh("program.hex",  imem.mem);
`endif
        tp = $fopen("trace_port.csv","w");
        el = $fopen("exec.log","w");
        $fwrite (el, "//   Cycle : #inst  hart   pc    opcode    reg=value   ; mnemonic\n");
        $fwrite (el, "//---------------------------------------------------------------\n");
        fd = $fopen("console.log","w");
        preload_dccm();
        preload_iccm();

        if($test$plusargs("dumpon")) $dumpvars;
        forever  core_clk = #5 ~core_clk;
    end


    assign rst_l = cycleCnt > 5 && srstn;
    assign porst_l = cycleCnt > 2;

   //=========================================================================-
   // RTL instance
   //=========================================================================-
eh2_veer_wrapper rvtop (
    .rst_l                  ( rst_l),
    .dbg_rst_l              ( porst_l       ),
    .clk                    ( core_clk      ),
    .rst_vec                ( reset_vector[31:1]),
    .nmi_int                ( nmi_int       ),
    .nmi_vec                ( nmi_vector[31:1]),
    .jtag_id                ( jtag_id[31:1]),

`ifdef RV_BUILD_AHB_LITE
    .haddr                  ( ic_haddr      ),
    .hburst                 ( ic_hburst     ),
    .hmastlock              ( ),
    .hprot                  ( ic_hprot      ),
    .hsize                  ( ic_hsize      ),
    .htrans                 ( ic_htrans     ),
    .hwrite                 ( ic_hwrite     ),

    .hrdata                 ( ic_hrdata     ),
    .hready                 ( ic_hready     ),
    .hresp                  ( ic_hresp      ),

    //---------------------------------------------------------------
    // Debug AHB Master
    //---------------------------------------------------------------
    .sb_haddr               (),
    .sb_hburst              (),
    .sb_hmastlock           (),
    .sb_hprot               (),
    .sb_hsize               (),
    .sb_htrans              (),
    .sb_hwrite              (),
    .sb_hwdata              (),

    .sb_hrdata              ('0),
    .sb_hready              ('1),
    .sb_hresp               ('0),

    //---------------------------------------------------------------
    // LSU AHB Master
    //---------------------------------------------------------------
    .lsu_haddr              ( lsu_haddr       ),
    .lsu_hburst             ( lsu_hburst      ),
    .lsu_hmastlock          ( ),
    .lsu_hprot              ( lsu_hprot       ),
    .lsu_hsize              ( lsu_hsize       ),
    .lsu_htrans             ( lsu_htrans      ),
    .lsu_hwrite             ( lsu_hwrite      ),
    .lsu_hwdata             ( lsu_hwdata      ),

    .lsu_hrdata             ( lsu_hrdata      ),
    .lsu_hready             ( lsu_hready      ),
    .lsu_hresp              ( lsu_hresp       ),

    //---------------------------------------------------------------
    // DMA Slave
    //---------------------------------------------------------------
    .dma_haddr              ( '0 ),
    .dma_hburst             ( '0 ),
    .dma_hmastlock          ( '0 ),
    .dma_hprot              ( '0 ),
    .dma_hsize              ( '0 ),
    .dma_htrans             ( '0 ),
    .dma_hwrite             ( '0 ),
    .dma_hwdata             ( '0 ),

    .dma_hrdata             (),
    .dma_hresp              (),
    .dma_hsel               ( 1'b1 ),
    .dma_hreadyin           ( 1'b1 ),
    .dma_hreadyout          (),
`endif
`ifdef RV_BUILD_AXI4
//-------------------------- LSU AXI signals--------------------------
    // AXI Write Channels
    .lsu_axi_awvalid        (lsu_axi_awvalid),
    .lsu_axi_awready        (lsu_axi_awready),
    .lsu_axi_awid           (lsu_axi_awid),
    .lsu_axi_awaddr         (lsu_axi_awaddr),
    .lsu_axi_awregion       (lsu_axi_awregion),
    .lsu_axi_awlen          (lsu_axi_awlen),
    .lsu_axi_awsize         (lsu_axi_awsize),
    .lsu_axi_awburst        (lsu_axi_awburst),
    .lsu_axi_awlock         (lsu_axi_awlock),
    .lsu_axi_awcache        (lsu_axi_awcache),
    .lsu_axi_awprot         (lsu_axi_awprot),
    .lsu_axi_awqos          (lsu_axi_awqos),

    .lsu_axi_wvalid         (lsu_axi_wvalid),
    .lsu_axi_wready         (lsu_axi_wready),
    .lsu_axi_wdata          (lsu_axi_wdata),
    .lsu_axi_wstrb          (lsu_axi_wstrb),
    .lsu_axi_wlast          (lsu_axi_wlast),

    .lsu_axi_bvalid         (lsu_axi_bvalid),
    .lsu_axi_bready         (lsu_axi_bready),
    .lsu_axi_bresp          (lsu_axi_bresp),
    .lsu_axi_bid            (lsu_axi_bid),


    .lsu_axi_arvalid        (lsu_axi_arvalid),
    .lsu_axi_arready        (lsu_axi_arready),
    .lsu_axi_arid           (lsu_axi_arid),
    .lsu_axi_araddr         (lsu_axi_araddr),
    .lsu_axi_arregion       (lsu_axi_arregion),
    .lsu_axi_arlen          (lsu_axi_arlen),
    .lsu_axi_arsize         (lsu_axi_arsize),
    .lsu_axi_arburst        (lsu_axi_arburst),
    .lsu_axi_arlock         (lsu_axi_arlock),
    .lsu_axi_arcache        (lsu_axi_arcache),
    .lsu_axi_arprot         (lsu_axi_arprot),
    .lsu_axi_arqos          (lsu_axi_arqos),

    .lsu_axi_rvalid         (lsu_axi_rvalid),
    .lsu_axi_rready         (lsu_axi_rready),
    .lsu_axi_rid            (lsu_axi_rid),
    .lsu_axi_rdata          (lsu_axi_rdata),
    .lsu_axi_rresp          (lsu_axi_rresp),
    .lsu_axi_rlast          (lsu_axi_rlast),

    //-------------------------- IFU AXI signals--------------------------
    // AXI Write Channels
    .ifu_axi_awvalid        (ifu_axi_awvalid),
    .ifu_axi_awready        (ifu_axi_awready),
    .ifu_axi_awid           (ifu_axi_awid),
    .ifu_axi_awaddr         (ifu_axi_awaddr),
    .ifu_axi_awregion       (ifu_axi_awregion),
    .ifu_axi_awlen          (ifu_axi_awlen),
    .ifu_axi_awsize         (ifu_axi_awsize),
    .ifu_axi_awburst        (ifu_axi_awburst),
    .ifu_axi_awlock         (ifu_axi_awlock),
    .ifu_axi_awcache        (ifu_axi_awcache),
    .ifu_axi_awprot         (ifu_axi_awprot),
    .ifu_axi_awqos          (ifu_axi_awqos),

    .ifu_axi_wvalid         (ifu_axi_wvalid),
    .ifu_axi_wready         (ifu_axi_wready),
    .ifu_axi_wdata          (ifu_axi_wdata),
    .ifu_axi_wstrb          (ifu_axi_wstrb),
    .ifu_axi_wlast          (ifu_axi_wlast),

    .ifu_axi_bvalid         (ifu_axi_bvalid),
    .ifu_axi_bready         (ifu_axi_bready),
    .ifu_axi_bresp          (ifu_axi_bresp),
    .ifu_axi_bid            (ifu_axi_bid),

    .ifu_axi_arvalid        (ifu_axi_arvalid),
    .ifu_axi_arready        (ifu_axi_arready),
    .ifu_axi_arid           (ifu_axi_arid),
    .ifu_axi_araddr         (ifu_axi_araddr),
    .ifu_axi_arregion       (ifu_axi_arregion),
    .ifu_axi_arlen          (ifu_axi_arlen),
    .ifu_axi_arsize         (ifu_axi_arsize),
    .ifu_axi_arburst        (ifu_axi_arburst),
    .ifu_axi_arlock         (ifu_axi_arlock),
    .ifu_axi_arcache        (ifu_axi_arcache),
    .ifu_axi_arprot         (ifu_axi_arprot),
    .ifu_axi_arqos          (ifu_axi_arqos),

    .ifu_axi_rvalid         (ifu_axi_rvalid),
    .ifu_axi_rready         (ifu_axi_rready),
    .ifu_axi_rid            (ifu_axi_rid),
    .ifu_axi_rdata          (ifu_axi_rdata),
    .ifu_axi_rresp          (ifu_axi_rresp),
    .ifu_axi_rlast          (ifu_axi_rlast),

    //-------------------------- SB AXI signals--------------------------
    // AXI Write Channels
    .sb_axi_awvalid         (sb_axi_awvalid),
    .sb_axi_awready         (sb_axi_awready),
    .sb_axi_awid            (sb_axi_awid),
    .sb_axi_awaddr          (sb_axi_awaddr),
    .sb_axi_awregion        (sb_axi_awregion),
    .sb_axi_awlen           (sb_axi_awlen),
    .sb_axi_awsize          (sb_axi_awsize),
    .sb_axi_awburst         (sb_axi_awburst),
    .sb_axi_awlock          (sb_axi_awlock),
    .sb_axi_awcache         (sb_axi_awcache),
    .sb_axi_awprot          (sb_axi_awprot),
    .sb_axi_awqos           (sb_axi_awqos),

    .sb_axi_wvalid          (sb_axi_wvalid),
    .sb_axi_wready          (sb_axi_wready),
    .sb_axi_wdata           (sb_axi_wdata),
    .sb_axi_wstrb           (sb_axi_wstrb),
    .sb_axi_wlast           (sb_axi_wlast),

    .sb_axi_bvalid          (sb_axi_bvalid),
    .sb_axi_bready          (sb_axi_bready),
    .sb_axi_bresp           (sb_axi_bresp),
    .sb_axi_bid             (sb_axi_bid),


    .sb_axi_arvalid         (sb_axi_arvalid),
    .sb_axi_arready         (sb_axi_arready),
    .sb_axi_arid            (sb_axi_arid),
    .sb_axi_araddr          (sb_axi_araddr),
    .sb_axi_arregion        (sb_axi_arregion),
    .sb_axi_arlen           (sb_axi_arlen),
    .sb_axi_arsize          (sb_axi_arsize),
    .sb_axi_arburst         (sb_axi_arburst),
    .sb_axi_arlock          (sb_axi_arlock),
    .sb_axi_arcache         (sb_axi_arcache),
    .sb_axi_arprot          (sb_axi_arprot),
    .sb_axi_arqos           (sb_axi_arqos),

    .sb_axi_rvalid          (sb_axi_rvalid),
    .sb_axi_rready          (sb_axi_rready),
    .sb_axi_rid             (sb_axi_rid),
    .sb_axi_rdata           (sb_axi_rdata),
    .sb_axi_rresp           (sb_axi_rresp),
    .sb_axi_rlast           (sb_axi_rlast),

    //-------------------------- DMA AXI signals--------------------------
    // All DMA-port nets route through dma_axi_* wires; what drives the DUT
    // inputs (the RTL bridge loopback, or the UVM DMA master) is selected by
    // the DMA_UVM_MASTER define in the assign block further below.
    .dma_axi_awvalid        (dma_axi_awvalid),
    .dma_axi_awready        (dma_axi_awready),
    .dma_axi_awid           (dma_axi_awid),
    .dma_axi_awaddr         (dma_axi_awaddr),
    .dma_axi_awsize         (dma_axi_awsize),
    .dma_axi_awprot         (dma_axi_awprot),
    .dma_axi_awlen          (dma_axi_awlen),
    .dma_axi_awburst        (dma_axi_awburst),


    .dma_axi_wvalid         (dma_axi_wvalid),
    .dma_axi_wready         (dma_axi_wready),
    .dma_axi_wdata          (dma_axi_wdata),
    .dma_axi_wstrb          (dma_axi_wstrb),
    .dma_axi_wlast          (dma_axi_wlast),

    .dma_axi_bvalid         (dma_axi_bvalid),
    .dma_axi_bready         (dma_axi_bready),
    .dma_axi_bresp          (dma_axi_bresp),
    .dma_axi_bid            (dma_axi_bid),


    .dma_axi_arvalid        (dma_axi_arvalid),
    .dma_axi_arready        (dma_axi_arready),
    .dma_axi_arid           (dma_axi_arid),
    .dma_axi_araddr         (dma_axi_araddr),
    .dma_axi_arsize         (dma_axi_arsize),
    .dma_axi_arprot         (dma_axi_arprot),
    .dma_axi_arlen          (dma_axi_arlen),
    .dma_axi_arburst        (dma_axi_arburst),

    .dma_axi_rvalid         (dma_axi_rvalid),
    .dma_axi_rready         (dma_axi_rready),
    .dma_axi_rid            (dma_axi_rid),
    .dma_axi_rdata          (dma_axi_rdata),
    .dma_axi_rresp          (dma_axi_rresp),
    .dma_axi_rlast          (dma_axi_rlast),
`endif
    .timer_int              ( '0  ),
    .extintsrc_req          ( '0  ),

    .lsu_bus_clk_en         ( 1'b1  ),
    .ifu_bus_clk_en         ( 1'b1  ),
    .dbg_bus_clk_en         ( 1'b1  ),
    .dma_bus_clk_en         ( 1'b1  ),


    .dccm_ext_in_pkt        ('0),
    .iccm_ext_in_pkt        ('0),
    .ic_data_ext_in_pkt     ('0),
    .ic_tag_ext_in_pkt      ('0),
    .btb_ext_in_pkt         ('0),
    .trace_rv_i_insn_ip     (trace_rv_i_insn_ip),
    .trace_rv_i_address_ip  (trace_rv_i_address_ip),
    .trace_rv_i_valid_ip    (trace_rv_i_valid_ip),
    .trace_rv_i_exception_ip(trace_rv_i_exception_ip),
    .trace_rv_i_ecause_ip   (trace_rv_i_ecause_ip),
    .trace_rv_i_interrupt_ip(trace_rv_i_interrupt_ip),
    .trace_rv_i_tval_ip     (trace_rv_i_tval_ip),

    .jtag_tck               ( tck  ),
    .jtag_tms               ( tms  ),
    .jtag_tdi               ( tdi  ),
    .jtag_trst_n            ( trstn  ),
    .jtag_tdo               ( tdo ),

    .mpc_debug_halt_ack     ( ),
    .mpc_debug_halt_req     ('0),
    .mpc_debug_run_ack      (),
    .mpc_debug_run_req      ('1),
    .mpc_reset_run_req      ('1),
     .debug_brkpt_status    (),

    .i_cpu_halt_req         ('0),
    .o_cpu_halt_ack         (),
    .o_cpu_halt_status      (),
    .i_cpu_run_req          ('0),
    .o_debug_mode_status    (),
    .o_cpu_run_ack          (),

    .dec_tlu_perfcnt0       (),
    .dec_tlu_perfcnt1       (),
    .dec_tlu_perfcnt2       (),
    .dec_tlu_perfcnt3       (),
    .dec_tlu_mhartstart     (),

    .soft_int               ('0),
    .core_id                ('0),
    .scan_mode              ( 1'b0 ),
    .mbist_mode             ( 1'b0 )

);

bit openocd;
initial begin
    openocd = $test$plusargs("openocd");
end

SimJTAG #2 jtag_drv(

    .clock(core_clk),
    .reset(~porst_l),

    .enable(openocd),
    .init_done(porst_l),

    .jtag_TCK(tck),
    .jtag_TMS(tms),
    .jtag_TDI(tdi),
    .jtag_TRSTn(trstn),

    .jtag_TDO_data(tdo),
    .jtag_TDO_driven(1'b1),
    .srstn(srstn),

    .exit()
);


function string dmi_reg_name ( int ra);
    case(ra)
    'h4:  return "DATA0    ";
    'h5:  return "DATA1    ";
    'h10: return "DM_CNTL  ";
    'h11: return "DM_STATUS";
    'h15: return "HAWINDOW ";
    'h16: return "AB_CS    ";
    'h17: return "AB_CMD   ";
    'h38: return "SB_CS    ";
    'h39: return "SB_ADDR0 ";
    'h3c: return "SB_DATA0 ";
    'h3d: return "SB_DATA1 ";
    'h40: return "HALTSUM  ";
    default: return $sformatf("0x%0h   ", ra);
    endcase
endfunction

bit reg_read;
bit[7:0] reg_addr;

// Debug Module monitor
always @ (posedge core_clk) begin
    if(`CPU_TOP.dmi_reg_wr_en)
        $display("DM: %10d Write %s = %h", cycleCnt, dmi_reg_name(`CPU_TOP.dmi_reg_addr),`CPU_TOP.dmi_reg_wdata);
    reg_read <= `CPU_TOP.dmi_reg_en & ~`CPU_TOP.dmi_reg_wr_en;
    reg_addr <= `CPU_TOP.dmi_reg_addr;
    if(reg_read)
        $display("DM: %10d Read  %s = %h", cycleCnt, dmi_reg_name(reg_addr),`CPU_TOP.dmi_reg_rdata);
end

`ifdef RV_BUILD_AHB_LITE

ahb_sif imem (
     // Inputs
     .HWDATA(64'h0),
     .HCLK(core_clk),
     .HSEL(1'b1),
     .HPROT(ic_hprot),
     .HWRITE(ic_hwrite),
     .HTRANS(ic_htrans),
     .HSIZE(ic_hsize),
     .HREADY(ic_hready),
     .HRESETn(rst_l),
     .HADDR(ic_haddr),
     .HBURST(ic_hburst),

     // Outputs
     .HREADYOUT(ic_hready),
     .HRESP(ic_hresp),
     .HRDATA(ic_hrdata)
);


ahb_sif lmem (
     // Inputs
     .HWDATA(lsu_hwdata),
     .HCLK(core_clk),
     .HSEL(1'b1),
     .HPROT(lsu_hprot),
     .HWRITE(lsu_hwrite),
     .HTRANS(lsu_htrans),
     .HSIZE(lsu_hsize),
     .HREADY(lsu_hready),
     .HRESETn(rst_l),
     .HADDR(lsu_haddr),
     .HBURST(lsu_hburst),

     // Outputs
     .HREADYOUT(lsu_hready),
     .HRESP(lsu_hresp),
     .HRDATA(lsu_hrdata)
);

`endif


`ifdef RV_BUILD_AXI4

// Phase 1: the static axi_slv imem/lmem leaves are replaced by UVM slave
// responder agents. The IFU port is served via `ifu_if` (declared in the UVM
// section below); the LSU external-memory leaf (bridge port s0) is served via
// `lmem_if` declared here. The axi_lsu_dma_bridge (and the DMA loopback) is
// unchanged, so LSU-to-ICCM traffic still routes through the DMA path.

// LSU external-memory leaf interface, driven by the lmem slave agent.
axi4_if lmem_if (.clk(core_clk), .rst_l(rst_l));

// Observed (master side of the leaf): handshake from the bridge s0 port,
// payload from the LSU master signals (exactly the inputs axi_slv lmem used).
assign lmem_if.arvalid  = lmem_axi_arvalid;
assign lmem_if.araddr   = lsu_axi_araddr;
assign lmem_if.arid     = lsu_axi_arid;
assign lmem_if.arlen    = lsu_axi_arlen;
assign lmem_if.arsize   = lsu_axi_arsize;
assign lmem_if.arburst  = lsu_axi_arburst;
assign lmem_if.arregion = '0; assign lmem_if.arlock = '0;
assign lmem_if.arcache  = '0; assign lmem_if.arprot = '0; assign lmem_if.arqos = '0;
assign lmem_if.rready   = lmem_axi_rready;
assign lmem_if.awvalid  = lmem_axi_awvalid;
assign lmem_if.awaddr   = lsu_axi_awaddr;
assign lmem_if.awid     = lsu_axi_awid;
assign lmem_if.awlen    = lsu_axi_awlen;
assign lmem_if.awsize   = lsu_axi_awsize;
assign lmem_if.awburst  = lsu_axi_awburst;
assign lmem_if.awregion = '0; assign lmem_if.awlock = '0;
assign lmem_if.awcache  = '0; assign lmem_if.awprot = '0; assign lmem_if.awqos = '0;
assign lmem_if.wvalid   = lmem_axi_wvalid;
assign lmem_if.wdata    = lsu_axi_wdata;
assign lmem_if.wstrb    = lsu_axi_wstrb;
assign lmem_if.wlast    = lsu_axi_wlast;
assign lmem_if.bready   = lmem_axi_bready;

// Driven (slave side of the leaf): back into the bridge s0 port.
assign lmem_axi_arready = lmem_if.arready;
assign lmem_axi_rvalid  = lmem_if.rvalid;
assign lmem_axi_rid     = lmem_if.rid;
assign lmem_axi_rresp   = lmem_if.rresp;
assign lmem_axi_rdata   = lmem_if.rdata;
assign lmem_axi_rlast   = lmem_if.rlast;
assign lmem_axi_awready = lmem_if.awready;
assign lmem_axi_wready  = lmem_if.wready;
assign lmem_axi_bvalid  = lmem_if.bvalid;
assign lmem_axi_bid     = lmem_if.bid;
assign lmem_axi_bresp   = lmem_if.bresp;


axi_lsu_dma_bridge # (`RV_LSU_BUS_TAG,`RV_LSU_BUS_TAG ) bridge(
    .clk(core_clk),
    .reset_l(rst_l),

    .m_arvalid(lsu_axi_arvalid),
    .m_arid(lsu_axi_arid),
    .m_araddr(lsu_axi_araddr),
    .m_arready(lsu_axi_arready),

    .m_rvalid(lsu_axi_rvalid),
    .m_rready(lsu_axi_rready),
    .m_rdata(lsu_axi_rdata),
    .m_rid(lsu_axi_rid),
    .m_rresp(lsu_axi_rresp),
    .m_rlast(lsu_axi_rlast),

    .m_awvalid(lsu_axi_awvalid),
    .m_awid(lsu_axi_awid),
    .m_awaddr(lsu_axi_awaddr),
    .m_awready(lsu_axi_awready),

    .m_wvalid(lsu_axi_wvalid),
    .m_wready(lsu_axi_wready),

    .m_bresp(lsu_axi_bresp),
    .m_bvalid(lsu_axi_bvalid),
    .m_bid(lsu_axi_bid),
    .m_bready(lsu_axi_bready),

    .s0_arvalid(lmem_axi_arvalid),
    .s0_arready(lmem_axi_arready),

    .s0_rvalid(lmem_axi_rvalid),
    .s0_rid(lmem_axi_rid),
    .s0_rresp(lmem_axi_rresp),
    .s0_rdata(lmem_axi_rdata),
    .s0_rlast(lmem_axi_rlast),
    .s0_rready(lmem_axi_rready),

    .s0_awvalid(lmem_axi_awvalid),
    .s0_awready(lmem_axi_awready),

    .s0_wvalid(lmem_axi_wvalid),
    .s0_wready(lmem_axi_wready),

    .s0_bresp(lmem_axi_bresp),
    .s0_bvalid(lmem_axi_bvalid),
    .s0_bid(lmem_axi_bid),
    .s0_bready(lmem_axi_bready),


    // Bridge port s1 connects to the b_dma_* nets, not directly to the DMA
    // port. The DMA-port driver select (loopback vs UVM master) is in the
    // assign block below.
    .s1_arvalid(b_dma_arvalid),
    .s1_arready(b_dma_arready),

    .s1_rvalid(b_dma_rvalid),
    .s1_rresp(b_dma_rresp),
    .s1_rdata(b_dma_rdata),
    .s1_rlast(b_dma_rlast),
    .s1_rready(b_dma_rready),

    .s1_awvalid(b_dma_awvalid),
    .s1_awready(b_dma_awready),

    .s1_wvalid(b_dma_wvalid),
    .s1_wready(b_dma_wready),

    .s1_bresp(b_dma_bresp),
    .s1_bvalid(b_dma_bvalid),
    .s1_bready(b_dma_bready)
);

// ----------------------------------------------------------------------------
// DMA-port driver select.
//   - default (loopback): the RTL bridge s1 drives the DMA port handshakes and
//     the LSU master signals supply the payload — exactly the original tb_top
//     behaviour, so LSU-to-ICCM traffic still works.
//   - DMA_UVM_MASTER: the UVM DMA master agent (dma_if) drives the DMA port;
//     the bridge s1 is tied to accept-and-drop (LSU-to-ICCM is unsupported in
//     this mode — use programs that don't store to ICCM).
// ----------------------------------------------------------------------------
`ifndef DMA_UVM_MASTER
    // Loopback: bridge s1 -> DMA-port handshakes; LSU master -> payload.
    assign dma_axi_awvalid = b_dma_awvalid;  assign b_dma_awready = dma_axi_awready;
    assign dma_axi_wvalid  = b_dma_wvalid;   assign b_dma_wready  = dma_axi_wready;
    assign dma_axi_bready  = b_dma_bready;    assign b_dma_bvalid  = dma_axi_bvalid;
    assign b_dma_bresp     = dma_axi_bresp;
    assign dma_axi_arvalid = b_dma_arvalid;  assign b_dma_arready = dma_axi_arready;
    assign dma_axi_rready  = b_dma_rready;    assign b_dma_rvalid  = dma_axi_rvalid;
    assign b_dma_rresp     = dma_axi_rresp;   assign b_dma_rdata   = dma_axi_rdata;
    assign b_dma_rlast     = dma_axi_rlast;
    assign dma_axi_awid    = '0;             assign dma_axi_arid   = '0;
    assign dma_axi_awaddr  = lsu_axi_awaddr;  assign dma_axi_awsize = lsu_axi_awsize;
    assign dma_axi_awprot  = lsu_axi_awprot;  assign dma_axi_awlen  = lsu_axi_awlen;
    assign dma_axi_awburst = lsu_axi_awburst;
    assign dma_axi_wdata   = lsu_axi_wdata;   assign dma_axi_wstrb  = lsu_axi_wstrb;
    assign dma_axi_wlast   = lsu_axi_wlast;
    assign dma_axi_araddr  = lsu_axi_araddr;  assign dma_axi_arsize = lsu_axi_arsize;
    assign dma_axi_arprot  = lsu_axi_arprot;  assign dma_axi_arlen  = lsu_axi_arlen;
    assign dma_axi_arburst = lsu_axi_arburst;
`endif

`endif

//=========================================================================-
// UVM bus interfaces, end-of-test hand-off, and run_test()
//
// Phase 1: the IFU port and the LSU external-memory leaf (lmem_if, declared in
// the bridge section above) are served by ACTIVE UVM slave responder agents.
// The LSU master port, SB and DMA ports are passively monitored. All ports use
// the default axi4_if width (ID_WIDTH=4), so a single non-parameterized slave
// agent type drives/monitors any of them.
//=========================================================================-
`ifdef UVM
`ifdef RV_BUILD_AXI4
    axi4_if ifu_if (.clk(core_clk), .rst_l(rst_l));
    axi4_if lsu_if (.clk(core_clk), .rst_l(rst_l));
    axi4_if sb_if  (.clk(core_clk), .rst_l(rst_l));
    axi4_if dma_if (.clk(core_clk), .rst_l(rst_l));

    // IFU port: observe master-sourced signals, DRIVE slave-sourced signals
    // back to the DUT (the ifu slave agent serves instruction fetches).
    assign ifu_if.awvalid = ifu_axi_awvalid; assign ifu_if.awid    = ifu_axi_awid;
    assign ifu_if.awaddr  = ifu_axi_awaddr;  assign ifu_if.awregion= ifu_axi_awregion;
    assign ifu_if.awlen   = ifu_axi_awlen;   assign ifu_if.awsize  = ifu_axi_awsize;
    assign ifu_if.awburst = ifu_axi_awburst; assign ifu_if.awlock  = ifu_axi_awlock;
    assign ifu_if.awcache = ifu_axi_awcache; assign ifu_if.awprot  = ifu_axi_awprot;
    assign ifu_if.awqos   = ifu_axi_awqos;
    assign ifu_if.wvalid  = ifu_axi_wvalid;  assign ifu_if.wdata   = ifu_axi_wdata;
    assign ifu_if.wstrb   = ifu_axi_wstrb;   assign ifu_if.wlast   = ifu_axi_wlast;
    assign ifu_if.bready  = ifu_axi_bready;
    assign ifu_if.arvalid = ifu_axi_arvalid; assign ifu_if.arid    = ifu_axi_arid;
    assign ifu_if.araddr  = ifu_axi_araddr;  assign ifu_if.arregion= ifu_axi_arregion;
    assign ifu_if.arlen   = ifu_axi_arlen;   assign ifu_if.arsize  = ifu_axi_arsize;
    assign ifu_if.arburst = ifu_axi_arburst; assign ifu_if.arlock  = ifu_axi_arlock;
    assign ifu_if.arcache = ifu_axi_arcache; assign ifu_if.arprot  = ifu_axi_arprot;
    assign ifu_if.arqos   = ifu_axi_arqos;   assign ifu_if.rready  = ifu_axi_rready;
    // driven back into the DUT
    assign ifu_axi_awready = ifu_if.awready; assign ifu_axi_wready  = ifu_if.wready;
    assign ifu_axi_bvalid  = ifu_if.bvalid;  assign ifu_axi_bid     = ifu_if.bid;
    assign ifu_axi_bresp   = ifu_if.bresp;   assign ifu_axi_arready = ifu_if.arready;
    assign ifu_axi_rvalid  = ifu_if.rvalid;  assign ifu_axi_rid     = ifu_if.rid;
    assign ifu_axi_rdata   = ifu_if.rdata;   assign ifu_axi_rresp   = ifu_if.rresp;
    assign ifu_axi_rlast   = ifu_if.rlast;

    // LSU master port (observation)
    assign lsu_if.awvalid = lsu_axi_awvalid; assign lsu_if.awready = lsu_axi_awready;
    assign lsu_if.awid    = lsu_axi_awid;    assign lsu_if.awaddr  = lsu_axi_awaddr;
    assign lsu_if.awregion= lsu_axi_awregion;assign lsu_if.awlen   = lsu_axi_awlen;
    assign lsu_if.awsize  = lsu_axi_awsize;  assign lsu_if.awburst = lsu_axi_awburst;
    assign lsu_if.awlock  = lsu_axi_awlock;  assign lsu_if.awcache = lsu_axi_awcache;
    assign lsu_if.awprot  = lsu_axi_awprot;  assign lsu_if.awqos   = lsu_axi_awqos;
    assign lsu_if.wvalid  = lsu_axi_wvalid;  assign lsu_if.wready  = lsu_axi_wready;
    assign lsu_if.wdata   = lsu_axi_wdata;   assign lsu_if.wstrb   = lsu_axi_wstrb;
    assign lsu_if.wlast   = lsu_axi_wlast;
    assign lsu_if.bvalid  = lsu_axi_bvalid;  assign lsu_if.bready  = lsu_axi_bready;
    assign lsu_if.bresp   = lsu_axi_bresp;   assign lsu_if.bid     = lsu_axi_bid;
    assign lsu_if.arvalid = lsu_axi_arvalid; assign lsu_if.arready = lsu_axi_arready;
    assign lsu_if.arid    = lsu_axi_arid;    assign lsu_if.araddr  = lsu_axi_araddr;
    assign lsu_if.arregion= lsu_axi_arregion;assign lsu_if.arlen   = lsu_axi_arlen;
    assign lsu_if.arsize  = lsu_axi_arsize;  assign lsu_if.arburst = lsu_axi_arburst;
    assign lsu_if.arlock  = lsu_axi_arlock;  assign lsu_if.arcache = lsu_axi_arcache;
    assign lsu_if.arprot  = lsu_axi_arprot;  assign lsu_if.arqos   = lsu_axi_arqos;
    assign lsu_if.rvalid  = lsu_axi_rvalid;  assign lsu_if.rready  = lsu_axi_rready;
    assign lsu_if.rid     = lsu_axi_rid;     assign lsu_if.rdata   = lsu_axi_rdata;
    assign lsu_if.rresp   = lsu_axi_rresp;   assign lsu_if.rlast   = lsu_axi_rlast;

    // SB master port (observation)
    assign sb_if.awvalid  = sb_axi_awvalid;  assign sb_if.awready  = sb_axi_awready;
    assign sb_if.awid     = sb_axi_awid;     assign sb_if.awaddr   = sb_axi_awaddr;
    assign sb_if.awregion = sb_axi_awregion; assign sb_if.awlen    = sb_axi_awlen;
    assign sb_if.awsize   = sb_axi_awsize;   assign sb_if.awburst  = sb_axi_awburst;
    assign sb_if.awlock   = sb_axi_awlock;   assign sb_if.awcache  = sb_axi_awcache;
    assign sb_if.awprot   = sb_axi_awprot;   assign sb_if.awqos    = sb_axi_awqos;
    assign sb_if.wvalid   = sb_axi_wvalid;   assign sb_if.wready   = sb_axi_wready;
    assign sb_if.wdata    = sb_axi_wdata;    assign sb_if.wstrb    = sb_axi_wstrb;
    assign sb_if.wlast    = sb_axi_wlast;
    assign sb_if.bvalid   = sb_axi_bvalid;   assign sb_if.bready   = sb_axi_bready;
    assign sb_if.bresp    = sb_axi_bresp;    assign sb_if.bid      = sb_axi_bid;
    assign sb_if.arvalid  = sb_axi_arvalid;  assign sb_if.arready  = sb_axi_arready;
    assign sb_if.arid     = sb_axi_arid;     assign sb_if.araddr   = sb_axi_araddr;
    assign sb_if.arregion = sb_axi_arregion; assign sb_if.arlen    = sb_axi_arlen;
    assign sb_if.arsize   = sb_axi_arsize;   assign sb_if.arburst  = sb_axi_arburst;
    assign sb_if.arlock   = sb_axi_arlock;   assign sb_if.arcache  = sb_axi_arcache;
    assign sb_if.arprot   = sb_axi_arprot;   assign sb_if.arqos    = sb_axi_arqos;
    assign sb_if.rvalid   = sb_axi_rvalid;   assign sb_if.rready   = sb_axi_rready;
    assign sb_if.rid      = sb_axi_rid;      assign sb_if.rdata    = sb_axi_rdata;
    assign sb_if.rresp    = sb_axi_rresp;    assign sb_if.rlast    = sb_axi_rlast;

`ifndef DMA_UVM_MASTER
    // DMA port: passive observation (the RTL loopback drives the port). The
    // reduced sideband fields the DMA port does not carry are tied to 0.
    assign dma_if.awvalid = dma_axi_awvalid; assign dma_if.awready = dma_axi_awready;
    assign dma_if.awid    = dma_axi_awid;    assign dma_if.awaddr  = dma_axi_awaddr;
    assign dma_if.awregion= '0;              assign dma_if.awlen   = dma_axi_awlen;
    assign dma_if.awsize  = dma_axi_awsize;  assign dma_if.awburst = dma_axi_awburst;
    assign dma_if.awlock  = '0;              assign dma_if.awcache = '0;
    assign dma_if.awprot  = dma_axi_awprot;  assign dma_if.awqos   = '0;
    assign dma_if.wvalid  = dma_axi_wvalid;  assign dma_if.wready  = dma_axi_wready;
    assign dma_if.wdata   = dma_axi_wdata;   assign dma_if.wstrb   = dma_axi_wstrb;
    assign dma_if.wlast   = dma_axi_wlast;
    assign dma_if.bvalid  = dma_axi_bvalid;  assign dma_if.bready  = dma_axi_bready;
    assign dma_if.bresp   = dma_axi_bresp;   assign dma_if.bid     = dma_axi_bid;
    assign dma_if.arvalid = dma_axi_arvalid; assign dma_if.arready = dma_axi_arready;
    assign dma_if.arid    = dma_axi_arid;    assign dma_if.araddr  = dma_axi_araddr;
    assign dma_if.arregion= '0;              assign dma_if.arlen   = dma_axi_arlen;
    assign dma_if.arsize  = dma_axi_arsize;  assign dma_if.arburst = dma_axi_arburst;
    assign dma_if.arlock  = '0;              assign dma_if.arcache = '0;
    assign dma_if.arprot  = dma_axi_arprot;  assign dma_if.arqos   = '0;
    assign dma_if.rvalid  = dma_axi_rvalid;  assign dma_if.rready  = dma_axi_rready;
    assign dma_if.rid     = dma_axi_rid;     assign dma_if.rdata   = dma_axi_rdata;
    assign dma_if.rresp   = dma_axi_rresp;   assign dma_if.rlast   = dma_axi_rlast;
`else
    // DMA port: the UVM DMA master agent drives it. Drive master-sourced signals
    // into the DUT; observe slave-sourced signals into dma_if.
    assign dma_axi_awvalid = dma_if.awvalid; assign dma_axi_awid    = dma_if.awid;
    assign dma_axi_awaddr  = dma_if.awaddr;  assign dma_axi_awsize  = dma_if.awsize;
    assign dma_axi_awprot  = dma_if.awprot;  assign dma_axi_awlen   = dma_if.awlen;
    assign dma_axi_awburst = dma_if.awburst;
    assign dma_axi_wvalid  = dma_if.wvalid;  assign dma_axi_wdata   = dma_if.wdata;
    assign dma_axi_wstrb   = dma_if.wstrb;   assign dma_axi_wlast   = dma_if.wlast;
    assign dma_axi_bready  = dma_if.bready;
    assign dma_axi_arvalid = dma_if.arvalid; assign dma_axi_arid    = dma_if.arid;
    assign dma_axi_araddr  = dma_if.araddr;  assign dma_axi_arsize  = dma_if.arsize;
    assign dma_axi_arprot  = dma_if.arprot;  assign dma_axi_arlen   = dma_if.arlen;
    assign dma_axi_arburst = dma_if.arburst;
    assign dma_axi_rready  = dma_if.rready;
    assign dma_if.awready  = dma_axi_awready; assign dma_if.wready  = dma_axi_wready;
    assign dma_if.bvalid   = dma_axi_bvalid;  assign dma_if.bresp   = dma_axi_bresp;
    assign dma_if.bid      = dma_axi_bid;     assign dma_if.arready = dma_axi_arready;
    assign dma_if.rvalid   = dma_axi_rvalid;  assign dma_if.rid     = dma_axi_rid;
    assign dma_if.rdata    = dma_axi_rdata;   assign dma_if.rresp   = dma_axi_rresp;
    assign dma_if.rlast    = dma_axi_rlast;
    // Drain the bridge s1 path so an LSU-to-ICCM access does not hang the bridge
    // (this routing is unsupported when the UVM master owns the DMA port).
    assign b_dma_awready = 1'b1; assign b_dma_wready = 1'b1;
    assign b_dma_bvalid  = 1'b0; assign b_dma_bresp  = 2'b0;
    assign b_dma_arready = 1'b1; assign b_dma_rvalid = 1'b0;
    assign b_dma_rresp   = 2'b0; assign b_dma_rdata  = 64'b0; assign b_dma_rlast = 1'b0;
    // Publish whether the DMA master actually drives the port (compile-gated),
    // so the env only makes the DMA agent active when it really owns the port.
    initial uvm_config_db#(int)::set(null, "*", "dma_uvm_master", 1);
`endif

    // Bus clock-enable strobes (tied to 1'b1 at the DUT today; observed here).
    clk_en_if cken_if (.clk(core_clk), .rst_l(rst_l));
    assign cken_if.lsu_bus_clk_en = 1'b1;
    assign cken_if.ifu_bus_clk_en = 1'b1;
    assign cken_if.dbg_bus_clk_en = 1'b1;
    assign cken_if.dma_bus_clk_en = 1'b1;

    // End-of-test hand-off (written by the mailbox monitor above).
    veer_eot_if eot ();

    initial begin
`ifdef RV_BUILD_AXI4
        uvm_config_db#(virtual axi4_if)::set(null, "*", "ifu_vif",  ifu_if);
        uvm_config_db#(virtual axi4_if)::set(null, "*", "lmem_vif", lmem_if);
        uvm_config_db#(virtual axi4_if)::set(null, "*", "lsu_vif",  lsu_if);
        uvm_config_db#(virtual axi4_if)::set(null, "*", "sb_vif",   sb_if);
        uvm_config_db#(virtual axi4_if)::set(null, "*", "dma_vif",  dma_if);
`endif
        uvm_config_db#(virtual clk_en_if)::set(null, "*", "clk_en_vif", cken_if);
        uvm_config_db#(virtual veer_eot_if)::set(null, "*", "eot_vif", eot);
        run_test();
    end
`endif

task preload_iccm;
bit[31:0] data;
bit[31:0] addr, eaddr, saddr;

/*
addresses:
 0xfffffff0 - ICCM start address to load
 0xfffffff4 - ICCM end address to load
*/
init_iccm();
addr = 'hffff_fff0;
saddr = {hexmem[addr+3],hexmem[addr+2],hexmem[addr+1],hexmem[addr]};
if ( (saddr < `RV_ICCM_SADR) || (saddr > `RV_ICCM_EADR)) return;
`ifndef RV_ICCM_ENABLE
    $display("********************************************************");
    $display("ICCM preload: there is no ICCM in VeeR, terminating !!!");
    $display("********************************************************");
    $finish;
`endif
addr += 4;
eaddr = {hexmem[addr+3],hexmem[addr+2],hexmem[addr+1],hexmem[addr]};
$display("ICCM pre-load from %h to %h", saddr, eaddr);

for(addr= saddr; addr <= eaddr; addr+=4) begin
    data = {hexmem[addr+3],hexmem[addr+2],hexmem[addr+1],hexmem[addr]};
    slam_iccm_ram(addr, data == 0 ? 0 : {riscv_ecc32(data),data});
end

endtask


task preload_dccm;
bit[31:0] data;
bit[31:0] addr, saddr, eaddr;

/*
addresses:
 0xffff_fff8 - DCCM start address to load
 0xffff_fffc - DCCM end address to load
*/
init_dccm();

addr = 'hffff_fff8;
saddr = {hexmem[addr+3],hexmem[addr+2],hexmem[addr+1],hexmem[addr]};
if (saddr < `RV_DCCM_SADR || saddr > `RV_DCCM_EADR) return;
`ifndef RV_DCCM_ENABLE
    $display("********************************************************");
    $display("DCCM preload: there is no DCCM in VeeR, terminating !!!");
    $display("********************************************************");
    $finish;
`endif
addr += 4;
eaddr = {hexmem[addr+3],hexmem[addr+2],hexmem[addr+1],hexmem[addr]};
$display("DCCM pre-load from %h to %h", saddr, eaddr);

for(addr=saddr; addr <= eaddr; addr+=4) begin
    data = {hexmem[addr+3],hexmem[addr+2],hexmem[addr+1],hexmem[addr]};
    slam_dccm_ram(addr, data == 0 ? 0 : {riscv_ecc32(data),data});
end

endtask

`define ICCM_PATH `RV_TOP.mem.iccm.iccm
`define DRAM(bk) rvtop.mem.Gen_dccm_enable.dccm.mem_bank[bk].dccm.dccm_bank.ram_core
`define IRAM(bk) `ICCM_PATH.mem_bank[bk].iccm.iccm_bank.ram_core


task slam_dccm_ram(input [31:0] addr, input[38:0] data);
int bank, indx;
bank = get_dccm_bank(addr, indx);
`ifdef RV_DCCM_ENABLE
case(bank)
0: `DRAM(0)[indx] = data;
1: `DRAM(1)[indx] = data;
`ifdef RV_DCCM_NUM_BANKS_4
2: `DRAM(2)[indx] = data;
3: `DRAM(3)[indx] = data;
`endif
`ifdef RV_DCCM_NUM_BANKS_8
2: `DRAM(2)[indx] = data;
3: `DRAM(3)[indx] = data;
4: `DRAM(4)[indx] = data;
5: `DRAM(5)[indx] = data;
6: `DRAM(6)[indx] = data;
7: `DRAM(7)[indx] = data;
`endif
endcase
`endif
endtask

task init_dccm();
`ifdef RV_DCCM_ENABLE
    `DRAM(0) = '{default:39'h0};
    `DRAM(1) = '{default:39'h0};
`ifdef RV_DCCM_NUM_BANKS_4
    `DRAM(2) = '{default:39'h0};
    `DRAM(3) = '{default:39'h0};
`endif
`ifdef RV_DCCM_NUM_BANKS_8
    `DRAM(2) = '{default:39'h0};
    `DRAM(3) = '{default:39'h0};
    `DRAM(4) = '{default:39'h0};
    `DRAM(5) = '{default:39'h0};
    `DRAM(6) = '{default:39'h0};
    `DRAM(7) = '{default:39'h0};
`endif
`endif
endtask


task slam_iccm_ram( input[31:0] addr, input[38:0] data);
int bank, idx;

bank = get_iccm_bank(addr, idx);
`ifdef RV_ICCM_ENABLE
case(bank) // {
  0: `IRAM(0)[idx] = data;
  1: `IRAM(1)[idx] = data;
  2: `IRAM(2)[idx] = data;
  3: `IRAM(3)[idx] = data;

 `ifdef RV_ICCM_NUM_BANKS_8
  4: `IRAM(4)[idx] = data;
  5: `IRAM(5)[idx] = data;
  6: `IRAM(6)[idx] = data;
  7: `IRAM(7)[idx] = data;
 `endif

 `ifdef RV_ICCM_NUM_BANKS_16
  4: `IRAM(4)[idx] = data;
  5: `IRAM(5)[idx] = data;
  6: `IRAM(6)[idx] = data;
  7: `IRAM(7)[idx] = data;
  8: `IRAM(8)[idx] = data;
  9: `IRAM(9)[idx] = data;
  10: `IRAM(10)[idx] = data;
  11: `IRAM(11)[idx] = data;
  12: `IRAM(12)[idx] = data;
  13: `IRAM(13)[idx] = data;
  14: `IRAM(14)[idx] = data;
  15: `IRAM(15)[idx] = data;
 `endif
endcase // }
`endif
endtask

task init_iccm;
`ifdef RV_ICCM_ENABLE
    `IRAM(0) = '{default:39'h0};
    `IRAM(1) = '{default:39'h0};
    `IRAM(2) = '{default:39'h0};
    `IRAM(3) = '{default:39'h0};

`ifdef RV_ICCM_NUM_BANKS_8
    `IRAM(4) = '{default:39'h0};
    `IRAM(5) = '{default:39'h0};
    `IRAM(6) = '{default:39'h0};
    `IRAM(7) = '{default:39'h0};
`endif

`ifdef RV_ICCM_NUM_BANKS_16
    `IRAM(4) = '{default:39'h0};
    `IRAM(5) = '{default:39'h0};
    `IRAM(6) = '{default:39'h0};
    `IRAM(7) = '{default:39'h0};
    `IRAM(8) = '{default:39'h0};
    `IRAM(9) = '{default:39'h0};
    `IRAM(10) = '{default:39'h0};
    `IRAM(11) = '{default:39'h0};
    `IRAM(12) = '{default:39'h0};
    `IRAM(13) = '{default:39'h0};
    `IRAM(14) = '{default:39'h0};
    `IRAM(15) = '{default:39'h0};
 `endif
`endif
endtask


function[6:0] riscv_ecc32(input[31:0] data);
reg[6:0] synd;
synd[0] = ^(data & 32'h56aa_ad5b);
synd[1] = ^(data & 32'h9b33_366d);
synd[2] = ^(data & 32'he3c3_c78e);
synd[3] = ^(data & 32'h03fc_07f0);
synd[4] = ^(data & 32'h03ff_f800);
synd[5] = ^(data & 32'hfc00_0000);
synd[6] = ^{data, synd[5:0]};
return synd;
endfunction

function int get_dccm_bank(input[31:0] addr,  output int bank_idx);
`ifdef RV_DCCM_NUM_BANKS_2
    bank_idx = int'(addr[`RV_DCCM_BITS-1:3]);
    return int'( addr[2]);
`elsif RV_DCCM_NUM_BANKS_4
    bank_idx = int'(addr[`RV_DCCM_BITS-1:4]);
    return int'(addr[3:2]);
`elsif RV_DCCM_NUM_BANKS_8
    bank_idx = int'(addr[`RV_DCCM_BITS-1:5]);
    return int'( addr[4:2]);
`endif
endfunction

function int get_iccm_bank(input[31:0] addr,  output int bank_idx);
`ifdef RV_ICCM_NUM_BANKS_4
    bank_idx = int'(addr[`RV_ICCM_BITS-1:4]);
    return int'(addr[3:2]);
`elsif RV_ICCM_NUM_BANKS_8
    bank_idx = int'(addr[`RV_ICCM_BITS-1:5]);
    return int'( addr[4:2]);
`elsif RV_ICCM_NUM_BANKS_16
    bank_idx = int'(addr[`RV_ICCM_BITS-1:6]);
    return int'( addr[5:2]);
`endif
endfunction

/* verilator lint_off CASEINCOMPLETE */
`include "dasm.svi"
/* verilator lint_on CASEINCOMPLETE */



endmodule
