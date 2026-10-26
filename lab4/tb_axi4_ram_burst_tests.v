`timescale 1ns / 1ps
//======================================================================
// DESCRIPTION: Combined directed testbench for axi4_ram_burst.v.
//
// This file merges the former tb_axi4_ram_burst_edge.v and
// tb_axi4_ram_burst_corner.v into ONE bench sharing one AXI master, one
// DUT and one set of helpers.  The two suites keep separate verdicts
// because they have opposite expectations:
//
//   PART A -- BURST EDGE tests (EXPECTED TO PASS on a correct slave)
//     [BE1] basic INCR burst          -- len=4 write/read round-trip
//     [BE2] long INCR burst           -- 32 beats
//     [BE3] narrow burst (awsize=1)   -- 2 bytes/beat, lane-correct
//     [BE4] unaligned INCR start      -- burst from a non-word address
//     [BE5] rlast placement           -- exactly one rlast, on beat len
//     [BE6] per-beat wstrb            -- strobes vary across a burst
//     [BE7] back-to-back bursts       -- no idle cycle between them
//     [BE8] 4KB boundary              -- burst ending flush against 0x1000
//
//   PART B -- BURST CORNER cases (a correct implementation passes all)
//     [BC1]  FIXED burst write address (type 0) -> must hold the address
//     [BC2]  FIXED burst read address  (type 0) -> must hold the address
//     [BC3]  WRAP burst read address   (type 2) -> must wrap in the block
//     [BC4]  WRAP burst write address  (type 2) -> must wrap in the block
//     [BC5]  R-channel backpressure    -> no stale first beat
//     [BC6]  INCR burst addressing     -> one word per beat, both channels
//     [BC7]  reserved burst type 3     -> liveness only, must not wedge
//     [BC8]  AW intrusion mid-burst    -> AWREADY low until the write ends
//     [BC9]  read traffic mid-burst    -> must not disturb the open burst
//     [BC10] BREADY withheld           -> BVALID held, not dropped/overtaken
//
//   edge_pass   = 1 <=> ALL burst edge tests passed.
//   corner_pass = 1 <=> ALL burst corner cases behaved correctly.
//
// The edge suite runs first; the corner cases stall channels on purpose and
// can wedge a buggy FSM, so they must not run ahead of the positive tests.
// A pulse_reset() precedes every test in both parts, so a test that wedges a
// state machine cannot corrupt the next one; mem[] survives reset, and every
// test seeds the addresses it checks, so the two suites may share addresses.
//
// Corners 8, 9 and 10 are driven by the AW-intrusion monitor below, which
// flags three distinct faults:
//   aw_ready_viol  - AWREADY high during the data phase (AW accepted, WLAST
//                    not yet accepted).
//   aw_accept_viol - a second AW actually handshakes before the current
//                    write's B response, so the open burst is silently
//                    retargeted and its remaining beats land elsewhere.
//   b_hold_viol    - BVALID dropped without a BREADY handshake.  AXI4 forbids
//                    withdrawing a VALID; a slave that does so has thrown
//                    away a response the master never accepted.
// The data-phase window deliberately ENDS at the WLAST handshake, so a
// post-WLAST response state is not judged by the strict AWREADY check;
// accepting a second AW there is still caught by aw_accept_viol.
//
// Handshake idiom (as in tb_axi4_ram_tests.v): drive stimulus at a negedge,
// sample ready/valid at the negedge, let the DUT consummate on the posedge.
//======================================================================
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module tb_axi4_ram_burst_tests (
    input  wire clk,
    input  wire reset,
    output reg  done,
    output reg  edge_pass,
    output reg  corner_pass
);

localparam DATA_WIDTH = 32;
localparam ADDR_WIDTH = 16;
localparam STRB_WIDTH = (DATA_WIDTH/8);
localparam ID_WIDTH   = 8;

localparam integer TO = 256;

reg  [ID_WIDTH-1:0]   s_axi_awid;
reg  [ADDR_WIDTH-1:0] s_axi_awaddr;
reg  [7:0]            s_axi_awlen;
reg  [2:0]            s_axi_awsize;
reg  [1:0]            s_axi_awburst;
reg                   s_axi_awlock;
reg  [3:0]            s_axi_awcache;
reg  [2:0]            s_axi_awprot;
reg                   s_axi_awvalid;
wire                  s_axi_awready;
reg  [DATA_WIDTH-1:0] s_axi_wdata;
reg  [STRB_WIDTH-1:0] s_axi_wstrb;
reg                   s_axi_wlast;
reg                   s_axi_wvalid;
wire                  s_axi_wready;
wire [ID_WIDTH-1:0]   s_axi_bid;
wire [1:0]            s_axi_bresp;
wire                  s_axi_bvalid;
reg                   s_axi_bready;
reg  [ID_WIDTH-1:0]   s_axi_arid;
reg  [ADDR_WIDTH-1:0] s_axi_araddr;
reg  [7:0]            s_axi_arlen;
reg  [2:0]            s_axi_arsize;
reg  [1:0]            s_axi_arburst;
reg                   s_axi_arlock;
reg  [3:0]            s_axi_arcache;
reg  [2:0]            s_axi_arprot;
reg                   s_axi_arvalid;
wire                  s_axi_arready;
wire [ID_WIDTH-1:0]   s_axi_rid;
wire [DATA_WIDTH-1:0] s_axi_rdata;
wire [1:0]            s_axi_rresp;
wire                  s_axi_rlast;
wire                  s_axi_rvalid;
reg                   s_axi_rready;

reg  force_rst;
wire dut_rst = reset | force_rst;

integer errors;       // infrastructure errors (unexpected timeouts)
integer edge_fail;    // burst edge tests that did not behave correctly
integer corner_fail;  // burst corner cases that did not behave correctly

// ---- AW-intrusion monitor (corners 8 and 9) ----
// Tracks the write transaction purely from the bus, independent of any
// state encoding inside the DUT, so it works on any implementation.
reg                  aw_watch_en;
reg                  wr_inflight;    // AW handshake .. B handshake
reg                  wr_data_phase;  // AW handshake .. WLAST handshake
reg                  b_outstanding;  // BVALID seen high without BREADY
reg                  aw_ready_viol;
reg                  aw_accept_viol;
reg                  b_hold_viol;
reg [ADDR_WIDTH-1:0] aw_viol_addr;

always @(posedge clk) begin
    if (!aw_watch_en) begin
        wr_inflight   <= 1'b0;
        wr_data_phase <= 1'b0;
        b_outstanding <= 1'b0;
    end else begin
        // AXI4: once BVALID is asserted it must stay asserted until BREADY.
        // Dropping it strands the write - the master never saw the response.
        if (b_outstanding && !s_axi_bvalid) begin
            if (!b_hold_viol)
                $display("  VIOL: BVALID dropped at t=%0t without a BREADY handshake",
                         $time);
            b_hold_viol <= 1'b1;
        end
        if (s_axi_bvalid && !s_axi_bready) b_outstanding <= 1'b1;
        if (s_axi_bvalid &&  s_axi_bready) b_outstanding <= 1'b0;

        // AWREADY must be low for every cycle of the data phase except the
        // cycle in which the last beat is accepted (the write is finished
        // at that point, so re-arming AWREADY there is legal).
        if (wr_data_phase && s_axi_awready
            && !(s_axi_wvalid && s_axi_wready && s_axi_wlast)) begin
            if (!aw_ready_viol)
                $display("  VIOL: AWREADY asserted at t=%0t with the write burst still owing beats",
                         $time);
            aw_ready_viol <= 1'b1;
        end
        if (s_axi_awvalid && s_axi_awready) begin
            if (wr_inflight) begin
                if (!aw_accept_viol)
                    $display("  VIOL: second AW accepted (addr=0x%0h) at t=%0t before the current write returned B",
                             s_axi_awaddr, $time);
                aw_accept_viol <= 1'b1;
                aw_viol_addr   <= s_axi_awaddr;
            end
            wr_inflight   <= 1'b1;
            wr_data_phase <= 1'b1;
        end
        if (s_axi_wvalid && s_axi_wready && s_axi_wlast) wr_data_phase <= 1'b0;
        if (s_axi_bvalid && s_axi_bready)                wr_inflight   <= 1'b0;
    end
end

reg [DATA_WIDTH-1:0] rbeat [0:31];
integer              rbeat_n;
reg                  rbeat_last;
reg [DATA_WIDTH-1:0] expv  [0:31];

axi_ram #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH), .ID_WIDTH(ID_WIDTH), .PIPELINE_OUTPUT(0)
) dut (
    .clk(clk), .rst(dut_rst),
    .s_axi_awid(s_axi_awid),     .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),   .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst), .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache), .s_axi_awprot(s_axi_awprot),
    .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),   .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),   .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bid(s_axi_bid),       .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
    .s_axi_arid(s_axi_arid),     .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),   .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst), .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache), .s_axi_arprot(s_axi_arprot),
    .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
    .s_axi_rid(s_axi_rid),       .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),   .s_axi_rlast(s_axi_rlast),
    .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready)
);

// ---- helpers (identical negedge idiom to tb_axi4_ram_corner.v) ----

task automatic pulse_reset;
    integer k;
begin
    s_axi_awvalid=0; s_axi_wvalid=0; s_axi_wlast=0; s_axi_arvalid=0;
    s_axi_bready=1; s_axi_rready=1;
    @(negedge clk);
    force_rst=1'b1; repeat (3) @(negedge clk); force_rst=1'b0;
    repeat (3) @(negedge clk);
end
endtask

task automatic do_write(
    input [ID_WIDTH-1:0] id, input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data, input [STRB_WIDTH-1:0] strb, input wait_b
);
    integer w;
begin
    @(negedge clk);
    s_axi_awid=id; s_axi_awaddr=addr; s_axi_awlen=8'd0; s_axi_awsize=3'd2;
    s_axi_awburst=2'b01; s_axi_awlock=0; s_axi_awcache=4'b0011; s_axi_awprot=0;
    s_axi_awvalid=1;
    w=0; while(!s_axi_awready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_awready) begin $display("  TIMEOUT: AW addr=0x%0h",addr); errors=errors+1; end
    @(negedge clk); s_axi_awvalid=0;
    s_axi_wdata=data; s_axi_wstrb=strb; s_axi_wlast=1'b1; s_axi_wvalid=1;
    w=0; while(!s_axi_wready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_wready) begin $display("  TIMEOUT: W addr=0x%0h",addr); errors=errors+1; end
    @(negedge clk); s_axi_wvalid=0; s_axi_wlast=0;
    if(wait_b) begin
        w=0; while(!s_axi_bvalid && w<TO) begin @(negedge clk); w=w+1; end
        if(!s_axi_bvalid) begin $display("  TIMEOUT: B addr=0x%0h",addr); errors=errors+1; end
        @(negedge clk);
    end
end
endtask

task automatic do_read(
    input [ADDR_WIDTH-1:0] addr, output [DATA_WIDTH-1:0] data_out, output last_out
);
    integer w;
begin
    @(negedge clk);
    s_axi_arid=0; s_axi_araddr=addr; s_axi_arlen=8'd0; s_axi_arsize=3'd2;
    s_axi_arburst=2'b01; s_axi_arlock=0; s_axi_arcache=4'b0011; s_axi_arprot=0;
    s_axi_arvalid=1;
    w=0; while(!s_axi_arready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_arready) begin $display("  TIMEOUT: AR addr=0x%0h",addr); errors=errors+1; end
    @(negedge clk); s_axi_arvalid=0;
    w=0; while(!s_axi_rvalid && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_rvalid) begin
        $display("  TIMEOUT: RVALID addr=0x%0h",addr); errors=errors+1;
        data_out={DATA_WIDTH{1'bx}}; last_out=1'bx;
    end else begin
        data_out=s_axi_rdata; last_out=s_axi_rlast;
    end
    @(negedge clk);
end
endtask

// streaming burst write; bounded; judged by caller read-back
task automatic do_write_burst(
    input [ID_WIDTH-1:0] id, input [ADDR_WIDTH-1:0] base,
    input [7:0] len, input [1:0] bt, input [DATA_WIDTH-1:0] data0
);
    integer i, w;
begin
    @(negedge clk);
    s_axi_awid=id; s_axi_awaddr=base; s_axi_awlen=len; s_axi_awsize=3'd2;
    s_axi_awburst=bt; s_axi_awlock=0; s_axi_awcache=4'b0011; s_axi_awprot=0;
    s_axi_awvalid=1;
    w=0; while(!s_axi_awready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_awready) $display("  (note) burst AW did not complete addr=0x%0h", base);
    @(negedge clk); s_axi_awvalid=0;
    for (i=0; i<=len; i=i+1) begin
        s_axi_wdata=data0+i; s_axi_wstrb=4'hF; s_axi_wlast=(i==len); s_axi_wvalid=1;
        w=0; while(!s_axi_wready && w<TO) begin @(negedge clk); w=w+1; end
        @(negedge clk);
    end
    s_axi_wvalid=0; s_axi_wlast=0;
    w=0; while(!s_axi_bvalid && w<TO) begin @(negedge clk); w=w+1; end
    @(negedge clk);
end
endtask

// ---- split-phase write helpers (corners 8 and 9) ----
// do_write_burst() drives a whole burst atomically; corners 8 and 9 need to
// stop in the middle of one, so the phases are separate tasks here.

task automatic aw_watch_start;
begin
    aw_ready_viol  = 1'b0;
    aw_accept_viol = 1'b0;
    b_hold_viol    = 1'b0;
    aw_viol_addr   = {ADDR_WIDTH{1'b0}};
    aw_watch_en    = 1'b1;
    @(negedge clk);
end
endtask

task automatic aw_watch_stop;
begin
    @(negedge clk);
    aw_watch_en = 1'b0;
end
endtask

task automatic aw_issue(
    input [ID_WIDTH-1:0] id, input [ADDR_WIDTH-1:0] addr,
    input [7:0] len, input [1:0] bt
);
    integer w;
begin
    @(negedge clk);
    s_axi_awid=id; s_axi_awaddr=addr; s_axi_awlen=len; s_axi_awsize=3'd2;
    s_axi_awburst=bt; s_axi_awlock=0; s_axi_awcache=4'b0011; s_axi_awprot=0;
    s_axi_awvalid=1'b1;
    w=0; while(!s_axi_awready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_awready) begin $display("  TIMEOUT: AW addr=0x%0h",addr); errors=errors+1; end
    @(negedge clk); s_axi_awvalid=1'b0;
end
endtask

// one W beat, then idle for a cycle (a gap between beats is legal and keeps
// the burst parked in its data phase while the intrusion is driven)
task automatic w_beat(input [DATA_WIDTH-1:0] data, input last);
    integer w;
begin
    @(negedge clk);
    s_axi_wdata=data; s_axi_wstrb=4'hF; s_axi_wlast=last; s_axi_wvalid=1'b1;
    w=0; while(!s_axi_wready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_wready) begin $display("  TIMEOUT: W data=0x%0h",data); errors=errors+1; end
    @(negedge clk); s_axi_wvalid=1'b0; s_axi_wlast=1'b0;
end
endtask

task automatic b_wait(output got);
    integer w;
begin
    w=0; while(!s_axi_bvalid && w<TO) begin @(negedge clk); w=w+1; end
    got = s_axi_bvalid;
    if(!got) begin $display("  TIMEOUT: BVALID"); errors=errors+1; end
    @(negedge clk);
end
endtask

// Bounded wait for BVALID that reports rather than charging `errors`; corner
// 10 judges a missing B itself instead of calling it testbench trouble.
task automatic b_wait_quiet(input integer limit, output got);
    integer w;
begin
    w=0; got=1'b0;
    while(!got && w<limit) begin
        if (s_axi_bvalid) got=1'b1;
        else begin @(negedge clk); w=w+1; end
    end
end
endtask

// Hold AWVALID for `cycles` cycles in the middle of an open burst and report
// whether the slave ever offered AWREADY for it.
task automatic aw_intrude(
    input [ADDR_WIDTH-1:0] addr, input integer cycles, output accepted
);
    integer c;
begin
    accepted = 1'b0;
    @(negedge clk);
    s_axi_awid=8'hEE; s_axi_awaddr=addr; s_axi_awlen=8'd3; s_axi_awsize=3'd2;
    s_axi_awburst=2'b01; s_axi_awlock=0; s_axi_awcache=4'b0011; s_axi_awprot=0;
    s_axi_awvalid=1'b1;
    for (c=0; c<cycles; c=c+1) begin
        if (s_axi_awready) accepted = 1'b1;
        @(negedge clk);
    end
    s_axi_awvalid=1'b0;
    @(negedge clk);
end
endtask

// burst read; captures beats into rbeat[]
task automatic do_read_burst(
    input [ADDR_WIDTH-1:0] base, input [7:0] len, input [1:0] bt
);
    integer w, g;
begin
    @(negedge clk);
    s_axi_arid=0; s_axi_araddr=base; s_axi_arlen=len; s_axi_arsize=3'd2;
    s_axi_arburst=bt; s_axi_arlock=0; s_axi_arcache=4'b0011; s_axi_arprot=0;
    s_axi_arvalid=1;
    w=0; while(!s_axi_arready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_arready) begin $display("  TIMEOUT: burst AR addr=0x%0h",base); errors=errors+1; end
    @(negedge clk); s_axi_arvalid=0;
    rbeat_n=0; rbeat_last=1'b0; g=0;
    while(!rbeat_last && g<TO && rbeat_n<32) begin
        if(s_axi_rvalid && s_axi_rready) begin
            rbeat[rbeat_n]=s_axi_rdata; rbeat_last=s_axi_rlast; rbeat_n=rbeat_n+1;
        end
        @(negedge clk); g=g+1;
    end
end
endtask

// ---- extra helpers used by the burst edge suite ----


// INCR burst write with a caller-supplied strobe per beat (strb applied to all
// beats) and caller-supplied size.
task automatic do_write_burst_cfg(
    input [ID_WIDTH-1:0] id, input [ADDR_WIDTH-1:0] base,
    input [7:0] len, input [1:0] bt, input [2:0] size,
    input [DATA_WIDTH-1:0] data0, input [STRB_WIDTH-1:0] strb
);
    integer i, w;
begin
    @(negedge clk);
    s_axi_awid=id; s_axi_awaddr=base; s_axi_awlen=len; s_axi_awsize=size;
    s_axi_awburst=bt; s_axi_awlock=0; s_axi_awcache=4'b0011; s_axi_awprot=0;
    s_axi_awvalid=1;
    w=0; while(!s_axi_awready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_awready) begin $display("  TIMEOUT: AWcfg 0x%0h",base); errors=errors+1; end
    @(negedge clk); s_axi_awvalid=0;
    for (i=0; i<=len; i=i+1) begin
        s_axi_wdata=data0+i; s_axi_wstrb=strb; s_axi_wlast=(i==len); s_axi_wvalid=1;
        w=0; while(!s_axi_wready && w<TO) begin @(negedge clk); w=w+1; end
        @(negedge clk);
    end
    s_axi_wvalid=0; s_axi_wlast=0;
    w=0; while(!s_axi_bvalid && w<TO) begin @(negedge clk); w=w+1; end
    @(negedge clk);
end
endtask

// Narrow (awsize=1) INCR burst: 2 bytes per beat, strobes alternate between
// the low and high half-word so each beat writes only its own lanes.
task automatic do_write_burst_narrow(
    input [ID_WIDTH-1:0] id, input [ADDR_WIDTH-1:0] base,
    input [7:0] len, input [15:0] data0
);
    integer i, w;
    reg [ADDR_WIDTH-1:0] a;
begin
    @(negedge clk);
    s_axi_awid=id; s_axi_awaddr=base; s_axi_awlen=len; s_axi_awsize=3'd1;
    s_axi_awburst=2'b01; s_axi_awlock=0; s_axi_awcache=4'b0011; s_axi_awprot=0;
    s_axi_awvalid=1;
    w=0; while(!s_axi_awready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_awready) begin $display("  TIMEOUT: AWnarrow 0x%0h",base); errors=errors+1; end
    @(negedge clk); s_axi_awvalid=0;
    for (i=0; i<=len; i=i+1) begin
        a = base + (i*2);
        if (a[1] == 1'b0) begin
            s_axi_wdata = {16'h0000, (data0+i)};  s_axi_wstrb = 4'b0011;
        end else begin
            s_axi_wdata = {(data0+i), 16'h0000};  s_axi_wstrb = 4'b1100;
        end
        s_axi_wlast=(i==len); s_axi_wvalid=1;
        w=0; while(!s_axi_wready && w<TO) begin @(negedge clk); w=w+1; end
        @(negedge clk);
    end
    s_axi_wvalid=0; s_axi_wlast=0;
    w=0; while(!s_axi_bvalid && w<TO) begin @(negedge clk); w=w+1; end
    @(negedge clk);
end
endtask

// Burst read that also records how many rlast pulses were seen.
integer rlast_count;
task automatic do_read_burst_count(
    input [ADDR_WIDTH-1:0] base, input [7:0] len, input [1:0] bt
);
    integer w, g;
begin
    @(negedge clk);
    s_axi_arid=0; s_axi_araddr=base; s_axi_arlen=len; s_axi_arsize=3'd2;
    s_axi_arburst=bt; s_axi_arlock=0; s_axi_arcache=4'b0011; s_axi_arprot=0;
    s_axi_arvalid=1;
    w=0; while(!s_axi_arready && w<TO) begin @(negedge clk); w=w+1; end
    if(!s_axi_arready) begin $display("  TIMEOUT: AR 0x%0h",base); errors=errors+1; end
    @(negedge clk); s_axi_arvalid=0;
    rbeat_n=0; rbeat_last=1'b0; rlast_count=0; g=0;
    while(!rbeat_last && g<TO && rbeat_n<32) begin
        if(s_axi_rvalid && s_axi_rready) begin
            rbeat[rbeat_n]=s_axi_rdata; rbeat_last=s_axi_rlast; rbeat_n=rbeat_n+1;
            if(s_axi_rlast) rlast_count=rlast_count+1;
        end
        @(negedge clk); g=g+1;
    end
end
endtask

// ====================================================================
// Test sequence: PART A (burst edge) then PART B (burst corner)
// ====================================================================
integer w, k, i;
reg [DATA_WIDTH-1:0] tmp;
reg                  tlast;

initial begin
    s_axi_awid=0; s_axi_awaddr=0; s_axi_awlen=0; s_axi_awsize=0;
    s_axi_awburst=2'b01; s_axi_awlock=0; s_axi_awcache=0; s_axi_awprot=0;
    s_axi_awvalid=0;
    s_axi_wdata=0; s_axi_wstrb=0; s_axi_wlast=0; s_axi_wvalid=0;
    s_axi_bready=1'b1;
    s_axi_arid=0; s_axi_araddr=0; s_axi_arlen=0; s_axi_arsize=0;
    s_axi_arburst=2'b01; s_axi_arlock=0; s_axi_arcache=0; s_axi_arprot=0;
    s_axi_arvalid=0;
    s_axi_rready=1'b1;
    force_rst=1'b0;
    aw_watch_en=1'b0; wr_inflight=1'b0; wr_data_phase=1'b0; b_outstanding=1'b0;
    aw_ready_viol=1'b0; aw_accept_viol=1'b0; b_hold_viol=1'b0;
    aw_viol_addr={ADDR_WIDTH{1'b0}};
    errors=0; edge_fail=0; corner_fail=0;
    done=1'b0; edge_pass=1'b0; corner_pass=1'b0;

    @(negedge reset);
    repeat (5) @(posedge clk);

    $display("=========================================================");
    $display("PART A: BURST EDGE tests (EXPECT ALL TO PASS)");
    $display("=========================================================");

    // ---------------- BE1: basic INCR burst, len=4 ----------------
    $display("[BE1] INCR burst len=4 round-trip (EXPECT PASS)");
    pulse_reset();
    do_write_burst(0, 16'h0400, 8'd4, 2'b01, 32'h1000_0000);
    do_read_burst(16'h0400, 8'd4, 2'b01);
    k=0;
    if (rbeat_n !== 5) begin
        $display("  FAIL: got %0d beats, expected 5", rbeat_n); k=1;
    end else for (i=0; i<5; i=i+1)
        if (rbeat[i] !== (32'h10000000 + i)) begin
            $display("  FAIL: beat %0d = 0x%0h expected 0x%0h", i, rbeat[i], 32'h10000000+i);
            k=1;
        end
    if (k) edge_fail=edge_fail+1; else $display("  PASS: 5 beats in order");

    // ---------------- BE2: long INCR burst, 32 beats ----------------
    $display("[BE2] long INCR burst, 32 beats (EXPECT PASS)");
    pulse_reset();
    do_write_burst(0, 16'h0500, 8'd31, 2'b01, 32'h2000_0000);
    do_read_burst(16'h0500, 8'd31, 2'b01);
    k=0;
    if (rbeat_n !== 32) begin
        $display("  FAIL: got %0d beats, expected 32", rbeat_n); k=1;
    end else for (i=0; i<32; i=i+1)
        if (rbeat[i] !== (32'h20000000 + i)) begin
            $display("  FAIL: beat %0d = 0x%0h", i, rbeat[i]); k=1;
        end
    if (k) edge_fail=edge_fail+1; else $display("  PASS: 32 beats correct");

    // ---------------- BE3: narrow burst, awsize=1 ----------------
    // 4 beats of 2 bytes from 0x0600 fill words 0x0600 and 0x0604.
    $display("[BE3] narrow burst awsize=1 (EXPECT PASS)");
    pulse_reset();
    do_write(0, 16'h0600, 32'h0000_0000, 4'hF, 1'b1);
    do_write(0, 16'h0604, 32'h0000_0000, 4'hF, 1'b1);
    do_write_burst_narrow(0, 16'h0600, 8'd3, 16'hAA01);
    do_read(16'h0600, tmp, tlast);
    k=0;
    if (tmp !== 32'hAA02AA01) begin
        $display("  FAIL: word0 = 0x%0h expected 0xAA02AA01", tmp); k=1;
    end
    do_read(16'h0604, tmp, tlast);
    if (tmp !== 32'hAA04AA03) begin
        $display("  FAIL: word1 = 0x%0h expected 0xAA04AA03", tmp); k=1;
    end
    if (k) edge_fail=edge_fail+1; else $display("  PASS: narrow beats landed lane-correct");

    // ---------------- BE4: unaligned INCR start ----------------
    $display("[BE4] unaligned INCR start address (EXPECT PASS)");
    pulse_reset();
    do_write_burst(0, 16'h0702, 8'd2, 2'b01, 32'h3000_0000);
    do_read_burst(16'h0700, 8'd2, 2'b01);
    if (rbeat_n !== 3) begin
        $display("  FAIL: got %0d beats, expected 3", rbeat_n);
        edge_fail=edge_fail+1;
    end else $display("  PASS: unaligned burst completed with 3 beats");

    // ---------------- BE5: rlast placement ----------------
    $display("[BE5] rlast on exactly the final beat (EXPECT PASS)");
    pulse_reset();
    k=0;
    do_write_burst(0, 16'h0800, 8'd7, 2'b01, 32'h4000_0000);
    do_read_burst_count(16'h0800, 8'd7, 2'b01);
    if (rbeat_n !== 8 || rlast_count !== 1) begin
        $display("  FAIL: len=7 gave %0d beats, %0d rlast", rbeat_n, rlast_count); k=1;
    end
    do_read_burst_count(16'h0800, 8'd0, 2'b01);
    if (rbeat_n !== 1 || rlast_count !== 1) begin
        $display("  FAIL: len=0 gave %0d beats, %0d rlast", rbeat_n, rlast_count); k=1;
    end
    do_read_burst_count(16'h0800, 8'd1, 2'b01);
    if (rbeat_n !== 2 || rlast_count !== 1) begin
        $display("  FAIL: len=1 gave %0d beats, %0d rlast", rbeat_n, rlast_count); k=1;
    end
    if (k) edge_fail=edge_fail+1; else $display("  PASS: one rlast, on the last beat, at every length");

    // ---------------- BE6: per-beat wstrb ----------------
    // Whole burst written with only the low half-word enabled; the high half
    // of every touched word must keep its pre-set value.
    $display("[BE6] partial wstrb across a burst (EXPECT PASS)");
    pulse_reset();
    do_write(0, 16'h0900, 32'hFFFF_FFFF, 4'hF, 1'b1);
    do_write(0, 16'h0904, 32'hFFFF_FFFF, 4'hF, 1'b1);
    do_write_burst_cfg(0, 16'h0900, 8'd1, 2'b01, 3'd2, 32'h0000_1234, 4'b0011);
    k=0;
    do_read(16'h0900, tmp, tlast);
    if (tmp !== 32'hFFFF1234) begin
        $display("  FAIL: word0 = 0x%0h expected 0xFFFF1234", tmp); k=1;
    end
    do_read(16'h0904, tmp, tlast);
    if (tmp !== 32'hFFFF1235) begin
        $display("  FAIL: word1 = 0x%0h expected 0xFFFF1235", tmp); k=1;
    end
    if (k) edge_fail=edge_fail+1; else $display("  PASS: masked lanes preserved across the burst");

    // ---------------- BE7: back-to-back bursts ----------------
    $display("[BE7] back-to-back bursts (EXPECT PASS)");
    pulse_reset();
    do_write_burst(0, 16'h0A00, 8'd3, 2'b01, 32'h5000_0000);
    do_write_burst(0, 16'h0A10, 8'd3, 2'b01, 32'h6000_0000);
    k=0;
    do_read_burst(16'h0A00, 8'd3, 2'b01);
    if (rbeat_n !== 4 || rbeat[0] !== 32'h50000000 || rbeat[3] !== 32'h50000003) begin
        $display("  FAIL: first burst beats=%0d [0]=0x%0h [3]=0x%0h",
                 rbeat_n, rbeat[0], rbeat[3]); k=1;
    end
    do_read_burst(16'h0A10, 8'd3, 2'b01);
    if (rbeat_n !== 4 || rbeat[0] !== 32'h60000000 || rbeat[3] !== 32'h60000003) begin
        $display("  FAIL: second burst beats=%0d [0]=0x%0h [3]=0x%0h",
                 rbeat_n, rbeat[0], rbeat[3]); k=1;
    end
    if (k) edge_fail=edge_fail+1; else $display("  PASS: both bursts intact");

    // ---------------- BE8: 4KB boundary ----------------
    // A legal INCR burst may run up to, but not across, a 4KB boundary.
    // 4 beats ending exactly at 0x0FFC must work, as must one starting at
    // 0x1000 immediately after it.
    $display("[BE8] burst flush against the 4KB boundary (EXPECT PASS)");
    pulse_reset();
    k=0;
    do_write_burst(0, 16'h0FF0, 8'd3, 2'b01, 32'h7000_0000);
    do_read_burst(16'h0FF0, 8'd3, 2'b01);
    if (rbeat_n !== 4 || rbeat[3] !== 32'h70000003) begin
        $display("  FAIL: pre-boundary burst beats=%0d [3]=0x%0h", rbeat_n, rbeat[3]); k=1;
    end
    do_write_burst(0, 16'h1000, 8'd3, 2'b01, 32'h8000_0000);
    do_read_burst(16'h1000, 8'd3, 2'b01);
    if (rbeat_n !== 4 || rbeat[0] !== 32'h80000000) begin
        $display("  FAIL: post-boundary burst beats=%0d [0]=0x%0h", rbeat_n, rbeat[0]); k=1;
    end
    if (k) edge_fail=edge_fail+1; else $display("  PASS: both sides of the boundary intact");

    // ----------------------------------------------------------------
    $display("[SUMMARY A] burst edge fails=%0d, infra=%0d", edge_fail, errors);
    if (edge_fail == 0 && errors == 0) begin
        $display("[RESULT A] ALL burst edge tests PASSED");
        edge_pass = 1'b1;
    end else begin
        $display("[RESULT A] burst edge tests FAILED: %0d edge, %0d infra", edge_fail, errors);
        edge_pass = 1'b0;
    end

    // ================================================================
    // PART B.  `errors` restarts here so PART A's infra count is not
    // double-judged; every corner opens with its own pulse_reset.
    // ================================================================
    errors = 0;
    pulse_reset;

    $display("=========================================================");
    $display("PART B: BURST CORNER cases (a correct implementation passes all)");
    $display("=========================================================");

    // ----------------------------------------------------------------
    // BC1: FIXED burst write addressing.
    // A FIXED burst writes every beat to the SAME address, so after 4
    // beats mem[base] must hold the last beat (D3) and the next word must
    // be untouched. The DUT increments the address regardless of burst
    // type, so it walks D0..D3 across four words instead.
    // ----------------------------------------------------------------
    begin : bc1
        integer k; reg [DATA_WIDTH-1:0] rd; reg l; reg okc;
        pulse_reset;
        $display("[BURST 1] FIXED burst write addressing, burst type 0");
        for (k=0; k<4; k=k+1) do_write(0, 16'h0200 + (k<<2), 32'h00000000, 4'hF, 1);
        do_write_burst(0, 16'h0200, 8'd3, 2'b00, 32'h40000000); // FIXED, D0..D3
        okc=1'b1;
        do_read(16'h0200, rd, l); if (rd !== 32'h40000003) okc=1'b0; // last beat wins
        do_read(16'h0204, rd, l); if (rd !== 32'h00000000) okc=1'b0; // must stay untouched
        if (!okc) begin
            $display("  FAIL: FIXED write walked the address (0x200 should be D3, 0x204 untouched)");
            corner_fail = corner_fail + 1;
        end else $display("  PASS: FIXED write holds address");
    end

    // ----------------------------------------------------------------
    // BC2: FIXED burst read addressing.
    // Preload 4 distinct words, then FIXED-read 4 beats from the base.
    // FIXED must return the SAME word every beat; the DUT increments the
    // address regardless of burst type.
    // ----------------------------------------------------------------
    begin : bc2
        integer k; reg okc;
        pulse_reset;
        $display("[BURST 2] FIXED burst read addressing, burst type 0");
        for (k=0; k<4; k=k+1) begin
            expv[k] = 32'h50000000 + k;
            do_write(0, 16'h0240 + (k<<2), expv[k], 4'hF, 1);
        end
        do_read_burst(16'h0240, 8'd3, 2'b00);   // FIXED
        okc = (rbeat_n==4) && rbeat_last;
        for (k=0; k<4; k=k+1) if (!(rbeat[k]===expv[0])) okc=1'b0; // all == M0
        if (!okc) begin
            $display("  FAIL: FIXED read beats=%0d got[%0h %0h %0h %0h] exp all 0x%0h",
                     rbeat_n, rbeat[0],rbeat[1],rbeat[2],rbeat[3], expv[0]);
            corner_fail = corner_fail + 1;
        end else $display("  PASS: FIXED read holds address");
    end

    // ----------------------------------------------------------------
    // BC3: WRAP burst read addressing.
    // Preload block 0x00..0x0C, WRAP-read 4 beats from 0x08. Correct
    // sequence wraps: w2,w3,w0,w1. DUT increments linearly (no wrap).
    // ----------------------------------------------------------------
    begin : bc3
        integer k; reg okc;
        pulse_reset;
        $display("[BURST 3] WRAP burst read addressing, burst type 2 (EXPECT PASS)");
        for (k=0; k<4; k=k+1) begin
            expv[k] = 32'h60000000 + k;
            do_write(0, (k<<2), expv[k], 4'hF, 1);
        end
        do_read_burst(16'h0008, 8'd3, 2'b10);   // WRAP from 0x08
        okc = (rbeat_n==4) && rbeat_last
           && (rbeat[0]===expv[2]) && (rbeat[1]===expv[3])
           && (rbeat[2]===expv[0]) && (rbeat[3]===expv[1]);
        if (!okc) begin
            $display("  FAIL: WRAP read beats=%0d got[%0h %0h %0h %0h] exp[%0h %0h %0h %0h]",
                     rbeat_n, rbeat[0],rbeat[1],rbeat[2],rbeat[3],
                     expv[2],expv[3],expv[0],expv[1]);
            corner_fail = corner_fail + 1;
        end else $display("  PASS: WRAP read wraps within block");
    end

    // ----------------------------------------------------------------
    // BC4: WRAP burst write addressing.
    // WRAP-write 4 beats from 0x08. Correct: 0x08<-D0,0x0C<-D1,0x00<-D2,
    // 0x04<-D3. DUT treats WRAP as INCR (and corrupts via RESP), so
    // 0x00/0x04 are never written correctly.
    // ----------------------------------------------------------------
    begin : bc4
        integer k; reg [DATA_WIDTH-1:0] rd; reg l; reg okc;
        pulse_reset;
        $display("[BURST 4] WRAP burst write addressing, burst type 2 (EXPECT PASS)");
        for (k=0; k<4; k=k+1) do_write(0, (k<<2), 32'h00000000, 4'hF, 1);
        do_write_burst(0, 16'h0008, 8'd3, 2'b10, 32'h70000000);  // D0..D3
        okc=1'b1;
        do_read(16'h0000, rd, l); if (rd !== 32'h70000002) okc=1'b0;  // D2
        do_read(16'h0004, rd, l); if (rd !== 32'h70000003) okc=1'b0;  // D3
        do_read(16'h0008, rd, l); if (rd !== 32'h70000000) okc=1'b0;  // D0
        do_read(16'h000C, rd, l); if (rd !== 32'h70000001) okc=1'b0;  // D1
        if (!okc) begin
            $display("  FAIL: WRAP write did not wrap (0x0000 should hold D2=0x70000002)");
            corner_fail = corner_fail + 1;
        end else $display("  PASS: WRAP write wraps within block");
    end

    // ----------------------------------------------------------------
    // BC5: R-channel backpressure (stale first beat).
    // Prime rdata_reg with DY, then read X holding rready low a few
    // cycles. rvalid asserts before mem is fetched, so the first accepted
    // beat is the stale DY instead of DX.
    // ----------------------------------------------------------------
    begin : bc5
        reg [DATA_WIDTH-1:0] DX, DY, cap_data, rd; reg cap_last, got, l;
        integer w, drain;
        pulse_reset;
        DX=32'hAAAA1111; DY=32'h5555EEEE;
        $display("[BURST 5] R-channel backpressure");
        do_write(0, 16'h0040, DY, 4'hF, 1);
        do_write(0, 16'h0044, DX, 4'hF, 1);
        do_read (16'h0040, rd, l);        // leaves rdata_reg = DY

        @(negedge clk);
        s_axi_arid=0; s_axi_araddr=16'h0044; s_axi_arlen=0; s_axi_arsize=2;
        s_axi_arburst=2'b01; s_axi_arlock=0; s_axi_arcache=4'b0011;
        s_axi_arprot=0; s_axi_arvalid=1;
        w=0; while(!s_axi_arready && w<TO) begin @(negedge clk); w=w+1; end
        @(negedge clk); s_axi_arvalid=0;

        s_axi_rready=1'b0; repeat (3) @(negedge clk);
        s_axi_rready=1'b1;
        got=1'b0; cap_data={DATA_WIDTH{1'bx}}; cap_last=1'bx; w=0;
        while(!s_axi_rvalid && w<TO) begin @(negedge clk); w=w+1; end
        if (s_axi_rvalid) begin cap_data=s_axi_rdata; cap_last=s_axi_rlast; got=1'b1; end
        @(negedge clk);
        drain=0;
        while(!cap_last && drain<TO) begin
            if (s_axi_rvalid && s_axi_rready) cap_last=s_axi_rlast;
            @(negedge clk); drain=drain+1;
        end
        if (!got) begin
            $display("  FAIL: never received a read beat");
            corner_fail = corner_fail + 1;
        end else if (cap_data !== DX) begin
            $display("  FAIL: first beat data=0x%0h (expected 0x%0h)", cap_data, DX);
            corner_fail = corner_fail + 1;
        end else $display("  PASS: correct data under backpressure");
    end

    // ----------------------------------------------------------------
    // BC6: INCR burst addressing (AWBURST/ARBURST = 2'b01).
    // The one encoding the rest of the suite leans on implicitly, pinned
    // down here directly: an INCR burst must walk one word per beat on
    // both channels and must not spill past the last beat. Write D0..D3
    // from 0x0300, read them back single-beat, then INCR-read the same
    // four words as one burst.
    // ----------------------------------------------------------------
    begin : bc6
        integer k; reg [DATA_WIDTH-1:0] rd; reg l; reg okc;
        pulse_reset;
        $display("[BURST 6] INCR burst addressing, burst type 1");
        for (k=0; k<5; k=k+1) do_write(0, 16'h0300 + (k<<2), 32'h00000000, 4'hF, 1);
        do_write_burst(0, 16'h0300, 8'd3, 2'b01, 32'h80000000); // INCR, D0..D3
        okc=1'b1;
        for (k=0; k<4; k=k+1) begin
            expv[k] = 32'h80000000 + k;
            do_read(16'h0300 + (k<<2), rd, l);
            if (rd !== expv[k]) begin
                $display("  FAIL: INCR write mem[0x%0h]=0x%0h exp 0x%0h",
                         16'h0300 + (k<<2), rd, expv[k]);
                okc=1'b0;
            end
        end
        do_read(16'h0310, rd, l);                 // one past the burst
        if (rd !== 32'h00000000) begin
            $display("  FAIL: INCR write ran past last beat, mem[0x0310]=0x%0h", rd);
            okc=1'b0;
        end
        do_read_burst(16'h0300, 8'd3, 2'b01);     // INCR read of the same block
        if (!((rbeat_n==4) && rbeat_last
              && (rbeat[0]===expv[0]) && (rbeat[1]===expv[1])
              && (rbeat[2]===expv[2]) && (rbeat[3]===expv[3]))) begin
            $display("  FAIL: INCR read beats=%0d got[%0h %0h %0h %0h] exp[%0h %0h %0h %0h]",
                     rbeat_n, rbeat[0],rbeat[1],rbeat[2],rbeat[3],
                     expv[0],expv[1],expv[2],expv[3]);
            okc=1'b0;
        end
        if (!okc) corner_fail = corner_fail + 1;
        else $display("  PASS: INCR walks one word per beat on both channels");
    end

    // ----------------------------------------------------------------
    // BC7: reserved burst type (AWBURST/ARBURST = 2'b11).
    // 2'b11 is reserved in AXI4, so the addressing the DUT picks is not
    // specified and is NOT judged here. What IS required is that a
    // reserved encoding cannot wedge the slave: the write burst must
    // still drain its beats and return BVALID, the read burst must still
    // return exactly len+1 beats with RLAST on the last one and no X
    // data, and normal INCR traffic must work afterwards.
    // ----------------------------------------------------------------
    begin : bc7
        integer k; reg [DATA_WIDTH-1:0] rd; reg l; reg okc; integer pre_err;
        pulse_reset;
        $display("[BURST 7] reserved burst type 3 (liveness only, addressing unspecified)");
        for (k=0; k<4; k=k+1) do_write(0, 16'h0380 + (k<<2), 32'h00000000, 4'hF, 1);
        pre_err = errors;
        do_write_burst(0, 16'h0380, 8'd3, 2'b11, 32'h90000000);
        okc=1'b1;
        do_read_burst(16'h0380, 8'd3, 2'b11);
        if (!(rbeat_n==4 && rbeat_last)) begin
            $display("  FAIL: reserved-type read returned %0d beat(s), rlast=%0b (exp 4 beats + rlast)",
                     rbeat_n, rbeat_last);
            okc=1'b0;
        end
        for (k=0; k<rbeat_n; k=k+1) begin
            if (^rbeat[k] === 1'bx) begin
                $display("  FAIL: reserved-type read beat %0d is X (0x%0h)", k, rbeat[k]);
                okc=1'b0;
            end
        end
        // slave must still be usable for a well-formed INCR burst
        do_write_burst(0, 16'h0380, 8'd3, 2'b01, 32'hA0000000);
        for (k=0; k<4; k=k+1) begin
            do_read(16'h0380 + (k<<2), rd, l);
            if (rd !== 32'hA0000000 + k) begin
                $display("  FAIL: slave not usable after reserved burst, mem[0x%0h]=0x%0h exp 0x%0h",
                         16'h0380 + (k<<2), rd, 32'hA0000000 + k);
                okc=1'b0;
            end
        end
        if (errors != pre_err) begin
            $display("  FAIL: reserved burst type caused %0d channel timeout(s)", errors - pre_err);
            okc=1'b0;
        end
        if (!okc) corner_fail = corner_fail + 1;
        else $display("  PASS: reserved burst type stays live and leaves the slave usable");
    end

    // ----------------------------------------------------------------
    // BC8: AW intrusion in the middle of a write burst.
    // Open a 4-beat INCR write at 0x0400, deliver two beats, then hold
    // AWVALID for a DIFFERENT address (0x0480) while the burst still owes
    // two beats. The slave has exactly one set of write registers, so it
    // must keep AWREADY low until the burst is done; if it accepts the
    // intruder, the open burst is retargeted and its remaining beats land
    // at 0x0480. Both the handshake and the resulting memory damage are
    // checked, so the corner cannot be passed by a DUT that merely hides
    // the symptom.
    // ----------------------------------------------------------------
    begin : bc8
        integer k; reg [DATA_WIDTH-1:0] rd; reg l; reg okc; reg accepted; reg bgot;
        pulse_reset;
        $display("[BURST 8] AW intrusion mid-burst: AWREADY must stay low until the write completes");
        for (k=0; k<4; k=k+1) do_write(0, 16'h0400 + (k<<2), 32'h00000000, 4'hF, 1);
        for (k=0; k<4; k=k+1) do_write(0, 16'h0480 + (k<<2), 32'h00000000, 4'hF, 1);
        okc=1'b1;

        aw_watch_start;
        aw_issue(8'h11, 16'h0400, 8'd3, 2'b01);
        w_beat(32'hC0000000, 1'b0);
        w_beat(32'hC0000001, 1'b0);
        aw_intrude(16'h0480, 6, accepted);     // burst still owes 2 beats
        w_beat(32'hC0000002, 1'b0);
        w_beat(32'hC0000003, 1'b1);
        b_wait(bgot);
        aw_watch_stop;

        if (accepted || aw_accept_viol) begin
            $display("  FAIL: slave accepted a second AW (0x0480) while the 0x0400 burst was open");
            okc=1'b0;
        end
        if (aw_ready_viol) begin
            $display("  FAIL: AWREADY was asserted while the write burst still owed beats");
            okc=1'b0;
        end
        if (!bgot) begin
            $display("  FAIL: no BVALID for the interrupted burst");
            okc=1'b0;
        end
        for (k=0; k<4; k=k+1) begin
            do_read(16'h0400 + (k<<2), rd, l);
            if (rd !== 32'hC0000000 + k) begin
                $display("  FAIL: mem[0x%0h]=0x%0h exp 0x%0h (burst retargeted by the intruding AW)",
                         16'h0400 + (k<<2), rd, 32'hC0000000 + k);
                okc=1'b0;
            end
        end
        for (k=0; k<4; k=k+1) begin
            do_read(16'h0480 + (k<<2), rd, l);
            if (rd !== 32'h00000000) begin
                $display("  FAIL: mem[0x%0h]=0x%0h, beats leaked to the intruder's address",
                         16'h0480 + (k<<2), rd);
                okc=1'b0;
            end
        end
        if (!okc) corner_fail = corner_fail + 1;
        else $display("  PASS: AW intrusion rejected, burst landed intact");
    end

    // ----------------------------------------------------------------
    // BC9: read traffic started in the middle of a write burst.
    // Same open write burst, but the interference comes from the read
    // channel: a full 4-beat INCR read of an unrelated block is issued
    // between beat 1 and beat 2. The read and write paths are independent,
    // so nothing may move: AWREADY must stay low for the whole data phase
    // (a shared FSM that walks back to its idle/accept state on AR traffic
    // fails here), the read must return its own data, and the write must
    // still land correctly once its remaining beats are delivered.
    // ----------------------------------------------------------------
    begin : bc9
        integer k; reg [DATA_WIDTH-1:0] rd; reg l; reg okc; reg bgot;
        pulse_reset;
        $display("[BURST 9] read transaction started mid-write-burst");
        for (k=0; k<4; k=k+1) begin
            expv[k] = 32'hD0000000 + k;
            do_write(0, 16'h0500 + (k<<2), expv[k], 4'hF, 1);
        end
        for (k=0; k<4; k=k+1) do_write(0, 16'h0440 + (k<<2), 32'h00000000, 4'hF, 1);
        okc=1'b1;

        aw_watch_start;
        aw_issue(8'h22, 16'h0440, 8'd3, 2'b01);
        w_beat(32'hC1000000, 1'b0);
        w_beat(32'hC1000001, 1'b0);
        do_read_burst(16'h0500, 8'd3, 2'b01);  // read while the write is open
        w_beat(32'hC1000002, 1'b0);
        w_beat(32'hC1000003, 1'b1);
        b_wait(bgot);
        aw_watch_stop;

        if (aw_ready_viol) begin
            $display("  FAIL: read traffic re-asserted AWREADY while the write burst was open");
            okc=1'b0;
        end
        if (aw_accept_viol) begin
            $display("  FAIL: a second AW was accepted while the write burst was open");
            okc=1'b0;
        end
        if (!bgot) begin
            $display("  FAIL: no BVALID after the read intrusion");
            okc=1'b0;
        end
        if (!((rbeat_n==4) && rbeat_last
              && (rbeat[0]===expv[0]) && (rbeat[1]===expv[1])
              && (rbeat[2]===expv[2]) && (rbeat[3]===expv[3]))) begin
            $display("  FAIL: mid-write read beats=%0d got[%0h %0h %0h %0h] exp[%0h %0h %0h %0h]",
                     rbeat_n, rbeat[0],rbeat[1],rbeat[2],rbeat[3],
                     expv[0],expv[1],expv[2],expv[3]);
            okc=1'b0;
        end
        for (k=0; k<4; k=k+1) begin
            do_read(16'h0440 + (k<<2), rd, l);
            if (rd !== 32'hC1000000 + k) begin
                $display("  FAIL: mem[0x%0h]=0x%0h exp 0x%0h (write burst disturbed by the read)",
                         16'h0440 + (k<<2), rd, 32'hC1000000 + k);
                okc=1'b0;
            end
        end
        if (!okc) corner_fail = corner_fail + 1;
        else $display("  PASS: concurrent read left the open write burst alone");
    end

    // ----------------------------------------------------------------
    // BC10: the master never asserts BREADY.
    // The third way a write fails to complete: every beat is delivered, but
    // the response is never accepted, so the transaction is still open. A
    // slave with one set of write registers must sit on it - BVALID stays up
    // until BREADY (AXI4 forbids withdrawing a VALID), and AWREADY stays low
    // so the stalled response cannot be overtaken by a new write. BREADY is
    // held low for the whole burst here, an AW for a different address is
    // pushed at the slave while the response is stranded, and only then is
    // BREADY released.
    //
    // Channel timeouts inside this corner are re-attributed to the corner
    // instead of the global `errors` counter: a slave that has already been
    // wedged by this case will time out the checks that follow, and that is
    // this corner's failure, not testbench trouble.
    // ----------------------------------------------------------------
    begin : bc10
        integer k; reg [DATA_WIDTH-1:0] rd; reg l; reg okc;
        reg accepted; reg bgot; reg bseen; integer pre_err; integer w;
        pulse_reset;
        $display("[BURST 10] BREADY withheld: the response must be held, not dropped or overtaken");
        for (k=0; k<4; k=k+1) do_write(0, 16'h04C0 + (k<<2), 32'h00000000, 4'hF, 1);
        for (k=0; k<4; k=k+1) do_write(0, 16'h0580 + (k<<2), 32'h00000000, 4'hF, 1);
        okc=1'b1; pre_err=errors;

        aw_watch_start;
        s_axi_bready = 1'b0;                   // master never accepts the response
        aw_issue(8'h33, 16'h04C0, 8'd3, 2'b01);
        w_beat(32'hC2000000, 1'b0);
        w_beat(32'hC2000001, 1'b0);
        w_beat(32'hC2000002, 1'b0);
        w_beat(32'hC2000003, 1'b1);            // all beats delivered, B not accepted
        b_wait_quiet(TO, bseen);
        repeat (6) @(negedge clk);             // B must survive a stalled master
        aw_intrude(16'h0580, 6, accepted);     // and must not be overtaken
        s_axi_bready = 1'b1;
        b_wait_quiet(TO, bgot);
        @(negedge clk);
        aw_watch_stop;

        if (!bseen) begin
            $display("  FAIL: no BVALID after the last beat");
            okc=1'b0;
        end
        if (b_hold_viol) begin
            $display("  FAIL: BVALID was withdrawn while BREADY was low, the response is lost");
            okc=1'b0;
        end
        if (accepted || aw_accept_viol) begin
            $display("  FAIL: slave accepted a new AW (0x0580) while the B response was still outstanding");
            okc=1'b0;
        end
        if (aw_ready_viol) begin
            $display("  FAIL: AWREADY was asserted while the write burst still owed beats");
            okc=1'b0;
        end
        if (!bgot) begin
            $display("  FAIL: no BVALID once BREADY was finally asserted, the write never completed");
            okc=1'b0;
        end
        for (k=0; k<4; k=k+1) begin
            do_read(16'h04C0 + (k<<2), rd, l);
            if (rd !== 32'hC2000000 + k) begin
                $display("  FAIL: mem[0x%0h]=0x%0h exp 0x%0h", 16'h04C0 + (k<<2), rd, 32'hC2000000 + k);
                okc=1'b0;
            end
        end
        for (k=0; k<4; k=k+1) begin
            do_read(16'h0580 + (k<<2), rd, l);
            if (rd !== 32'h00000000) begin
                $display("  FAIL: mem[0x%0h]=0x%0h, beats leaked to the intruder's address",
                         16'h0580 + (k<<2), rd);
                okc=1'b0;
            end
        end
        // the write channel must be usable again once the response is taken
        do_write(0, 16'h05C0, 32'hC2FFFFFF, 4'hF, 1);
        do_read (16'h05C0, rd, l);
        if (rd !== 32'hC2FFFFFF) begin
            $display("  FAIL: write channel wedged after the stalled response, mem[0x05C0]=0x%0h", rd);
            okc=1'b0;
        end
        if (errors != pre_err) begin
            $display("  FAIL: %0d channel timeout(s) caused by the withheld BREADY", errors - pre_err);
            errors = pre_err;                  // charged to the corner, not to infra
            okc=1'b0;
        end
        if (!okc) corner_fail = corner_fail + 1;
        else $display("  PASS: response held until BREADY and never overtaken");
    end

    // ----------------------------------------------------------------
    $display("[SUMMARY B] burst corner fails=%0d, infra=%0d", corner_fail, errors);
    if (corner_fail == 0 && errors == 0) begin
        $display("[RESULT B] ALL burst corner tests PASSED");
        corner_pass = 1'b1;
    end else begin
        $display("[RESULT B] burst corner tests FAILED: %0d corner(s), %0d infra error(s)",
                 corner_fail, errors);
        $display("           (a correct implementation passes all corners)");
        corner_pass = 1'b0;
    end

    $display("=========================================================");
    $display("[RESULT] burst edge=%0s  burst corner=%0s",
             edge_pass ? "PASS" : "FAIL", corner_pass ? "PASS" : "FAIL");
    $display("=========================================================");
    done = 1'b1;
end

endmodule
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
