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
// axi4_slave_sequencer : present for structure / future use. The Phase 1 slave
// driver is reactive (autonomous), so no sequences run on it yet; Phase 3
// response-policy sequences (wait states, error injection) will use it.
//-----------------------------------------------------------------------------
`ifndef AXI4_SLAVE_SEQUENCER_SV
`define AXI4_SLAVE_SEQUENCER_SV

typedef uvm_sequencer #(axi4_slave_seq_item) axi4_slave_sequencer;

`endif // AXI4_SLAVE_SEQUENCER_SV
