`timescale 1ns / 1ps
//======================================================================
// DESCRIPTION: Combined directed testbench for axi_ram (non-burst).
//
// This file merges the former tb_axi4_ram_edge.v and tb_axi4_ram_corner.v
// into ONE bench sharing one AXI master, one DUT and one set of helpers.
// The two suites keep separate verdicts because they have opposite
// expectations:
//
//   PART A -- EDGE tests   (EXPECTED TO PASS on a correct slave)
//     [E1]  wstrb byte-lane masking       -- only selected lanes update
//     [E2]  zero-strobe write is a no-op  -- wstrb=0 modifies nothing
//     [E3]  ID propagation                -- bid==awid, rid==arid
//     [E6]  single outstanding B, delayed bready
//     [E8]  read/write channel independence
//     [E9]  narrow transfer (awsize<bus)  -- only the addressed lane updates
//     [E10] unaligned address             -- sub-word address hits the lane
//     [E11] exclusive access (awlock=1)   -- slave answers OKAY
//     [E12] sideband awcache/awprot/arprot -- non-default values change nothing
//     [E13] same-ID ordering              -- responses return in issue order
//     [E14] PIPELINE_OUTPUT=1             -- registered R path still round-trips
//     [E15] signal stability              -- data held while valid && !ready
//     [E16] memory survives reset         -- mem[] contents outlive rst
//
//   PART B -- CORNER cases (a correct implementation passes these too)
//     [C1] R-channel backpressure    -> rvalid before mem fetch: stale beat
//     [C2] delayed bready + 2nd write-> single B reg: responses merged
//     [C3] read-before-write invalid -> no valid-bit: unwritten reads OKAY
//
//   edge_pass   = 1 <=> ALL edge tests passed.
//   corner_pass = 1 <=> ALL corner cases behaved correctly.
//
// The edge suite runs first so the corner cases -- which deliberately stall
// channels and may wedge a buggy FSM -- cannot perturb it.  A reset pulse
// separates the two parts; mem[] survives reset (see E16), and corner 3's
// pristine address 0x0800 is touched by nothing else in this file.
//
// Handshake idiom: the DUT registers *ready and deasserts it on the same
// edge it accepts (legal AXI).  A master that samples ready AFTER the
// posedge never sees valid && ready high together.  We therefore DRIVE at a
// negedge, SAMPLE ready/valid at the negedge (where the current cycle's
// values are stable), and let the DUT CONSUMMATE on the next posedge.
//======================================================================
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module tb_axi4_ram_tests (
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

localparam integer TO = 256;   // generic handshake timeout (cycles)

// ---- AXI write address channel ----
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
// ---- AXI write data channel ----
reg  [DATA_WIDTH-1:0] s_axi_wdata;
reg  [STRB_WIDTH-1:0] s_axi_wstrb;
reg                   s_axi_wlast;
reg                   s_axi_wvalid;
wire                  s_axi_wready;
// ---- AXI write response channel ----
wire [ID_WIDTH-1:0]   s_axi_bid;
wire [1:0]            s_axi_bresp;
wire                  s_axi_bvalid;
reg                   s_axi_bready;
// ---- AXI read address channel ----
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
// ---- AXI read data channel ----
wire [ID_WIDTH-1:0]   s_axi_rid;
wire [DATA_WIDTH-1:0] s_axi_rdata;
wire [1:0]            s_axi_rresp;
wire                  s_axi_rlast;
wire                  s_axi_rvalid;
reg                   s_axi_rready;

// TB-controlled reset so a test can reset the DUT mid-sequence.
reg  force_rst;
wire dut_rst = reset | force_rst;

integer errors;       // infrastructure errors (unexpected timeouts)
integer edge_fail;    // edge tests that did not behave correctly
integer corner_fail;  // corner cases that did not behave correctly

// "return" values from the helper tasks (avoids output-port plumbing).
reg [ID_WIDTH-1:0]   last_bid;
reg [DATA_WIDTH-1:0] last_rdata;
reg [ID_WIDTH-1:0]   last_rid;
reg                  last_rlast;
reg [1:0]            last_bresp;
reg [1:0]            last_rresp;

// ---------------------------------------------------------------- DUT
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

// -------------------------------------------------- DUT with PIPELINE_OUTPUT=1
// Shares every master-driven input with `dut`; owns its response channels and
// keeps bready/rready tied high so it never stalls.  Only inspected in E14.
wire [ID_WIDTH-1:0]   p_bid;
wire [1:0]            p_bresp;
wire                  p_bvalid;
wire [ID_WIDTH-1:0]   p_rid;
wire [DATA_WIDTH-1:0] p_rdata;
wire [1:0]            p_rresp;
wire                  p_rlast;
wire                  p_rvalid;
wire                  p_awready, p_wready, p_arready;

axi_ram #(
    .DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH), .ID_WIDTH(ID_WIDTH), .PIPELINE_OUTPUT(1)
) dut_pipe (
    .clk(clk), .rst(dut_rst),
    .s_axi_awid(s_axi_awid),     .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awlen(s_axi_awlen),   .s_axi_awsize(s_axi_awsize),
    .s_axi_awburst(s_axi_awburst), .s_axi_awlock(s_axi_awlock),
    .s_axi_awcache(s_axi_awcache), .s_axi_awprot(s_axi_awprot),
    .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(p_awready),
    .s_axi_wdata(s_axi_wdata),   .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wlast(s_axi_wlast),   .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(p_wready),
    .s_axi_bid(p_bid),           .s_axi_bresp(p_bresp),
    .s_axi_bvalid(p_bvalid),     .s_axi_bready(1'b1),
    .s_axi_arid(s_axi_arid),     .s_axi_araddr(s_axi_araddr),
    .s_axi_arlen(s_axi_arlen),   .s_axi_arsize(s_axi_arsize),
    .s_axi_arburst(s_axi_arburst), .s_axi_arlock(s_axi_arlock),
    .s_axi_arcache(s_axi_arcache), .s_axi_arprot(s_axi_arprot),
    .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(p_arready),
    .s_axi_rid(p_rid),           .s_axi_rdata(p_rdata),
    .s_axi_rresp(p_rresp),       .s_axi_rlast(p_rlast),
    .s_axi_rvalid(p_rvalid),     .s_axi_rready(1'b1)
);

// -------------------------------------------------- E15 stability monitor
// AXI requires payload to stay stable while valid is high and ready is low.
// Fires only when the stall persists across two consecutive posedges, so a
// completing beat (which may legitimately change the payload) is not flagged.
// `mon_en` gates it off for PART B, whose corners stall channels on purpose.
reg                  mon_en;
reg                  stab_fail;
reg                  mon_r_armed, mon_b_armed;
reg [DATA_WIDTH-1:0] mon_rdata;
reg [ID_WIDTH-1:0]   mon_bid;

always @(posedge clk) begin
    if (dut_rst) begin
        stab_fail <= 1'b0; mon_r_armed <= 1'b0; mon_b_armed <= 1'b0;
    end else if (mon_en) begin
        if (mon_r_armed && s_axi_rvalid && !s_axi_rready &&
            (s_axi_rdata !== mon_rdata))
            stab_fail <= 1'b1;
        if (mon_b_armed && s_axi_bvalid && !s_axi_bready &&
            (s_axi_bid !== mon_bid))
            stab_fail <= 1'b1;

        mon_r_armed <= s_axi_rvalid && !s_axi_rready;
        mon_b_armed <= s_axi_bvalid && !s_axi_bready;
        mon_rdata   <= s_axi_rdata;
        mon_bid     <= s_axi_bid;
    end
end

// ====================================================================
// Reusable AXI master helpers (single-beat, non-burst).
// Convention: every task starts and ends just after a posedge.  Results
// land in the module-level last_* regs.
// ====================================================================

// AW + W (+ optional B) single-beat write.  wait_b=1 also accepts the
// response (bready is expected high) and captures bid/bresp; wait_b=0
// leaves B pending for the caller to handle.
task automatic do_write(
    input [ID_WIDTH-1:0]   id,
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data,
    input [STRB_WIDTH-1:0] strb,
    input                  wait_b
);
begin
    do_write_cfg(id, addr, data, strb, 3'd2, 1'b0, 4'b0011, 3'b000, wait_b);
end
endtask

// Configurable write: exposes size / lock / cache / prot to the caller.
task automatic do_write_cfg(
    input [ID_WIDTH-1:0]   id,
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] data,
    input [STRB_WIDTH-1:0] strb,
    input [2:0]            size,
    input                  lock,
    input [3:0]            cache,
    input [2:0]            prot,
    input                  wait_b
);
    integer w;
begin
    // ---- AW ----
    @(negedge clk);
    s_axi_awid    = id;
    s_axi_awaddr  = addr;
    s_axi_awlen   = 8'd0;
    s_axi_awsize  = size;
    s_axi_awburst = 2'b01;  // INCR
    s_axi_awlock  = lock;
    s_axi_awcache = cache;
    s_axi_awprot  = prot;
    s_axi_awvalid = 1'b1;
    w = 0;
    while (!s_axi_awready && w < TO) begin @(negedge clk); w = w + 1; end
    if (!s_axi_awready) begin
        $display("  TIMEOUT: AW handshake failed addr=0x%0h t=%0t", addr, $time);
        errors = errors + 1;
    end
    @(negedge clk);          // cross the latching posedge
    s_axi_awvalid = 1'b0;

    // ---- W ----
    s_axi_wdata  = data;
    s_axi_wstrb  = strb;
    s_axi_wlast  = 1'b1;
    s_axi_wvalid = 1'b1;
    w = 0;
    while (!s_axi_wready && w < TO) begin @(negedge clk); w = w + 1; end
    if (!s_axi_wready) begin
        $display("  TIMEOUT: W handshake failed addr=0x%0h t=%0t", addr, $time);
        errors = errors + 1;
    end
    @(negedge clk);          // cross the latching posedge
    s_axi_wvalid = 1'b0;
    s_axi_wlast  = 1'b0;

    // ---- B (optional) ----
    if (wait_b) begin
        w = 0;
        while (!s_axi_bvalid && w < TO) begin @(negedge clk); w = w + 1; end
        if (!s_axi_bvalid) begin
            $display("  TIMEOUT: BVALID not seen addr=0x%0h t=%0t", addr, $time);
            errors   = errors + 1;
            last_bid = {ID_WIDTH{1'bx}};
            last_bresp = 2'bxx;
        end else begin
            last_bid   = s_axi_bid;
            last_bresp = s_axi_bresp;
        end
        @(negedge clk);      // cross the posedge that consummates B
    end
end
endtask

// Single-beat read with rready held high; captures rdata/rid/rlast/rresp.
task automatic do_read(
    input [ID_WIDTH-1:0]   id,
    input [ADDR_WIDTH-1:0] addr
);
begin
    do_read_cfg(id, addr, 3'd2, 1'b0, 4'b0011, 3'b000);
end
endtask

task automatic do_read_cfg(
    input [ID_WIDTH-1:0]   id,
    input [ADDR_WIDTH-1:0] addr,
    input [2:0]            size,
    input                  lock,
    input [3:0]            cache,
    input [2:0]            prot
);
    integer w;
begin
    s_axi_rready = 1'b1;
    @(negedge clk);
    s_axi_arid    = id;
    s_axi_araddr  = addr;
    s_axi_arlen   = 8'd0;
    s_axi_arsize  = size;
    s_axi_arburst = 2'b01;
    s_axi_arlock  = lock;
    s_axi_arcache = cache;
    s_axi_arprot  = prot;
    s_axi_arvalid = 1'b1;
    w = 0;
    while (!s_axi_arready && w < TO) begin @(negedge clk); w = w + 1; end
    if (!s_axi_arready) begin
        $display("  TIMEOUT: AR handshake failed addr=0x%0h t=%0t", addr, $time);
        errors = errors + 1;
    end
    @(negedge clk);          // cross the latching posedge -> RDATA
    s_axi_arvalid = 1'b0;

    // rready is high; wait for the beat (sample at negedge).
    w = 0;
    while (!s_axi_rvalid && w < TO) begin @(negedge clk); w = w + 1; end
    if (!s_axi_rvalid) begin
        $display("  TIMEOUT: RVALID not seen addr=0x%0h t=%0t", addr, $time);
        errors = errors + 1;
        last_rdata = {DATA_WIDTH{1'bx}};
        last_rid   = {ID_WIDTH{1'bx}};
        last_rlast = 1'bx;
        last_rresp = 2'bxx;
    end else begin
        last_rdata = s_axi_rdata;   // stable this cycle
        last_rid   = s_axi_rid;
        last_rlast = s_axi_rlast;
        last_rresp = s_axi_rresp;
    end
    @(negedge clk);          // cross the posedge that consummates R
end
endtask

// ====================================================================
// Test sequence: PART A (edge) then PART B (corner)
// ====================================================================
integer w, bcount, k;

initial begin
    // Defaults
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
    mon_en=1'b1;
    errors=0; edge_fail=0; corner_fail=0;
    done=1'b0; edge_pass=1'b0; corner_pass=1'b0;

    @(negedge reset);
    repeat (5) @(posedge clk);

    $display("====================================================");
    $display("PART A: EDGE / regression tests (EXPECT ALL TO PASS)");
    $display("====================================================");

    // ----------------------------------------------------------------
    // E1: wstrb byte-lane masking. Clear 0x0300, then write 0xAABBCCDD
    // with strb=4'b0101 (byte lanes 0 and 2). Only those lanes update:
    // expect 0x00BB00DD.
    // ----------------------------------------------------------------
    $display("[E1] wstrb byte-lane masking (EXPECT PASS)");
    s_axi_bready = 1'b1;
    do_write(0, 16'h0300, 32'h00000000, 4'hF, 1'b1);
    do_write(0, 16'h0300, 32'hAABBCCDD, 4'b0101, 1'b1);
    do_read (0, 16'h0300);
    if (last_rdata !== 32'h00BB00DD) begin
        $display("  FAIL: got 0x%0h expected 0x00BB00DD", last_rdata);
        edge_fail = edge_fail + 1;
    end else $display("  PASS: only strobed lanes updated");

    // ----------------------------------------------------------------
    // E2: zero-strobe write is a no-op. Seed a value, write over it with
    // wstrb=0, expect the original value untouched.
    // ----------------------------------------------------------------
    $display("[E2] zero-strobe write is a no-op (EXPECT PASS)");
    do_write(0, 16'h0304, 32'h12345678, 4'hF, 1'b1);
    do_write(0, 16'h0304, 32'hFFFFFFFF, 4'h0, 1'b1);
    do_read (0, 16'h0304);
    if (last_rdata !== 32'h12345678) begin
        $display("  FAIL: got 0x%0h expected 0x12345678 (strb=0 must not write)", last_rdata);
        edge_fail = edge_fail + 1;
    end else $display("  PASS: wstrb=0 modified nothing");

    // ----------------------------------------------------------------
    // E3: ID propagation. bid must echo awid, rid must echo arid.
    // ----------------------------------------------------------------
    $display("[E3] ID propagation bid==awid, rid==arid (EXPECT PASS)");
    do_write(8'h3C, 16'h0308, 32'hCAFEBABE, 4'hF, 1'b1);
    do_read (8'h5A, 16'h0308);
    if (last_bid !== 8'h3C) begin
        $display("  FAIL: bid=0x%0h expected 0x3C", last_bid); edge_fail = edge_fail + 1;
    end else if (last_rid !== 8'h5A) begin
        $display("  FAIL: rid=0x%0h expected 0x5A", last_rid); edge_fail = edge_fail + 1;
    end else $display("  PASS: bid/rid echoed correctly");

    // ----------------------------------------------------------------
    // E6: a single outstanding write with delayed bready gets exactly ONE
    // B response with the correct bid (contrast corner 2, which uses TWO).
    // ----------------------------------------------------------------
    $display("[E6] single outstanding B, delayed bready (EXPECT PASS)");
    s_axi_bready = 1'b0;
    do_write(8'h77, 16'h0320, 32'h5A5A0006, 4'hF, 1'b0);
    w=0; while(!s_axi_bvalid && w<TO) begin @(negedge clk); w=w+1; end
    if (!s_axi_bvalid) begin
        $display("  FAIL: BVALID never asserted"); edge_fail = edge_fail + 1;
    end else if (s_axi_bid !== 8'h77) begin
        $display("  FAIL: bid=0x%0h expected 0x77", s_axi_bid); edge_fail = edge_fail + 1;
    end else begin
        @(negedge clk); s_axi_bready = 1'b1;
        bcount=0;
        for (w=0; w<32; w=w+1) begin
            if (s_axi_bvalid && s_axi_bready) bcount = bcount + 1;
            @(negedge clk);
        end
        if (bcount != 1) begin
            $display("  FAIL: saw %0d B handshakes, expected 1", bcount);
            edge_fail = edge_fail + 1;
        end else begin
            do_read(0, 16'h0320);
            if (last_rdata !== 32'h5A5A0006) begin
                $display("  FAIL: data=0x%0h expected 0x5A5A0006", last_rdata);
                edge_fail = edge_fail + 1;
            end else $display("  PASS: one response, correct bid, data stored");
        end
    end
    s_axi_bready = 1'b1;

    // ----------------------------------------------------------------
    // E8: read/write channel independence. Pre-write H, then start a
    // write to G and leave its B pending (bready low). A read of H must
    // still complete correctly while the write response is outstanding.
    // ----------------------------------------------------------------
    $display("[E8] read/write channel independence (EXPECT PASS)");
    s_axi_bready = 1'b1;
    do_write(0, 16'h0330, 32'h4448_0008, 4'hF, 1'b1);       // H
    s_axi_bready = 1'b0;
    do_write(0, 16'h0334, 32'h4747_0008, 4'hF, 1'b0);       // G, B left pending
    do_read(0, 16'h0330);                                   // read H with G's B pending
    if (last_rdata !== 32'h44480008) begin
        $display("  FAIL: read H got 0x%0h expected 0x44480008 (blocked by pending B?)", last_rdata);
        edge_fail = edge_fail + 1;
    end else begin
        @(negedge clk); s_axi_bready = 1'b1;           // drain G's response
        w=0; while(s_axi_bvalid && w<TO) begin @(negedge clk); w=w+1; end
        do_read(0, 16'h0334);
        if (last_rdata !== 32'h47470008) begin
            $display("  FAIL: read G got 0x%0h expected 0x47470008", last_rdata);
            edge_fail = edge_fail + 1;
        end else $display("  PASS: read served while write response pending");
    end
    s_axi_bready = 1'b1;

    // ----------------------------------------------------------------
    // E9: narrow transfer. awsize=0 (one byte per beat) with wstrb selecting
    // lane 1 only. The other three lanes of the word must be untouched.
    // ----------------------------------------------------------------
    $display("[E9] narrow transfer awsize=0 (EXPECT PASS)");
    do_write(0, 16'h0340, 32'hFFFF_FFFF, 4'hF, 1'b1);
    do_write_cfg(0, 16'h0341, 32'h0000_A500, 4'b0010, 3'd0, 1'b0, 4'b0011, 3'd0, 1'b1);
    do_read(0, 16'h0340);
    if (last_rdata !== 32'hFFFFA5FF) begin
        $display("  FAIL: got 0x%0h expected 0xFFFFA5FF", last_rdata);
        edge_fail = edge_fail + 1;
    end else $display("  PASS: only the addressed lane changed");

    // ----------------------------------------------------------------
    // E10: unaligned address. Byte address 0x0346 sits in word 0x0344,
    // lane 2. Writing it must leave the rest of that word alone.
    // ----------------------------------------------------------------
    $display("[E10] unaligned address (EXPECT PASS)");
    do_write(0, 16'h0344, 32'h1111_1111, 4'hF, 1'b1);
    do_write_cfg(0, 16'h0346, 32'h00CC_0000, 4'b0100, 3'd0, 1'b0, 4'b0011, 3'd0, 1'b1);
    do_read(0, 16'h0344);
    if (last_rdata !== 32'h11CC1111) begin
        $display("  FAIL: got 0x%0h expected 0x11CC1111", last_rdata);
        edge_fail = edge_fail + 1;
    end else $display("  PASS: unaligned byte hit the right lane");

    // ----------------------------------------------------------------
    // E11: exclusive access. A slave with no exclusive support must answer
    // OKAY (2'b00), never EXOKAY (2'b01).
    // ----------------------------------------------------------------
    $display("[E11] exclusive access awlock=1 (EXPECT PASS)");
    do_write_cfg(8'h5A, 16'h0348, 32'hE0E0_0001, 4'hF, 3'd2, 1'b1, 4'b0011, 3'd0, 1'b1);
    do_read_cfg(8'h5A, 16'h0348, 3'd2, 1'b1, 4'b0011, 3'd0);
    if (last_bresp !== 2'b00 || last_rresp !== 2'b00) begin
        $display("  FAIL: bresp=0x%0h rresp=0x%0h, expected OKAY on both",
                 last_bresp, last_rresp);
        edge_fail = edge_fail + 1;
    end else if (last_rdata !== 32'hE0E00001) begin
        $display("  FAIL: locked round-trip got 0x%0h", last_rdata);
        edge_fail = edge_fail + 1;
    end else $display("  PASS: OKAY returned, data round-tripped");

    // ----------------------------------------------------------------
    // E12: sideband signals. awcache/awprot/arprot at non-default values
    // must not change behaviour -- this slave ignores them.
    // ----------------------------------------------------------------
    $display("[E12] sideband awcache/awprot/arprot (EXPECT PASS)");
    do_write_cfg(0, 16'h034C, 32'hCAFE_0002, 4'hF, 3'd2, 1'b0, 4'hF, 3'b111, 1'b1);
    do_read_cfg(0, 16'h034C, 3'd2, 1'b0, 4'hF, 3'b111);
    if (last_rdata !== 32'hCAFE0002) begin
        $display("  FAIL: got 0x%0h expected 0xCAFE0002", last_rdata);
        edge_fail = edge_fail + 1;
    end else $display("  PASS: sideband values ignored as expected");

    // ----------------------------------------------------------------
    // E13: same-ID ordering. Two writes then two reads sharing one ID must
    // come back in issue order with that ID.
    // ----------------------------------------------------------------
    $display("[E13] same-ID ordering (EXPECT PASS)");
    do_write(8'h33, 16'h0350, 32'h0000_1111, 4'hF, 1'b1);
    if (last_bid !== 8'h33) begin
        $display("  FAIL: first bid=0x%0h expected 0x33", last_bid);
        edge_fail = edge_fail + 1;
    end
    do_write(8'h33, 16'h0354, 32'h0000_2222, 4'hF, 1'b1);
    if (last_bid !== 8'h33) begin
        $display("  FAIL: second bid=0x%0h expected 0x33", last_bid);
        edge_fail = edge_fail + 1;
    end
    do_read(8'h33, 16'h0350);
    if (last_rid !== 8'h33 || last_rdata !== 32'h00001111) begin
        $display("  FAIL: first read rid=0x%0h data=0x%0h", last_rid, last_rdata);
        edge_fail = edge_fail + 1;
    end
    do_read(8'h33, 16'h0354);
    if (last_rid !== 8'h33 || last_rdata !== 32'h00002222) begin
        $display("  FAIL: second read rid=0x%0h data=0x%0h", last_rid, last_rdata);
        edge_fail = edge_fail + 1;
    end else $display("  PASS: same-ID responses in order");

    // ----------------------------------------------------------------
    // E14: PIPELINE_OUTPUT=1. dut_pipe sees identical stimulus; its R path
    // carries an extra register stage. Same data must come back.
    // ----------------------------------------------------------------
    $display("[E14] PIPELINE_OUTPUT=1 round-trip (EXPECT PASS)");
    do_write(8'h77, 16'h0358, 32'h9ABC_DEF0, 4'hF, 1'b1);
    s_axi_rready = 1'b1;
    @(negedge clk);
    s_axi_arid=8'h77; s_axi_araddr=16'h0358; s_axi_arlen=0; s_axi_arsize=3'd2;
    s_axi_arburst=2'b01; s_axi_arlock=0; s_axi_arcache=4'b0011; s_axi_arprot=0;
    s_axi_arvalid=1'b1;
    w=0; while(!p_arready && w<TO) begin @(negedge clk); w=w+1; end
    if(!p_arready) begin $display("  TIMEOUT: pipe AR"); errors=errors+1; end
    @(negedge clk); s_axi_arvalid=1'b0;
    w=0; while(!p_rvalid && w<TO) begin @(negedge clk); w=w+1; end
    if(!p_rvalid) begin
        $display("  FAIL: pipelined R never arrived"); edge_fail = edge_fail + 1;
    end else if (p_rdata !== 32'h9ABCDEF0 || p_rid !== 8'h77 || p_rlast !== 1'b1) begin
        $display("  FAIL: pipe data=0x%0h rid=0x%0h rlast=%0b",
                 p_rdata, p_rid, p_rlast);
        edge_fail = edge_fail + 1;
    end else $display("  PASS: registered R path round-trips");
    @(negedge clk);

    // ----------------------------------------------------------------
    // E15: signal stability. Report the passive monitor that has been
    // watching R and B payloads under backpressure since reset.
    // ----------------------------------------------------------------
    $display("[E15] payload stability under backpressure (EXPECT PASS)");
    if (stab_fail) begin
        $display("  FAIL: payload changed while valid was high and ready low");
        edge_fail = edge_fail + 1;
    end else $display("  PASS: R/B payloads held stable while stalled");

    // ----------------------------------------------------------------
    // E16: memory survives reset. Write a word, pulse reset, read it back.
    // ----------------------------------------------------------------
    $display("[E16] memory contents survive reset (EXPECT PASS)");
    do_write(0, 16'h035C, 32'h5EED_5EED, 4'hF, 1'b1);
    @(negedge clk); force_rst = 1'b1;
    repeat (3) @(negedge clk);
    force_rst = 1'b0;
    repeat (3) @(negedge clk);
    do_read(0, 16'h035C);
    if (last_rdata !== 32'h5EED5EED) begin
        $display("  FAIL: got 0x%0h expected 0x5EED5EED after reset", last_rdata);
        edge_fail = edge_fail + 1;
    end else $display("  PASS: mem[] outlived reset");

    // ----------------------------------------------------------------
    $display("[SUMMARY A] edge fails=%0d, infra=%0d", edge_fail, errors);
    if (edge_fail == 0 && errors == 0) begin
        $display("[RESULT A] ALL edge tests PASSED");
        edge_pass = 1'b1;
    end else begin
        $display("[RESULT A] edge tests FAILED: %0d edge, %0d infra", edge_fail, errors);
        edge_pass = 1'b0;
    end

    // ================================================================
    // PART B.  The corner cases stall channels on purpose, so the E15
    // stability monitor is parked and a reset separates them from PART A.
    // mem[] survives reset (E16), and 0x0800 stays pristine for corner 3.
    // `errors` restarts here so PART A's infra count is not double-judged.
    // ================================================================
    mon_en = 1'b0;
    errors = 0;
    @(negedge clk); force_rst = 1'b1;
    repeat (3) @(negedge clk);
    force_rst = 1'b0;
    repeat (5) @(negedge clk);
    s_axi_bready = 1'b1; s_axi_rready = 1'b1;

    $display("====================================================");
    $display("PART B: CORNER cases (a correct implementation passes these too)");
    $display("====================================================");

    // ----------------------------------------------------------------
    // CORNER 1: R-channel backpressure.
    // Prime rdata_reg with DY, then read X while holding rready low for
    // a few cycles. A correct slave delivers exactly one beat = DX with
    // rlast=1. The bug: rvalid asserts before mem is fetched, so the
    // first accepted beat is the stale DY with rlast=0.
    // ----------------------------------------------------------------
    begin : corner1
        reg [DATA_WIDTH-1:0] DX, DY, cap_data;
        reg cap_last, got;
        integer cw, drain;
        DX = 32'hAAAA1111;
        DY = 32'h5555EEEE;
        $display("[CORNER 1] R-channel backpressure (EXPECT PASS)");
        do_write(0, 16'h0040, DY, 4'hF, 1'b1);
        do_write(0, 16'h0044, DX, 4'hF, 1'b1);
        do_read (0, 16'h0040);              // leaves rdata_reg = DY

        // AR for X = 0x0044
        @(negedge clk);
        s_axi_arid=0; s_axi_araddr=16'h0044; s_axi_arlen=0; s_axi_arsize=2;
        s_axi_arburst=2'b01; s_axi_arlock=0; s_axi_arcache=4'b0011;
        s_axi_arprot=0; s_axi_arvalid=1;
        cw=0;
        while (!s_axi_arready && cw<TO) begin @(negedge clk); cw=cw+1; end
        @(negedge clk); s_axi_arvalid=0;   // crossed posedge -> RDATA

        // Hold rready low across the first RDATA cycle(s).
        s_axi_rready=1'b0;
        repeat (3) @(negedge clk);

        // Now accept; capture the FIRST beat the slave forces on us.
        s_axi_rready=1'b1;
        got=1'b0; cap_data={DATA_WIDTH{1'bx}}; cap_last=1'bx; cw=0;
        while (!s_axi_rvalid && cw<TO) begin @(negedge clk); cw=cw+1; end
        if (s_axi_rvalid) begin
            cap_data = s_axi_rdata;
            cap_last = s_axi_rlast;
            got = 1'b1;
        end
        @(negedge clk);   // cross posedge that consummates the first beat
        // Drain any further beats so the DUT returns to IDLE.
        drain=0;
        while (!cap_last && drain<TO) begin
            if (s_axi_rvalid && s_axi_rready) cap_last = s_axi_rlast;
            @(negedge clk);
            drain=drain+1;
        end

        if (!got) begin
            $display("  FAIL: never received a read beat");
            corner_fail = corner_fail + 1;
        end else if (cap_data !== DX || cap_last !== 1'b1) begin
            $display("  FAIL: first beat data=0x%0h last=%0b (expected 0x%0h last=1)",
                     cap_data, cap_last, DX);
            corner_fail = corner_fail + 1;
        end else begin
            $display("  PASS: single correct beat under backpressure");
        end
    end

    // ----------------------------------------------------------------
    // CORNER 2: delayed bready with a second outstanding write.
    // Hold bready low, complete write1 (id=1) through wlast, then issue
    // write2 (id=2) while write1's B is still pending. Raise bready and
    // count responses: a correct slave owes TWO B's. The bug collapses
    // them into ONE (single bvalid/bid register).
    // ----------------------------------------------------------------
    begin : corner2
        reg [DATA_WIDTH-1:0] D1, D2;
        integer cbcount, cw;
        D1 = 32'hDEAD0001; D2 = 32'hDEAD0002;
        $display("[CORNER 2] delayed bready + 2nd write (EXPECT PASS)");
        s_axi_bready = 1'b0;                 // do not accept responses yet
        do_write(8'd1, 16'h0100, D1, 4'hF, 1'b0);
        do_write(8'd2, 16'h0104, D2, 4'hF, 1'b0);

        // Now accept and count distinct B handshakes over a window.
        // With bready held high, each pending response is consummated on
        // one posedge, so it is visible at exactly one negedge -> counting
        // negedges where bvalid is high counts responses.
        @(negedge clk);
        s_axi_bready = 1'b1;
        cbcount=0;
        for (cw=0; cw<TO; cw=cw+1) begin
            if (s_axi_bvalid && s_axi_bready) cbcount = cbcount + 1;
            @(negedge clk);
        end
        if (cbcount != 2) begin
            $display("  FAIL: saw %0d write responses, expected 2 (B merged)", cbcount);
            corner_fail = corner_fail + 1;
        end else begin
            $display("  PASS: both write responses delivered");
        end

        // Data itself should be stored regardless.
        do_read(0, 16'h0100);
        if (last_rdata !== D1) begin
            $display("  NOTE: X1 data wrong got=0x%0h exp=0x%0h", last_rdata, D1);
            corner_fail = corner_fail + 1;
        end
        do_read(0, 16'h0104);
        if (last_rdata !== D2) begin
            $display("  NOTE: X2 data wrong got=0x%0h exp=0x%0h", last_rdata, D2);
            corner_fail = corner_fail + 1;
        end
    end

    // ----------------------------------------------------------------
    // CORNER 3: a read of a never-written location is not flagged invalid.
    // The RAM zero-initialises mem[], so a read of a pristine address
    // returns 0x0 with rresp=OKAY -- indistinguishable from a location that
    // was deliberately written to 0. There is no valid-bit tracking, so
    // "no data written here yet" cannot be signalled. AXI's only channel
    // for "this data is not valid" is rresp=SLVERR (2'b10) (or DECERR
    // 2'b11); a guarded slave returns that for an unwritten address. This
    // DUT hardwires rresp=2'b00, so it always claims OKAY.
    //
    // Address 0x0800 is pristine -- touched by no other test in this file.
    // Expected (guarded slave): rresp != OKAY on the beat.
    // DUT: rresp == OKAY  ->  FAIL (the missing guard).
    // ----------------------------------------------------------------
    begin : corner3
        reg [ADDR_WIDTH-1:0] PA;
        reg [DATA_WIDTH-1:0] cap_data;
        reg [1:0]            cap_resp;
        reg                  cap_last, got;
        integer cw;
        PA = 16'h0800;
        $display("[CORNER 3] read-before-write not flagged invalid (EXPECT PASS)");

        // AR for the pristine address (single beat, rready held high).
        s_axi_rready = 1'b1;
        @(negedge clk);
        s_axi_arid=0; s_axi_araddr=PA; s_axi_arlen=0; s_axi_arsize=2;
        s_axi_arburst=2'b01; s_axi_arlock=0; s_axi_arcache=4'b0011;
        s_axi_arprot=0; s_axi_arvalid=1;
        cw=0;
        while (!s_axi_arready && cw<TO) begin @(negedge clk); cw=cw+1; end
        if (!s_axi_arready) begin
            $display("  TIMEOUT: AR handshake failed addr=0x%0h t=%0t", PA, $time);
            errors = errors + 1;
        end
        @(negedge clk); s_axi_arvalid=0;   // crossed posedge -> RDATA

        // Capture the beat and, crucially, its response code.
        got=1'b0; cap_data={DATA_WIDTH{1'bx}}; cap_resp=2'bxx; cap_last=1'bx; cw=0;
        while (!s_axi_rvalid && cw<TO) begin @(negedge clk); cw=cw+1; end
        if (s_axi_rvalid) begin
            cap_data = s_axi_rdata;
            cap_resp = s_axi_rresp;
            cap_last = s_axi_rlast;
            got = 1'b1;
        end else begin
            $display("  TIMEOUT: RVALID not seen addr=0x%0h t=%0t", PA, $time);
            errors = errors + 1;
        end
        @(negedge clk);   // consummate the beat

        if (!got) begin
            $display("  FAIL: never received a read beat");
            corner_fail = corner_fail + 1;
        end else if (cap_resp === 2'b00) begin
            $display("  FAIL: unwritten addr 0x%0h read back OKAY (rresp=0x%0h data=0x%0h); no invalid-data guard",
                     PA, cap_resp, cap_data);
            corner_fail = corner_fail + 1;
        end else begin
            $display("  PASS: unwritten read flagged invalid (rresp=0x%0h)", cap_resp);
        end
    end

    // ----------------------------------------------------------------
    // Summaries
    // ----------------------------------------------------------------
    $display("[SUMMARY B] corner fails=%0d, infra=%0d", corner_fail, errors);
    if (corner_fail == 0 && errors == 0) begin
        $display("[RESULT B] ALL corner tests PASSED");
        corner_pass = 1'b1;
    end else begin
        $display("[RESULT B] corner tests FAILED: %0d corner(s), %0d infra error(s)",
                 corner_fail, errors);
        corner_pass = 1'b0;
    end

    $display("====================================================");
    $display("[RESULT] edge=%0s  corner=%0s",
             edge_pass ? "PASS" : "FAIL", corner_pass ? "PASS" : "FAIL");
    $display("====================================================");
    done = 1'b1;
end

endmodule
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
