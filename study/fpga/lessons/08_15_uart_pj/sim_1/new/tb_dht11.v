`timescale 1ns / 1ps

module tb_dht11_controller;

    reg clk;
    reg reset;
    reg start;
    reg sensor_low;

    reg [39:0] test_data;

    wire [15:0] humidity;
    wire [15:0] temperature;
    wire done;
    wire valid;
    tri dht11_io;

    integer i =0 ;


    // 100MHz clock
    always #5 clk = ~clk;


    // 가짜 DHT11 센서
    // sensor_low = 1 -> LOW
    // sensor_low = 0 -> 선을 놓음 -> pullup 때문에 HIGH
    assign dht11_io = sensor_low ? 1'b0 : 1'bz;

    pullup(dht11_io);


    dht11_controller #(
        .TICK_1US(100)
    ) dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .humidity(humidity),
        .temperature(temperature),
        .done(done),
        .valid(valid),
        .dht11_io(dht11_io)
    );


    // bit 하나 보내기
    task send_bit;
        input bit_value;
        begin

            // LOW 50us
            sensor_low = 1;
            #50_000;

            // HIGH
            sensor_low = 0;

            if (bit_value == 1)
                #70_000;      // 1
            else
                #26_000;      // 0

        end
    endtask


    initial begin

        clk        = 0;
        reset      = 1;
        start      = 0;
        sensor_low = 0;

        // 습도 60%, 온도 25도
        // 3C 00 19 00 55
        test_data = 40'h3C00190055;


        // reset
        #100;
        reset = 0;


        // start
        #100;
        start = 1;

        #20;
        start = 0;


        // SYNC 상태까지 기다림
        wait(dut.state == 2);


        // DHT11 응답
        sensor_low = 1;
        #80_000;

        sensor_low = 0;
        #80_000;


        // DATA가 시작되기 전에 LOW
        sensor_low = 1;

        // DATA_LOW 상태 기다림
        wait(dut.state == 3);


        // 40bit 전송
        // 39번 비트부터 0번 비트까지
        for(i = 39; i >= 0; i = i - 1) begin
            send_bit(test_data[i]);
        end


        // 센서가 선을 놓음
        sensor_low = 0;


        // 완료 기다림
        wait(done == 1);


        #100_000;

        $finish;

    end

endmodule