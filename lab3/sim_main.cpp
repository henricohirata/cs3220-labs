// DESCRIPTION:  simulation of pipeline 
//======================================================================
#include <iostream>
#include <cstdlib>

// Include common routines
#include <verilated.h>
// Include model header, generated from Verilating "pipeline.v"
#include "Vpipeline.h"
#include "Vpipeline__Syms.h"

#ifdef VCD_OUTPUT
#include <verilated_vcd_c.h>
#endif

#define RUN_CYCLES 100000

#define CLOCK_PERIOD 2

#define RESET_TIME  10

// gp (x3) — TinyRV pass/fail register written at end of each test
#define GP_REGNO 3
#define GP_PASS  1

// Current simulation time (64-bit unsigned)
uint64_t timestamp = 0;

double sc_time_stamp() { 
  return timestamp;
}

int main(int argc, char** argv, char** env) {
    // turn off unused variable warnings
    if (0 && argc && argv && env) {}

    // Construct the Verilated model
    Vpipeline* dut = new Vpipeline();

#ifdef VCD_OUTPUT
    Verilated::traceEverOn(true);
    auto trace = new VerilatedVcdC();
    dut->trace(trace, 2999);
    trace->open("trace.vcd");
#endif

#ifdef DPRINTF
    uint64_t inst_count_WB = 0;
#endif

    uint64_t total_cycles = 0;
    bool sim_done = false;

    dut->clk = 0;
    dut->reset = 0;

    while (timestamp < RUN_CYCLES && !sim_done) {      
        bool clk_transition = (timestamp % CLOCK_PERIOD) == 0;
        if (clk_transition) 
            dut->clk = !dut->clk; 

        if (timestamp > 1 && timestamp < RESET_TIME) {
            dut->reset = 1;  // Assert reset
        } else {
            dut->reset = 0;  // Deassert reset
        }
        
        // Evaluate model
        dut->eval();

        if (clk_transition && dut->clk && timestamp >= RESET_TIME) {
            ++total_cycles;

            // End simulation as soon as the test reports pass (gp <- 1).
            bool valid_WB = (int)dut->pipeline->my_WB_stage->WB_counters[0] != 0;
            if (valid_WB) {
                int wr_reg_WB  = (int)dut->pipeline->my_WB_stage->WB_counters[4];
                int wregno_WB  = (int)dut->pipeline->my_WB_stage->WB_counters[5];
                int regval_WB  = (int)dut->pipeline->my_WB_stage->WB_counters[6];
                if (wr_reg_WB && wregno_WB == GP_REGNO && regval_WB == GP_PASS)
                    sim_done = true;
            }
        }

    #ifdef DPRINTF 
        // Verilator allows to access verilator public data structure
        if (clk_transition && dut->clk) {
            bool valid_WB = (int)dut->pipeline->my_WB_stage->WB_counters[0] != 0;
            if (valid_WB)  { 
                std::cout << "[" << (int)(timestamp) << "] ";
                std::cout << " PC=0x"   << std::hex << (int)dut->pipeline->my_WB_stage->WB_counters[1];
                std::cout << " Inst=0x" << std::hex << (int)dut->pipeline->my_WB_stage->WB_counters[2];
                std::cout << " Op="     << std::dec << (int)dut->pipeline->my_WB_stage->WB_counters[3];
                int wr_reg_WB = (int)dut->pipeline->my_WB_stage->WB_counters[4];
                if (wr_reg_WB) {
                    std::cout << " wr_reg=" << std::dec << wr_reg_WB; 
                    std::cout << " wregno=" << std::dec << (int)dut->pipeline->my_WB_stage->WB_counters[5];
                    std::cout << " regval=" << std::dec << (int)dut->pipeline->my_WB_stage->WB_counters[6];
                }
                std::cout << std::endl; 
                
                ++inst_count_WB;
            }
        }

    #endif

    #ifdef VCD_OUTPUT
        trace->dump(timestamp);
    #endif
        ++timestamp;
    }

#ifdef DPRINTF
    std::cout << "Total instructions=" << std::dec << inst_count_WB
              << ", cycles=" << total_cycles
              << ", IPC=" << ((inst_count_WB * 1.0f) / total_cycles) << std::endl; 
#endif

    int exitcode = (int)dut->pipeline->my_WB_stage->last_WB_value[3];

    // Final model cleanup
    dut->final();

#ifdef VCD_OUTPUT
    trace->close();
    delete trace;
#endif

    // Destroy DUT
    delete dut;

    // Always print cycle count (parsed by run_tests.sh/autograder)
    std::cout << "Cycles=" << total_cycles << std::endl;

    // Optional cycle-budget enforcement (set CYCLE_BUDGET env var)
    const char* budget_env = std::getenv("CYCLE_BUDGET");
    bool budget_ok = true;
    if (budget_env && budget_env[0] != '\0') {
        unsigned long budget = std::strtoul(budget_env, nullptr, 10);
        if (total_cycles > budget) {
            budget_ok = false;
            std::cout << "Failed. cycle budget exceeded: " << total_cycles
                      << " > " << budget << std::endl;
        }
    }

    // TinyRV1 test Pass/Fail status
    if (1 == exitcode && budget_ok)
        std::cout<<"Passed!"<<std::endl;
    else if (1 != exitcode)
        std::cout<<"Failed. exitcode: "<<exitcode<<std::endl;

    // Fin
    exit(0);
}
