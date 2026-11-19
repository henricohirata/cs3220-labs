module systolic_array #(
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
    input                       rst_in,
    input                       rst_accumulator_rdy_in, // If 1, reset accumulator in array
    input                       stream_out_rdy_in_in,      // If 1, stream acc result out

    input [IN_WIDTH*ROWS-1:0]   row_data_in_in,
    input [IN_WIDTH*COLS-1:0]   col_data_in_in,
    output [OUT_WIDTH*ROWS-1:0] row_data_out
);
    // ------------------------------------------------------------------
    // Register inputs (provided) // something todo with verilator timing issue
    // ------------------------------------------------------------------
    reg       rst;
    reg       rst_accumulator_rdy;
    reg       stream_out_rdy;
    reg [IN_WIDTH*ROWS-1:0] row_data_in;
    reg [IN_WIDTH*COLS-1:0] col_data_in;

    always @(posedge clk) begin
        rst                 <= rst_in;
        rst_accumulator_rdy <= rst_accumulator_rdy_in;
        stream_out_rdy      <= stream_out_rdy_in_in;
        row_data_in         <= row_data_in_in;
        col_data_in         <= col_data_in_in;
    end


    // ------------------------------------------------------------------
    // Ctrl unit (provided)
    // One rst_accumulator and one stream_out_rdy signal per column, delayed in ctrl.v
    // ------------------------------------------------------------------
    wire [COLS-1:0] control_rst_accumulator_rdy;
    wire [COLS-1:0] control_stream_out_rdy;

    ctrl #(
        .IN_WIDTH(IN_WIDTH),
        .OUT_WIDTH(OUT_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS),
        .MULT_LAT(MULT_LAT),
        .ACC_LAT(ACC_LAT)
    ) ctrl_0 (
        .clk(clk),
        .rst(rst),
        .input_rst_accumulator(rst_accumulator_rdy),
        .input_stream_out_rdy(stream_out_rdy),
        .rst_accumulator(control_rst_accumulator_rdy),
        .stream_out_rdy(control_stream_out_rdy)
    );


    // ------------------------------------------------------------------
    // NOTE [Take-Home Part A]: MxN arrays with N = K
    // - Part A may not need any code changes. If your In-Class 2 design uses ROWS and COLS
    //   correctly everywhere (wire arrays, loop bounds, delays, OWN_DELAY), it may already pass ./run.sh.
    // - Either way, explain in your report how your In-Class 2 design handles MxN arrays, and what
    //   you changed, if anything.
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    // In-Class 1 solution: 2x2 array built from 4 MAC instances (provided)
    //
    //              col_data_in[0]      col_data_in[1]
    //                   |                   |
    //   row_data_in[0] -> PE(0,0) ----------> PE(0,1)
    //                   |                   |
    //   row_data_in[1] -> PE(1,0) ----------> PE(1,1)
    //
    // - Row data flows left -> right. Column data and both control signals flow top -> bottom.
    // - Results (psum_out) flow right -> left and leave the array from column 0 on row_data_out.
    //
    //TODO [In-Class 2]: Replace these 4 instances (and the named wires below) with a generate block
    // that works for any ROWS and COLS. See README_InClass2.md for hints.
    // Suggestions [In-Class 2]:
    //   • Declare 2-D wire arrays one entry larger than the grid, for example:
    //       wire [IN_WIDTH-1:0]  row_w  [0:ROWS-1][0:COLS];    // row_w[r][c] feeds PE(r,c)
    //       wire [IN_WIDTH-1:0]  col_w  [0:ROWS][0:COLS-1];    // col_w[r][c] feeds PE(r,c)
    //       wire                 rst_w  [0:ROWS][0:COLS-1];    // rst_accumulator, rst_w[r][c] feeds PE(r,c)
    //       wire                 so_w   [0:ROWS][0:COLS-1];    // stream_out_rdy,  so_w[r][c] feeds PE(r,c)
    //       wire [OUT_WIDTH-1:0] psum_w [0:ROWS-1][0:COLS];    // psum_w[r][c] = PE(r,c).psum_out
    //   • Edges in their own loops: top row reads ctrl and col_data_in, left column reads
    //     row_data_in, psum_w[r][COLS] = 0 (no right neighbor), row_data_out row r = psum_w[r][0].
    //   • One nested loop (genvar r over ROWS, genvar c over COLS) instantiates every MAC.
    //     Write PE(r,c) by replacing the fixed indices of the 4 instances below with r and c.
    //     Port mapping for PE(r,c):
    //       Port                 Connects to         Port                  Connects to
    //       rst_accumulator_in   rst_w[r][c]         rst_accumulator_out   rst_w[r+1][c]
    //       stream_out_rdy_in    so_w[r][c]          stream_out_rdy_out    so_w[r+1][c]
    //       row_data_in          row_w[r][c]         row_data_out          row_w[r][c+1]
    //       col_data_in          col_w[r][c]         col_data_out          col_w[r+1][c]
    //       bypass_data_in       psum_w[r][c+1]      psum_out              psum_w[r][c]
    //   • Pass .ROWS_IDX(r), .COLS_IDX(c), and OWN_DELAY as a formula in c and COLS.
    //   • Name the loops (begin : g_row / begin : g_col) so trace.vcd shows g_row[1].g_col[0]...
    //   • Check: with ROWS = COLS = 2, your generate block must pass run_inclass1.sh just like
    //     the 4 hand-written instances did.
    // ------------------------------------------------------------------


    wire [IN_WIDTH-1:0] row_w [0:ROWS-1][0:COLS];
    wire [IN_WIDTH-1:0] col_w [0:ROWS][0:COLS-1];
    wire rst_w [0:ROWS][0:COLS-1];
    wire so_w [0:ROWS][0:COLS-1];
    wire [OUT_WIDTH-1:0] psum_w [0:ROWS-1][0:COLS];

    genvar r, c;

    generate
        for (c = 0; c < COLS; c = c + 1) begin : g_top
            assign col_w[0][c] = col_data_in[IN_WIDTH*c +: IN_WIDTH];
            assign rst_w[0][c] = control_rst_accumulator_rdy[c];
            assign so_w[0][c] = control_stream_out_rdy[c];
        end
    endgenerate

    generate
        for (r = 0; r < ROWS; r = r + 1) begin : g_edge
            assign row_w[r][0]    = row_data_in[IN_WIDTH*r +: IN_WIDTH];
            assign psum_w[r][COLS] = '0;
            assign row_data_out[OUT_WIDTH*r +: OUT_WIDTH] = psum_w[r][0];
        end
    endgenerate

    generate
        for (r = 0; r < ROWS; r = r + 1) begin : g_row
            for (c = 0; c < COLS; c = c + 1) begin : g_col
                mac #(
                    .IN_WIDTH(IN_WIDTH), .IN_FRAC(IN_FRAC), .OUT_WIDTH(OUT_WIDTH), .OUT_FRAC(OUT_FRAC),
                    .MULT_LAT(MULT_LAT), .ADD_LAT(ACC_LAT), .K(K), .ROWS(ROWS), .COLS(COLS),
                    .ROWS_IDX(r), .COLS_IDX(c), .OWN_DELAY(COLS - 1 - c)
                ) mac_inst (
                    .clk(clk),
                    .rst(rst),
                    .rst_accumulator_in(rst_w[r][c]),
                    .stream_out_rdy_in(so_w[r][c]),
                    .row_data_in(row_w[r][c]),
                    .col_data_in(col_w[r][c]),
                    .bypass_data_in(psum_w[r][c+1]),
                    .row_data_out(row_w[r][c+1]),
                    .col_data_out(col_w[r+1][c]),
                    .rst_accumulator_out(rst_w[r+1][c]),
                    .stream_out_rdy_out(so_w[r+1][c]),
                    .psum_out(psum_w[r][c])
                );
            end
        end
    endgenerate

endmodule
