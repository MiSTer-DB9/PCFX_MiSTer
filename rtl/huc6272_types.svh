// HuC6272 (KING) internal data types
//
// Copyright (c) 2025-2026 David Hunter
//
// This program is GPL licensed. See COPYING for the full license.

typedef enum bit [3:0] {
    BGF_UNUSED = 4'h0,
    BGF_INT_DOT_4 = 4'h1,
    BGF_INT_DOT_16 = 4'h2,
    BGF_INT_DOT_256 = 4'h3,
    BGF_INT_DOT_64K = 4'h4,
    BGF_INT_DOT_16M = 4'h5,
    BGF_EXT_BLK_4 = 4'h9,
    BGF_EXT_BLK_16 = 4'hA,
    BGF_EXT_BLK_256 = 4'hB,
    BGF_EXT_BLK_64K = 4'hC,
    BGF_EXT_BLK_16M = 4'hD,
    BGF_EXT_DOT_64K = 4'hE,
    BGF_EXT_DOT_16M = 4'hF
} bg_format_t;

typedef struct packed {
    bg_format_t     format;
    logic [2:0]     prio;
    logic [7:0]     bat, cg;
    logic [3:0]     size_m, size_n;
    logic [10:0]    bsx, bsy;
} rf_bgp_t;

typedef struct packed {
    rf_bgp_t [4]    bgp;
    logic           rsw;
    logic           sub_wrap;
    logic [7:0]     sub_bat0, sub_cg0;
    logic [3:0]     size_sub_m0, size_sub_n0;
} rf_bgm_t;
