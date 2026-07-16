`timescale 1ns/1ps
// DDR3-backed replacement adapter for the uploaded YOLO global_feature_buffer.
// It preserves the YOLO-side 2048-bit read/write concept, but uses a 32-bit
// command interface toward MIG/AXI. Each GFB address maps to 256 bytes.
module global_feature_buffer_ddr3_adapter #(
    parameter DATA_WIDTH = 2048,
    parameter ADDR_WIDTH = 14,
    parameter DDR_BASE_ADDR = 32'h0000_0100
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [DATA_WIDTH-1:0] wdata,
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire                  we,

    input  wire [ADDR_WIDTH-1:0] raddr,
    input  wire                  re,
    output reg  [DATA_WIDTH-1:0] rdata,
    output reg                   rvalid,
    output wire                  busy,

    output reg                   cmd_valid,
    input  wire                  cmd_ready,
    output reg                   cmd_write,
    output reg  [31:0]           cmd_addr,
    output reg  [31:0]           cmd_wdata,
    output reg  [3:0]            cmd_wstrb,
    input  wire                  rd_valid,
    input  wire [31:0]           rd_data
);
    localparam WORDS_PER_GFB = DATA_WIDTH/32; // 64
    localparam S_IDLE    = 3'd0;
    localparam S_W_SEND  = 3'd1;
    localparam S_R_SEND  = 3'd2;
    localparam S_R_WAIT  = 3'd3;
    localparam S_R_DONE  = 3'd4;

    reg [2:0] state = S_IDLE;
    reg [6:0] idx = 0;
    reg [DATA_WIDTH-1:0] wbuf = 0;
    reg [ADDR_WIDTH-1:0] addr_latched = 0;

    assign busy = (state != S_IDLE);

    wire [31:0] base_byte_addr = DDR_BASE_ADDR + ({18'd0, addr_latched} << 8); // *256

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            idx <= 0;
            wbuf <= 0;
            addr_latched <= 0;
            rdata <= 0;
            rvalid <= 1'b0;
            cmd_valid <= 1'b0;
            cmd_write <= 1'b0;
            cmd_addr <= 32'd0;
            cmd_wdata <= 32'd0;
            cmd_wstrb <= 4'h0;
        end else begin
            rvalid <= 1'b0;
            if (cmd_valid && cmd_ready) cmd_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    idx <= 0;
                    if (we) begin
                        addr_latched <= waddr;
                        wbuf <= wdata;
                        state <= S_W_SEND;
                    end else if (re) begin
                        addr_latched <= raddr;
                        rdata <= 0;
                        state <= S_R_SEND;
                    end
                end
                S_W_SEND: begin
                    if (!cmd_valid) begin
                        cmd_valid <= 1'b1;
                        cmd_write <= 1'b1;
                        cmd_addr  <= base_byte_addr + ({25'd0, idx} << 2);
                        cmd_wdata <= wbuf[idx*32 +: 32];
                        cmd_wstrb <= 4'hf;
                    end else if (cmd_valid && cmd_ready) begin
                        if (idx == WORDS_PER_GFB-1) begin
                            state <= S_IDLE;
                        end else begin
                            idx <= idx + 1'b1;
                        end
                    end
                end
                S_R_SEND: begin
                    if (!cmd_valid) begin
                        cmd_valid <= 1'b1;
                        cmd_write <= 1'b0;
                        cmd_addr  <= base_byte_addr + ({25'd0, idx} << 2);
                        cmd_wdata <= 32'd0;
                        cmd_wstrb <= 4'h0;
                        state <= S_R_WAIT;
                    end
                end
                S_R_WAIT: begin
                    if (rd_valid) begin
                        rdata[idx*32 +: 32] <= rd_data;
                        if (idx == WORDS_PER_GFB-1) begin
                            state <= S_R_DONE;
                        end else begin
                            idx <= idx + 1'b1;
                            state <= S_R_SEND;
                        end
                    end
                end
                S_R_DONE: begin
                    rvalid <= 1'b1;
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
