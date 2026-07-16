`timescale 1ns/1ps
// Fixed-priority 2-to-1 command arbiter. GFB/YOLO has priority over UDP writes.
module ddr3_cmd_arbiter_2to1(
    input  wire        clk,
    input  wire        rst,

    input  wire        a_valid,
    output wire        a_ready,
    input  wire        a_write,
    input  wire [31:0] a_addr,
    input  wire [31:0] a_wdata,
    input  wire [3:0]  a_wstrb,
    output reg         a_rd_valid,
    output reg  [31:0] a_rd_data,

    input  wire        b_valid,
    output wire        b_ready,
    input  wire        b_write,
    input  wire [31:0] b_addr,
    input  wire [31:0] b_wdata,
    input  wire [3:0]  b_wstrb,
    output reg         b_rd_valid,
    output reg  [31:0] b_rd_data,

    output reg         m_valid,
    input  wire        m_ready,
    output reg         m_write,
    output reg  [31:0] m_addr,
    output reg  [31:0] m_wdata,
    output reg  [3:0]  m_wstrb,
    input  wire        m_rd_valid,
    input  wire [31:0] m_rd_data
);
    reg sel; // last accepted command: 0=a, 1=b
    wire grant_b = b_valid;
    wire grant_a = !b_valid && a_valid;
    assign a_ready = m_ready && m_valid && grant_a;
    assign b_ready = m_ready && m_valid && grant_b;

    always @(*) begin
        if (grant_b) begin
            m_valid = 1'b1;
            m_write = b_write;
            m_addr  = b_addr;
            m_wdata = b_wdata;
            m_wstrb = b_wstrb;
        end else begin
            m_valid = grant_a;
            m_write = a_write;
            m_addr  = a_addr;
            m_wdata = a_wdata;
            m_wstrb = a_wstrb;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            sel <= 1'b0;
            a_rd_valid <= 1'b0; b_rd_valid <= 1'b0;
            a_rd_data <= 32'd0; b_rd_data <= 32'd0;
        end else begin
            a_rd_valid <= 1'b0; b_rd_valid <= 1'b0;
            if (m_valid && m_ready) begin
                sel <= grant_b ? 1'b1 : 1'b0;
            end
            if (m_rd_valid) begin
                if (sel) begin
                    b_rd_valid <= 1'b1;
                    b_rd_data <= m_rd_data;
                end else begin
                    a_rd_valid <= 1'b1;
                    a_rd_data <= m_rd_data;
                end
            end
        end
    end
endmodule
