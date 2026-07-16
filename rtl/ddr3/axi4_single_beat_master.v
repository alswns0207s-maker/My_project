`timescale 1ns/1ps
// Simple AXI4 master for one 32-bit read/write beat at a time.
// Intended to connect to MIG AXI slave through AXI interconnect or directly when widths match.
module axi4_single_beat_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire                  cmd_valid,
    output reg                   cmd_ready,
    input  wire                  cmd_write,
    input  wire [ADDR_WIDTH-1:0] cmd_addr,
    input  wire [DATA_WIDTH-1:0] cmd_wdata,
    input  wire [DATA_WIDTH/8-1:0] cmd_wstrb,

    output reg                   rd_valid,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output reg                   busy,
    output reg                   error,

    output wire [ID_WIDTH-1:0]   m_axi_awid,
    output reg  [ADDR_WIDTH-1:0] m_axi_awaddr,
    output wire [7:0]            m_axi_awlen,
    output wire [2:0]            m_axi_awsize,
    output wire [1:0]            m_axi_awburst,
    output wire                  m_axi_awlock,
    output wire [3:0]            m_axi_awcache,
    output wire [2:0]            m_axi_awprot,
    output wire [3:0]            m_axi_awqos,
    output reg                   m_axi_awvalid,
    input  wire                  m_axi_awready,

    output reg  [DATA_WIDTH-1:0] m_axi_wdata,
    output reg  [DATA_WIDTH/8-1:0] m_axi_wstrb,
    output wire                  m_axi_wlast,
    output reg                   m_axi_wvalid,
    input  wire                  m_axi_wready,

    input  wire [ID_WIDTH-1:0]   m_axi_bid,
    input  wire [1:0]            m_axi_bresp,
    input  wire                  m_axi_bvalid,
    output reg                   m_axi_bready,

    output wire [ID_WIDTH-1:0]   m_axi_arid,
    output reg  [ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [7:0]            m_axi_arlen,
    output wire [2:0]            m_axi_arsize,
    output wire [1:0]            m_axi_arburst,
    output wire                  m_axi_arlock,
    output wire [3:0]            m_axi_arcache,
    output wire [2:0]            m_axi_arprot,
    output wire [3:0]            m_axi_arqos,
    output reg                   m_axi_arvalid,
    input  wire                  m_axi_arready,

    input  wire [ID_WIDTH-1:0]   m_axi_rid,
    input  wire [DATA_WIDTH-1:0] m_axi_rdata,
    input  wire [1:0]            m_axi_rresp,
    input  wire                  m_axi_rlast,
    input  wire                  m_axi_rvalid,
    output reg                   m_axi_rready
);
    localparam S_IDLE  = 3'd0;
    localparam S_W_ADDR= 3'd1;
    localparam S_W_RESP= 3'd2;
    localparam S_R_ADDR= 3'd3;
    localparam S_R_DATA= 3'd4;
    reg [2:0] state;

    assign m_axi_awid    = {ID_WIDTH{1'b0}};
    assign m_axi_awlen   = 8'd0;
    assign m_axi_awsize  = (DATA_WIDTH == 32) ? 3'd2 : (DATA_WIDTH == 64) ? 3'd3 : 3'd2;
    assign m_axi_awburst = 2'b01;
    assign m_axi_awlock  = 1'b0;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'd0;
    assign m_axi_wlast   = 1'b1;

    assign m_axi_arid    = {ID_WIDTH{1'b0}};
    assign m_axi_arlen   = 8'd0;
    assign m_axi_arsize  = (DATA_WIDTH == 32) ? 3'd2 : (DATA_WIDTH == 64) ? 3'd3 : 3'd2;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arlock  = 1'b0;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'd0;

    wire unused_bid = ^m_axi_bid;
    wire unused_rid = ^m_axi_rid;
    wire unused_rlast = m_axi_rlast;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            cmd_ready <= 1'b0;
            rd_valid <= 1'b0;
            rd_data <= {DATA_WIDTH{1'b0}};
            busy <= 1'b0;
            error <= 1'b0;
            m_axi_awaddr <= {ADDR_WIDTH{1'b0}};
            m_axi_awvalid <= 1'b0;
            m_axi_wdata <= {DATA_WIDTH{1'b0}};
            m_axi_wstrb <= {DATA_WIDTH/8{1'b0}};
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b0;
            m_axi_araddr <= {ADDR_WIDTH{1'b0}};
            m_axi_arvalid <= 1'b0;
            m_axi_rready <= 1'b0;
        end else begin
            cmd_ready <= 1'b0;
            rd_valid <= 1'b0;
            error <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    cmd_ready <= 1'b1;
                    if (cmd_valid) begin
                        busy <= 1'b1;
                        if (cmd_write) begin
                            m_axi_awaddr <= cmd_addr;
                            m_axi_wdata <= cmd_wdata;
                            m_axi_wstrb <= cmd_wstrb;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wvalid <= 1'b1;
                            m_axi_bready <= 1'b1;
                            state <= S_W_ADDR;
                        end else begin
                            m_axi_araddr <= cmd_addr;
                            m_axi_arvalid <= 1'b1;
                            m_axi_rready <= 1'b1;
                            state <= S_R_ADDR;
                        end
                    end
                end
                S_W_ADDR: begin
                    if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                    if (m_axi_wvalid && m_axi_wready) m_axi_wvalid <= 1'b0;
                    if ((!m_axi_awvalid || m_axi_awready) && (!m_axi_wvalid || m_axi_wready)) begin
                        state <= S_W_RESP;
                    end
                end
                S_W_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        error <= (m_axi_bresp != 2'b00);
                        state <= S_IDLE;
                    end
                end
                S_R_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        state <= S_R_DATA;
                    end
                end
                S_R_DATA: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        rd_data <= m_axi_rdata;
                        rd_valid <= 1'b1;
                        error <= (m_axi_rresp != 2'b00);
                        m_axi_rready <= 1'b0;
                        state <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
