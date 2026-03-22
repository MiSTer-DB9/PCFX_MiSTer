// HuC6272 (KING)
//
// Copyright (c) 2025-2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

`include "huc6272_types.svh"

module huc6272
    (
     input         CLK,
     input         CE,
     input         RESn,

     // CPU memory / I/O bus interface
     input [2:1]   A,
     input [15:0]  DI,
     output [15:0] DO,
     input         CSn,
     input         WRn,
     input         RDn,
     output        BUSYn,
     output        IRQn,

     // DRAM bank A interface
     input [15:0]  RA_DI,
     output [15:0] RA_DO,
     output [8:0]  RA_A,
     output        RA_OEn,
     output        RA_WEn,
     output        RA_RASn,
     output        RA_LCASn,
     output        RA_UCASn,

     // DRAM bank B interface
     input [15:0]  RB_DI,
     output [15:0] RB_DO,
     output [8:0]  RB_A,
     output        RB_OEn,
     output        RB_WEn,
     output        RB_RASn,
     output        RB_LCASn,
     output        RB_UCASn,

     // Video interface
     input         DCK, // pixel clock enable
     input         DCK_NEGEDGE,
     input         HSYNC_POSEDGE,
     input         HSYNC_NEGEDGE,
     input         VSYNC_POSEDGE,
     input         VSYNC_NEGEDGE,
     output [23:0] VD, // [7:0] = palette data / [23:0] = {Y,U,V}
     output        VDE, // data enable (not in blanking)

     // SCSI (CD-ROM) interface
     input [7:0]   SCSI_DI,
     output [7:0]  SCSI_DO,
     output        SCSI_DOE,
     output        SCSI_ATNn,
     input         SCSI_BSYn,
     output        SCSI_ACKn,
     output        SCSI_RSTn,
     input         SCSI_MSGn,
     output        SCSI_SELn,
     input         SCSI_CDn,
     input         SCSI_REQn,
     input         SCSI_IOn
     );

rf_scsi_t       rf_scsi;
rf_bgm_t        rf_bgm;

st_scsi_t       st_scsi;

logic [17:1]    vid_ma_a;
logic [15:0]    vid_ma_di, vid_ma_do;
logic [1:0]     vid_ma_be;
logic           vid_ma_wr, vid_ma_req, vid_ma_ack;
logic [17:1]    vid_mb_a;
logic [15:0]    vid_mb_di, vid_mb_do;
logic [1:0]     vid_mb_be;
logic           vid_mb_wr, vid_mb_req, vid_mb_ack;

//////////////////////////////////////////////////////////////////////
// CPU memory / I/O bus interface

huc6272_cpuif cpuif
   (
    .*
    );

//////////////////////////////////////////////////////////////////////
// DRAM memory controllers

huc6272_dmc dmca
   (
    .*,

    .A(vid_ma_a),
    .DI(vid_ma_di),
    .DO(vid_ma_do),
    .BE(vid_ma_be),
    .WR(vid_ma_wr),
    .REQ(vid_ma_req),
    .ACK(vid_ma_ack),

    .R_DI(RA_DI),
    .R_DO(RA_DO),
    .R_A(RA_A),
    .R_OEn(RA_OEn),
    .R_WEn(RA_WEn),
    .R_RASn(RA_RASn),
    .R_LCASn(RA_LCASn),
    .R_UCASn(RA_UCASn)
    );

huc6272_dmc dmcb
   (
    .*,

    .A(vid_mb_a),
    .DI(vid_mb_di),
    .DO(vid_mb_do),
    .BE(vid_mb_be),
    .WR(vid_mb_wr),
    .REQ(vid_mb_req),
    .ACK(vid_mb_ack),

    .R_DI(RB_DI),
    .R_DO(RB_DO),
    .R_A(RB_A),
    .R_OEn(RB_OEn),
    .R_WEn(RB_WEn),
    .R_RASn(RB_RASn),
    .R_LCASn(RB_LCASn),
    .R_UCASn(RB_UCASn)
    );

//////////////////////////////////////////////////////////////////////
// SCSI interface

huc6272_scsi scsi
   (
    .*
    );

//////////////////////////////////////////////////////////////////////
// Video interface

huc6272_video video
   (
    .*,

    .MA_A(vid_ma_a),
    .MA_DI(vid_ma_di),
    .MA_DO(vid_ma_do),
    .MA_BE(vid_ma_be),
    .MA_WR(vid_ma_wr),
    .MA_REQ(vid_ma_req),
    .MA_ACK(vid_ma_ack),

    .MB_A(vid_mb_a),
    .MB_DI(vid_mb_di),
    .MB_DO(vid_mb_do),
    .MB_BE(vid_mb_be),
    .MB_WR(vid_mb_wr),
    .MB_REQ(vid_mb_req),
    .MB_ACK(vid_mb_ack)
    );

endmodule

`include "huc6272_cpuif.sv"
`include "huc6272_dmc.sv"
`include "huc6272_scsi.sv"
`include "huc6272_video.sv"
`include "huc6272_fetch.sv"
`include "huc6272_bgm.sv"
