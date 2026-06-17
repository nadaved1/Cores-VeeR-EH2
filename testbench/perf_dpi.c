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
// perf_dpi : tiny DPI-C helper returning a monotonic wallclock timestamp in
// seconds, used by both tb_top (directed flow) and tb_uvm_top (UVM flow) to
// report simulation wallclock time and speed.
//-----------------------------------------------------------------------------
#include <time.h>

// Force C linkage when this file is pulled into a C++ compile (e.g. Verilator's
// generated harness compiles user sources with g++). Verilator emits the DPI
// import as `extern "C"`, so the definition must match or linking fails.
#ifdef __cplusplus
extern "C" {
#endif

// Maps to SystemVerilog `import "DPI-C" function real sv_wall_time_sec();`
double sv_wall_time_sec(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

#ifdef __cplusplus
}
#endif
