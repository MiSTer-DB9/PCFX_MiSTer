//
// sdram
// Copyright (c) 2015-2019 Sorgelig
// Copyright (c) 2026 David Hunter
//
// Some parts of SDRAM code used from project:
// http://hamsterworks.co.nz/mediawiki/index.php/Simple_SDRAM_Controller
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

module sdram
    #(parameter CLK_MHZ = 142.8571428)
(
    input             init,        // reset to initialize RAM
    input             clk,         // clock ~100MHz

    inout      [15:0] SDRAM_DQ,    // 16 bit bidirectional data bus
    output reg [12:0] SDRAM_A,     // 13 bit multiplexed address bus
    output            SDRAM_DQML,  // two byte masks
    output            SDRAM_DQMH,  // 
    output reg  [1:0] SDRAM_BA,    // two banks
    output            SDRAM_nCS,   // a single chip select
    output            SDRAM_nWE,   // write enable
    output            SDRAM_nRAS,  // row address select
    output            SDRAM_nCAS,  // columns address select
    output            SDRAM_CKE,   // clock enable
    //output            SDRAM_CLK,   // clock for chip

    input      [26:0] ch1_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
    output reg [31:0] ch1_dout,    // data output to cpu
    input      [31:0] ch1_din,     // data input from cpu
    input             ch1_req,     // request
    input             ch1_rnw,     // 1 - read, 0 - write
    input      [3:0]  ch1_be,
    output reg        ch1_ready,
    output reg        ch1_reqprocessed,
    
    input      [26:0] ch2_addr,    // 25 bit address for 8bit mode. addr[0] = 0 for 16bit mode for correct operations.
    output reg [31:0] ch2_dout,    // data output to cpu
    input      [31:0] ch2_din,     // data input from cpu
    input             ch2_req,     // request
    input             ch2_rnw,     // 1 - read, 0 - write
    output reg        ch2_ready,

    input      [26:0] ch3_addr,
    output reg [31:0] ch3_dout,
    input      [31:0] ch3_din,
    input             ch3_req,
    input             ch3_rnw,
    output reg        ch3_ready
);

// All times in ns are for AS4C32M16SB-7: tCK3 (clk cycle) = 7 ns (143 MHz)
// Parameters are in whole cycles, and assume clk cycle = 1 / CLK_MHZ
function int ns_to_cyc(int ns);
    ns_to_cyc = int'($ceil(CLK_MHZ * ns / 1000.0));
endfunction

localparam TRC_MIN  = ns_to_cyc(63);
localparam TRRD_MIN = ns_to_cyc(14);
localparam TRCD_MIN = ns_to_cyc(21);
localparam TRP_MIN  = ns_to_cyc(21);
localparam TWR_MIN  = ns_to_cyc(14);
localparam TRAS_MIN = ns_to_cyc(42);
localparam TRAS_MAX = ns_to_cyc(120000);

// Burst length = 4
localparam BURST_LENGTH        = 2;
localparam BURST_CODE          = (BURST_LENGTH == 8) ? 3'b011 : (BURST_LENGTH == 4) ? 3'b010 : (BURST_LENGTH == 2) ? 3'b001 : 3'b000;  // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE         = 1'b0;     // 0=sequential, 1=interleaved
localparam CAS_LATENCY         = 3'd2;     // 2 for < 100MHz, 3 for >100MHz
localparam OP_MODE             = 2'b00;    // only 00 (standard operation) allowed
localparam NO_WRITE_BURST      = 1'b1;     // 0= write burst enabled, 1=only single access write
localparam MODE                = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_CODE};

localparam sdram_startup_cycles= 14'd12100;// 100us, plus a little more, @ 100MHz
localparam cycles_per_refresh  = 14'd300;  // (64000*64)/8192-1 Calc'd as (64ms @ 64MHz)/8192 rose
localparam startup_refresh_max = 14'b11111111111111;

// SDRAM commands
wire [2:0] CMD_NOP             = 3'b111;
wire [2:0] CMD_ACTIVE          = 3'b011;
wire [2:0] CMD_READ            = 3'b101;
wire [2:0] CMD_WRITE           = 3'b100;
wire [2:0] CMD_PRECHARGE       = 3'b010;
wire [2:0] CMD_AUTO_REFRESH    = 3'b001;
wire [2:0] CMD_LOAD_MODE       = 3'b000;

reg [13:0] refresh_count = startup_refresh_max - sdram_startup_cycles;
reg  [2:0] command;
reg [15:0] dqout;

// BAnk STate
localparam BAST_IDLE     = 0;
localparam BAST_ACT      = 1;
localparam BAST_ACT_WAIT = 2;
localparam BAST_R_CMD    = 3;
localparam BAST_R_DQM    = 4;
localparam BAST_R        = 5;
localparam BAST_W_CMD    = 6;
localparam BAST_W_CMD_2  = 7;
localparam BAST_W_REC    = 8;
localparam BAST_PRE      = 9;

reg [3:0]  bast [4];
reg [3:0]  bacnt [4];

wire [3:0] bast0 = bast[0];
wire [3:0] bast1 = bast[1];
wire [3:0] bast2 = bast[2];
wire [3:0] bast3 = bast[3];

// Bus Priority Encoder STate
reg [3:0]  bpest; // state
reg [1:0]  bpeba; // bank

localparam STATE_STARTUP = 0;
localparam STATE_WAIT    = 1;
localparam STATE_RW1     = 2;
localparam STATE_RW2     = 3;
localparam STATE_IDLE    = 4;
localparam STATE_IDLE_1  = 5;
localparam STATE_IDLE_2  = 6;
localparam STATE_IDLE_3  = 7;
localparam STATE_IDLE_4  = 8;
localparam STATE_IDLE_5  = 9;

reg        ch1_rq, ch2_rq, ch3_rq;

/* -----\/----- EXCLUDED -----\/-----
always @* begin
reg done;

    done = 0;
    bpest = BAST_IDLE;
    bpeba = 0;

    for (int b = 0; b < 4; b++) begin
        if (!done)
            case (bast[b])
                BAST_IDLE: begin
                    if (b == 0 && (ch1_rq | ch1_req)) begin
                        bpest = BAST_ACT;
                        bpeba = b;
                    end
                end
            endcase
    end
end
 -----/\----- EXCLUDED -----/\----- */
// TODO
assign bpest = bast[0];
assign bpeba = 0;


always @(posedge clk) begin
    for (int b = 0; b < 4; b++) begin
        case (bast[b])
            BAST_IDLE: begin
                if (b == 0 && (ch1_rq | ch1_req))
                    bast[b] <= BAST_ACT;
            end
            BAST_ACT:
                if (bpeba == b) begin
                    bast[b] <= BAST_ACT_WAIT;
                    bacnt[b] <= TRCD_MIN - 2;
                end
            BAST_ACT_WAIT:
                if (bacnt[b] == 0) begin
                    bast[b] <= ch1_rnw ? BAST_R_CMD : BAST_W_CMD;
                end
            BAST_R_CMD:
                if (bpeba == b)
                    bast[b] <= BAST_R_DQM;
            BAST_R_DQM: begin
                bast[b] <= BAST_R;
                bacnt[b] <= BURST_LENGTH - 1;
            end
            BAST_R:
                if (bacnt[b] == 0) begin
                    bast[b] <= BAST_PRE;
                    bacnt[b] <= (TRP_MIN-(BURST_LENGTH-1)) - 1;
                end
            BAST_W_CMD:
                if (bpeba == b)
                    bast[b] <= BAST_W_CMD_2;
            BAST_W_CMD_2: begin
                bast[b] <= BAST_W_REC;
                bacnt[b] <= TWR_MIN - 1;
            end
            BAST_W_REC:
                if (bacnt[b] == 0) begin
                    bast[b] <= BAST_PRE;
                    bacnt[b] <= (TRP_MIN-TWR_MIN) - 1;
                end
            BAST_PRE:
                if (bacnt[b] == 0) begin
                    bast[b] <= BAST_IDLE;
                end
        endcase
    end
end

always @(posedge clk) begin
    reg [CAS_LATENCY+BURST_LENGTH:0] data_ready_delay1, data_ready_delay2, data_ready_delay3;

    reg [12:0] cas_addr;
    reg [31:0] saved_data;
    reg  [3:0] saved_be;
    reg [15:0] dq_reg;
    reg  [3:0] state = STATE_STARTUP;

    reg [1:0] ch;

    

    ch1_rq <= ch1_rq | ch1_req;
    ch2_rq <= ch2_rq | ch2_req;
    ch3_rq <= ch3_rq | ch3_req;

    ch1_ready <= 0;
    ch2_ready <= 0;
    ch3_ready <= 0;
   
    ch1_reqprocessed <= 0;

    refresh_count <= refresh_count+1'b1;

    data_ready_delay1 <= data_ready_delay1>>1;
    data_ready_delay2 <= data_ready_delay2>>1;
    data_ready_delay3 <= data_ready_delay3>>1;

    dq_reg <= SDRAM_DQ;

    if(data_ready_delay1[1]) ch1_dout[15:00] <= dq_reg;
    if(data_ready_delay1[0]) ch1_dout[31:16] <= dq_reg;
    if(data_ready_delay1[0]) ch1_ready <= 1;

    if(data_ready_delay2[1]) ch2_dout[15:00] <= dq_reg;
    if(data_ready_delay2[0]) ch2_dout[31:16] <= dq_reg;
    if(data_ready_delay2[0]) ch2_ready <= 1;

    if(data_ready_delay3[1]) ch3_dout[15:00] <= dq_reg;
    if(data_ready_delay3[0]) ch3_dout[31:16] <= dq_reg;
    if(data_ready_delay3[0]) ch3_ready <= 1;

    dqout <= 16'bZ;

    command <= CMD_NOP;
    SDRAM_A[12:11] <= 2'b11; // DQM
    case (state)
        STATE_STARTUP: begin
            SDRAM_A[10:0] <= 0;
            SDRAM_BA      <= 0;

            // All the commands during the startup are NOPS, except these
            if (refresh_count == startup_refresh_max-63) begin
                // ensure all rows are closed
                command     <= CMD_PRECHARGE;
                SDRAM_A[10] <= 1;  // all banks
                SDRAM_BA    <= 2'b00;
            end
            if (refresh_count == startup_refresh_max-55) begin
                // these refreshes need to be at least tREF (66ns) apart
                command     <= CMD_AUTO_REFRESH;
            end
            if (refresh_count == startup_refresh_max-47) begin
                command     <= CMD_AUTO_REFRESH;
            end
            if (refresh_count == startup_refresh_max-39) begin
                // Now load the mode register
                command     <= CMD_LOAD_MODE;
                SDRAM_A     <= MODE;
            end

            if (!refresh_count) begin
                state   <= STATE_IDLE;
                refresh_count <= 0;
            end
        end

        STATE_IDLE_5: state <= STATE_IDLE_4;
        STATE_IDLE_4: state <= STATE_IDLE_3;
        STATE_IDLE_3: state <= STATE_IDLE_2;
        STATE_IDLE_2: state <= STATE_IDLE_1;
        STATE_IDLE_1: begin
            state      <= STATE_IDLE;
            // mask possible refresh to reduce colliding.
            if (refresh_count > cycles_per_refresh) begin
                //------------------------------------------------------------------------
                //-- Start the refresh cycle. 
                //-- This tasks tRFC (66ns), so 7 idle cycles are needed @ 120MHz
                //------------------------------------------------------------------------
                state    <= STATE_IDLE_5;
                command  <= CMD_AUTO_REFRESH;
                refresh_count <= refresh_count - cycles_per_refresh + 1'd1;
            end
        end

        STATE_IDLE: begin
            if (0)
                ;
            else begin
                for (int b = 0; b < 4; b++) begin
                    if (bacnt[b] != 0)
                        bacnt[b] <= bacnt[b] - 1'd1;
                end

                case (bpest)
                    BAST_IDLE:
                        if (refresh_count > cycles_per_refresh) begin
                            // Priority is to issue a refresh if one is outstanding
                            state <= STATE_IDLE_1;
                        end
                    BAST_ACT: begin
                        if (~ch1_rnw) begin
                            {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {~ch1_be[1:0], 1'b1, ch1_addr[25:1]};
                        end else begin
                            {cas_addr[12:9],SDRAM_BA,SDRAM_A,cas_addr[8:0]} <= {2'b00, 1'b1, ch1_addr[25:1]};
                        end
                        SDRAM_BA   <= bpeba;
                        saved_data <= ch1_din;
                        saved_be   <= ch1_be;
                        ch         <= 0;
                        ch1_rq     <= 0;
                        command    <= CMD_ACTIVE;
                    end
                    BAST_R_CMD: begin                    
                        SDRAM_A <= cas_addr;
                        command <= CMD_READ;
                        if(ch == 0) data_ready_delay1[CAS_LATENCY+BURST_LENGTH] <= 1;
                        else if(ch == 1) data_ready_delay2[CAS_LATENCY+BURST_LENGTH] <= 1;
                        else             data_ready_delay3[CAS_LATENCY+BURST_LENGTH] <= 1;
                    end
                    BAST_R_DQM: begin
                        SDRAM_A[12:11] <= 0; // DQM
                    end
                    BAST_W_CMD: begin
                        SDRAM_A <= cas_addr;
                        command <= CMD_WRITE;
                        dqout   <= saved_data[15:0];
                    end
                    BAST_W_CMD_2: begin
                        SDRAM_A[10]    <= 1;
                        SDRAM_A[0]     <= 1;
                        command        <= CMD_WRITE;
                        dqout          <= saved_data[31:16];
                        SDRAM_A[12:11] <= ~saved_be[3:2]; // DQM
                        if(ch == 0)      ch1_ready <= 1;
                        else if(ch == 1) ch2_ready <= 1;
                        else             ch3_ready <= 1;
                    end
                    default: ;
                endcase
            end
        end
    endcase

    if (init) begin
        state <= STATE_STARTUP;
        refresh_count <= startup_refresh_max - sdram_startup_cycles;
        for (int i = 0; i < 4; i++)
            bast[i] <= BAST_IDLE;
    end
end

assign SDRAM_DQ   = dqout;
assign SDRAM_nCS  = 0;
assign SDRAM_nRAS = command[2];
assign SDRAM_nCAS = command[1];
assign SDRAM_nWE  = command[0];
assign SDRAM_CKE  = 1;
assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];

//altddio_out
//#(
//  .extend_oe_disable("OFF"),
//  .intended_device_family("Cyclone V"),
//  .invert_output("OFF"),
//  .lpm_hint("UNUSED"),
//  .lpm_type("altddio_out"),
//  .oe_reg("UNREGISTERED"),
//  .power_up_high("OFF"),
//  .width(1)
//)
//sdramclk_ddr
//(
//  .datain_h(1'b0),
//  .datain_l(1'b1),
//  .outclock(clk),
//  .dataout(SDRAM_CLK),
//  .aclr(1'b0),
//  .aset(1'b0),
//  .oe(1'b1),
//  .outclocken(1'b1),
//  .sclr(1'b0),
//  .sset(1'b0)
//);

function [1:0] addr_to_bank(input [26:0] a);
    addr_to_bank = a[24:23];
endfunction

function [12:0] addr_to_row(input [26:0] a);
    addr_to_row = a[22:10];
endfunction

function [9:0] addr_to_col(input [26:0] a);
    addr_to_col = {a[25], a[9:1]};
endfunction

endmodule
