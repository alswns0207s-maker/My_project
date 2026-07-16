// Insert this wiring inside vc707_mb_oss_eth_bram_top.v after oss_udp_bram_endpoint wires are declared.
// This is a snippet, not a standalone module.

/*
wire [2047:0] yolo_gfb_wdata = 2048'd0; // connect from your YOLO writer if needed
wire [13:0]   yolo_gfb_waddr = 14'd0;
wire          yolo_gfb_we    = 1'b0;
wire [13:0]   yolo_gfb_raddr;            // connect to data_formatter/yolo_head_wrapper o_gb_raddr
wire          yolo_gfb_re;               // connect to o_gb_ren
wire [2047:0] yolo_gfb_rdata;            // connect to i_gb_rdata
wire          yolo_gfb_rvalid;           // connect to i_gb_rvalid
wire          yolo_gfb_busy;
wire          udp_fifo_overflow;
wire          axi_busy, axi_error;

vc707_yolo_ddr3_core #(
    .GFB_BASE_ADDR(32'h0000_0100),
    .GFB_ADDR_WIDTH(14)
) u_yolo_ddr3_core (
    .clk(app_clk_100),
    .rst(app_rst | ~init_calib_complete),

    .udp_bram_addr(eth_bram_addr),
    .udp_bram_din(eth_bram_din),
    .udp_bram_dout(eth_bram_dout),
    .udp_bram_en(eth_bram_en),
    .udp_bram_we(eth_bram_we),
    .udp_fifo_overflow(udp_fifo_overflow),

    .yolo_gfb_wdata(yolo_gfb_wdata),
    .yolo_gfb_waddr(yolo_gfb_waddr),
    .yolo_gfb_we(yolo_gfb_we),
    .yolo_gfb_raddr(yolo_gfb_raddr),
    .yolo_gfb_re(yolo_gfb_re),
    .yolo_gfb_rdata(yolo_gfb_rdata),
    .yolo_gfb_rvalid(yolo_gfb_rvalid),
    .yolo_gfb_busy(yolo_gfb_busy),

    // Connect these m_axi_* ports to MIG 7 Series S_AXI through direct wiring
    // or AXI Interconnect/Data Width Converter.
    .m_axi_awid(mig_s_axi_awid),
    .m_axi_awaddr(mig_s_axi_awaddr),
    .m_axi_awlen(mig_s_axi_awlen),
    .m_axi_awsize(mig_s_axi_awsize),
    .m_axi_awburst(mig_s_axi_awburst),
    .m_axi_awlock(mig_s_axi_awlock),
    .m_axi_awcache(mig_s_axi_awcache),
    .m_axi_awprot(mig_s_axi_awprot),
    .m_axi_awqos(mig_s_axi_awqos),
    .m_axi_awvalid(mig_s_axi_awvalid),
    .m_axi_awready(mig_s_axi_awready),
    .m_axi_wdata(mig_s_axi_wdata),
    .m_axi_wstrb(mig_s_axi_wstrb),
    .m_axi_wlast(mig_s_axi_wlast),
    .m_axi_wvalid(mig_s_axi_wvalid),
    .m_axi_wready(mig_s_axi_wready),
    .m_axi_bid(mig_s_axi_bid),
    .m_axi_bresp(mig_s_axi_bresp),
    .m_axi_bvalid(mig_s_axi_bvalid),
    .m_axi_bready(mig_s_axi_bready),
    .m_axi_arid(mig_s_axi_arid),
    .m_axi_araddr(mig_s_axi_araddr),
    .m_axi_arlen(mig_s_axi_arlen),
    .m_axi_arsize(mig_s_axi_arsize),
    .m_axi_arburst(mig_s_axi_arburst),
    .m_axi_arlock(mig_s_axi_arlock),
    .m_axi_arcache(mig_s_axi_arcache),
    .m_axi_arprot(mig_s_axi_arprot),
    .m_axi_arqos(mig_s_axi_arqos),
    .m_axi_arvalid(mig_s_axi_arvalid),
    .m_axi_arready(mig_s_axi_arready),
    .m_axi_rid(mig_s_axi_rid),
    .m_axi_rdata(mig_s_axi_rdata),
    .m_axi_rresp(mig_s_axi_rresp),
    .m_axi_rlast(mig_s_axi_rlast),
    .m_axi_rvalid(mig_s_axi_rvalid),
    .m_axi_rready(mig_s_axi_rready),
    .axi_busy(axi_busy),
    .axi_error(axi_error)
);
*/
