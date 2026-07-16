`timescale 1ns/1ps
// Example only: connect uploaded YOLO head modules to DDR3-backed GFB.
// Replace the old global_feature_buffer instance with the yolo_gfb_* signals
// exported by vc707_yolo_ddr3_core.
module yolo_ddr3_connection_example #(
    parameter ADDR_WIDTH = 14,
    parameter GB_BUS_WIDTH = 2048
)(
    input  wire clk,
    input  wire rst_n,

    input  wire start_head,
    input  wire [ADDR_WIDTH-1:0] head_base_addr,
    input  wire [7:0] grid_w,
    input  wire [7:0] grid_h,

    output wire yolo_gfb_re,
    output wire [ADDR_WIDTH-1:0] yolo_gfb_raddr,
    input  wire [GB_BUS_WIDTH-1:0] yolo_gfb_rdata,
    input  wire yolo_gfb_rvalid
);
    // Minimal example using the uploaded data_formatter because it already has i_gb_rvalid.
    wire ready_in = 1'b1;
    wire done;
    wire split_valid;
    wire [47:0] split_data;
    wire [7:0] split_cx, split_cy;
    wire [1:0] split_anchor;

    data_formatter #(
        .GB_BUS_WIDTH(GB_BUS_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)
    ) u_formatter (
        .clk(clk), .rst_n(rst_n), .i_start(start_head),
        .i_base_addr(head_base_addr), .i_grid_w(grid_w), .i_grid_h(grid_h),
        .o_done(done),
        .o_gb_ren(yolo_gfb_re), .o_gb_raddr(yolo_gfb_raddr),
        .i_gb_rdata(yolo_gfb_rdata), .i_gb_rvalid(yolo_gfb_rvalid),
        .ready_in(ready_in), .o_split_valid(split_valid), .o_split_data(split_data),
        .o_split_cx(split_cx), .o_split_cy(split_cy), .o_split_anchor(split_anchor)
    );
endmodule
