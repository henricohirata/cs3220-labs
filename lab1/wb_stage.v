 `include "define.vh" 


module WB_STAGE(
  input wire clk,
  input wire reset,  
  input wire [`MEM_latch_WIDTH-1:0] from_MEM_latch,
  output wire [`from_WB_to_FE_WIDTH-1:0] from_WB_to_FE,
  output wire [`from_WB_to_DE_WIDTH-1:0] from_WB_to_DE,  
  output wire [`from_WB_to_AGEX_WIDTH-1:0] from_WB_to_AGEX,
  output wire [`from_WB_to_MEM_WIDTH-1:0] from_WB_to_MEM
);

  wire valid_WB; 
  wire [`IOPBITS-1:0] op_I_WB;
  wire [`INSTBITS-1:0] inst_WB; 
  wire [`DBITS-1:0] PC_WB;
  wire [`DBITS-1:0] inst_count_WB; 


  
  wire wr_reg_WB; // is this instruction writing into a register file? 
  
  wire [`REGNOBITS-1:0] wregno_WB; // destination register ID 
  wire [`DBITS-1:0] regval_WB;  // the contents to be written in the register file (or CSR )
  
  wire rd_mem_WB;

  wire [`DBITS-1:0] aluout_WB;
  wire [`DBITS-1:0] rd_val_WB;

  // ===== Task 8 (bonus): write back loaded values ==========================
  //
  //   Once lw exists, the value written into the register file no longer
  //   always comes from the ALU.
  //
  //   TODO: add the two signals a load needs to the unpack list below, one
  //   of them is already declared above. Rewrite regval_WB to choose
  //   between them.  The order must match the order mem_stage.v packed
  //   MEM_latch_contents, and `MEM_latch_WIDTH must count them.
  //
  //   A load also has to be in your Task 6(c) wr_reg_DE list, or nothing is
  //   written back at all.
  // =========================================================================

   assign {
                                valid_WB,
                                inst_WB,
                                PC_WB,
                                op_I_WB,
                                inst_count_WB,
                                // more signals might need   
                                aluout_WB, 
                                wr_reg_WB,
                                wregno_WB,
                                rd_val_WB,
                                rd_mem_WB
                                 } = from_MEM_latch; 
        
        // write register by sending data to the DE stage 
        

assign regval_WB = rd_mem_WB ? rd_val_WB : aluout_WB;

// forward signals to FE stage
assign from_WB_to_FE = '0;

// forward signals to AGEX stage
assign from_WB_to_AGEX = '0;

// forward signals to MEM stage
assign from_WB_to_MEM = '0;

// we send register write (and CSR register) information to DE stage 
assign from_WB_to_DE = {wr_reg_WB, wregno_WB, regval_WB} ;  

// this code need to be commented out when we synthesize the code later 
    // special workaround to get tests Pass/Fail status
    reg [`REGWORDS-1:0][31:0] last_WB_value /* verilator public */;


  always @(negedge clk) begin
  if (reset) begin
      for (int i = 0; i < `REGWORDS; ++i) begin
        last_WB_value[i] <= 0;
      end
    end else begin
    if (wr_reg_WB)
      last_WB_value[wregno_WB] <= regval_WB;
    end
  end 

  // this is only for debugging purpose to interact with sim_main.cpp when we use verilator 
  reg [`WBCOUNTERS-1:0][31:0] WB_counters /* verilator public */;
  always @(posedge clk) begin
    if (reset) begin
      WB_counters <= '0;
    end else begin
      WB_counters[0] <= 32'(valid_WB);
      WB_counters[1] <= 32'(PC_WB);   
      WB_counters[2] <= 32'(inst_WB);   
      WB_counters[3] <= 32'(op_I_WB); 
      WB_counters[4] <= 32'(wr_reg_WB);
      WB_counters[5] <= 32'(wregno_WB);
      WB_counters[6] <= 32'(regval_WB);
      WB_counters[7] <= '0;
    end
  end
endmodule 
