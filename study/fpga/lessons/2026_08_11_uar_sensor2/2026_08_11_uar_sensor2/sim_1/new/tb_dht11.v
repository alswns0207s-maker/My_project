`timescale 1ns / 1ps


module tb_dht11 ();
    reg clk, reset, start;
    reg dht11_sensor_io, dht11_sensor_io_control;
    reg [39:0]test_data;
    wire [15:0] humidity, temperature;
    wire done, valid, dht11_io;


    DHT11_controller U_DHT11_CONTROLLER(
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
    task testdata_task (output [7:0]o_dht_int, output[7:0]o_dht_deci,
     output[7:0]o_temp_int, output[7:0]o_temp_deci, output[7:0]checksum);
    integer j = 0;
    reg [39:0]test_data; 
    o_dht_int = $random;
    o_dht_deci = $random % 10;
    o_temp_int = $random % 51;
    o_temp_deci = $random % 10;
    checksum = o_dht_int + o_dht_deci + o_temp_int + o_temp_deci;
    test_data = {o_dht_int, o_dht_deci, o_temp_int, o_temp_deci};

    endtask

    integer i;

    initial begin
        clk = 0;
        reset = 1;
        start = 0;
        #10;
        reset = 0;
        #10;
        start = 1;
        #(19_000_000); //19msec
        #(30_000);    //30usec
        dht11_sensor_io = 1'b0;
        #(80_000);
        for(i = 0; i < 40; i = i + 1)begin
        dht11_sensor_io = 1'b1;
        #(80_000);
        dht11_sensor_io = 1'b0;
        //data
        test_data = 40'h11 12 13 14 15;
        //50usec low
        #(50_000);
        if(test_data [39-i] == 1)
        dht11_sensor_io = 1'b1;
        #(70_000);
    end
    $stop;

endmodule
