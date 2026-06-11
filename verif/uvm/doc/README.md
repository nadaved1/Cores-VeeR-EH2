# VeeR EH2 — UVM Bus/SoC Integration Environment

A UVM environment that verifies the **bus/SoC integration** of the VeeR EH2
core: its AXI4 (and later AHB-Lite) IFU/LSU/SB master interfaces and the DMA
slave port, under realistic and adversarial bus traffic (bursts, wait states,
back-pressure, out-of-order, error responses). It is **not** an ISA/datapath
checker — CPU correctness is covered separately (ISS co-sim + riscv-dv).

It runs on commercial simulators (VCS / Xcelium / Questa) and lives entirely
alongside the existing `testbench/`. The open-source **Verilator** flow
(`testbench/flist` + `tb_top`) is untouched and remains the fast directed/smoke
regression path.

## Layout

```
verif/uvm/
  uvm.flist                 commercial-sim file list (includes testbench/flist)
  tb/    tb_uvm_top.sv       UVM top: DUT + interfaces + run_test()
  if/    axi4_if.sv          parameterized AXI4 interface (+ modports)
         clk_en_if.sv        bus clock-enable strobes
         veer_eot_if.sv      end-of-test hand-off (replaces $finish-on-mailbox)
  env/   veer_bus_pkg.sv     package (includes the classes below)
         veer_bus_cfg.sv     env configuration (agent active/passive, …)
         veer_bus_env.sv     top env (agents/scoreboard/coverage added later)
  tests/ veer_bus_base_test.sv
         veer_bus_smoke_test.sv   default +UVM_TESTNAME
  doc/   README.md
```

## How it coexists with the program

The core still executes a real `program.hex` exactly as in `tb_top`:
`tb_uvm_top` reproduces the DUT instance, program preload (`preload_iccm` /
`preload_dccm`), and trace/console logging. The only behavioral change is the
end-of-test path: instead of calling `$finish` on the mailbox pass/fail byte,
`tb_uvm_top` drives `veer_eot_if`, so the UVM test ends its `run_phase`
objection cleanly and a full UVM report is printed.

`tb_uvm_top` redefines the `TOP` / `RV_TOP` / `CPU_TOP` hierarchy macros (baked
to `tb_top.*` in `snapshots/<cfg>/common_defines.vh`) to point at `tb_uvm_top`.

## Running (Phase 0)

From the repo root, with `RV_ROOT` set and a config snapshot generated
(`make -f tools/Makefile ${BUILD_DIR}/defines.h`, done automatically):

```
# VCS
make -f tools/Makefile vcs-uvm UVM_TEST=veer_bus_smoke_test

# Xcelium
make -f tools/Makefile xrun-uvm UVM_TEST=veer_bus_smoke_test

# Questa
make -f tools/Makefile questa-uvm UVM_TEST=veer_bus_smoke_test
```

Override the program with `TEST=<name>` (same mechanism as the Verilator flow),
e.g. `make -f tools/Makefile vcs-uvm TEST=dhry`.

**Pass criteria:** the program prints `TEST_PASSED` (mailbox) **and** UVM prints
a clean report (no `UVM_ERROR` / `UVM_FATAL`).

> Note: the `verilator-build` recipe appends `` `undef RV_ASSERT_ON `` to the
> snapshot's `common_defines.vh`, which disables SVA. If you want assertions
> live in the UVM run, regenerate the snapshot (`make clean` then the UVM
> target, or re-run `configs/veer.config`) so it has not been undef'd by a prior
> Verilator build.

## Confirming the Verilator flow is unaffected

```
make -f tools/Makefile clean
make -f tools/Makefile verilator TEST=hello_world   # still prints TEST_PASSED
```

The UVM additions never modify `testbench/flist`, `tb_top.sv`, `ahb_sif.sv`, or
the `verilator-build` recipe, so a green Verilator run before and after proves
separation.

## Phase 1 — what's active now

The `axi4_slave_agent` ([verif/uvm/agents/axi4_slave/](../agents/axi4_slave/)) is a
reactive AXI4 slave responder backed by a class golden memory
(`axi4_slave_mem`, preloaded from program.hex). Its behaviour is a 1:1 port of
the proven `axi_slv` (always-ready, 1-cycle registered read, single-beat, OKAY)
so the program still runs to completion — only now UVM owns the responder.

`veer_bus_env` builds:
- `ifu_agent` — active slave on the IFU port (serves fetches), replacing `imem`.
- `lmem_agent` — active slave on the LSU external-memory leaf (bridge port s0),
  replacing `lmem`. The `axi_lsu_dma_bridge` and the DMA loopback are unchanged,
  so LSU→ICCM traffic still routes through the DMA path.
- `lsu_mon_agent` / `sb_mon_agent` / `dma_mon_agent` — passive monitors.

Each monitor publishes reconstructed read/write bursts on an analysis port
(consumed by the Phase 2 scoreboard and Phase 3 coverage). The mailbox pass/fail
status is now decoded directly from the bus in `tb_uvm_top` (the static `lmem`
that previously exposed it is gone).

> The responder reproduces `axi_slv` exactly (it does not yet honor RREADY
> back-pressure or inject wait-states/errors). The handshake-respecting,
> wait-state and error-injection modes arrive in Phase 3 via slave response-
> policy sequences; `axi4_slave_cfg.read_latency` is the first knob.

## Phase 2 — DMA master + scoreboard

`axi4_master_agent` ([verif/uvm/agents/axi4_master/](../agents/axi4_master/)) is a
proper AXI4 master that drives the core's DMA slave port (write/read bursts with
optional master-side RREADY/BREADY back-pressure). `veer_bus_scoreboard`
([env/veer_bus_scoreboard.sv](../env/veer_bus_scoreboard.sv)) keeps a byte-level
reference image of everything the DMA master writes and checks every DMA read-
back against it — verifying data round-trips through the core's DMA controller
and CCM.

Owning the DMA port means **detaching the RTL LSU→DMA loopback**, which can't
share the port wires. So the master-drive wiring is compile-gated by
`DMA_UVM_MASTER`:
- without it (default): the RTL loopback drives the DMA port (Phase 1 behaviour,
  LSU→ICCM works); the DMA agent only monitors.
- with `+define+DMA_UVM_MASTER`: the UVM master owns the port; LSU→ICCM is
  unsupported (use programs that don't store to ICCM).

```
make -f tools/Makefile vcs-uvm UVM_TEST=veer_bus_dma_test \
     UVM_DEFINES=+define+DMA_UVM_MASTER
```

The DMA scratch window defaults to the start of DCCM (`veer_bus_cfg.dma_base/
dma_window`). Keep it clear of memory the program uses, or the scoreboard will
see the program's writes as mismatches.

## Phase 3 — coverage, wait-state stress, regression

- **Functional coverage** ([cov/axi4_cov.sv](../cov/axi4_cov.sv)): per-port
  covergroups over direction × burst × len × size × response × address-region,
  with crosses. Enabled via `veer_bus_cfg.enable_cov` (on in the dma/stress
  tests).
- **Slave response policy:** `axi4_slave_driver` gains a handshake-respecting
  policy mode (`axi4_slave_cfg.policy_enable`) that inserts randomized wait
  states on every channel and can inject SLVERR (`err_rate_pct`, left 0 against a
  live program). The faithful Phase 1 mode remains the default.
- **`veer_bus_stress_test`**: runs the program with IFU/LSU wait-state stress +
  back-pressured DMA bursts + coverage. Multi-seed:
  ```
  make -f tools/Makefile vcs-uvm UVM_TEST=veer_bus_stress_test \
       UVM_DEFINES=+define+DMA_UVM_MASTER run_arg="+ntb_random_seed=7"
  ```
- **Virtual sequencer** (`veer_bus_vseqr`) + `veer_bus_dma_vseq` coordinate DMA
  traffic; the same test is a no-op on the DMA side when built without
  `DMA_UVM_MASTER`.

Optional AHB-Lite agents are intentionally left for later (the env focuses on the
default AXI4 build).

## Roadmap

- **Phase 0 (done):** scaffolding, build/run path.
- **Phase 1 (done):** active IFU/LSU slave responders, passive monitors.
- **Phase 2 (this commit):** DMA master agent + DMA consistency scoreboard.
- **Phase 3 (this commit):** functional coverage, slave wait-state stress,
  back-pressure DMA sequences, multi-seed regression.
- **Future:** AHB-Lite agents; per-ID out-of-order slave model; targeted
  error-injection negative tests; clock-ratio (`*_bus_clk_en`) sequences.
