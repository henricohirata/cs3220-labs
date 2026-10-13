 `include "define.vh" 


 module external_alu(
    input clk,
    input rst,
    input [`ALUDATABITS-1:0] OP1,
    input [`ALUDATABITS-1:0] OP2,
    output [`ALUDATABITS-1:0] OP3,
    input [`ALUOPBITS-1:0] ALUOP,
    output [`ALUCSROUTBITS-1:0] CSR_ALU_OUT,
    input [`ALUCSRINBITS-1:0] CSR_ALU_IN
);


wire div_input_a_ack, div_input_b_ack;
wire mult_input_a_ack, mult_input_b_ack;

wire div_output_z_ack;
wire mult_output_z_ack;

wire div_input_a_stb, div_input_b_stb;
wire mult_input_a_stb, mult_input_b_stb;

wire div_output_z_stb;
wire mult_output_z_stb;

wire ALU_ready_1;
wire ALU_ready_2;
wire ALU_resutls_valid;

wire [`ALUDATABITS-1:0] div_output_z;
wire [`ALUDATABITS-1:0] mult_output_z;

// alu state transition from get_a to get_b
assign ALU_ready_1 = (ALUOP == 1) ? (div_input_a_ack ) : (mult_input_a_ack);
assign ALU_ready_2 = (ALUOP == 1) ? (div_input_b_ack ) : (mult_input_b_ack);
assign ALU_resutls_valid = (ALUOP == 1) ? div_output_z_stb : mult_output_z_stb;
assign CSR_ALU_OUT = {ALU_resutls_valid, ALU_ready_2, ALU_ready_1};

assign div_input_a_stb = (ALUOP == 1) ? CSR_ALU_IN[1] : 1'b0;
assign div_input_b_stb = (ALUOP == 1) ? CSR_ALU_IN[2] : 1'b0;
assign mult_input_a_stb = (ALUOP == 2) ? CSR_ALU_IN[1] : 1'b0;
assign mult_input_b_stb = (ALUOP == 2) ? CSR_ALU_IN[2] : 1'b0;


assign div_output_z_ack = (ALUOP == 1) ? CSR_ALU_IN[0] : 1'b0;
assign mult_output_z_ack = (ALUOP == 2) ? CSR_ALU_IN[0] : 1'b0;

assign OP3 = (ALUOP == 1) ? div_output_z : mult_output_z;


divider div0(
        .input_a(OP1),
        .input_b(OP2),
        .input_a_stb(div_input_a_stb),
        .input_b_stb(div_input_b_stb),
        .output_z_ack(div_output_z_ack),
        .clk(clk),
        .rst(rst),
        .output_z(div_output_z),
        .output_z_stb(div_output_z_stb),
        .input_a_ack(div_input_a_ack),
        .input_b_ack(div_input_b_ack)
        );


multiplier mult0(
        .input_a(OP1),
        .input_b(OP2),
        .input_a_stb(mult_input_a_stb),
        .input_b_stb(mult_input_b_stb),
        .output_z_ack(mult_output_z_ack),
        .clk(clk),
        .rst(rst),
        .output_z(mult_output_z),
        .output_z_stb(mult_output_z_stb),
        .input_a_ack(mult_input_a_ack),
        .input_b_ack(mult_input_b_ack)
    );




endmodule
