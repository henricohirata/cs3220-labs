module systolic_array_axis #(
    parameter IN_WIDTH          = 8,
    parameter IN_FRAC           = 0,
    parameter OUT_WIDTH         = 8,
    parameter OUT_FRAC          = 0,
    parameter MULT_LAT          = 3,                 // Multiplication latency
    parameter ACC_LAT           = 1,                 // Addition latency (<=1, not support pipelined acc)
    parameter ROWS              = 4,                 // Row number of systolic array
    parameter K                 = 4,
    parameter COLS              = 4                  // Column number of systolic array
)(
    input                       clk,
    input                       rst,
    input                       en,
    input                       flush,               // If 1, flush the pipeline
    input                       rst_accumulator_rdy, // If 1, reset accumulator in array
    input                       stream_out_rdy,      // If 1, stream acc result out
    input [IN_WIDTH*ROWS-1:0]   row_data_in,         // AXIS row_data_in
    input                       row_data_in_vld,
    output                      row_data_in_rdy,
    input [IN_WIDTH*COLS-1:0]   col_data_in,         // AXIS col_data_in
    input                       col_data_in_vld,
    output                      col_data_in_rdy,
    output [OUT_WIDTH*ROWS-1:0] row_data_out,        // AXIS row_data_out
    output                      row_data_out_vld,
    input                       row_data_out_rdy
);

    //TODO [Take-Home Part C]: Signal declarations



    //TODO [Take-Home Part C]: Input handshake
    // - A beat moves only on a cycle where vld && rdy are both high
    // - rst_accumulator_rdy and stream_out_rdy belong to the current row_data_in beat
    // - What should your systolic array see on a cycle where no beat transfers?



    //TODO [Take-Home Part C]: systolic_array instantiation
    // - Reuse your design from Parts A and B as it is; do not change its interface



    //TODO [Take-Home Part C]: Output alignment
    // - Your systolic_array outputs row i of C i cycles after row 0
    // - Each output beat here must hold one full column of C (all rows in the same beat)
    // - When is a value on your array's row_data_out a real result, and when is it filler?



    //TODO [Take-Home Part C]: Output buffering and handshake
    // - The receiver may hold row_data_out_rdy low; results already in the array keep coming out
    // - Hold row_data_out and row_data_out_vld stable while row_data_out_rdy is low
    // - Do not make row_data_out_vld depend combinationally on row_data_out_rdy
    // - The synchronous FIFO (synchronus_fifo.v) may be useful here; how deep does it need to be?


endmodule
