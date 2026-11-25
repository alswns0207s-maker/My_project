`timescale 1ns / 1ps
`timescale 1ns / 1ps
module tb_practice_oop_ex2();


    //----parent-------------
    class base_packet;
         int id;


         function new(int id);
            this.id = id;
         endfunction
         virtual function void print();
            $display (" 1)base_packet : new runs (id = %d)", id);
         endfunction


    endclass
    //child 
    class eth_packet extends base_packet; //부모로 부터 상속을 받아서 쓰겠다
        bit [47:0] mac_da;
        function new (int id, bit [47:0]da = 0);
            super.new(id); //parent class init초기화
            mac_da = da;
        endfunction

        virtual function void print();
        super.print();
            $display ("2) eth_packet:new runs (da = %012d)", mac_da);
        endfunction
    endclass

    //grand child
    class bad_packet extends eth_packet;
        function new(int id);
            super.new(id);
        endfunction

        virtual function void print();
            $display("3) bad_packet where did id go?");
        endfunction
    endclass


    eth_packet e;
    bad_packet b;

    initial begin
        $display ("[ex02] with super.print() vs without it");
        e = new(7, 48'haabbccddeeff);
        b = new (9);
        $display("A) e.print() ----calls super.print()");
        e.print();
        $display("b) b.print() --calls super,prunt()");
        b.print();
        $finish;

    end




endmodule
