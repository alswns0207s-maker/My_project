`timescale 1ns / 1ps



interface adder_interface;
    logic [7:0] a, b, s;
    logic c, mode;
endinterface
//-------------------------------------------------------------
class transaction;
    rand bit [7:0] a, b;
    rand bit mode;
    logic [7:0] s;
    logic c;

    constraint in_range {a inside {[1 : 127]};}

endclass
//-------------------------------------------------------------
class generator;

    transaction tr;
    mailbox #(transaction) mbox;  //gen to drive mailbox
    event event2gen;

    function new(mailbox#(transaction) gen2drv_mbox, event event2gen);
        this.mbox = gen2drv_mbox;
        this.event2gen = event2gen;
    endfunction


    task run;
        forever begin
            tr = new;
            tr.randomize();
            mbox.put(tr);
            @(event2gen);
        end
    endtask


endclass
//-------------------------------------------------------------
class driver;
    transaction tr;
    virtual adder_interface adder_vif;
    mailbox #(transaction) mbox;
    event event2gen;
    function new(mailbox#(transaction) gen2drv_mbox, event event2gen,
                 virtual adder_interface adder_vif);
        this.mbox = gen2drv_mbox;
        this.adder_vif = adder_vif;
        this.event2gen = event2gen;
    endfunction
    task run;
        forever begin
            mbox.get(tr);
            adder_vif.a = tr.a;
            adder_vif.b = tr.b;
            adder_vif.mode = tr.mode;
            #10;
            ->event2gen;
        end
    endtask
endclass
//--------------------------------------------------------------------------------

class monitor;
    transaction tr;
    mailbox #(transaction) mbox;
    virtual adder_interface adder_vif;
    function new(mailbox#(transaction) mbox, virtual adder_interface adder_vif);
        this.mbox = mbox;
        this.adder_vif = adder_vif;
    endfunction
    task run;
        forever begin
            tr = new;
            tr.a = adder_vif.a;
            tr.b = adder_vif.b;
            tr.mode = adder_vif.mode;
            tr.s = adder_vif.s;
            tr.c = adder_vif.c;
            mbox.put(tr);
        end
    endtask
endclass

//------------------------------------------------------------------------------------

class scoreboard;
    transaction                  tr;
    mailbox #(transaction)       mbox;
    bit                    [7:0] compare_sum;
    bit                          compare_carry;
    int                          pass_cnt       = 0;
    int                          fail_cnt       = 0;

    function new(mailbox#(transaction) mbox);
        this.mbox = mbox;
    endfunction
    task run;
        forever begin
            mbox.get(tr);
            if (!tr.mode) begin
                {compare_carry, compare_sum} = tr.a + tr.b;
            end else begin
                {compare_carry, compare_sum} = tr.a - tr.b;
            end

            if (compare_sum == tr.s && compare_carry == tr.c) begin
                pass_cnt++;
                $display("%t : scb pass", $time);
            end else begin
                fail_cnt++;
                $display("%t : scb fail, a=%d b=%d mode=%d", $time, tr.a, tr.b,
                         tr.mode);
            end
        end
    endtask
endclass


//--------------------------------------------------------------------------------------
class environment;
    generator gen;
    driver    drv;
    monitor   mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event event2gen;

    function new(virtual adder_interface adder_vif);
        gen2drv_mbox = new;
        mon2scb_mbox = new;

        gen = new(gen2drv_mbox, event2gen);
        drv = new(gen2drv_mbox, event2gen, adder_vif);
        mon = new(mon2scb_mbox, adder_vif);
        scb = new(mon2scb_mbox);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join
    endtask
endclass
//--------------------------------------------------------------------------------------------











//--------------------------------------------------------------------------------------------
module tb_adder ();
    adder_interface adder_if ();
    environment env;

    adder DUT (
        .a(adder_if.a),
        .b(adder_if.b),
        .mode(adder_if.mode),
        .s(adder_if.s),
        .c(adder_if.c)

    );

    initial begin
        env = new(adder_if);
        env.run();
        $stop;
    end

endmodule
