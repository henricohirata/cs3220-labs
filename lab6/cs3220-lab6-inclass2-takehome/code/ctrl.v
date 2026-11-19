module ctrl #(
    parameter IN_WIDTH = 8,
    parameter OUT_WIDTH = 16,
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter MULT_LAT = 1,
    parameter ACC_LAT = 1
)(
    input clk,
    input rst,
    input input_rst_accumulator,
    input input_stream_out_rdy,
    output [COLS-1:0] rst_accumulator,
    output [COLS-1:0] stream_out_rdy
);

    // ------------------------------------------------------------------
    // Delay amounts
    // ------------------------------------------------------------------
    //TODO [In-Class 2]: Replace the fixed number in RST_DELAY with a formula in MULT_LAT.
    // - The value below is from In-Class 1 and only works for MULT_LAT = 3.
    // - How it was counted: the pulse arrives together with the first input of a new dot product,
    //   and the accumulator should reset when the first PRODUCT of that dot product reaches the
    //   adder. That takes the multiplier pipeline, plus the register after it (see MAC.v).
    //
    // Suggestions [In-Class 2]:
    //   • Write the same count in terms of MULT_LAT instead of a fixed number.
    //   • Check: at MULT_LAT = 3 your formula must give 4, and run_inclass2.sh sweeps MULT_LAT
    //     from 2 to 6.
    localparam RST_DELAY = MULT_LAT + 1;

    //TODO [In-Class 2]: Replace the fixed number in STREAM_OUT_DELAY with a formula in MULT_LAT, ACC_LAT, and COLS.
    // - The value below is from In-Class 1 and only works for MULT_LAT = 3 and COLS = 2.
    // - How it was counted: the pulse arrives with the LAST input at column 0. In a 2x2 array,
    //   column 1 (the last column) gets its last input 1 cycle later. Then add the time for that
    //   product to reach the adder (the same count as RST_DELAY), and 1 cycle for the adder itself
    //   (ACC_LAT = 1).
    // - The chain output goes through one more register (stream_out_rdy_reg) before the MACs see
    //   it. That +1 is already in the code below; do not count it here.
    //
    // Suggestions [In-Class 2]:
    //   • In an array with COLS columns, how many cycles after column 0 does the last column get
    //     its last input?
    //   • Write the delay in terms of MULT_LAT, ACC_LAT, and COLS.
    //   • Check: at MULT_LAT = 3 and COLS = 2 your formula must give 6.
    //   • Check in trace.vcd: the last column's stream_out_rdy_in should be high on the cycle right
    //     after its adder_out shows the finished sum (so psum[0] holds it).
    localparam STREAM_OUT_DELAY = (COLS - 1) + RST_DELAY + ACC_LAT;


    // ------------------------------------------------------------------
    // rst_accumulator: delay chain to column 0, then 1 extra cycle per column (provided)
    // Column j's data arrives j cycles after column 0's, so its reset pulse does too.
    // ------------------------------------------------------------------
    reg [RST_DELAY-1:0] rst_delay;
    wire [COLS-1:0]     rst_col;

    always @(posedge clk) begin
        if (rst) rst_delay[0] <= 1'b0;
        else     rst_delay[0] <= input_rst_accumulator;
    end

    genvar j;
    generate
        for (j = 1; j < RST_DELAY; j = j + 1) begin : rst_delay_chain
            always @(posedge clk) begin
                if (rst) rst_delay[j] <= 1'b0;
                else     rst_delay[j] <= rst_delay[j-1];
            end
        end
    endgenerate

    assign rst_col[0] = rst_delay[RST_DELAY-1];

    generate
        for (j = 1; j < COLS; j = j + 1) begin : rst_col_chain
            reg rst_col_reg;
            always @(posedge clk) begin
                if (rst) rst_col_reg <= 1'b0;
                else     rst_col_reg <= rst_col[j-1];
            end
            assign rst_col[j] = rst_col_reg;
        end
    endgenerate

    assign rst_accumulator = rst_col;


    // ------------------------------------------------------------------
    // stream_out_rdy: one delay chain, then the same pulse goes to every column (provided)
    // ------------------------------------------------------------------
    reg [STREAM_OUT_DELAY-1:0] stream_out_delay;
    reg [COLS-1:0]             stream_out_rdy_reg;

    always @(posedge clk) begin
        if (rst) stream_out_delay[0] <= 1'b0;
        else     stream_out_delay[0] <= input_stream_out_rdy;
    end

    generate
        for (j = 1; j < STREAM_OUT_DELAY; j = j + 1) begin : stream_out_delay_chain
            always @(posedge clk) begin
                if (rst) stream_out_delay[j] <= 1'b0;
                else     stream_out_delay[j] <= stream_out_delay[j-1];
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) stream_out_rdy_reg <= '0;
        else     stream_out_rdy_reg <= {COLS{stream_out_delay[STREAM_OUT_DELAY-1]}};
    end

    assign stream_out_rdy = stream_out_rdy_reg;

endmodule
