`timescale 1ns / 1ps
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module tb_axi4_ram_burst (
  input wire clk,
  input wire reset
);

// Width of data bus in bits
parameter DATA_WIDTH = 32;
// Width of address bus in bits
parameter ADDR_WIDTH = 16;
// Width of wstrb (width of data bus in words)
parameter STRB_WIDTH = (DATA_WIDTH/8);
// Width of ID signal
parameter ID_WIDTH = 8;
// Extra pipeline register on output
parameter PIPELINE_OUTPUT = 0;


wire [ID_WIDTH-1:0]    s_axi_awid;
wire [ADDR_WIDTH-1:0]  s_axi_awaddr;
wire [7:0]             s_axi_awlen;
wire [2:0]             s_axi_awsize;
wire [1:0]             s_axi_awburst;
wire                   s_axi_awlock;
wire [3:0]             s_axi_awcache;
wire [2:0]             s_axi_awprot;
wire                   s_axi_awvalid;
wire                   s_axi_awready;
wire [DATA_WIDTH-1:0]  s_axi_wdata;
wire [STRB_WIDTH-1:0]  s_axi_wstrb;
wire                   s_axi_wlast;
wire                   s_axi_wvalid;
wire                   s_axi_wready;
wire [ID_WIDTH-1:0]    s_axi_bid;
wire [1:0]             s_axi_bresp;
wire                   s_axi_bvalid;
wire                   s_axi_bready;
wire [ID_WIDTH-1:0]    s_axi_arid;
wire [ADDR_WIDTH-1:0]  s_axi_araddr;
wire [7:0]             s_axi_arlen;
wire [2:0]             s_axi_arsize;
wire [1:0]             s_axi_arburst;
wire                   s_axi_arlock;
wire [3:0]             s_axi_arcache;
wire [2:0]             s_axi_arprot;
wire                   s_axi_arvalid;
wire                   s_axi_arready;
wire [ID_WIDTH-1:0]    s_axi_rid;
wire [DATA_WIDTH-1:0]  s_axi_rdata;
wire [1:0]             s_axi_rresp;
wire                   s_axi_rlast;
wire                   s_axi_rvalid;
wire                   s_axi_rready;

wire correct_V/* verilator public */;
wire correct_V_ap_vld/* verilator public */;

axi4_tester axi4_tester_inst(
    .ap_clk(clk),
    .ap_rst_n(!reset),
    .m_axi_data_in_out_V_AWVALID(s_axi_awvalid),
    .m_axi_data_in_out_V_AWREADY(s_axi_awready),
    .m_axi_data_in_out_V_AWADDR(s_axi_awaddr),
    .m_axi_data_in_out_V_AWID(),
    .m_axi_data_in_out_V_AWLEN(s_axi_awlen),
    .m_axi_data_in_out_V_AWSIZE(s_axi_awsize),
    .m_axi_data_in_out_V_AWBURST(s_axi_awburst),
    .m_axi_data_in_out_V_AWLOCK(s_axi_awlock),
    .m_axi_data_in_out_V_AWCACHE(s_axi_awcache),
    .m_axi_data_in_out_V_AWPROT(s_axi_awprot),
    .m_axi_data_in_out_V_AWQOS(),
    .m_axi_data_in_out_V_AWREGION(),
    .m_axi_data_in_out_V_AWUSER(),
    .m_axi_data_in_out_V_WVALID(s_axi_wvalid),
    .m_axi_data_in_out_V_WREADY(s_axi_wready),
    .m_axi_data_in_out_V_WDATA(s_axi_wdata),
    .m_axi_data_in_out_V_WSTRB(s_axi_wstrb),
    .m_axi_data_in_out_V_WLAST(s_axi_wlast),
    .m_axi_data_in_out_V_WID(),
    .m_axi_data_in_out_V_WUSER(),
    .m_axi_data_in_out_V_ARVALID(s_axi_arvalid),
    .m_axi_data_in_out_V_ARREADY(s_axi_arready),
    .m_axi_data_in_out_V_ARADDR(s_axi_araddr),
    .m_axi_data_in_out_V_ARID(),
    .m_axi_data_in_out_V_ARLEN(s_axi_arlen),
    .m_axi_data_in_out_V_ARSIZE(s_axi_arsize),
    .m_axi_data_in_out_V_ARBURST(s_axi_arburst),
    .m_axi_data_in_out_V_ARLOCK(s_axi_arlock),
    .m_axi_data_in_out_V_ARCACHE(s_axi_arcache),
    .m_axi_data_in_out_V_ARPROT(s_axi_arprot),
    .m_axi_data_in_out_V_ARQOS(),
    .m_axi_data_in_out_V_ARREGION(),
    .m_axi_data_in_out_V_ARUSER(),
    .m_axi_data_in_out_V_RVALID(s_axi_rvalid),
    .m_axi_data_in_out_V_RREADY(s_axi_rready),
    .m_axi_data_in_out_V_RDATA(s_axi_rdata),
    .m_axi_data_in_out_V_RLAST(s_axi_rlast),
    .m_axi_data_in_out_V_RID(s_axi_rid),
    .m_axi_data_in_out_V_RUSER(),
    .m_axi_data_in_out_V_RRESP(s_axi_rresp),
    .m_axi_data_in_out_V_BVALID(s_axi_bvalid),
    .m_axi_data_in_out_V_BREADY(s_axi_bready),
    .m_axi_data_in_out_V_BRESP(s_axi_bresp),
    .m_axi_data_in_out_V_BID(s_axi_bid),
    .m_axi_data_in_out_V_BUSER(),
    .correct_V(correct_V),
    .correct_V_ap_vld(correct_V_ap_vld)
);
axi_ram axi_ram_inst(
    .clk(clk),
    .rst(reset),
    .s_axi_awid(s_axi_awid),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),
    .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst),
    .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache),
    .s_axi_awprot(s_axi_awprot),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_arid(s_axi_arid),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),
    .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst),
    .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache),
    .s_axi_arprot(s_axi_arprot),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rlast(s_axi_rlast),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready)
);

endmodule