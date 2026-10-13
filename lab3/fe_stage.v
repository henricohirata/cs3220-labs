 `include "define.vh" 

module FE_STAGE(
  input wire                              clk,
  input wire                              reset,
  input wire  [`from_DE_to_FE_WIDTH-1:0]  from_DE_to_FE,
  input wire  [`from_AGEX_to_FE_WIDTH-1:0] from_AGEX_to_FE,   
  input wire  [`from_MEM_to_FE_WIDTH-1:0] from_MEM_to_FE,   
  input wire  [`from_WB_to_FE_WIDTH-1:0]  from_WB_to_FE, 
  output wire [`FE_latch_WIDTH-1:0]       FE_latch_out
);

  `UNUSED_VAR (from_MEM_to_FE)
  `UNUSED_VAR (from_WB_to_FE)

  // I-MEM
  (* ram_init_file = `IDMEMINITFILE *)
  reg [`DBITS-1:0] imem [`IMEMWORDS-1:0];
 
  initial begin
      $readmemh(`IDMEMINITFILE , imem);
  end
  /*
  // Display memory contents with verilator 
  always @(posedge clk) begin
    for (integer i=0 ; i<`IMEMWORDS ; i=i+1) begin
        $display("%h", imem[i]);
    end
  end
  */

  /* pipeline latch */ 
  reg [`FE_latch_WIDTH-1:0] FE_latch;  // FE latch 
  wire valid_FE;

  reg [`DBITS-1:0] PC_FE_latch; // PC latch in the FE stage   // you could use a part of FE_latch as a PC latch as well 
  
  wire [`INSTBITS-1:0] inst_FE;  // instruction value in the FE stage 
  wire [`DBITS-1:0] pcplus_FE;  // pc plus value in the FE stage 
  reg [`DBITS-1:0] pcnext_FE;
  wire stall_pipe_FE; // signal to indicate when a front-end needs to be stall
  
  wire [`FE_latch_WIDTH-1:0] FE_latch_contents;  // the signals that will be FE latch contents 
  
  // reading instruction from imem 
  assign inst_FE = imem[PC_FE_latch[`IMEMADDRBITS-1:`IMEMWORDBITS]];  // this code works. imem is stored 4B together
  
  // This is the value of "incremented PC", computed in the FE stage
  assign pcplus_FE = PC_FE_latch + `INSTSIZE;

  // Branch misprediction setup
  wire br_mispred_AGEX;  
  wire [`DBITS-1:0] br_target_AGEX;  
  wire is_brjmp_AGEX;
  wire do_brjmp_AGEX;
  wire [7:0] pc_xor_bhr_AGEX;
  wire [`DBITS-1:0] PC_AGEX;
  
  assign {
    stall_pipe_FE
  } = from_DE_to_FE[0]; 
  
  assign {
    br_mispred_AGEX, 
    br_target_AGEX,
    is_brjmp_AGEX,
    do_brjmp_AGEX,
    pc_xor_bhr_AGEX,
    PC_AGEX
  } = from_AGEX_to_FE;

  // Branch prediction functionalities
  reg [7:0] BHR;
  
  reg [1:0] PHT [255:0];
  
  reg [25:0] BTB_TAG [15:0];
  reg BTB_VALID [15:0];
  reg [31:0] BTB_TARGET [15:0];

  wire [7:0] pc_xor_bhr_FE;
  
  wire pht_pred;
  
  wire [25:0] btb_tag_fetched;
  wire btb_valid_fetched;
  wire [31:0] btb_target_fetched;

  // reg [31:0] pc_next;

  assign pc_xor_bhr_FE = PC_FE_latch[9:2] ^ BHR;
  assign pht_pred = PHT[pc_xor_bhr_FE] > 1;

  assign btb_tag_fetched = BTB_TAG[PC_FE_latch[5:2]];
  assign btb_valid_fetched = BTB_VALID[PC_FE_latch[5:2]];
  assign btb_target_fetched = BTB_TARGET[PC_FE_latch[5:2]];

  always @ (*) begin
    if (pht_pred && btb_tag_fetched == PC_FE_latch[31:6] && btb_valid_fetched)
      pcnext_FE = btb_target_fetched;
    else
      pcnext_FE = pcplus_FE;
  end

  initial begin
      BHR = '0;
      for (integer i = 0; i < 16; ++i) begin
        BTB_TAG[i] = '0;
        BTB_VALID[i] = '0;
        BTB_TARGET[i] = '0;
      end
      for (integer i = 0; i < 256; ++i)
        PHT[i] = '1;
  end


  reg [31:0] num_brjmp;
  reg [31:0] mis_pred;
  wire [31:0] correct_pred;

  assign correct_pred = num_brjmp - mis_pred;

  always @ (posedge clk) begin
    if (reset) begin 
      num_brjmp <= '0;
    end else if (is_brjmp_AGEX) begin
      num_brjmp <= num_brjmp + 1;
      BTB_TAG[PC_AGEX[5:2]] <= PC_AGEX[31:6];
      BTB_VALID[PC_AGEX[5:2]] <= 1;
      BTB_TARGET[PC_AGEX[5:2]] <= br_target_AGEX;
      if (do_brjmp_AGEX) begin  
        case (PHT[pc_xor_bhr_AGEX])
          2'b00: PHT[pc_xor_bhr_AGEX] <= 2'b01;
          2'b01: PHT[pc_xor_bhr_AGEX] <= 2'b10;
          2'b10: PHT[pc_xor_bhr_AGEX] <= 2'b11;
          2'b11: PHT[pc_xor_bhr_AGEX] <= 2'b11;
        endcase
      end
      else begin
        case (PHT[pc_xor_bhr_AGEX])
          2'b00: PHT[pc_xor_bhr_AGEX] <= 2'b00;
          2'b01: PHT[pc_xor_bhr_AGEX] <= 2'b00;
          2'b10: PHT[pc_xor_bhr_AGEX] <= 2'b01;
          2'b11: PHT[pc_xor_bhr_AGEX] <= 2'b10;
        endcase
      end
      BHR <= {BHR[7:1], do_brjmp_AGEX};
    end
  end

  // Calculate next PC
  always @ (posedge clk) begin  
    if (reset) begin 
      PC_FE_latch <= `STARTPC;
    end else if (br_mispred_AGEX) begin
      PC_FE_latch <= br_target_AGEX;
    end else if (!stall_pipe_FE) begin 
      // PC_FE_latch <= pcplus_FE; 
      PC_FE_latch <= pcnext_FE; 
    end
  end
   
  // if you add more bits here, please increase the width of latch in define.vh
  // the order of latch contents should be matched in the decode stage when we extract the contents. 
  assign FE_latch_contents = {
    valid_FE,
    inst_FE, 
    PC_FE_latch, 
    pcplus_FE,
    pcnext_FE,
    pc_xor_bhr_FE
  };

  // Update FE latch
  always @ (posedge clk) begin
    if (reset) begin 
      FE_latch <= '0; 
      mis_pred <= '0;
    end else begin 
      if (br_mispred_AGEX) begin
        FE_latch <= '0;
        mis_pred <= mis_pred + 1;
      end
      else if (stall_pipe_FE)
        FE_latch <= FE_latch; 
      else 
        FE_latch <= FE_latch_contents; 
    end  
  end

  assign valid_FE = (| inst_FE);

  // send FE latch contents to next pipeline stage
  assign FE_latch_out = FE_latch;

endmodule
