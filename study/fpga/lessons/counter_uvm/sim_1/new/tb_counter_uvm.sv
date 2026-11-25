`timescale 1ns / 1ps

`include "uvm_macros.svh" //define : uvm_*macro
import uvm_pkg::*; //import : UVM package

interface counter_if(
    input bit clk
);
    logic       reset;
    logic       cnt_en;
    logic [7:0] count;

endinterface

//transaction -> seq_item from uvm_sequence_item
class seq_item extends uvm_sequence_item;
    rand bit reset;
    rand bit cnt_en;
    bit [7:0] count;

    function new(string name = "COUNTER_seq_item");
        super.new(name);
    endfunction

    `uvm_object_utils_begin(seq_item)
        `uvm_field_int(reset, UVM_DEFAULT)
        `uvm_field_int(cnt_en, UVM_DEFAULT)
        `uvm_field_int(count, UVM_DEFAULT)
    `uvm_object_utils_end

endclass

// sequence, ( generator )
// randomize, seq_item( transaction object)
class counter_sequence extends uvm_sequence#(seq_item);
    `uvm_object_utils(counter_sequence)

    function new(string name = "counter_sequence");
        super.new(name);
    endfunction

    task body();
        seq_item item;

        // 1) apply reset
        item = seq_item::type_id::create("item");
        start_item(item);
        item.reset  = 1;
        item.cnt_en = 0;
        finish_item(item);

        // 2) release reset, randomize cnt_en for a while
        repeat (30) begin
            item = seq_item::type_id::create("item");
            start_item(item);
            assert(item.randomize() with { reset == 0; });
            finish_item(item);
        end
    endtask
endclass

// driver : seq_item -> interface pin
class driver extends uvm_driver#(seq_item);
    `uvm_component_utils(driver)

    virtual counter_if vif;

    function new(string name = "driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual counter_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "virtual interface not found : vif")
    endfunction

    task run_phase(uvm_phase phase);
        seq_item item;
        forever begin
            seq_item_port.get_next_item(item);
            @(negedge vif.clk);
            vif.reset  <= item.reset;
            vif.cnt_en <= item.cnt_en;
            seq_item_port.item_done();
        end
    endtask
endclass

// monitor : interface pin -> seq_item -> analysis_port
class monitor extends uvm_monitor;
    `uvm_component_utils(monitor)

    virtual counter_if vif;
    uvm_analysis_port#(seq_item) ap;

    function new(string name = "monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual counter_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "virtual interface not found : vif")
        ap = new("ap", this);
    endfunction

    task run_phase(uvm_phase phase);
        seq_item item;
        forever begin
            @(posedge vif.clk);
            item        = seq_item::type_id::create("item");
            item.reset  = vif.reset;
            item.cnt_en = vif.cnt_en;
            item.count  = vif.count;
            ap.write(item);
        end
    endtask
endclass

// agent : driver + sequencer + monitor
class agent extends uvm_agent;
    `uvm_component_utils(agent)

    driver                    drv;
    uvm_sequencer#(seq_item)  sqr;
    monitor                   mon;

    function new(string name = "agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = driver::type_id::create("drv", this);
        sqr = uvm_sequencer#(seq_item)::type_id::create("sqr", this);
        mon = monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

// scoreboard : compare DUT count against expected model
class scoreboard extends uvm_subscriber#(seq_item);
    `uvm_component_utils(scoreboard)

    bit [7:0] expected_count;

    function new(string name = "scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void write(seq_item t);
        if (t.reset) begin
            expected_count = 0;
        end
        else begin
            if (t.count !== expected_count)
                `uvm_error("SCB", $sformatf("MISMATCH exp=%0d act=%0d", expected_count, t.count))
            else
                `uvm_info("SCB", $sformatf("MATCH count=%0d", t.count), UVM_LOW)

            if (t.cnt_en)
                expected_count = expected_count + 1'b1;
        end
    endfunction
endclass

// env : agent + scoreboard
class env extends uvm_env;
    `uvm_component_utils(env)

    agent      agt;
    scoreboard scb;

    function new(string name = "env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = agent::type_id::create("agt", this);
        scb = scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.analysis_export);
    endfunction
endclass

// test : env + sequence start
class test extends uvm_test;
    `uvm_component_utils(test)

    env e;

    function new(string name = "test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        e = env::type_id::create("e", this);
    endfunction

    task run_phase(uvm_phase phase);
        counter_sequence seq;
        phase.raise_objection(this);

        seq = counter_sequence::type_id::create("seq");
        seq.start(e.agt.sqr);

        phase.drop_objection(this);
    endtask
endclass

module tb_counter_uvm();

    bit clk = 0;
    always #5 clk = ~clk;

    counter_if c_if(clk);

    counter DUT (
        .clk    (c_if.clk),
        .reset  (c_if.reset),
        .cnt_en (c_if.cnt_en),
        .count  (c_if.count)
    );

    initial begin
        uvm_config_db#(virtual counter_if)::set(null, "*", "vif", c_if);
        run_test("test");
    end

endmodule
