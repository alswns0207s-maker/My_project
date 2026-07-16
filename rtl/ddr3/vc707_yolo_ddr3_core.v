`timescale 1ns/1ps
// Core that connects:
//   1) existing UDP endpoint BRAM-like 32-bit port -> DDR3 write queue
//   2) uploaded YOLO GFB-style 2048-bit port -> DDR3 read/write adapter
//   3) shared 32-bit AXI4 master -> MIG AXI slave
module vc707_yolo_ddr3_core #(
    parameter GFB_BASE_ADDR = 32'h0000_0100,
    parameter GFB_ADDR_WIDTH = 14
)(
    input  wire clk,
    input  wire rst,

    // Existing oss_udp_bram_endpoint BRAM-like port
    input  wire [31:0] udp_bram_addr,
    input  wire [31:0] udp_bram_din,
    output wire [31:0] udp_bram_dout,
    input  wire        udp_bram_en,
    input  wire [3:0]  udp_bram_we,
    output wire        udp_fifo_overflow,

    // YOLO global_feature_buffer-style interface
    input  wire [2047:0] yolo_gfb_wdata,
    input  wire [GFB_ADDR_WIDTH-1:0] yolo_gfb_waddr,
    input  wire        yolo_gfb_we,
    input  wire [GFB_ADDR_WIDTH-1:0] yolo_gfb_raddr,
    input  wire        yolo_gfb_re,
    output wire [2047:0] yolo_gfb_rdata,
    output wire        yolo_gfb_rvalid,
    output wire        yolo_gfb_busy,

    // AXI4 master toward MIG AXI slave
    output wire [3:0]  m_axi_awid,
    output wire [31:0] m_axi_awaddr,
    output wire [7:0]  m_axi_awlen,
    output wire [2:0]  m_axi_awsize,
    output wire [1:0]  m_axi_awburst,
    output wire        m_axi_awlock,
    output wire [3:0]  m_axi_awcache,
    output wire [2:0]  m_axi_awprot,
    output wire [3:0]  m_axi_awqos,
    output wire        m_axi_awvalid,
    input  wire        m_axi_awready,
    output wire [31:0] m_axi_wdata,
    output wire [3:0]  m_axi_wstrb,
    output wire        m_axi_wlast,
    output wire        m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [3:0]  m_axi_bid,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output wire        m_axi_bready,
    output wire [3:0]  m_axi_arid,
    output wire [31:0] m_axi_araddr,
    output wire [7:0]  m_axi_arlen,
    output wire [2:0]  m_axi_arsize,
    output wire [1:0]  m_axi_arburst,
    output wire        m_axi_arlock,
    output wire [3:0]  m_axi_arcache,
    output wire [2:0]  m_axi_arprot,
    output wire [3:0]  m_axi_arqos,
    output wire        m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [3:0]  m_axi_rid,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rlast,
    input  wire        m_axi_rvalid,
    output wire        m_axi_rready,

    output wire        axi_busy,
    output wire        axi_error
);
    wire        udp_cmd_valid, udp_cmd_ready, udp_cmd_write;
    wire [31:0] udp_cmd_addr, udp_cmd_wdata;
    wire [3:0]  udp_cmd_wstrb;
    wire        udp_rd_valid;
    wire [31:0] udp_rd_data;

    bram32_udp_to_mem_cmd u_udp_to_cmd (
        .clk(clk), .rst(rst),
        .bram_addr(udp_bram_addr), .bram_din(udp_bram_din), .bram_dout(udp_bram_dout),
        .bram_en(udp_bram_en), .bram_we(udp_bram_we),
        .cmd_valid(udp_cmd_valid), .cmd_ready(udp_cmd_ready), .cmd_write(udp_cmd_write),
        .cmd_addr(udp_cmd_addr), .cmd_wdata(udp_cmd_wdata), .cmd_wstrb(udp_cmd_wstrb),
        .rd_valid(udp_rd_valid), .rd_data(udp_rd_data), .overflow(udp_fifo_overflow)
    );

    wire        gfb_cmd_valid, gfb_cmd_ready, gfb_cmd_write;
    wire [31:0] gfb_cmd_addr, gfb_cmd_wdata;
    wire [3:0]  gfb_cmd_wstrb;
    wire        gfb_rd_valid;
    wire [31:0] gfb_rd_data;

    global_feature_buffer_ddr3_adapter #(
        .DDR_BASE_ADDR(GFB_BASE_ADDR), .ADDR_WIDTH(GFB_ADDR_WIDTH)
    ) u_gfb_ddr3 (
        .clk(clk), .rst(rst),
        .wdata(yolo_gfb_wdata), .waddr(yolo_gfb_waddr), .we(yolo_gfb_we),
        .raddr(yolo_gfb_raddr), .re(yolo_gfb_re),
        .rdata(yolo_gfb_rdata), .rvalid(yolo_gfb_rvalid), .busy(yolo_gfb_busy),
        .cmd_valid(gfb_cmd_valid), .cmd_ready(gfb_cmd_ready), .cmd_write(gfb_cmd_write),
        .cmd_addr(gfb_cmd_addr), .cmd_wdata(gfb_cmd_wdata), .cmd_wstrb(gfb_cmd_wstrb),
        .rd_valid(gfb_rd_valid), .rd_data(gfb_rd_data)
    );

    wire        arb_cmd_valid, arb_cmd_ready, arb_cmd_write;
    wire [31:0] arb_cmd_addr, arb_cmd_wdata;
    wire [3:0]  arb_cmd_wstrb;
    wire        arb_rd_valid;
    wire [31:0] arb_rd_data;

    ddr3_cmd_arbiter_2to1 u_arb (
        .clk(clk), .rst(rst),
        .a_valid(udp_cmd_valid), .a_ready(udp_cmd_ready), .a_write(udp_cmd_write),
        .a_addr(udp_cmd_addr), .a_wdata(udp_cmd_wdata), .a_wstrb(udp_cmd_wstrb),
        .a_rd_valid(udp_rd_valid), .a_rd_data(udp_rd_data),
        .b_valid(gfb_cmd_valid), .b_ready(gfb_cmd_ready), .b_write(gfb_cmd_write),
        .b_addr(gfb_cmd_addr), .b_wdata(gfb_cmd_wdata), .b_wstrb(gfb_cmd_wstrb),
        .b_rd_valid(gfb_rd_valid), .b_rd_data(gfb_rd_data),
        .m_valid(arb_cmd_valid), .m_ready(arb_cmd_ready), .m_write(arb_cmd_write),
        .m_addr(arb_cmd_addr), .m_wdata(arb_cmd_wdata), .m_wstrb(arb_cmd_wstrb),
        .m_rd_valid(arb_rd_valid), .m_rd_data(arb_rd_data)
    );

    axi4_single_beat_master u_axi_master (
        .clk(clk), .rst(rst),
        .cmd_valid(arb_cmd_valid), .cmd_ready(arb_cmd_ready), .cmd_write(arb_cmd_write),
        .cmd_addr(arb_cmd_addr), .cmd_wdata(arb_cmd_wdata), .cmd_wstrb(arb_cmd_wstrb),
        .rd_valid(arb_rd_valid), .rd_data(arb_rd_data), .busy(axi_busy), .error(axi_error),
        .m_axi_awid(m_axi_awid), .m_axi_awaddr(m_axi_awaddr), .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize), .m_axi_awburst(m_axi_awburst), .m_axi_awlock(m_axi_awlock),
        .m_axi_awcache(m_axi_awcache), .m_axi_awprot(m_axi_awprot), .m_axi_awqos(m_axi_awqos),
        .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb), .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_bid(m_axi_bid), .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
        .m_axi_arid(m_axi_arid), .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize), .m_axi_arburst(m_axi_arburst), .m_axi_arlock(m_axi_arlock),
        .m_axi_arcache(m_axi_arcache), .m_axi_arprot(m_axi_arprot), .m_axi_arqos(m_axi_arqos),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rid(m_axi_rid), .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast), .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready)
    );
endmodule
