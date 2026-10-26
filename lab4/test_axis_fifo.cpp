// DESCRIPTION:  simulation of tb_axis_fifo 
//======================================================================
#include <iostream>

// Include common routines
#include <verilated.h>
// Include model header, generated from Verilating "tb_axis_fifo.v"
#include "Vtb_axis_fifo.h"
#include "Vtb_axis_fifo__Syms.h"

#ifdef VCD_OUTPUT
#include <verilated_vcd_c.h>
#endif

#define RUN_CYCLES 100000

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
    Vtb_axis_fifo* dut = new Vtb_axis_fifo();

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

        // Verilator allows to access verilator public data structure
        if (clk_transition && dut->clk) {
    
            int din_0_rsc_vld = dut->tb_axis_fifo->din_0_rsc_vld;
            int din_0_rsc_rdy = dut->tb_axis_fifo->din_0_rsc_rdy;
            int dout_0_rsc_vld = dut->tb_axis_fifo->dout_0_rsc_vld;
            int dout_0_rsc_rdy = dut->tb_axis_fifo->dout_0_rsc_rdy;

            if (din_0_rsc_vld & din_0_rsc_rdy) {
                std :: cout << "din_0_rsc_dat=" << std::hex << dut->tb_axis_fifo->din_0_rsc_dat << std::endl;
            }
            if (dout_0_rsc_vld & dout_0_rsc_rdy) {
                std :: cout << "dout_0_rsc_dat=" << std::hex << dut->tb_axis_fifo->dout_0_rsc_dat << std::endl;
            }
            timestamp_WB = timestamp - RESET_TIME;            
        }


    #ifdef VCD_OUTPUT
        trace->dump(timestamp);
    #endif
        ++timestamp;
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

    // Destroy DUT
    delete dut;
    // Fin
    exit(0);
}