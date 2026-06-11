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
// veer_eot_if : end-of-test status hand-off.
//
// The original testbench (tb_top.sv) ends the simulation with $finish the
// moment the program writes the pass/fail magic byte to the mailbox. Under UVM
// that would kill the run before report/check phases execute. tb_uvm_top
// instead sets `seen` / `pass` here, letting the UVM test end its run_phase
// objection gracefully so a full UVM report (incl. the scoreboard verdict in
// later phases) is printed.
//-----------------------------------------------------------------------------
`ifndef VEER_EOT_IF_SV
`define VEER_EOT_IF_SV

interface veer_eot_if;
  bit seen;  // asserted once the program signals completion (pass/fail/timeout)
  bit pass;  // valid when seen: 1 = TEST_PASSED, 0 = TEST_FAILED / timeout
endinterface

`endif // VEER_EOT_IF_SV
