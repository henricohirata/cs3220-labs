// DESCRIPTION:  simulation of tb_axi4_ram_burst 
//======================================================================
#include <iostream>

// Include common routines
#include <verilated.h>
// Include model header, generated from Verilating "tb_axi4_ram_burst.v"
#include "Vtb_axi4_ram_burst.h"
#include "Vtb_axi4_ram_burst__Syms.h"

#ifdef VCD_OUTPUT
#include <verilated_vcd_c.h>
#endif

#define RUN_CYCLES 200000

#define CLOCK_PERIOD 2

#define RESET_TIME  10

// Current simulation time (64-bit unsigned)
uint64_t timestamp = 0;

double sc_time_stamp() { 
  return timestamp;
}

int main(int argc, char** argv, char** env) {
    // turn off unused variable warnings
    if (0 && argc && argv && env) {}

    // Construct the Verilated model
    Vtb_axi4_ram_burst* dut = new Vtb_axi4_ram_burst();
    int exitcode = 0;

#ifdef VCD_OUTPUT
    Verilated::traceEverOn(true);
    auto trace = new VerilatedVcdC();
    dut->trace(trace, 2999);
    trace->open("trace.vcd");
#endif

#ifdef DPRINTF
    uint64_t timestamp_WB = 0;
#endif

    dut->clk = 0;
    dut->reset = 0;

    while (timestamp < RUN_CYCLES) {      
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

        int correct_vld;
        // Verilator allows to access verilator public data structure
        if (clk_transition && dut->clk) {
    
            correct_vld = dut->tb_axi4_ram_burst->correct_V_ap_vld;

            if (correct_vld) {
                if (dut->tb_axi4_ram_burst->correct_V == 0) {
                    std::cout << "ERROR: correct_V = 0" << std::endl;
                    exitcode = 0;
                }else{
                    std::cout << "correct_V = 1" << std::endl;
                    exitcode = 1;
                }
            }
            timestamp_WB = timestamp - RESET_TIME;            
        }


    #ifdef VCD_OUTPUT
        trace->dump(timestamp);
    #endif
        ++timestamp;
    
    //if correct_V is valid, then exit
    if (correct_vld)
        break;

    }

#ifdef DPRINTF
    std::cout << "Cycles=" << (timestamp_WB / 2) << std::endl; 
#endif

    // Final model cleanup
    dut->final();

#ifdef VCD_OUTPUT
    trace->close();
    delete trace;
#endif

    if (1 == exitcode)
        std::cout<<"Passed!"<<std::endl;
    else
        std::cout<<"Failed. exitcode: "<<exitcode<<std::endl;

    // Destroy DUT
    delete dut;
    // Fin
    exit(0);
}