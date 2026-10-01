module alu #(
    parameter DATA_WIDTH = 32,
    parameter INST_WIDTH = 4
)(
    input                   i_clk,
    input                   i_rst_n,
    input  [DATA_WIDTH-1:0] i_data_a,
    input  [DATA_WIDTH-1:0] i_data_b,
    input  [INST_WIDTH-1:0] i_inst,
    input                   i_valid,
    output reg [DATA_WIDTH-1:0] o_data,
    output reg                  o_overflow,
    output reg                  o_valid
);

    localparam 
    S_ADD = 4'd0,
    S_SUB = 4'd1,
    S_MUL = 4'd2,
    S_MAX = 4'd3,
    S_MIN = 4'd4,
    U_ADD = 4'd5,
    U_SUB = 4'd6,
    U_MUL = 4'd7,
    U_MAX = 4'd8,
    U_MIN = 4'd9,
    AND = 4'd10,
    OR = 4'd11,
    XOR = 4'd12,
    BIT_FLIP = 4'd13,
    BIT_REV = 4'd14;

    wire signed [DATA_WIDTH-1:0] s_a = i_data_a;
    wire signed [DATA_WIDTH-1:0] s_b = i_data_b;

    wire signed [32:0] s_add_res = {s_a[31], s_a} + {s_b[31], s_b};
    wire signed [32:0] s_sub_res = {s_a[31], s_a} - {s_b[31], s_b};
    wire signed [63:0] s_mul_res = s_a * s_b;

    wire [32:0] u_add_res = {1'b0, i_data_a} + {1'b0, i_data_b};
    wire [32:0] u_sub_res = {1'b0, i_data_a} - {1'b0, i_data_b};
    wire [63:0] u_mul_res = i_data_a * i_data_b;

    reg [DATA_WIDTH-1:0] next_data;
    reg next_overflow;

    always @(*) begin

        next_data = 32'b0;
        next_overflow = 1'b0;

        case (i_inst)

            S_ADD: begin
                next_data = s_add_res[31:0];
                next_overflow = (i_data_a[31] == i_data_b[31]) && (i_data_a[31] != s_add_res[31]);

            end

            S_SUB: begin
                next_data = s_sub_res[31:0];
                next_overflow = (i_data_a[31] != i_data_b[31]) && (i_data_a[31] != s_sub_res[31]);
            end

            S_MUL: begin
                next_data = s_mul_res[31:0];
                next_overflow = (s_mul_res[63:32] != {32{s_mul_res[31]}});
            end

            S_MAX: begin
                next_data = (s_a >= s_b) ? i_data_a : i_data_b;
                next_overflow = 1'b0;
            end

            S_MIN: begin
                next_data = (s_a <= s_b) ? i_data_a : i_data_b;
                next_overflow = 1'b0;
            end

            U_ADD: begin
                next_data = u_add_res[31:0];
                next_overflow = u_add_res[32];
            end

            U_SUB: begin
                next_data = u_sub_res[31:0];
                next_overflow = u_sub_res[32];
            end

            U_MUL: begin
                next_data = u_mul_res[31:0];
                next_overflow = |u_mul_res[63:32];
            end

            U_MAX: begin
                next_data = (i_data_a >= i_data_b) ? i_data_a : i_data_b;
                next_overflow = 1'b0;
            end

            U_MIN: begin
                next_data = (i_data_a <= i_data_b) ? i_data_a : i_data_b;
                next_overflow = 1'b0;
            end

            AND: begin 
                next_data = i_data_a & i_data_b;
                next_overflow = 1'b0;
            end

            OR: begin 
                next_data = i_data_a | i_data_b;
                next_overflow = 1'b0;
            end

            XOR: begin
                next_data = i_data_a ^ i_data_b;
                next_overflow = 1'b0;
            end

            BIT_FLIP: begin
                next_data = ~i_data_a;
                next_overflow = 1'b0;
            end

            BIT_REV: begin
                next_data = {i_data_a[0], i_data_a[1], i_data_a[2], i_data_a[3], i_data_a[4], i_data_a[5], i_data_a[6], i_data_a[7], i_data_a[8], i_data_a[9], i_data_a[10], i_data_a[11], i_data_a[12], i_data_a[13], i_data_a[14], i_data_a[15], i_data_a[16], i_data_a[17], i_data_a[18], i_data_a[19], i_data_a[20], i_data_a[21], i_data_a[22], i_data_a[23], i_data_a[24], i_data_a[25], i_data_a[26], i_data_a[27], i_data_a[28], i_data_a[29], i_data_a[30], i_data_a[31]};
                next_overflow = 1'b0;
            end
        endcase
    end

    always @(posedge i_clk or negedge i_rst_n) begin

        if (!i_rst_n) begin
            o_data <= 32'b0;
            o_overflow <= 1'b0;
            o_valid <= 1'b0;
        end else begin
            o_valid <= i_valid;
            if (i_valid) begin
                o_data <= next_data;
                o_overflow <= next_overflow;
            end else begin
                o_overflow <= 1'b0;
            end
        end
    end

endmodule