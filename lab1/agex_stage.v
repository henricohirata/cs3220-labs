`include "define.vh"

module AGEX_STAGE(
  input wire clk,
  input wire reset,
  input wire [`from_MEM_to_AGEX_WIDTH-1:0] from_MEM_to_AGEX,
  input wire [`from_WB_to_AGEX_WIDTH-1:0] from_WB_to_AGEX,
  input wire [`DE_latch_WIDTH-1:0] from_DE_latch,
  output wire [`AGEX_latch_WIDTH-1:0] AGEX_latch_out,
  output wire [`from_AGEX_to_FE_WIDTH-1:0] from_AGEX_to_FE,
  output wire [`from_AGEX_to_DE_WIDTH-1:0] from_AGEX_to_DE
);

  /////////////////////////////////////////////////////////////////////////////
  //  This is the only file you edit during the two in-class sessions.
  //
  //    In-Class 1   Task 1  unpack the DE latch          -> test1..test3
  //                 Task 2  the ALU
  //                 Task 3  pack the AGEX latch
  //    In-Class 2   Task 4  the branch condition         -> test4..test8
  //                 Task 5  branch target and redirect
  //    Take-home    Task 6  extend the decode            (de_stage.v)
  //                 Task 7  more ALU arms, jump targets     
  //    Bonus        Task 8  the rest of the ISA          (also mem_stage.v,
  //                                                       wb_stage.v, define.vh)
  //
  //  How to run:
  //    make                                     build + run the test named in
  //                                             define.vh, write trace.vcd
  //    IDMEMINITFILE=$PWD/test/inclass_1/test1.mem make tests
  //                                             build + run one specific test
  //    ./run_tests.sh inclass_1                 run the three In-Class 1 tests
  //    ./run_tests.sh inclass_2                 run the five In-Class 2 tests
  //    make clean                               delete obj_dir, logs, trace.vcd
  /////////////////////////////////////////////////////////////////////////////

  `UNUSED_VAR (from_MEM_to_AGEX)
  `UNUSED_VAR (from_WB_to_AGEX)

  reg [`AGEX_latch_WIDTH-1:0] AGEX_latch;
  // wire to send the AGEX latch contents to other pipeline stages
  assign AGEX_latch_out = AGEX_latch;

  wire[`AGEX_latch_WIDTH-1:0] AGEX_latch_contents;

  wire valid_AGEX;
  wire [`INSTBITS-1:0]inst_AGEX;
  wire [`DBITS-1:0]PC_AGEX;
  wire [`DBITS-1:0] inst_count_AGEX;
  wire [`DBITS-1:0] pcplus_AGEX;
  wire [`IOPBITS-1:0] op_I_AGEX;
  reg br_cond_AGEX; // 1 means a branch condition is satisified. 0 means a branch condition is not satisifed

  wire is_br_AGEX;
  wire wr_reg_AGEX;
  wire [`REGNOBITS-1:0] wregno_AGEX;

  wire [`DBITS-1:0] regval1_AGEX;
  wire [`DBITS-1:0] regval2_AGEX;
  wire [`DBITS-1:0] sxt_imm_AGEX;

  reg [`DBITS-1:0] br_target_AGEX;
  wire br_mispred_AGEX;

  reg [`DBITS-1:0] aluout_AGEX;

  wire rd_mem_AGEX;
  wire wr_mem_AGEX;
  wire [`DBITS-1:0] wr_val_AGEX;
  wire [`DBITS-1:0] memaddr_AGEX;

  // ===== Task 1: unpack the DE latch ============================
  //
  //   de_stage.v packs 12 fields into `DE_latch_WIDTH bits. See
  //   DE_latch_contents near the bottom of de_stage.v.  Six of them are named
  //   below; the other six are still buried inside de_latch_rest.
  //
  //   TODO: replace de_latch_rest with those six fields, in the order
  //   de_stage.v packed them, then delete the wire declaration just below this
  //   comment.  All six are already declared for you a few lines up.
  //
  // ===========================================================================
  wire [`DE_latch_WIDTH - (1 + `INSTBITS + `DBITS + `DBITS + `IOPBITS + `DBITS) - 1 : 0] de_latch_rest;

  assign  {
            valid_AGEX,
            inst_AGEX,
            PC_AGEX,
            pcplus_AGEX,
            op_I_AGEX,
            inst_count_AGEX,
            // de_latch_rest        // <-- Task 1: replace with the six remaining fields
            regval1_AGEX,
            regval2_AGEX,
            sxt_imm_AGEX,
            is_br_AGEX,
            wr_reg_AGEX,
  	        wregno_AGEX
          } = from_DE_latch;


  // ===== Task 2: the ALU ========================================
  //
  //   TODO: declare aluout_AGEX and write the case that computes it.
  //
  //   In-Class 1 only needs the `ADD_I and `ADDI_I arms.  Keep the default arm:
  //   a combinational block that does not assign its output on every path
  //   infers a latch.  Task 7 adds more arms.
  //
  // ===========================================================================
  always @ (*) begin
    case (op_I_AGEX)

      `ADD_I: aluout_AGEX = regval1_AGEX + regval2_AGEX;
      `ADDI_I: aluout_AGEX = regval1_AGEX + sxt_imm_AGEX;
      `SUB_I: aluout_AGEX = regval1_AGEX - regval2_AGEX;
      `MUL_I: aluout_AGEX = regval1_AGEX * regval2_AGEX;

      `AND_I: aluout_AGEX = regval1_AGEX & regval2_AGEX;
      `ANDI_I: aluout_AGEX = regval1_AGEX & sxt_imm_AGEX;
      `OR_I: aluout_AGEX = regval1_AGEX | regval2_AGEX;
      `ORI_I: aluout_AGEX = regval1_AGEX | sxt_imm_AGEX;
      `XOR_I: aluout_AGEX = regval1_AGEX ^ regval2_AGEX;
      `XORI_I: aluout_AGEX = regval1_AGEX ^ sxt_imm_AGEX;

      `SLL_I: aluout_AGEX = regval1_AGEX << regval2_AGEX[4:0];
      `SLLI_I: aluout_AGEX = regval1_AGEX << sxt_imm_AGEX[4:0];
      `SRL_I: aluout_AGEX = regval1_AGEX >> regval2_AGEX[4:0];
      `SRLI_I: aluout_AGEX = regval1_AGEX >> sxt_imm_AGEX[4:0];
      `SRA_I: aluout_AGEX = $signed(regval1_AGEX) >>> regval2_AGEX[4:0];
      `SRAI_I: aluout_AGEX = $signed(regval1_AGEX) >>> sxt_imm_AGEX[4:0];

      `SLT_I: aluout_AGEX = ($signed(regval1_AGEX) < $signed(regval2_AGEX)) ? 32'd1 : 32'd0;
      `SLTI_I: aluout_AGEX = ($signed(regval1_AGEX) < $signed(sxt_imm_AGEX)) ? 32'd1 : 32'd0;
      `SLTU_I: aluout_AGEX = (regval1_AGEX < regval2_AGEX) ? 32'd1 : 32'd0;
      `SLTIU_I: aluout_AGEX = (regval1_AGEX < sxt_imm_AGEX) ? 32'd1 : 32'd0;

      `LUI_I: aluout_AGEX = sxt_imm_AGEX;
      `AUIPC_I: aluout_AGEX = PC_AGEX + sxt_imm_AGEX;
      `JAL_I: aluout_AGEX = pcplus_AGEX;
      `JALR_I: aluout_AGEX = pcplus_AGEX;

      `LW_I: aluout_AGEX = regval1_AGEX + sxt_imm_AGEX;
      `SW_I: aluout_AGEX = regval1_AGEX + sxt_imm_AGEX;

      default: aluout_AGEX = '0;
    endcase
  end


  // ===== Task 3: pack the AGEX latch ============================
  //
  //   mem_stage.v unpacks a fixed list from this latch, so there is exactly one
  //   correct layout and it is written in a file you are not editing.
  //
  //   TODO: read the first assign in mem_stage.v, then replace the zero padding
  //   below with the three fields it expects after inst_count.  You should end
  //   up with 8 fields totalling `AGEX_latch_WIDTH (141 bits as shipped).
  //
  //   
  // ===========================================================================

  assign rd_mem_AGEX = (op_I_AGEX == `LW_I);
  assign wr_mem_AGEX = (op_I_AGEX == `SW_I);
  assign wr_val_AGEX = regval2_AGEX;
  assign memaddr_AGEX = regval1_AGEX + sxt_imm_AGEX;

  assign AGEX_latch_contents = {
                                valid_AGEX,
                                inst_AGEX,
                                PC_AGEX,
                                op_I_AGEX,
                                inst_count_AGEX,
                                aluout_AGEX,
                                wr_reg_AGEX,
                                wregno_AGEX,
                                rd_mem_AGEX,
                                wr_mem_AGEX,
                                wr_val_AGEX,
                                memaddr_AGEX
  };

  always @ (posedge clk ) begin
    if(reset) begin
      AGEX_latch <= {`AGEX_latch_WIDTH{1'b0}};
        end
    else
        begin
            AGEX_latch <= AGEX_latch_contents ;
        end
  end


  // ===== Task 4: the branch condition ===========================
  //
  //   TODO: `BEQ_I below always says "taken", which is a placeholder, not an
  //   answer.  Replace it with the real comparison and write the other five
  //   arms.  Watch the signedness: `BLT_I / `BGE_I compare as signed numbers,
  //   `BLTU_I / `BGEU_I compare the same bit patterns as unsigned numbers.
  //
  //   HINT: br_cond_AGEX answers "if this instruction is a conditional branch, is the
  //   condition true?".  It says nothing about whether the instruction IS a
  //   branch, that is is_br_AGEX, which de_stage.v decodes for you.  That is
  //   why an addi can fall into default here without doing any harm.
  //
  // ===========================================================================
  always @ (*) begin
    case (op_I_AGEX)
      `BEQ_I : br_cond_AGEX = (regval1_AGEX == regval2_AGEX);
      `BNE_I : br_cond_AGEX = (regval1_AGEX != regval2_AGEX);
      `BLT_I : br_cond_AGEX = ($signed(regval1_AGEX) < $signed(regval2_AGEX));
      `BGE_I : br_cond_AGEX = ($signed(regval1_AGEX) >= $signed(regval2_AGEX));
      `BLTU_I : br_cond_AGEX = (regval1_AGEX < regval2_AGEX);
      `BGEU_I : br_cond_AGEX = (regval1_AGEX >= regval2_AGEX);

      default : br_cond_AGEX = 1'b0;
    endcase
  end


  // ===== Task 5: branch target and the redirect =================
  //
  //   br_target_AGEX is "the address that SHOULD be fetched after this
  //   instruction".  The br_mispred_AGEX line below compares that against
  //   pcplus_AGEX, the address FE actually fetched, and calls any difference a
  //   mispredict.  So br_target_AGEX needs a sensible value on EVERY path, 
  //   taken branch, not-taken branch, and not-a-branch, not just on the
  //   taken path.
  //
  //   TODO: replace the '0 below. Fill in from_AGEX_to_FE. 
  //   Match the order fe_stage.v unpacks and check the total against `from_AGEX_to_FE_WIDTH.
  //   Fill in from_AGEX_to_DE, which de_stage.v unpacks.
  //
  // ===========================================================================

  always @(*) begin

    if (op_I_AGEX == `JALR_I) begin
      br_target_AGEX = (regval1_AGEX + sxt_imm_AGEX) & ~32'h1;
    end
    else if (op_I_AGEX == `JAL_I) begin
      br_target_AGEX = PC_AGEX + sxt_imm_AGEX;
    end
    else if (is_br_AGEX && br_cond_AGEX) begin
      br_target_AGEX = PC_AGEX + sxt_imm_AGEX;
    end
    else begin
      br_target_AGEX = pcplus_AGEX;
    end

  end

  assign br_mispred_AGEX = (is_br_AGEX
                         && (br_target_AGEX != pcplus_AGEX)) ? 1 : 0; // Given to you.  Do not change this line.

  // forward signals to the FE stage
  assign from_AGEX_to_FE = {br_mispred_AGEX, br_target_AGEX};        

  // forward signals to the DE stage
  assign from_AGEX_to_DE = br_mispred_AGEX;        


  // ===== Task 7: more ALU arms, and the jump targets =============
  //
  //   TODO (a): add these arms to the Task 2 ALU case:
  //               `SUB_I  `LUI_I  `AUIPC_I  `JAL_I  `JALR_I
  //             `JAL_I and `JALR_I write the return address into rd.
  //
  //   TODO (b): extend the Task 5 target block so jal and jalr redirect too.
  //             jal adds its immediate to PC_AGEX.  jalr adds its immediate
  //             to a register value, then clears bit 0 of the result.
  //             Neither one has a condition to evaluate.
  //
  // ===========================================================================

  // ===== Task 8 (bonus): the rest of the instruction set =====================
  //
  //   TODO (a): finish the Task 2 ALU case.  Still missing:
  //               `AND_I   `OR_I    `XOR_I   `SLL_I   `SRL_I   `SRA_I
  //               `SLT_I   `SLTU_I  `MUL_I
  //               `ANDI_I  `ORI_I   `XORI_I  `SLLI_I  `SRLI_I  `SRAI_I
  //               `SLTI_I  `SLTIU_I
  //             Shifts use only the low 5 bits of the shift operand, and the
  //             signed operations need $signed().  All of these belong in the
  //             Task 6(c) wr_reg_DE list as well.
  //
  //   TODO (b): lw and sw.  This is the stage that works out which address the
  //             access touches, and whether the instruction reads memory,
  //             writes memory, or neither.  Compute what mem_stage.v needs,
  //             pack it into AGEX_latch_contents back in Task 3, and keep
  //             define.vh in step.  Read mem_stage.v first.
  //
  //             mem_stage.v and wb_stage.v have the matching half.
  // ===========================================================================

endmodule
