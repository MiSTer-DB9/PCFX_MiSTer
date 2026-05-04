// HuC6261 (NEW Iron Guanyin) Priority Encoder
//
// Copyright (c) 2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

module huc6261_prio
   #(parameter N = 4,
     parameter OW = $clog2(N+1))
   (
    input           CLK,

    // Control inputs
    input [2:0]     PRI [N],

    // Video status inputs
    input [N-1:0]   KEY,

    // Encoder output: 0..(N-1) = top, N = none
    output [OW-1:0] OUT
    );

// Priority channels: one per level
logic [OW-1:0]  psel [8];
logic [7:0]     pkey;

// Final output
logic [OW-1:0]  out;

genvar i;
generate
    for (i = 0; i < 8; i++) begin :demux
        always @* begin
            psel[i] = '0;
            pkey[i] = '0;
            for (int j = 0; j < N; j++)
                if (PRI[j] == i) begin
                    psel[i] |= OW'(j);
                    pkey[i] |= KEY[j];
                end
        end
    end
endgenerate

always @(posedge CLK) begin
    out <= OW'(N);
    for (int i = 0; i < 8; i++) begin :select
        if (pkey[i])
            out <= psel[i];
    end
end

assign OUT = out;

endmodule
