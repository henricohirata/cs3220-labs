module mac #(
    parameter IN_WIDTH = 8,
    parameter IN_FRAC = 0,
    parameter OUT_WIDTH = 8,
    parameter OUT_FRAC = 0,
    parameter MULT_LAT = 3,
    parameter ADD_LAT = 1,
    parameter K = 1,
    parameter ROWS = 1,
    parameter COLS = 1,
    parameter COLS_IDX = 1,
    parameter ROWS_IDX = 1,
    parameter OWN_DELAY = 0        // Extra cycles this MAC holds its own result before sending it out (set in systolic_array.v)
)(
    input                      clk,
    input                      rst,
    input                      rst_accumulator_in,
    input                      stream_out_rdy_in,
    input       [IN_WIDTH-1:0] row_data_in,
    input       [IN_WIDTH-1:0] col_data_in,
    input       [IN_WIDTH-1:0] bypass_data_in,
    output reg  [IN_WIDTH-1:0] row_data_out,
    output reg  [IN_WIDTH-1:0] col_data_out,
    output reg                 rst_accumulator_out,
    output reg                 stream_out_rdy_out,
    output reg [OUT_WIDTH-1:0] psum_out
);

    // ------------------------------------------------------------------
    // Signal declarations (provided)
    // ------------------------------------------------------------------
    localparam COLS_WIDTH = (COLS > 1) ? $clog2(COLS) : 1;

    // Shift register that holds this MAC's own result for OWN_DELAY extra cycles
    reg  [OUT_WIDTH-1:0]    psum [0:(1 << COLS_WIDTH)-1];
    reg  [OUT_WIDTH-1:0]    psum_reg;
    reg  [OUT_WIDTH-1:0]    mult_out;

    wire [OUT_WIDTH-1:0]    multiplier_out;
    wire                    multiplier_done;

    wire [IN_WIDTH-1:0]     adder_in_A;
    wire [IN_WIDTH-1:0]     adder_in_B;
    wire [OUT_WIDTH-1:0]    adder_out;
    wire                    adder_done;

    // Bypass controls
    wire                    bypass_en;
    wire [31:0]             temp = COLS - 1;
    wire [COLS_WIDTH-1:0]   bypass_counter_max = temp[COLS_WIDTH-1:0];
    reg  [COLS_WIDTH-1:0]   bypass_counter;
    reg                     stream_started;
    reg                     stream_out_rdy_in_reg;


    // ------------------------------------------------------------------
    // Multiplier (provided)
    // ------------------------------------------------------------------
    multiplier #(
        .INPUT_A_WIDTH(IN_WIDTH),
        .INPUT_B_WIDTH(IN_WIDTH),
        .INPUT_A_FRAC(IN_FRAC),
        .INPUT_B_FRAC(IN_FRAC),
        .OUTPUT_WIDTH(OUT_WIDTH),
        .OUTPUT_FRAC(OUT_FRAC),
        .DELAY(MULT_LAT)
    ) mul (
        .clk(clk),
        .reset(rst),
        .stall(1'b0),
        .en(~rst),
        .a_in(row_data_in),
        .b_in(col_data_in),
        .out(multiplier_out),
        .done(multiplier_done)
    );

    // Register the multiplier output: products reach the adder 1 cycle after multiplier_done (provided)
    always @(posedge clk) begin
        if (rst) begin
            mult_out <= '0;
        end else if (multiplier_done) begin
            mult_out <= multiplier_out;
        end else begin
            mult_out <= '0;
        end
    end


    // ------------------------------------------------------------------
    // Adder / accumulator
    // ------------------------------------------------------------------
    // adder_in_A is the registered product. adder_in_B restarts the sum when rst_accumulator_in is high.
    assign adder_in_A = mult_out;
    assign adder_in_B = rst_accumulator_in ? '0 : adder_out;

    adder #(
        .INPUT_A_WIDTH(IN_WIDTH),
        .INPUT_B_WIDTH(IN_WIDTH),
        .INPUT_A_FRAC(IN_FRAC),
        .INPUT_B_FRAC(IN_FRAC),
        .OUTPUT_WIDTH(OUT_WIDTH),
        .OUTPUT_FRAC(OUT_FRAC),
        .DELAY(ADD_LAT)
    ) add (
        .clk(clk),
        .reset(rst),
        .stall(1'b0),
        .en(~rst && multiplier_done),
        .a_in(adder_in_A),
        .b_in(adder_in_B),
        .out(adder_out),
        .done(adder_done)
    );


    // ------------------------------------------------------------------
    // Pass row/col data and control signals to the next MAC (1 cycle per hop)
    // ------------------------------------------------------------------



    always @(posedge clk) begin
        if (rst) begin
            row_data_out        <= '0;
            col_data_out        <= '0;
            rst_accumulator_out <= 1'b0;
            stream_out_rdy_out  <= 1'b0;
        end else begin
            row_data_out        <= row_data_in;
            col_data_out        <= col_data_in;
            rst_accumulator_out <= rst_accumulator_in;
            stream_out_rdy_out  <= stream_out_rdy_in;
        end
    end

    // ------------------------------------------------------------------
    // Hold this MAC's own result (provided)
    // psum[0] is the accumulator value one cycle later; psum[i] is i cycles later than psum[0].
    // OWN_DELAY (set per column in systolic_array.v) picks how long to hold the result.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) psum[0] <= '0;
        else     psum[0] <= adder_out;
    end

    genvar i;
    generate
        for (i = 0; i < (1 << COLS_WIDTH) - 1; i = i + 1) begin : psum_propagate
            always @(posedge clk) begin
                if (rst) psum[i+1] <= '0;
                else     psum[i+1] <= psum[i];
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) psum_reg <= '0;
        else     psum_reg <= psum[OWN_DELAY];
    end


    // ------------------------------------------------------------------
    // Stream out: send this MAC's own result, then pass its right neighbor's results
    //
    // How it works, for one row of COLS MACs:
    // - Results move right -> left, one MAC per cycle: each MAC's psum_out feeds the bypass_data_in
    //   of the MAC on its left. Column 0's psum_out is the array output for that row.
    // - Every column gets its stream_out_rdy_in pulse on the same cycle (see ctrl.v).
    // - On that pulse, each MAC first sends its OWN result (psum_reg). For the next COLS-1 cycles it
    //   forwards whatever arrives on bypass_data_in from the right. This is "bypassing".
    // - OWN_DELAY (systolic_array.v) lines the own results up, so column 0 sends C[i][0], then
    //   C[i][1], C[i][2], ... arrive from the right one cycle apart.
    //
    // Signals used below (declared above):
    // - stream_started        : 0 after reset, 1 forever after the first stream_out_rdy_in.
    //                           Before the first result, the MAC should output 0.
    // - stream_out_rdy_in_reg : stream_out_rdy_in delayed by 1 cycle.
    // - bypass_counter        : counts the COLS-1 bypass cycles. It starts the cycle after the pulse
    //                           (use stream_out_rdy_in_reg), counts up to bypass_counter_max, then
    //                           returns to 0.
    // - bypass_en             : 1 while this MAC is bypassing, i.e. while bypass_counter is not 0.
    //
    // Output mux (register psum_out on the clock):
    // - while bypassing                 : bypass_data_in
    // - otherwise, once stream_started  : psum_reg (this MAC's own result)
    // - otherwise                       : 0
    //
    //TODO [Take-Home Part B]: When N != K, a MAC's own result can be ready while it is still
    // passing results from its right neighbor (or long before its turn to send).
    // - Where can the own result wait without being overwritten by the next dot product?
    // - Could synchronus_fifo.v help? How deep does it need to be?
    // ------------------------------------------------------------------

    // stream_started
    always @(posedge clk) begin
        if (rst)                    stream_started <= 1'b0;
        else if (stream_out_rdy_in) stream_started <= 1'b1;
    end

    // stream_out_rdy_in_reg
    always @(posedge clk) begin
        if (rst) stream_out_rdy_in_reg <= 1'b0;
        else     stream_out_rdy_in_reg <= stream_out_rdy_in;
    end

    // bypass_en and bypass_counter
    assign bypass_en = (bypass_counter != 0);
    always @(posedge clk) begin
        if (rst)                                     bypass_counter <= '0;
        else if (bypass_counter == bypass_counter_max) bypass_counter <= '0;
        else if (stream_out_rdy_in_reg || bypass_en) bypass_counter <= bypass_counter + 1'b1;
        else                                         bypass_counter <= '0;
    end

    // Output mux (drive psum_out)
    always @(posedge clk) begin
        if (rst)                 psum_out <= '0;
        else if (bypass_en)      psum_out <= bypass_data_in;
        else if (stream_started) psum_out <= psum_reg;
        else                     psum_out <= '0;
    end

endmodule
