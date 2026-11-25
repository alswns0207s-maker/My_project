`timescale 1ns / 1ps

module btn_debounce (
    input  clk,
    input  reset,
    input  i_btn,
    output o_btn
);


    reg edge_reg;
    reg [7:0] q_reg;  //8tab shift register SIPO
    wire debounce;  // output of 8 And gate


    //8bit shift register, SIPO
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            q_reg <= 8'h00;
        end else begin
            // q_reg <= {q_reg[6:0], i_btn};
            q_reg <= {i_btn, q_reg[7:1]};
        end
    end


    //8bit input AND gate
assign debounce = &q_reg;

always @(posedge clk, posedge reset) begin

        if (reset) edge_reg <= 1'b0;

        edge_reg <= 8'h00;
        else begin
            edge_reg <=debounce;
        end
end


assign o_btn = debounce &(~edge_reg);

endmodule

reg[$clog2(50)-1:0] counter_reg;
reg     o_1mhz;
always@(posedge clk, posedge reset)begin
    if(reset)begin
        counter_reg <=0;
        o_1mhz <=0;
    end else begin
        counter_reg <= counter_reg + 1;
        if(counter_reg == (50-1))begin
            counter_reg <=0;
            o_1mhz <= ~o_1mhz;
        end
    end
end
always@(posedge o_1mhz, posedge reset)begin
    if(reset)begin
        q_reg <= 8'h00;
    end else begin
        q_reg <= {i_btn, q_reg[7:1]};
    end
end

