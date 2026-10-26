`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module tb_axis_fifo (
  input wire clk,
  input wire reset
);
    
    //1 input stream
    parameter AXIS_DATA_WIDTH = 32, ADDR_WIDTH = 4;
    parameter DATA_NUM = 1024;
    parameter write_start = 512; 




    wire [AXIS_DATA_WIDTH-1:0] din_0_rsc_dat /* verilator public */;
    
    wire din_0_rsc_rdy /* verilator public */;
    wire din_0_rsc_vld /* verilator public */;
    wire [AXIS_DATA_WIDTH-1:0] dout_0_rsc_dat /* verilator public */;
    wire dout_0_rsc_rdy /* verilator public */;
    wire dout_0_rsc_vld /* verilator public */;


    reg    [AXIS_DATA_WIDTH-1:0] din_0_rsc_dat_all_reg[0:DATA_NUM-1];
    reg    [AXIS_DATA_WIDTH-1:0] din_0_rsc_dat_reg;
    
    reg    din_0_rsc_vld_reg;
    reg    dout_0_rsc_rdy_reg;
    reg    [128:0] cycle_count_reg;
    


    assign din_0_rsc_dat = din_0_rsc_dat_reg;
    assign din_0_rsc_vld = din_0_rsc_vld_reg;
    assign dout_0_rsc_rdy = dout_0_rsc_rdy_reg;



    integer in_0_ptr = 0;
    integer out_0_ptr = 0;

    //IO tracker
    integer f_in_0;
    integer f_out_0;

    axis_fifo #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH)
    )axis_fifo_inst(
        .wr_aclk(clk),
        .wr_rstn(!reset),
        .wr_axis_data(din_0_rsc_dat),
        .wr_axis_vld(din_0_rsc_vld),
        .wr_axis_rdy(din_0_rsc_rdy),
        .rd_aclk(clk),
        .rd_rstn(!reset),
        .rd_axis_data(dout_0_rsc_dat),
        .rd_axis_vld(dout_0_rsc_vld),
        .rd_axis_rdy(dout_0_rsc_rdy)
    );


    always @(posedge clk) begin
        cycle_count_reg <= cycle_count_reg + 1;
    end

    always@(posedge clk) begin
        din_0_rsc_vld_reg <= (~(in_0_ptr == DATA_NUM)) & (~reset) ; 
        dout_0_rsc_rdy_reg <= (~(out_0_ptr == DATA_NUM)) & (~reset) & (cycle_count_reg >= write_start);
    end

    // read the data from file
    always @(posedge clk)
    begin 
        if (reset) begin
            din_0_rsc_dat_reg = {AXIS_DATA_WIDTH{1'b0}};
            in_0_ptr = 0;
        end 
        else if (in_0_ptr == DATA_NUM) begin
            in_0_ptr = DATA_NUM;
        end
        else if (din_0_rsc_rdy & din_0_rsc_vld_reg ) begin
            in_0_ptr = in_0_ptr+1;
            din_0_rsc_dat_reg = din_0_rsc_dat_all_reg[in_0_ptr];
        end else begin
            in_0_ptr = in_0_ptr+0;
            din_0_rsc_dat_reg = din_0_rsc_dat_all_reg[in_0_ptr]; 
        end   
    end

    // recive the output 0 
    always @(posedge clk)
    begin 
        if (reset) begin
            out_0_ptr = 0;
        end else if(out_0_ptr == DATA_NUM) begin
            out_0_ptr = DATA_NUM;
        end else if (dout_0_rsc_vld & dout_0_rsc_rdy_reg) begin
            out_0_ptr = out_0_ptr+1;
        end else begin
            out_0_ptr = out_0_ptr+0;
        end
    end

    // reset
    initial 
    begin 
        $readmemb("data.txt", din_0_rsc_dat_all_reg);
    end


    // stop the simulation
    always @(posedge clk)
    begin
        if(in_0_ptr == AXIS_DATA_WIDTH && out_0_ptr == AXIS_DATA_WIDTH)
        begin
            $stop;
        end	
    end
endmodule 