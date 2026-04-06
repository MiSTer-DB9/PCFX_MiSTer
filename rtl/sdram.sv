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

// TODO: Handle CAS_LATENCY == 3

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

reg [3:0]  barq, barq_d; // access request
reg [3:0]  barnw; // read / not write
reg [11:0] barow [4]; // row address
reg [9:0]  bacol [4]; // column address
reg [31:0] badin [4]; // data to write
reg [3:0]  babe [4]; // byte enables
reg [3:0]  bast [4]; // bank current status
reg [3:0]  bawait [4]; // wait counter
// bacreq, badreq are bitmaps of future bus cycles required, LSB first
reg [3:0]  bacreq [4]; // cmd bus cycle request bitmap
reg [3:0]  badreq [4]; // data bus cycle request bitmap

wire [3:0] bast0 = bast[0];
wire [3:0] bast1 = bast[1];
wire [3:0] bast2 = bast[2];
//wire [3:0] bast3 = bast[3];

wire [3:0] bawait0 = bawait[0];
wire [3:0] bawait1 = bawait[1];
wire [3:0] bawait2 = bawait[2];
//wire [3:0] bawait3 = bawait[3];

wire [3:0] bacreq0 = bacreq[0];
wire [3:0] bacreq1 = bacreq[1];
wire [3:0] bacreq2 = bacreq[2];
//wire [3:0] bacreq3 = bacreq[3];

wire [3:0] badreq0 = badreq[0];
wire [3:0] badreq1 = badreq[1];
wire [3:0] badreq2 = badreq[2];
//wire [3:0] badreq3 = badreq[3];

// Bus Bank Scheduler
reg [3:0]  bbsst; // state
reg [1:0]  bbsba; // current bank
reg [1:0]  bbsba_d; // last bank
reg [3:0]  bbscact; // cmd bus cycle activity bitmap
reg [3:0]  bbsdact; // data bus cycle activity bitmap
reg        bbsschn; // bank was newly scheduled
reg [3:0]  bbsschban; // the newly scheduled bank
reg [3:0]  bbsschv; // schedule filled
reg [1:0]  bbsschba [4]; // bank schedule

wire [1:0] bbsschba0 = bbsschba[0];
wire [1:0] bbsschba1 = bbsschba[1];
wire [1:0] bbsschba2 = bbsschba[2];
wire [1:0] bbsschba3 = bbsschba[3];

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

reg  [3:0] state = STATE_STARTUP;

// Channel to bank connection
assign barq[0] = (barq_d[0] & ~ch1_ready) | ch1_req;
assign barq[1] = (barq_d[1] & ~ch2_ready) | ch2_req;
assign barq[2] = (barq_d[2] & ~ch3_ready) | ch3_req;
assign barq[3] = 0;

initial
    barq_d = 0;
always @(posedge clk) begin
    if (init)
        barq_d <= 0;
    else
        barq_d <= barq;
end

assign barnw[0] = ch1_rnw;
assign barnw[1] = ch2_rnw;
assign barnw[2] = ch3_rnw;

assign barow[0] = addr_to_row(ch1_addr);
assign barow[1] = addr_to_row(ch2_addr);
assign barow[2] = addr_to_row(ch3_addr);

assign bacol[0] = addr_to_col(ch1_addr);
assign bacol[1] = addr_to_col(ch2_addr);
assign bacol[2] = addr_to_col(ch3_addr);

assign badin[0] = ch1_din;
assign badin[1] = ch2_din;
assign badin[2] = ch3_din;

assign babe[0] = ch1_be;
assign babe[1] = 4'b0011;
assign babe[2] = 4'b0011;

wire bapause = state != STATE_IDLE || refresh_count > cycles_per_refresh;
wire baidle = (bast[0] == BAST_IDLE && bast[1] == BAST_IDLE &&
               bast[2] == BAST_IDLE && bast[3] == BAST_IDLE);

// Bank bus cycle request bitmap generator
always @* begin
    for (int b = 0; b < 4; b++) begin
        bacreq[b] = 0;
        badreq[b] = 0;

        case (bast[b])
            BAST_IDLE: begin
                if (~bapause && barq[b]) begin
                    bacreq[b] = 4'b1;
                end
            end
            BAST_ACT_WAIT:
                if (bawait[b] == 0) begin
                    bacreq[b] = (1<<BURST_LENGTH)-1;
                    badreq[b] = (1<<BURST_LENGTH)-1 << (barnw[b] ? 2 : 0);
                end
            default: ;
        endcase
    end
end

// Bank FSM
always @(posedge clk) begin
    for (int b = 0; b < 4; b++) begin
        if (bawait[b] != 0)
            bawait[b] <= bawait[b] - 1'd1;

        case (bast[b])
            BAST_IDLE: if (bbsba == b) begin
                if (~bapause && barq[b]) begin
                    bast[b] <= BAST_ACT;
                end
            end
            BAST_ACT: begin
                bast[b] <= BAST_ACT_WAIT;
                bawait[b] <= TRCD_MIN - 2;
            end
            BAST_ACT_WAIT: if (bbsba == b) begin
                if (bawait[b] == 0) begin
                    bast[b] <= barnw[b] ? BAST_R_CMD : BAST_W_CMD;
                end
            end
            BAST_R_CMD: begin
                bast[b] <= BAST_R_DQM;
            end
            BAST_R_DQM: begin
                bast[b] <= BAST_R;
                bawait[b] <= BURST_LENGTH - 1;
            end
            BAST_R:
                if (bawait[b] == 0) begin
                    bast[b] <= BAST_PRE;
                    bawait[b] <= (TRP_MIN-(BURST_LENGTH-1)) - 1;
                end
            BAST_W_CMD: begin
                bast[b] <= BAST_W_CMD_2;
            end
            BAST_W_CMD_2: begin
                bast[b] <= BAST_W_REC;
                bawait[b] <= TWR_MIN - 1;
            end
            BAST_W_REC:
                if (bawait[b] == 0) begin
                    bast[b] <= BAST_PRE;
                    bawait[b] <= (TRP_MIN-TWR_MIN) - 1;
                end
            BAST_PRE:
                if (bawait[b] == 0) begin
                    bast[b] <= BAST_IDLE;
                end
        endcase
    end
end

// Bus bank scheduler
always @* begin
    bbsba = bbsba_d;
    bbsschn = 0;
    bbsschban = 0;

    if (bbsschv[0]) begin
        // Select previously scheduled bank
        bbsba = bbsschba[0];
    end
    else begin
        // Nothing scheduled yet. Any volunteers?
        for (int b = 3; b >= 0; b--) begin
            if (bbsschn == 0) begin
                bbsschban = b;

                if ((bacreq[b] | badreq[b]) &
                    ~|(bacreq[b] & bbscact) & ~|(badreq[b] & bbsdact))
                    bbsschn = 1;
            end
        end
        if (bbsschn)
            // Select newly scheduled bank
            bbsba = bbsschban;
    end
end

initial
    bbsba_d = 0;

always @(posedge clk) begin
    bbsba_d <= bbsba;

    for (int i = 0; i < $size(bbsschv); i++) begin
        if (i < $size(bbsschv) - 1) begin
            bbsschv[i] <= bbsschv[i+1];
            bbsschba[i] <= bbsschba[i+1];
        end
        else begin
            bbsschv[i] <= 0;
            bbsschba[i] <= 0;
        end

        if (bbsschn & bacreq[bbsschban][i]) begin
            bbsschv[i] <= 1;
            bbsschba[i] <= bbsschban;
        end
    end
end

assign bbsst = bast[bbsba];

always @(posedge clk) begin
    bbscact <= {1'b0, bbscact[$left(bbscact):1]} | bacreq[bbsba];
    bbsdact <= {1'b0, bbsdact[$left(bbsdact):1]} | badreq[bbsba];
end

always @(posedge clk) begin
    reg [CAS_LATENCY+BURST_LENGTH:0] data_ready_delay1, data_ready_delay2, data_ready_delay3;

    reg [12:0] cas_addr;
    reg [15:0] dq_reg;


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
            case (bbsst)
                BAST_IDLE:
                    if (baidle && refresh_count > cycles_per_refresh) begin
                        // Priority is to issue a refresh if one is outstanding
                        state <= STATE_IDLE_1;
                    end
                BAST_ACT: begin
                    SDRAM_BA   <= bbsba;
                    SDRAM_A    <= barow[bbsba];
                    command    <= CMD_ACTIVE;
                end
                BAST_R_CMD: begin
                    SDRAM_BA       <= bbsba;
                    SDRAM_A[12:11] <= 0; // DQM for 1st beat
                    SDRAM_A[10]    <= 1; // auto-precharge
                    SDRAM_A[9:0]   <= bacol[bbsba];
                    command <= CMD_READ;
                    if(bbsba == 0)      data_ready_delay1[CAS_LATENCY+BURST_LENGTH] <= 1;
                    else if(bbsba == 1) data_ready_delay2[CAS_LATENCY+BURST_LENGTH] <= 1;
                    else                data_ready_delay3[CAS_LATENCY+BURST_LENGTH] <= 1;
                end
                BAST_R_DQM: begin
                    SDRAM_A[12:11] <= 0; // DQM for 2nd beat
                end
                BAST_W_CMD: begin
                    SDRAM_BA       <= bbsba;
                    SDRAM_A[12:11] <= ~babe[bbsba][1:0]; // DQM for 1st beat
                    SDRAM_A[10]    <= 0; // no auto-precharge
                    SDRAM_A[9:0]   <= bacol[bbsba];
                    command <= CMD_WRITE;
                    dqout   <= badin[bbsba][15:0];
                end
                BAST_W_CMD_2: begin
                    SDRAM_A[12:11] <= ~babe[bbsba][3:2]; // DQM for 2nd beat
                    SDRAM_A[10]    <= 1; // auto-precharge
                    SDRAM_A[0]     <= 1;
                    command        <= CMD_WRITE;
                    dqout          <= badin[bbsba][31:16];
                    if(bbsba == 0)      ch1_ready <= 1;
                    else if(bbsba == 1) ch2_ready <= 1;
                    else                ch3_ready <= 1;
                end
                default: ;
            endcase
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
