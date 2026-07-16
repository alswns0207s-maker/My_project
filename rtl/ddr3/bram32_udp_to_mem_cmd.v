`timescale 1ns/1ps
// Captures the existing oss_udp_bram_endpoint 32-bit BRAM-like write pulses
// and converts them to queued memory commands. Readback is provided only for
// debug; the original endpoint assumes fixed BRAM latency, so DDR3 readback is
// not a hard realtime path.
module bram32_udp_to_mem_cmd #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH_LOG2 = 10
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [31:0]           bram_addr,
    input  wire [31:0]           bram_din,
    output reg  [31:0]           bram_dout,
    input  wire                  bram_en,
    input  wire [3:0]            bram_we,

    output reg                   cmd_valid,
    input  wire                  cmd_ready,
    output reg                   cmd_write,
    output reg  [ADDR_WIDTH-1:0] cmd_addr,
    output reg  [DATA_WIDTH-1:0] cmd_wdata,
    output reg  [DATA_WIDTH/8-1:0] cmd_wstrb,
    input  wire                  rd_valid,
    input  wire [DATA_WIDTH-1:0] rd_data,

    output reg                   overflow
);
    localparam FIFO_DEPTH = (1 << FIFO_DEPTH_LOG2);
    reg [ADDR_WIDTH+DATA_WIDTH+DATA_WIDTH/8-1:0] fifo [0:FIFO_DEPTH-1];
    reg [FIFO_DEPTH_LOG2:0] wr_ptr = 0;
    reg [FIFO_DEPTH_LOG2:0] rd_ptr = 0;

    wire fifo_empty = (wr_ptr == rd_ptr);
    wire fifo_full  = (wr_ptr[FIFO_DEPTH_LOG2] != rd_ptr[FIFO_DEPTH_LOG2]) &&
                      (wr_ptr[FIFO_DEPTH_LOG2-1:0] == rd_ptr[FIFO_DEPTH_LOG2-1:0]);

    wire write_fire = bram_en && (bram_we != 4'd0);
    wire read_fire  = bram_en && (bram_we == 4'd0);

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            cmd_valid <= 1'b0;
            cmd_write <= 1'b1;
            cmd_addr <= {ADDR_WIDTH{1'b0}};
            cmd_wdata <= {DATA_WIDTH{1'b0}};
            cmd_wstrb <= {DATA_WIDTH/8{1'b0}};
            bram_dout <= 32'd0;
            overflow <= 1'b0;
        end else begin
            overflow <= 1'b0;
            if (write_fire) begin
                if (!fifo_full) begin
                    fifo[wr_ptr[FIFO_DEPTH_LOG2-1:0]] <= {bram_addr[ADDR_WIDTH-1:0], bram_din, bram_we};
                    wr_ptr <= wr_ptr + 1'b1;
                end else begin
                    overflow <= 1'b1;
                end
            end

            // Debug read path. For full DDR3 readback use the YOLO/GFB path or add a ready/valid read protocol.
            if (rd_valid) bram_dout <= rd_data[31:0];
            else if (read_fire) bram_dout <= 32'h44524459; // "DRDY" placeholder

            if (cmd_valid && cmd_ready) begin
                cmd_valid <= 1'b0;
            end

            if (!cmd_valid && !fifo_empty) begin
                {cmd_addr, cmd_wdata, cmd_wstrb} <= fifo[rd_ptr[FIFO_DEPTH_LOG2-1:0]];
                cmd_write <= 1'b1;
                cmd_valid <= 1'b1;
                rd_ptr <= rd_ptr + 1'b1;
            end
        end
    end
endmodule
