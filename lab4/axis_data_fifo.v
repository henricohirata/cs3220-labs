`timescale 1ns / 1ps

module axis_fifo #
(
    parameter ADDR_WIDTH = 12,
    parameter AXIS_DATA_WIDTH = 32
)
(
    /*
     * Ports to pipe in the data to the FIFO
     */
    input  wire                   wr_aclk,
    input  wire                   wr_rstn,
    input  wire [AXIS_DATA_WIDTH-1:0]  wr_axis_data,
    input  wire                   wr_axis_vld,
    output wire                   wr_axis_rdy,
    
    /*
     * Ports to get the data to the FIFO
     */
    input  wire                   rd_aclk,
    input  wire                   rd_rstn,
    output wire [AXIS_DATA_WIDTH-1:0]  rd_axis_data,
    output wire                   rd_axis_vld,
    input  wire                   rd_axis_rdy
);

reg [ADDR_WIDTH:0] wr_ptr_reg = {ADDR_WIDTH+1{1'b0}}, wr_ptr_next;
reg [ADDR_WIDTH:0] wr_ptr_gray_reg = {ADDR_WIDTH+1{1'b0}}, wr_ptr_gray_next;
reg [ADDR_WIDTH:0] wr_addr_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_reg = {ADDR_WIDTH+1{1'b0}}, rd_ptr_next;
reg [ADDR_WIDTH:0] rd_ptr_gray_reg = {ADDR_WIDTH+1{1'b0}}, rd_ptr_gray_next;
reg [ADDR_WIDTH:0] rd_addr_reg = {ADDR_WIDTH+1{1'b0}};

reg [ADDR_WIDTH:0] wr_ptr_gray_sync1_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] wr_ptr_gray_sync2_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_gray_sync1_reg = {ADDR_WIDTH+1{1'b0}};
reg [ADDR_WIDTH:0] rd_ptr_gray_sync2_reg = {ADDR_WIDTH+1{1'b0}};

reg wr_rst_sync1_reg = 1'b1;
reg wr_rst_sync2_reg = 1'b1;
reg wr_rst_sync3_reg = 1'b1;
reg rd_rst_sync1_reg = 1'b1;
reg rd_rst_sync2_reg = 1'b1;
reg rd_rst_sync3_reg = 1'b1;

reg [AXIS_DATA_WIDTH+1-1:0] mem[(2**ADDR_WIDTH)-1:0];
reg [AXIS_DATA_WIDTH+1-1:0] mem_read_data_reg = {AXIS_DATA_WIDTH+1{1'b0}};
reg mem_read_data_valid_reg = 1'b0, mem_read_data_valid_next;
wire [AXIS_DATA_WIDTH+1-1:0] mem_write_data;

reg [AXIS_DATA_WIDTH+1-1:0] rd_data_reg = {AXIS_DATA_WIDTH+1{1'b0}};

reg rd_axis_vld_reg = 1'b0, rd_axis_vld_next;

wire full = ((wr_ptr_gray_reg[ADDR_WIDTH]   != rd_ptr_gray_sync2_reg[ADDR_WIDTH]) &&
             (wr_ptr_gray_reg[ADDR_WIDTH-1] != rd_ptr_gray_sync2_reg[ADDR_WIDTH-1]) &&
             (wr_ptr_gray_reg[ADDR_WIDTH-2:0] == rd_ptr_gray_sync2_reg[ADDR_WIDTH-2:0]));

wire empty = rd_ptr_gray_reg == wr_ptr_gray_sync2_reg;

// control signals
reg write;
reg read;
reg store_output;

assign wr_axis_rdy = ~full & ~wr_rst_sync3_reg;

assign rd_axis_vld = rd_axis_vld_reg;

assign mem_write_data[AXIS_DATA_WIDTH-1:0] = wr_axis_data;
assign rd_axis_data = rd_data_reg[AXIS_DATA_WIDTH-1:0];

// reset synchronization
always @(posedge wr_aclk) begin
    if (!wr_rstn) begin
        wr_rst_sync1_reg <= 1'b1;
        wr_rst_sync2_reg <= 1'b1;
        wr_rst_sync3_reg <= 1'b1;
    end else begin
        wr_rst_sync1_reg <= 1'b0;
        wr_rst_sync2_reg <= wr_rst_sync1_reg | rd_rst_sync1_reg;
        wr_rst_sync3_reg <= wr_rst_sync2_reg;
    end
end

always @(posedge rd_aclk) begin
    if (!rd_rstn) begin
        rd_rst_sync1_reg <= 1'b1;
        rd_rst_sync2_reg <= 1'b1;
        rd_rst_sync3_reg <= 1'b1;
    end else begin
        rd_rst_sync1_reg <= 1'b0;
        rd_rst_sync2_reg <= wr_rst_sync1_reg | rd_rst_sync1_reg;
        rd_rst_sync3_reg <= rd_rst_sync2_reg;
    end
end

// Write logic
always @* begin
    write = 1'b0;

    wr_ptr_next = wr_ptr_reg;
    wr_ptr_gray_next = wr_ptr_gray_reg;
    
    // input data valid
    if (wr_axis_vld) begin
        if (~full) begin
            write = 1'b1;
            wr_ptr_next = wr_ptr_reg + 1;
            wr_ptr_gray_next = wr_ptr_next ^ (wr_ptr_next >> 1);
        end
    end
end

always @(posedge wr_aclk) begin
    if (wr_rst_sync3_reg) begin
        wr_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
    end else begin
        wr_ptr_reg <= wr_ptr_next;
        wr_ptr_gray_reg <= wr_ptr_gray_next;
    end

    wr_addr_reg <= wr_ptr_next;

    if (write) begin
        mem[wr_addr_reg[ADDR_WIDTH-1:0]] <= mem_write_data;
    end
end

// pointer synchronization
always @(posedge wr_aclk) begin
    if (wr_rst_sync3_reg) begin
        rd_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_sync2_reg <= {ADDR_WIDTH+1{1'b0}};
    end else begin
        rd_ptr_gray_sync1_reg <= rd_ptr_gray_reg;
        rd_ptr_gray_sync2_reg <= rd_ptr_gray_sync1_reg;
    end
end

always @(posedge rd_aclk) begin
    if (rd_rst_sync3_reg) begin
        wr_ptr_gray_sync1_reg <= {ADDR_WIDTH+1{1'b0}};
        wr_ptr_gray_sync2_reg <= {ADDR_WIDTH+1{1'b0}};
    end else begin
        wr_ptr_gray_sync1_reg <= wr_ptr_gray_reg;
        wr_ptr_gray_sync2_reg <= wr_ptr_gray_sync1_reg;
    end
end

// Read logic
always @* begin
    read = 1'b0;

    rd_ptr_next = rd_ptr_reg;
    rd_ptr_gray_next = rd_ptr_gray_reg;

    mem_read_data_valid_next = mem_read_data_valid_reg;

    if (store_output | ~mem_read_data_valid_reg) begin
        if (~empty) begin
            read = 1'b1;
            mem_read_data_valid_next = 1'b1;
            rd_ptr_next = rd_ptr_reg + 1;
            rd_ptr_gray_next = rd_ptr_next ^ (rd_ptr_next >> 1);
        end else begin
            mem_read_data_valid_next = 1'b0;
        end
    end
end

always @(posedge rd_aclk) begin
    if (rd_rst_sync3_reg) begin
        rd_ptr_reg <= {ADDR_WIDTH+1{1'b0}};
        rd_ptr_gray_reg <= {ADDR_WIDTH+1{1'b0}};
        mem_read_data_valid_reg <= 1'b0;
    end else begin
        rd_ptr_reg <= rd_ptr_next;
        rd_ptr_gray_reg <= rd_ptr_gray_next;
        mem_read_data_valid_reg <= mem_read_data_valid_next;
    end

    rd_addr_reg <= rd_ptr_next;

    if (read) begin
        mem_read_data_reg <= mem[rd_addr_reg[ADDR_WIDTH-1:0]];
    end
end

// Output register
always @* begin
    store_output = 1'b0;

    rd_axis_vld_next = rd_axis_vld_reg;

    if (rd_axis_rdy | ~rd_axis_vld_reg) begin
        store_output = 1'b1;
        rd_axis_vld_next = mem_read_data_valid_reg;
    end
end

always @(posedge rd_aclk) begin
    if (rd_rst_sync3_reg) begin
        rd_axis_vld_reg <= 1'b0;
    end else begin
        rd_axis_vld_reg <= rd_axis_vld_next;
    end

    if (store_output) begin
        rd_data_reg <= mem_read_data_reg;
    end
end

endmodule