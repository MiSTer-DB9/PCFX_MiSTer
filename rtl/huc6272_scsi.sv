// SCSI interface
//
// Copyright (c) 2025-2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

module huc6272_scsi
   (
    input        CLK,
    input        CE,
    input        RESn,

    // SCSI (CD-ROM) interface
    input [7:0]  SCSI_DI,
    output [7:0] SCSI_DO,
    output       SCSI_DOE,
    output       SCSI_ATNn,
    input        SCSI_BSYn,
    output       SCSI_ACKn,
    output       SCSI_RSTn,
    input        SCSI_MSGn,
    output       SCSI_SELn,
    input        SCSI_CDn,
    input        SCSI_REQn,
    input        SCSI_IOn,

    // Register file and status
    input        rf_scsi_t rf_scsi,
    output       st_scsi_t st_scsi
    );

logic [7:0]     rxbuf;
logic           dma_req, dma_req_set, dma_req_clr;

logic           reqn_d;
logic           assert_ack_dma, assert_ack_cnt;

// Data transfer engine (for DMA)

wire req_posedge = ~SCSI_REQn & reqn_d;

always @(posedge CLK) if (CE) begin
    reqn_d <= SCSI_REQn;

    if (~RESn) begin
        rxbuf <= '0;
    end
    else if (req_posedge) begin
        // Latch DI into RX buffer on REQn assertion.
        rxbuf <= st_scsi.din;
    end
end

// REQn assertion or REG.7L write sets REG.5H[6].
// RX buffer readout triggers ACKn pulse and clears REG.5H[6].

assign dma_req_set = rf_scsi.dma_mode & (req_posedge | rf_scsi.start_dma_rx);
assign dma_req_clr = rf_scsi.dma_mode & rf_scsi.rxbuf_rd;

always @(posedge CLK) if (CE) begin
    if (~RESn) begin
        dma_req <= '0;
    end
    else begin
        dma_req <= (dma_req & ~dma_req_clr) | dma_req_set;
    end
end

// Enforce minimum ACKn pulse assertion and negation periods.
always @(posedge CLK) if (CE) begin
    if (~RESn | ~rf_scsi.dma_mode) begin
        assert_ack_dma <= '0;
        assert_ack_cnt <= '0;
    end
    else begin
        if (assert_ack_cnt)
            assert_ack_cnt <= '0;
        else begin
            if (dma_req_clr) begin
                assert_ack_dma <= '1;
                assert_ack_cnt <= '1;
            end
            else if (assert_ack_dma) begin
                assert_ack_dma <= '0;
                assert_ack_cnt <= '1;
            end
        end
    end
end

// Bus hookups
assign SCSI_DO = rf_scsi.dout;
assign SCSI_DOE = SCSI_IOn & rf_scsi.assert_data;
assign SCSI_ATNn = ~rf_scsi.assert_atn;
assign SCSI_ACKn = ~(rf_scsi.assert_ack | assert_ack_dma);
assign SCSI_RSTn = ~rf_scsi.assert_rst;
assign SCSI_SELn = ~rf_scsi.assert_sel;

// Status outputs
assign st_scsi.cur_bus_stat = {~SCSI_RSTn, ~SCSI_BSYn, ~SCSI_REQn, ~SCSI_MSGn,
                               ~SCSI_CDn, ~SCSI_IOn, ~SCSI_SELn, 1'b0};
assign st_scsi.atn = ~SCSI_ATNn;
assign st_scsi.ack = ~SCSI_ACKn;
assign st_scsi.din = SCSI_DI;
assign st_scsi.rxbuf = rxbuf;
assign st_scsi.dma_req = dma_req;

endmodule
