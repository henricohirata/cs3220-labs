`include "define.vh"


module FE_STAGE(
  input wire clk,
  input wire reset,
  input wire [`from_DE_to_FE_WIDTH-1:0] from_DE_to_FE,
  input wire [`from_AGEX_to_FE_WIDTH-1:0] from_AGEX_to_FE,   
  input wire [`from_MEM_to_FE_WIDTH-1:0] from_MEM_to_FE,   
  input wire [`from_WB_to_FE_WIDTH-1:0] from_WB_to_FE, 
  output wire [`FE_latch_WIDTH-1:0] FE_latch_out
);

  `UNUSED_VAR (from_MEM_to_FE)
  `UNUSED_VAR (from_WB_to_FE)

  // I-MEM
  (* ram_init_file = `IDMEMINITFILE *)
  reg [`DBITS-1:0] imem [`IMEMWORDS-1:0];
 
  initial begin
      $readmemh(`IDMEMINITFILE , imem);
  end

  // Display memory contents with verilator 
  /*
  always @(posedge clk) begin
    for (integer i=0 ; i<`IMEMWORDS ; i=i+1) begin
        $display("%h", imem[i]);
    end
  end
  */

  /* pipeline latch */ 
  reg [`FE_latch_WIDTH-1:0] FE_latch;  // FE latch 
  wire valid_FE;

  `UNUSED_VAR(valid_FE)
  reg [`DBITS-1:0] PC_FE_latch; // PC latch in the FE stage   // you could use a part of FE_latch as a PC latch as well 

  reg [`DBITS-1:0] inst_count_FE; /* for debugging purpose */ 
  
  wire [`DBITS-1:0] inst_count_AGEX; /* for debugging purpose. resent the instruction counter */ 

  wire [`INSTBITS-1:0] inst_FE;  // instruction value in the FE stage 
  wire [`DBITS-1:0] pcplus_FE;  // pc plus value in the FE stage 
  wire stall_pipe_FE; // signal to indicate when a front-end needs to be stall

  wire [`BHR_WIDTH-1:0] bhr_FE;
  wire [`PHT_BITS-1:0]  pht_idx_FE;
  wire                  pred_dir_FE;

  wire                  bp_update_AGEX;
  wire                  br_taken_AGEX;
  wire [`PHT_BITS-1:0]  pht_idx_AGEX;


  wire [`DBITS-1:0] btb_target_FE;
  wire btb_hit_FE;
  wire pred_taken_FE;
  wire [`DBITS-1:0] pred_pc_FE;
  
  wire [`DBITS-1:0] btb_wr_pc_AGEX;
  wire [`DBITS-1:0] btb_wr_target_AGEX;

  assign pht_idx_FE = PC_FE_latch[`PHT_BITS+1:2] ^ bhr_FE;

  generate
    if (`BP_HASH == 1) begin : g_bimodal // PC only
      assign pht_idx_FE = PC_FE_latch[`PHT_BITS+1:2];

    end else if (`BP_HASH == 2) begin : g_gselect // {PC, BHR}
      assign pht_idx_FE = {PC_FE_latch[`PHT_BITS-`GSEL_HIST_BITS+1:2], bhr_FE[`GSEL_HIST_BITS-1:0]};

    end else begin : g_gshare // PC XOR BHR
      assign pht_idx_FE = PC_FE_latch[`PHT_BITS+1:2] ^ `PHT_BITS'(bhr_FE);
      
    end
  endgenerate

  BHR my_BHR (
    .clk(clk),
    .reset(reset),
    .wr_ena(bp_update_AGEX),
    .wr_data({{(`DBITS-1){1'b0}}, br_taken_AGEX}),
    .out(bhr_FE)
  );

  `ifdef BP_PHT_1BIT
    PHT_1BIT my_PHT (
      .clk(clk),
      .reset(reset),
      .rd_sel(pht_idx_FE),
      .out(pred_dir_FE),
      .wr_sel(pht_idx_AGEX),
      .wr_data(br_taken_AGEX),
      .wr_ena(bp_update_AGEX)
    );
  `else
    PHT my_PHT (
      .clk(clk),
      .reset(reset),
      .rd_sel(pht_idx_FE),
      .out(pred_dir_FE),
      .wr_sel(pht_idx_AGEX),
      .wr_data(br_taken_AGEX),
      .wr_ena(bp_update_AGEX)
    );
  `endif

  `ifdef BP_BTB_2WAY
    BTB_2WAY my_BTB (
      .clk(clk),
      .reset(reset),
      .rd_ena(1'b1),
      .rd_sel(PC_FE_latch),
      .out_data(btb_target_FE),
      .outs_valid(btb_hit_FE),
      .wr_ena(bp_update_AGEX),
      .wr_sel(btb_wr_pc_AGEX),
      .wr_data(btb_wr_target_AGEX)
    );
  `else
    BTB #(.IDX_BITS(`BP_BTB_BITS)) my_BTB (
      .clk(clk),
      .reset(reset),
      .rd_ena(1'b1),
      .rd_sel(PC_FE_latch),
      .out_data(btb_target_FE),
      .outs_valid(btb_hit_FE),
      .wr_ena(bp_update_AGEX),
      .wr_sel(btb_wr_pc_AGEX),
      .wr_data(btb_wr_target_AGEX)
    );
  `endif

  assign pred_taken_FE = btb_hit_FE && pred_dir_FE;
  assign pred_pc_FE = pred_taken_FE ? btb_target_FE : pcplus_FE;

  wire [`FE_latch_WIDTH-1:0] FE_latch_contents;  // the signals that will be FE latch contents 
  
  // reading instruction from imem 
  assign inst_FE = imem[PC_FE_latch[`IMEMADDRBITS-1:`IMEMWORDBITS]];  // this code works. imem is stored 4B together 
  
  // wire to send the FE latch contents to the DE stage 
  assign FE_latch_out = FE_latch; 
 

  // This is the value of "incremented PC", computed in the FE stage
  assign pcplus_FE = PC_FE_latch + `INSTSIZE;
   
  assign FE_latch_contents = {
                                valid_FE, 
                                inst_FE, 
                                PC_FE_latch, 
                                pcplus_FE,
                                inst_count_FE,
                                pht_idx_FE,
                                pred_dir_FE,
                                pred_pc_FE
                              };

  // **TODO: Complete the rest of the pipeline 
  //assign stall_pipe_FE = 1;   // you need
  wire br_mispred_AGEX;  
  wire [`DBITS-1:0] br_target_AGEX;  

  assign {
    stall_pipe_FE
  } = from_DE_to_FE[0]; 

  assign {
    br_mispred_AGEX,
    br_target_AGEX,
    bp_update_AGEX,
    br_taken_AGEX,
    pht_idx_AGEX,
    btb_wr_pc_AGEX,
    btb_wr_target_AGEX
  } = from_AGEX_to_FE;

  always @ (posedge clk) begin
  // Task 5: select the predicted next PC.
   if (reset) begin 
      PC_FE_latch <= `STARTPC;
      inst_count_FE <= 1;  /* inst_count starts from 1 for easy human reading. 1st fetch instructions can have 1 */ 
      end 
    else if (br_mispred_AGEX)
      PC_FE_latch <= br_target_AGEX;
    else if (stall_pipe_FE) 
      PC_FE_latch <= PC_FE_latch; 
    else begin 
      PC_FE_latch <= pred_pc_FE;
      inst_count_FE <= inst_count_FE + 1; 
      end 
  end
  

  always @ (posedge clk) begin
    if (reset) begin 
      FE_latch <= '0; 
    end else begin 
      if (br_mispred_AGEX)
        FE_latch <= '0;
      else if (stall_pipe_FE)
        FE_latch <= FE_latch; 
      else 
        FE_latch <= FE_latch_contents; 
    end  
  end

endmodule


module BHR (
  input wire clk,
  input wire reset,
  input wire wr_ena,
  input wire [`DBITS-1:0] wr_data,
  output wire [`BHR_WIDTH-1:0] out
);

  reg [`BHR_WIDTH-1:0] history;

  assign out = history;

  always @ (posedge clk) begin
    if (reset)
      history <= {`BHR_WIDTH{1'b0}};
    else if (wr_ena)
      history <= {history[`BHR_WIDTH-2:0], wr_data[0]};
  end

endmodule


module PHT (
  input wire clk,
  input wire reset,
  input wire [`PHT_BITS-1:0] rd_sel,
  output wire out,
  input wire [`PHT_BITS-1:0] wr_sel,
  input wire wr_data,
  input wire wr_ena
);

  reg [`counter_WIDTH-1:0] counters [`PHT_WIDTH-1:0];
  assign out = counters[rd_sel][`counter_WIDTH-1];

  always @ (posedge clk) begin
    if (reset) begin
      for (integer i = 0; i < `PHT_WIDTH; i = i + 1)
        counters[i] <= `counter_WIDTH'b01;
    end
    else if (wr_ena) begin

      if (wr_data && (counters[wr_sel] != {`counter_WIDTH{1'b1}})) begin
        counters[wr_sel] <= counters[wr_sel] + 1'b1;
      end
      else if (!wr_data && (counters[wr_sel] != {`counter_WIDTH{1'b0}})) begin
        counters[wr_sel] <= counters[wr_sel] - 1'b1;
      end

    end
  end

endmodule

module PHT_1BIT (
  input wire clk,
  input wire reset,
  input wire [`PHT_BITS-1:0] rd_sel,
  output wire out,
  input wire [`PHT_BITS-1:0] wr_sel,
  input wire wr_data,
  input wire wr_ena
);

  reg last_outcome [`PHT_WIDTH-1:0];
  assign out = last_outcome[rd_sel];

  always @ (posedge clk) begin
    if (reset) begin
      for (integer i = 0; i < `PHT_WIDTH; i = i + 1)
        last_outcome[i] <= 1'b0;
    end
    else if (wr_ena)
      last_outcome[wr_sel] <= wr_data;
  end

endmodule

module BTB #(
  parameter IDX_BITS = `BTB_BITS
) (
  input wire clk,
  input wire reset,
  input wire rd_ena,
  input wire [`DBITS-1:0] rd_sel,
  output wire [`DBITS-1:0] out_data,
  output wire outs_valid,
  input wire wr_ena,
  input wire [`DBITS-1:0] wr_sel,
  input wire [`DBITS-1:0] wr_data
);

  localparam ENTRIES  = 1 << IDX_BITS;
  localparam TAG_BITS = `DBITS - IDX_BITS - 2;

  reg valid_bits [ENTRIES-1:0];
  reg [TAG_BITS-1:0] tags [ENTRIES-1:0];
  reg [`DBITS-1:0] targets [ENTRIES-1:0];

  wire [IDX_BITS-1:0] rd_idx = rd_sel[IDX_BITS+1:2];
  wire [TAG_BITS-1:0] rd_tag = rd_sel[`DBITS-1:IDX_BITS+2];
  wire [IDX_BITS-1:0] wr_idx = wr_sel[IDX_BITS+1:2];
  wire [TAG_BITS-1:0] wr_tag = wr_sel[`DBITS-1:IDX_BITS+2];

  assign outs_valid = rd_ena && valid_bits[rd_idx] && (tags[rd_idx] == rd_tag);
  assign out_data = targets[rd_idx];

  always @(posedge clk) begin
    if (reset) begin
      for (integer i = 0; i < `BTB_WIDTH; i=i+1) begin
        valid_bits[i] <= 1'b0;
      end
    end
    else if (wr_ena) begin
      valid_bits[wr_idx] <= 1'b1;
      tags[wr_idx] <= wr_tag;
      targets[wr_idx] <= wr_data;
    end
  end

endmodule

module BTB_2WAY (
  input wire clk,
  input wire reset,
  input wire rd_ena,
  input wire [`DBITS-1:0] rd_sel,
  output wire [`DBITS-1:0] out_data,
  output wire outs_valid,
  input wire wr_ena,
  input wire [`DBITS-1:0] wr_sel,
  input wire [`DBITS-1:0] wr_data
);

  localparam SET_BITS = 3;
  localparam SETS = 1 << SET_BITS;
  localparam TAG_BITS = `DBITS - SET_BITS - 2;

  reg valid0 [SETS-1:0], valid1 [SETS-1:0];
  reg [TAG_BITS-1:0] tag0 [SETS-1:0], tag1 [SETS-1:0];
  reg [`DBITS-1:0] target0[SETS-1:0], target1[SETS-1:0];
  reg lru [SETS-1:0];

  wire [SET_BITS-1:0] rd_set = rd_sel[SET_BITS+1:2];
  wire [TAG_BITS-1:0] rd_tag = rd_sel[`DBITS-1:SET_BITS+2];
  wire [SET_BITS-1:0] wr_set = wr_sel[SET_BITS+1:2];
  wire [TAG_BITS-1:0] wr_tag = wr_sel[`DBITS-1:SET_BITS+2];

  wire rd_hit0 = valid0[rd_set] && (tag0[rd_set] == rd_tag);
  wire rd_hit1 = valid1[rd_set] && (tag1[rd_set] == rd_tag);

  assign outs_valid = rd_ena && (rd_hit0 || rd_hit1);
  assign out_data = rd_hit1 ? target1[rd_set] : target0[rd_set];

  wire wr_hit0 = valid0[wr_set] && (tag0[wr_set] == wr_tag);
  wire wr_hit1 = valid1[wr_set] && (tag1[wr_set] == wr_tag);

  wire wr_way  = wr_hit0 ? 1'b0 :
                 wr_hit1 ? 1'b1 :
                 !valid0[wr_set] ? 1'b0 :
                 !valid1[wr_set] ? 1'b1 : lru[wr_set];

  always @(posedge clk) begin
    if (reset) begin
      for (integer i = 0; i < SETS; i = i + 1) begin
        valid0[i] <= 1'b0;
        valid1[i] <= 1'b0;
        lru[i] <= 1'b0;
      end
    end
    else if (wr_ena) begin
      if (wr_way) begin
        valid1[wr_set] <= 1'b1;
        tag1[wr_set] <= wr_tag;
        target1[wr_set] <= wr_data;
      end else begin
        valid0[wr_set] <= 1'b1;
        tag0[wr_set] <= wr_tag;
        target0[wr_set] <= wr_data;
      end
      lru[wr_set] <= ~wr_way;
    end
  end

endmodule