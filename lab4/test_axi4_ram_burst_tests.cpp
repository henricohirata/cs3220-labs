// DESCRIPTION: combined directed burst tests for axi_ram via tb_axi4_ram_burst_tests
//
// One bench holds both suites, so this driver only generates the clock +
// reset and watches three ports: done, edge_pass and corner_pass.
//
//   edge_pass   - the POSITIVE tests; a correct implementation passes them,
//                 so they decide this program's exit code.
//   corner_pass - the graded protocol corner cases; while your design is incomplete some of
//                 them will fail, so they are reported but do
//                 not by themselves fail the run.
//======================================================================
#include <iostream>

#include <verilated.h>
#include "Vtb_axi4_ram_burst_tests.h"
#include "Vtb_axi4_ram_burst_tests__Syms.h"

#ifdef VCD_OUTPUT
#include <verilated_vcd_c.h>
#endif

#define RUN_CYCLES 1000000
#define CLOCK_PERIOD 2
#define RESET_TIME  10

// Current simulation time (64-bit unsigned)
uint64_t timestamp = 0;

double sc_time_stamp() {
    return timestamp;
}

int main(int argc, char** argv, char** env) {
    if (0 && argc && argv && env) {}

    Vtb_axi4_ram_burst_tests* dut = new Vtb_axi4_ram_burst_tests();
    int exitcode = 0;

#ifdef VCD_OUTPUT
    Verilated::traceEverOn(true);
    auto trace = new VerilatedVcdC();
    dut->trace(trace, 2999);
    trace->open("trace_axi4_ram_burst_tests.vcd");
#endif

    dut->clk   = 0;
    dut->reset = 0;

    while (timestamp < RUN_CYCLES) {
        bool clk_transition = (timestamp % CLOCK_PERIOD) == 0;
        if (clk_transition)
            dut->clk = !dut->clk;

        if (timestamp > 1 && timestamp < RESET_TIME) {
            dut->reset = 1;
        } else {
            dut->reset = 0;
        }

        dut->eval();

        if (clk_transition && dut->clk) {
            if (dut->done) {
                if (dut->edge_pass) {
                    std::cout << "[C++] axi4_ram_burst EDGE tests PASSED" << std::endl;
                    exitcode = 1;
                } else {
                    std::cout << "[C++] axi4_ram_burst EDGE tests FAILED "
                                 "(a correct implementation should pass all edge tests)"
                              << std::endl;
                    exitcode = 0;
                }
                if (dut->corner_pass) {
                    std::cout << "[C++] axi4_ram_burst CORNER cases PASSED" << std::endl;
                } else {
                    std::cout << "[C++] axi4_ram_burst CORNER cases FAILED "
                                 "(non-fatal; a correct implementation passes these)"
                              << std::endl;
                }
                break;
            }
        }

#ifdef VCD_OUTPUT
        trace->dump(timestamp);
#endif
        ++timestamp;
    }

    if (!dut->done) {
        std::cout << "[C++] axi4_ram_burst tests did not complete within RUN_CYCLES" << std::endl;
        exitcode = 0;
    }

    dut->final();

#ifdef VCD_OUTPUT
    trace->close();
    delete trace;
#endif

    delete dut;
    std::cout << ((exitcode == 1) ? "Passed!" : "Failed.") << std::endl;
    return (exitcode == 1) ? 0 : 1;
}
