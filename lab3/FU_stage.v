`include "define.vh"

module FU_STAGE(
  input wire                               clk,
  input wire                               reset,
  input wire [`from_DE_to_FU_WIDTH-1:0]    from_DE_to_FU,
  output wire [`from_FU_to_DE_WIDTH-1:0]   from_FU_to_DE
);

  wire [`ALUDATABITS-1:0]   OP1_FU;
  wire [`ALUDATABITS-1:0]   OP2_FU;
  wire [`ALUOPBITS-1:0]     ALUOP_FU;
  wire [`ALUCSRINBITS-1:0]  CSR_ALU_IN_FU;

  assign {
    OP1_FU,
    OP2_FU,
    ALUOP_FU,
    CSR_ALU_IN_FU
  } = from_DE_to_FU;


  wire [`ALUDATABITS-1:0]   OP3_FU;
  wire [`ALUCSROUTBITS-1:0] CSR_ALU_OUT_FU;

  external_alu my_ext_alu (
    .clk         (clk),
    .rst         (reset),
    .OP1         (OP1_FU),
    .OP2         (OP2_FU),
    .OP3         (OP3_FU),
    .ALUOP       (ALUOP_FU),
    .CSR_ALU_OUT (CSR_ALU_OUT_FU),
    .CSR_ALU_IN  (CSR_ALU_IN_FU)
  );

  assign from_FU_to_DE = {
    OP3_FU,
    CSR_ALU_OUT_FU
  };

endmodule