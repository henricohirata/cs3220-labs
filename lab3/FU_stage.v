`include "define.vh" 

module FU_STAGE(
  input wire                              clk,
  input wire                              reset,
  input wire [`from_DE_to_FU_WIDTH-1:0]    from_DE_to_FU,   
  output wire [`from_FU_to_DE_WIDTH-1:0]   from_FU_to_DE
);
  
  // TODO(in-class): Instantiate external_alu and wire the DE↔FU buses.
  //
  // Suggested steps (match field order with de_stage.v; check define.vh widths):
  //   1) Unpack from_DE_to_FU into wires: OP1, OP2, ALUOP, CSR_ALU_IN
  //      (widths: `ALUDATABITS, `ALUOPBITS, `ALUCSRINBITS).
  //   2) Instantiate external_alu (see port list in external_alu_wrapper.v /
  //      the README datasheet). Prefer named ports: .OP1(...), .CSR_ALU_IN(...), etc.
  //      Pass clk and reset through; do NOT edit the ALU itself.
  //   3) Pack the ALU outputs OP3 + CSR_ALU_OUT into from_FU_to_DE
  //      (widths: `ALUDATABITS, `ALUCSROUTBITS).
  //
  // Hint: this file is mostly wiring; the handshake *control* lives in de_stage.v.




endmodule
