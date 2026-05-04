// HuC6261 priority encoder testbench
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

`timescale 1us / 1ns

module huc6261_prio_tb;

initial begin
    $timeformat(-6, 0, " us", 1);

    $dumpfile("huc6261_prio_tb.fst");
    $dumpvars();
end

//////////////////////////////////////////////////////////////////////

localparam N = 3;
localparam OW = $clog2(N+1);

logic           clk = 1;
logic [2:0]     pri [N];
logic [N-1:0]   key;
logic [OW-1:0]  out;

huc6261_prio #(.N(N)) dut
   (
    .CLK(clk),
    .PRI(pri),
    .KEY(key),
    .OUT(out)
    );

initial forever begin :ckgen
    #0.01 clk = ~clk; // 50 MHz
end

//////////////////////////////////////////////////////////////////////

task get_expected_out(output [OW-1:0] out);
logic [2:0] top_pri;
    out = N;
    top_pri = 0;
    for (int i = 0; i < N; i++) begin
        if (top_pri <= pri[i] && key[i]) begin
            top_pri = pri[i];
            out = i;
        end
    end
endtask

task test_top;
logic [OW-1:0] out_exp;

    for (int i = 0; i < (1<<N); i++) begin
        key <= i;

        @(posedge clk) ;
        get_expected_out(out_exp);
        @(posedge clk) ;
        assert(out == out_exp);
    end
endtask

initial #0 begin
    pri = '{0, 4, 5};
    test_top();
    pri = '{7, 6, 1};
    test_top();
    pri = '{4, 2, 3};
    test_top();

    $finish;
end

endmodule


// Local Variables:
// compile-command: "iverilog -g2012 -grelative-include -s huc6261_prio_tb -o huc6261_prio_tb.vvp huc6261_prio_tb.sv ../huc6261_prio.sv && ./huc6261_prio_tb.vvp -fst"
// End:
