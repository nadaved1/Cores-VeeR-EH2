// SPDX-License-Identifier: Apache-2.0
// Passed on the simulator command line (after the snapshot's common_defines.vh)
// by the *-uvm targets when ASSERT_OFF=1, to compile out the design's
// `RV_ASSERT_ON-gated SVA without editing the generated snapshot.
`undef RV_ASSERT_ON
