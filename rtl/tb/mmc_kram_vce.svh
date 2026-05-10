logic           reset;
logic           clk, ce;
logic [2:1]     a;
logic           csn, rdn, wrn, busyn;
logic [15:0]    din, dout;
enum            {MMC, VCE, VDC0, VDC1} io_sel;
logic           vce_sel = '0;
logic [15:0]    mmc_dout, vce_dout;
logic           mmc_csn, vce_csn;
logic           dck, dck_nededge, dck70, dck70_negedge;
logic           hsync_posedge, hsync_negedge;
logic           vsync_posedge, vsync_negedge;
logic [15:0]    ra_di, ra_do;
wire [15:0]     krama_io;
logic [8:0]     ra_a;
logic           ra_oen, ra_wen, ra_rasn, ra_lcasn, ra_ucasn;
logic [15:0]    rb_di, rb_do;
wire [15:0]     kramb_io;
logic [8:0]     rb_a;
logic           rb_oen, rb_wen, rb_rasn, rb_lcasn, rb_ucasn;
logic [23:0]    mmc_vd, vce_vd;
logic [8:0]     vdc0_vd, vdc1_vd;
logic           mmc_vde;
logic           vce_hbl, vce_vbl, vce_vde;
`ifdef TB_VDC
logic           vdc0_csn;
logic [15:0]    vdc0_dout;
wire [15:0]     vram0_a;
wire [15:0]     vram0_di, vram0_do;
wire            vram0_we;
logic           vdc1_csn;
logic [15:0]    vdc1_dout;
wire [15:0]     vram1_a;
wire [15:0]     vram1_di, vram1_do;
wire            vram1_we;
`endif

huc6272 mmc
   (
    .CLK(clk),
    .CE(ce),
    .RESn(~reset),

    .A(a),
    .DI(din),
    .DO(mmc_dout),
    .CSn(mmc_csn),
    .WRn(wrn),
    .RDn(rdn),
    .BUSYn(busyn),

    .RA_DI(ra_di),
    .RA_DO(ra_do),
    .RA_A(ra_a),
    .RA_OEn(ra_oen),
    .RA_WEn(ra_wen),
    .RA_RASn(ra_rasn),
    .RA_LCASn(ra_lcasn),
    .RA_UCASn(ra_ucasn),

    .RB_DI(rb_di),
    .RB_DO(rb_do),
    .RB_A(rb_a),
    .RB_OEn(rb_oen),
    .RB_WEn(rb_wen),
    .RB_RASn(rb_rasn),
    .RB_LCASn(rb_lcasn),
    .RB_UCASn(rb_ucasn),

    .DCK(dck),
    .DCK_NEGEDGE(dck_negedge),
    .HSYNC_POSEDGE(hsync_posedge),
    .HSYNC_NEGEDGE(hsync_negedge),
    .VSYNC_POSEDGE(vsync_posedge),
    .VSYNC_NEGEDGE(vsync_negedge),
    .VD(mmc_vd),
    .VDE(mmc_vde)
    );

pd424260 krama
   (
    .IO(krama_io),
    .A(ra_a),
    .OEn(ra_oen),
    .WEn(ra_wen),
    .RASn(ra_rasn),
    .LCASn(ra_lcasn),
    .UCASn(ra_ucasn)
    );

assign krama_io = ra_oen ? ra_do : 'Z;
assign ra_di = krama_io;

pd424260 kramb
   (
    .IO(kramb_io),
    .A(rb_a),
    .OEn(rb_oen),
    .WEn(rb_wen),
    .RASn(rb_rasn),
    .LCASn(rb_lcasn),
    .UCASn(rb_ucasn)
    );

assign kramb_io = rb_oen ? rb_do : 'Z;
assign rb_di = kramb_io;

huc6261 vce
   (
    .CLK(clk),
    .CE(ce),
    .RESn(~reset),

    .CSn(vce_csn),
    .WRn(wrn),
    .RDn(rdn),
    .A2(a[2]),
    .DI(din),
    .DO(vce_dout),

    .DCK70(dck70),
    .DCK70_NEGEDGE(dck70_negedge),
    .HSYNC_POSEDGE(hsync_posedge),
    .HSYNC_NEGEDGE(hsync_negedge),
    .VSYNC_POSEDGE(vsync_posedge),
    .VSYNC_NEGEDGE(vsync_negedge),

    .VDC0_VD(vdc0_vd),
    .VDC1_VD(vdc1_vd),

    .DCKKR(dck),
    .DCKKR_NEGEDGE(dck_negedge),
    .MMC_VD(mmc_vd),

    .Y(vce_vd[16+:8]),
    .U(vce_vd[8+:8]),
    .V(vce_vd[0+:8]),
    .VBL(vce_vbl),
    .HBL(vce_hbl)
    );

assign vce_vde = ~(vce_hbl | vce_vbl);

`ifdef TB_VDC
huc6270 vdc0
    (
     .CLK(clk),
     .RST_N(~reset),
     .CLR_MEM('0),
     .CPU_CE(ce),

     .BYTEWORD('0),
     .A(a),
     .DI(din),
     .DO(vdc0_dout),
     .CS_N(vdc0_csn),
     .WR_N(wrn),
     .RD_N(rdn),
     .BUSY_N(),
     .IRQ_N(),

     .DCK_CE(dck70),
     .DCK_CE_F(dck70_negedge),
     .HSYNC_F(hsync_negedge),
     .HSYNC_R(hsync_posedge),
     .VSYNC_F(vsync_negedge),
     .VSYNC_R(vsync_posedge),
     .VD(vdc0_vd),
     .BORDER(),
     .GRID(),
     .SP64('0),

     .RAM_A(vram0_a),
     .RAM_DI(vram0_di),
     .RAM_DO(vram0_do),
     .RAM_WE(vram0_we),

     .BG_EN('1),
     .SPR_EN('1)
     );

dpram #(.addr_width(16), .data_width(16), .disable_value(0)) vram0
    (
     .clock(clk),
     .address_a(vram0_a),
     .data_a(vram0_do),
     .enable_a('1),
     .wren_a(vram0_we),
     .q_a(vram0_di),
     .cs_a('1),
     .address_b('0),
     .data_b('0),
     .enable_b('1),
     .wren_b('0),
     .q_b(),
     .cs_b('1)
     );

huc6270 vdc1
    (
     .CLK(clk),
     .RST_N(~reset),
     .CLR_MEM('0),
     .CPU_CE(ce),

     .BYTEWORD('0),
     .A(a),
     .DI(din),
     .DO(vdc1_dout),
     .CS_N(vdc1_csn),
     .WR_N(wrn),
     .RD_N(rdn),
     .BUSY_N(),
     .IRQ_N(),

     .DCK_CE(dck70),
     .DCK_CE_F(dck70_negedge),
     .HSYNC_F(hsync_negedge),
     .HSYNC_R(hsync_posedge),
     .VSYNC_F(vsync_negedge),
     .VSYNC_R(vsync_posedge),
     .VD(vdc1_vd),
     .BORDER(),
     .GRID(),
     .SP64('0),

     .RAM_A(vram1_a),
     .RAM_DI(vram1_di),
     .RAM_DO(vram1_do),
     .RAM_WE(vram1_we),

     .BG_EN('1),
     .SPR_EN('1)
     );

dpram #(.addr_width(16), .data_width(16), .disable_value(0)) vram1
    (
     .clock(clk),
     .address_a(vram1_a),
     .data_a(vram1_do),
     .enable_a('1),
     .wren_a(vram1_we),
     .q_a(vram1_di),
     .cs_a('1),
     .address_b('0),
     .data_b('0),
     .enable_b('1),
     .wren_b('0),
     .q_b(),
     .cs_b('1)
     );
`endif

initial begin
    reset = 1;
    ce = 0;
    rdn = 1;
    wrn = 1;
    csn = 1;
    clk = 1;
end

always @* begin
    mmc_csn = 1'b1;
    vce_csn = 1'b1;
    vdc0_csn = 1'b1;
    vdc1_csn = 1'b1;
    dout = 'X;
    case (io_sel)
        MMC: begin
            mmc_csn = csn;
            dout = mmc_dout;
        end
        VCE: begin
            vce_csn = csn;
            dout = vce_dout;
        end
        VDC0: begin
            vdc0_csn = csn;
            dout = vdc0_dout;
        end
        VDC1: begin
            vdc1_csn = csn;
            dout = vdc1_dout;
        end
        default: ;
    endcase
end

initial forever begin :ckgen
    #0.01 clk = ~clk; // 50 MHz
end

always @(posedge clk) begin :cegen
    ce <= ~ce;
end

//////////////////////////////////////////////////////////////////////

task io_read16(input [2:1] ain, output [15:0] v);
    @(posedge clk) ;
    while (!ce)
        @(posedge clk) ;
    a <= ain;
    rdn <= 0;
    csn <= 0;

    @(posedge clk) ;
    while (!ce | !busyn)
        @(posedge clk) ;
    v = dout;
    rdn <= 1;
    csn <= 1;
endtask

task io_write16(input [2:1] ain, input [15:0] v);
    @(posedge clk) ;
    while (!ce)
        @(posedge clk) ;
    a <= ain;
    din <= v;
    wrn <= 0;
    csn <= 0;

    @(posedge clk) ;
    while (!ce | !busyn)
        @(posedge clk) ;
    din <= 'X;
    wrn <= 1;
    csn <= 1;
endtask

task reg_read(input [6:0] rs, output [15:0] v);
    io_write16(2'b00, 16'(rs));
    io_read16(2'b10, v);
endtask

task reg_write(input [6:0] rs, input [15:0] v);
    io_write16(2'b00, 16'(rs));
    io_write16(2'b10, v);
endtask

task reg32_read(input [6:0] rs, output [31:0] v);
    io_write16(2'b00, 16'(rs));
    io_read16(2'b10, v[15:0]);
    io_read16(2'b11, v[31:16]);
endtask

task reg32_write(input [6:0] rs, input [31:0] v);
    io_write16(2'b00, 16'(rs));
    io_write16(2'b10, v[15:0]);
    io_write16(2'b11, v[31:16]);
endtask

//////////////////////////////////////////////////////////////////////

task vram_write(input page, input [17:0] addr, input [15:0] d);
    if (addr[17])
        kramb.write({page, addr[16:9]}, addr[8:0], d);
    else
        krama.write({page, addr[16:9]}, addr[8:0], d);
endtask

task vram_load_file(input string fn, input page);
integer fin;
integer code;
logic [15:0] data;
logic [18:1] addr;
    begin
        fin = $fopen(fn, "rb");
        assert(fin != 0) else $error("Unable to open file %s", fn);
        $display("Loading %s to VRAM page %1d", fn, page);
        addr = 0;
        while (!$feof(fin)) begin :load_loop
            code = $fread(data, fin, 0, 2);
            if (!$feof(fin)) begin
                data = {data[7:0], data[15:8]}; // $fread is big-endian
                vram_write(page, addr, data);
                addr += 1;
            end
        end
        $fclose(fin);
    end
endtask

