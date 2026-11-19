// DESCRIPTION:  simulation of systolic_array 
//======================================================================
#include <iostream>
#include <fstream>
#include <stdint.h>
#include <cstdlib> 
#include <ctime>

// Include common routines
#include <verilated.h>
// Include model header, generated from Verilating "systolic_array_axis.v"
#include "Vsystolic_array_axis.h"
#include "Vsystolic_array_axis__Syms.h"

#ifdef VCD_OUTPUT
#include <verilated_vcd_c.h>
#endif

#define RUN_CYCLES 10000000

#define CLOCK_PERIOD 2

#define RESET_TIME  10

// Current simulation time (64-bit unsigned)
uint64_t timestamp = 0;
uint64_t systolic_steps = 0;

double sc_time_stamp() { 
  return timestamp;
}

int main(int argc, char** argv, char** env) {
    // turn off unused variable warnings
    if (0 && argc && argv && env) {}

    // Construct the Verilated model
    Vsystolic_array_axis* dut = new Vsystolic_array_axis();

    //load a_matrix.bin using ifstream

    std::ifstream a_matrix_bin("a_matrix.bin", std::ios::binary);
    if (!a_matrix_bin) {
        std::cerr << "ERROR: could not open a_matrix.bin" << std::endl;
        exit(1);
    }
    //load b_matrix.bin using ifstream
    std::ifstream b_matrix_bin("b_matrix.bin", std::ios::binary);
    if (!b_matrix_bin) {
        std::cerr << "ERROR: could not open b_matrix.bin" << std::endl;
        exit(1);
    }
    //load c_matrix.bin using ifstream
    std::ifstream c_matrix_bin("c_matrix.bin", std::ios::binary);
    if (!c_matrix_bin) {
        std::cerr << "ERROR: could not open c_matrix.bin" << std::endl;
        exit(1);
    }
    //store generated results.bin using ofstream
    std::ofstream results("results.bin", std::ios::binary);
    if (!results) {
        std::cerr << "ERROR: could not open results.bin" << std::endl;
        exit(1);
    }

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
    dut->rst = 0;
    dut->row_data_in_vld = 0;
    dut->col_data_in_vld = 0;
    dut->row_data_out_rdy = 0;

    int counter = 0;
    srand( time(NULL) );
    
    while (timestamp < RUN_CYCLES) {      
        bool clk_transition = (timestamp % CLOCK_PERIOD) == 0;
        if (clk_transition) 
            dut->clk = !dut->clk; 

        if (timestamp > 1 && timestamp < RESET_TIME) {
            dut->rst = 1;  // Assert reset
        } else {
            dut->rst = 0;  // Deassert reset
        }
        
        // Evaluate model
        dut->eval();
        
        // Verilator allows to access verilator public data structure
        if (clk_transition && dut->clk) {
            if (timestamp > RESET_TIME) {
                /*** Deal with input signals ***/
                // Flush the pipeline telling no further input data
                dut->flush = 0;
                

                // Set dut->row_data_in valid or not
                if (!a_matrix_bin.eof()) {
                    dut->row_data_in_vld = 1;
                } else {
                    dut->row_data_in_vld = 0;
                }
                
                // Set dut->col_data_in valid or not
                if (!b_matrix_bin.eof()) {
                    dut->col_data_in_vld = 1;
                } else  {
                    dut->col_data_in_vld = 0;
                }

                // Deal with rst_accumulator, stream_out signals, 
                // and read a_matrix.bin to dut->row_data_in util end of file
                if (dut->row_data_in_vld && dut->row_data_in_rdy) { // transfer
                    if (!a_matrix_bin.eof()) {
                        a_matrix_bin.read(reinterpret_cast<char*>(&dut->row_data_in), ROWS);
                        if (counter % K == 0)  dut->rst_accumulator_rdy = 1;
                        else                   dut->rst_accumulator_rdy = 0;
                        if (counter % K == K-1)  dut->stream_out_rdy = 1;
                        else                     dut->stream_out_rdy = 0;
                        counter++;
                    }
                }

                // read b_matrix.bin to dut->col_data_in util end of file
                if (dut->col_data_in_vld && dut->col_data_in_rdy) { // transfer
                    if (!b_matrix_bin.eof()) {
                        b_matrix_bin.read(reinterpret_cast<char*>(&dut->col_data_in), COLS);
                    }
                }

                
                /*** Deal with output signals ***/
                // Pull-up dut->row_data_out_rdy
                dut->row_data_out_rdy = 1;

                // Store dut->row_data_out to c_matrix_gen.bin
                if (dut->row_data_out_vld && dut->row_data_out_rdy) { // transfer when vld && rdy
                    results.write(reinterpret_cast<char*>(&dut->row_data_out), ROWS);
                }
                
                
                systolic_steps++;
                // std::cout << "systolic_steps = " << systolic_steps << std::endl;
                timestamp_WB = timestamp - RESET_TIME;  
            }
            
            
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
    // Close files
    a_matrix_bin.close();
    b_matrix_bin.close();
    c_matrix_bin.close();
    results.close();
    
    // Fin
    exit(0);
}