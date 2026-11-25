`timescale 1ns / 1ps


module tb_dht11 ();
    reg clk, reset, start;
    reg dht11_sensor_io, dht11_sensor_io_control;
    reg [39:0]test_data;
    wire [15:0] humidity, temperature;
    wire done, valid, dht11_io;

    assign dht11_io = (dht11_sensor_io_control) ? dht11_sensor_io : 1'bz;

    DHT11_controller U_DHT_CONTROLLER (
        .clk(clk),
        .reset(reset),
        .start(start),
        .humidity(humidity),
        .temperature(temperature),
        .done(done),
        .valid(valid),
        .dht11_io(dht11_io)

    );

    always #5 clk = ~clk;

    integer i;

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        dht11_sensor_io = 1;//0도 무관
        dht11_sensor_io_control = 0; //1왜 안되는 지 생각
        #10;
        reset = 0;
        #10;
        start = 1;
        #(19_000_000); //19msec
        #(30_000);    //30usec
        dht11_sensor_io = 1'b0;
        dht11_sensor_io_control = 1;
        #(80_000);
        test_data = 40'h19 00 19 00 32;
        for(i = 0; i < 40; i = i + 1)begin
        dht11_sensor_io = 1'b1;
        #(80_000);
        dht11_sensor_io = 1'b0;
        //data
        //50usec low
        #(50_000);
        if(test_data [39-i] == 1)
        dht11_sensor_io = 1'b1;
        #(70_000);
    end





endmodule
