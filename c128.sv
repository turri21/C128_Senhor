//============================================================================
//  C128 Top level for MiSTer
//  Copyright (C) 2022 Erik Scheffers
//  Based on C64 for MiSTer Copyright (C) 2017-2021 Sorgelig
//
//  Used DE2-35 Top level by Dar (darfpga@aol.fr)
//
//  FPGA64 is Copyrighted 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
//  http://www.syntiac.com/fpga64.html
//
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
   //Master input clocks
   input         CLK_50M,
   input         CLK3_50M,

   //Async reset from top-level module.
   //Can be used as initial reset.
   input         RESET,

   //Must be passed to hps_io module
   inout  [48:0] HPS_BUS,

   //Base video clock. Usually equals to CLK_SYS.
   output        CLK_VIDEO,

   //Multiple resolutions are supported using different CE_PIXEL rates.
   //Must be based on CLK_VIDEO
   output        CE_PIXEL,

   //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
   //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
   output [12:0] VIDEO_ARX,
   output [12:0] VIDEO_ARY,

   output  [7:0] VGA_R,
   output  [7:0] VGA_G,
   output  [7:0] VGA_B,
   output        VGA_HS,
   output        VGA_VS,
   output        VGA_DE,    // = ~(VBlank | HBlank)
   output        VGA_F1,
   output [1:0]  VGA_SL,
   output        VGA_SCALER, // Force VGA scaler
   output        VGA_DISABLE, // analog out is off

   input  [11:0] HDMI_WIDTH,
   input  [11:0] HDMI_HEIGHT,
   output        HDMI_FREEZE,
   output        HDMI_BLACKOUT,
	 
`ifdef MISTER_FB
   // Use framebuffer in DDRAM
   // FB_FORMAT:
   //    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
   //    [3]   : 0=16bits 565 1=16bits 1555
   //    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
   //
   // FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
   output        FB_EN,
   output  [4:0] FB_FORMAT,
   output [11:0] FB_WIDTH,
   output [11:0] FB_HEIGHT,
   output [31:0] FB_BASE,
   output [13:0] FB_STRIDE,
   input         FB_VBL,
   input         FB_LL,
   output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
   // Palette control for 8bit modes.
   // Ignored for other video modes.
   output        FB_PAL_CLK,
   output  [7:0] FB_PAL_ADDR,
   output [23:0] FB_PAL_DOUT,
   input  [23:0] FB_PAL_DIN,
   output        FB_PAL_WR,
`endif
`endif

   output        LED_USER,  // 1 - ON, 0 - OFF.

   // b[1]: 0 - LED status is system status OR'd with b[0]
   //       1 - LED status is controled solely by b[0]
   // hint: supply 2'b00 to let the system control the LED.
   output  [1:0] LED_POWER,
   output  [1:0] LED_DISK,

   // I/O board button press simulation (active high)
   // b[1]: user button
   // b[0]: osd button
   output  [1:0] BUTTONS,

   input         CLK_AUDIO, // 24.576 MHz
   output [15:0] AUDIO_L,
   output [15:0] AUDIO_R,
   output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
   output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

   //ADC
   inout   [3:0] ADC_BUS,

   //SD-SPI
   output        SD_SCK,
   output        SD_MOSI,
   input         SD_MISO,
   output        SD_CS,
   input         SD_CD,

   //High latency DDR3 RAM interface
   //Use for non-critical time purposes
   output        DDRAM_CLK,
   input         DDRAM_BUSY,
   output  [7:0] DDRAM_BURSTCNT,
   output [28:0] DDRAM_ADDR,
   input  [63:0] DDRAM_DOUT,
   input         DDRAM_DOUT_READY,
   output        DDRAM_RD,
   output [63:0] DDRAM_DIN,
   output  [7:0] DDRAM_BE,
   output        DDRAM_WE,

   //SDRAM interface with lower latency
   output        SDRAM_CLK,
   output        SDRAM_CKE,
   output [12:0] SDRAM_A,
   output  [1:0] SDRAM_BA,
   inout  [15:0] SDRAM_DQ,
   output        SDRAM_DQML,
   output        SDRAM_DQMH,
   output        SDRAM_nCS,
   output        SDRAM_nCAS,
   output        SDRAM_nRAS,
   output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
   //Secondary SDRAM
   //Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
   input         SDRAM2_EN,
   output        SDRAM2_CLK,
   output [12:0] SDRAM2_A,
   output  [1:0] SDRAM2_BA,
   inout  [15:0] SDRAM2_DQ,
   output        SDRAM2_nCS,
   output        SDRAM2_nCAS,
   output        SDRAM2_nRAS,
   output        SDRAM2_nWE,
`endif

   input         UART_CTS,
   output        UART_RTS,
   input         UART_RXD,
   output        UART_TXD,
   output        UART_DTR,
   input         UART_DSR,

   // Open-drain User port.
   // 0 - D+/RX
   // 1 - D-/TX
   // 2..6 - USR2..USR6
   // Set USER_OUT to 1 to read from USER_IN.
   input   [6:0] USER_IN,
   output  [6:0] USER_OUT,

   input         OSD_STATUS
);

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_DISK   = 0;
assign LED_POWER  = 0;
assign LED_USER   = |drive_led | ioctl_download | tape_led | ~disk_ready;
assign BUTTONS    = 0;
assign VGA_SCALER = 0;

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXX XXXXXXXXXXX XXXXXXXXX XX  XX XXXXXXXxxxXXXXXXXXXXXX

//                                      1         1         1
// 6     7         8         9          0         1         2
// 45678901234567890123456789012345 67890123456789012345678901234567
// XXXXXXXXXXXX    XXXXXXXXXXXXXXXX XXXXXXX                        X

// bits  0.. 79 keep in sync with C64 core (X: identical, x: different use)
// bits 80..127 C128 core options

`include "build_id.v"
localparam CONF_STR = {
   "C128;UART9600:2400;",
   "H7S0,D64G64D71G71D81T64,Mount #8                    ;",
   "H0S1,D64G64D71G71D81T64,Mount #9                    ;",
   "-;",
   "F2,PRGCRTREUTAP;",
   "h3-;",
   "h3R[7],Tape Play/Pause;",
   "h3R[23],Tape Unload;",
   "h3O[11],Tape Sound,Off,On;",
   "-;",

   "P1,Audio & Video;",
   "HAP1O[100:99],Video Out,Follow 40/80,VIC,VDC;",
   "HAP1O[98],40/80 Display,40 col,80 col;",
   "HAP1-;",
   "P1O[2],Video Standard,PAL,NTSC;",
   "P1-;",
   "P1O[5:4],Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
   "P1O[9:8],Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
   "d1P1O[32],Vertical Crop,No,Yes;",
   "P1O[31:30],Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
   "P1-;",
   "hAP1O[35:34],VIC-II Variant,656x,856x,Early 856x;",
   "P1O[95:94],VIC-II Jailbars,Off,Low,Medium,High;",
   "HAP1-;",
   "HAP1O[81:80],VDC Variant,Auto,8563R9,8568;",
   "HAP1O[122],VDC Position,Centered,Original;",
`ifdef VDC_XRAY
   "HAP1O[127],VDC XRay,Off,On;",
`endif
`ifndef REDUCE_VDC_RAM
   "HAH6P1O[88],VDC Memory,16k,64k;",
`endif
   "HAP1O[92:91],VDC Palette,Default,Analogue,Monochrome,Composite;",
   "HAh2P1O[90:89],VDC Mono Colour,White,Green,Amber,Red;",
   "P1-;",
   "P1O[14:13],Left SID,Auto,6581,8580;",
   "P1O[16:15],Right SID,Auto,6581,8580;",
   "D4P1O[66:64],Left Filter,Default,Custom 1,Custom 2,Custom 3,Adjustable;",
   "D5P1O[69:67],Right Filter,Default,Custom 1,Custom 2,Custom 3,Adjustable;",
   "D4D8P1O[72:70],Left Fc Offset,0,1,2,3,4,5;",
   "D5D9P1O[75:73],Right Fc Offset,0,1,2,3,4,5;",
   "P1O[21:20],Right SID Port,Same,D420,DE00,DF00;",
	"P1O[37],8580 Digifix,On,Off;",
   "P1FC7,FLT,Load Custom Filters;",
   "P1-;",
   "P1O[12],Sound Expander,Disabled,OPL2;",
   "P1O[41:40],DigiMax,Disabled,DE00,DF00;",
   "P1O[19:18],Stereo Mix,None,25%,50%,100%;",

   "P2,Hardware;",
   "HAP2O[93],C64 mode,C128 extensions,Pure C64;",
   "HAP2-;",
   "P2O[58:57],Enable Drive #8,If Mounted,Always,Never;",
   "P2O[56:55],Enable Drive #9,If Mounted,Always,Never;",
   "D7P2O[84:83],Drive #8 5.25\" model,Auto,1541,1571;",
   "D0P2O[86:85],Drive #9 5.25\" model,Auto,1541,1571;",
   "P2O[44],Parallel port,Enabled,Disabled;",
   "P2O[25],External IEC,Disabled,Enabled;",
   "P2R[6],Reset Disk Drives;",
   "P2-;",
   "HAP2O[87],Internal Memory,128K,256K;",
   "P2O[52],GeoRAM,Disabled,4MB;",
   "P2O[54:53],REU,Disabled,512KB,2MB (512KB wrap),16MB;",
   "P2-;",
   "P2O[43],Expansion,Joysticks,RS232;",
   "P2O[51],RS232 mode,UP9600,VIC-1011;",
   "P2O[33],RS232 connection,Internal,External;",
   "P2O[36],Real-Time Clock,Auto,Disabled;",
   "P2O[46:45],CIA,Auto,6526,8521;",
   "P2-;",
   "P2O[27:26],Pot 1/2,Joy 1 Fire 2/3,Mouse,Paddles 1/2;",
   "P2O[29:28],Pot 3/4,Joy 2 Fire 2/3,Mouse,Paddles 3/4;",
   "P2-;",
   "P2O[60:59],Key modifier,L+R Shift,L Shift,R Shift;",
   "HAP2O[97:96],Caps Lock mode,Auto,Caps Lock,ASCII/DIN;",
   "P2-;",
   "P2O[1],Release Keys on Reset,Yes,No;",
   "P2O[24],Clear RAM on Reset,Yes,No;",
   "P2O[50],Reset & Run PRG,Yes,No;",
   "P2O[42],Pause When OSD is Open,No,Yes;",
   "P2O[39],Tape Autoplay,Yes,No;",
   "P2-;",
   "P2FC3,ROMBIN,System ROMs                 ;",
   "P2FC4,ROMBIN,Drive ROMs                  ;",
   "HAP2FC6,ROMBIN,Internal Function ROM      ;",
   "P2FC5,CRT,Boot Cartridge              ;",
   "-;",
   "O[3],Swap Joysticks,No,Yes;",
   "-;",
   "O[49:48],8502 Speed,Standard,x2,x3,x4;",
   "HAO[101],Z80 Speed,Standard,x2;",
   "-;",
   "HAhCR[82],Reset & Remove Int.Func.ROM;",
   "hBR[17],Reset & Remove Cartridge;",
   "R[0],Reset;",
   "J,Fire 1,Fire 2,Fire 3,Paddle Btn,Mod1,Mod2;",
   "jn,A,B,Y,X|P,R,L;",
   "jp,A,B,Y,X|P,R,L;",
   "I,",
   "Missing/invalid boot0.rom/MRA,",          // 1
   "Missing/invalid boot1.rom/MRA,",          // 2
   "SHIFT LOCK: Off,SHIFT LOCK: On,",         // 3/4
   "CAPS LOCK: On,CAPS LOCK: Off,",           // 5/6
   "ASCII/DIN: DIN,ASCII/DIN: ASCII,",        // 7/8
   "40/80 DISPLAY: 80,40/80 DISPLAY: 40,",    // 9/10
   "NO SCROLL LOCK: Off,NO SCROLL LOCK: On;", // 11/12
   "DEFMRA,/_Computer/C128def.mra;",
   "V,v",`BUILD_DATE
};

wire pll_sys_locked;
wire clk_sys;
wire clk64;
wire clk48;

pll pll
(
   .refclk(CLK_50M),
   .outclk_0(clk48),
   .outclk_1(clk64),
   .outclk_2(clk_sys),
   .reconfig_to_pll(reconfig_to_pll),
   .reconfig_from_pll(reconfig_from_pll),
   .locked(pll_sys_locked)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
   .mgmt_clk(CLK_50M),
   .mgmt_reset(0),
   .mgmt_waitrequest(cfg_waitrequest),
   .mgmt_read(0),
   .mgmt_readdata(),
   .mgmt_write(cfg_write),
   .mgmt_address(cfg_address),
   .mgmt_writedata(cfg_data),
   .reconfig_to_pll(reconfig_to_pll),
   .reconfig_from_pll(reconfig_from_pll)
);

wire pll_vdc_locked;
wire clk_vdc;

pll_vdc pll_vdc
(
   .refclk(CLK3_50M),
   .outclk_0(clk_vdc),
   .locked(pll_vdc_locked)
);

wire pll_locked = pll_sys_locked & pll_vdc_locked;

always @(posedge CLK_50M) begin
   reg ntscd = 0, ntscd2 = 0;
   reg [2:0] state = 0;
   reg ntsc_r;

   cfg_write <= 0;

   ntscd <= ntsc;
   ntscd2 <= ntscd;
   if (ntscd2 == ntscd && ntscd2 != ntsc_r) begin
      ntsc_r <= ntscd2;
      state <= 1;
   end

   if(!cfg_waitrequest) begin
      if(state) state<=state+1'd1;
      case(state)
         1: begin
               cfg_address <= 0;
               cfg_data <= 0;
               cfg_write <= 1;
            end
         3: begin
               cfg_address <= 7;
               cfg_data <= ntsc_r ? 3357876127 : 1503512573;
               cfg_write <= 1;
            end
         5: begin
               cfg_address <= 2;
               cfg_data <= 0;
               cfg_write <= 1;
            end
      endcase
   end
end

reg reset_n;
reg reset_wait = 0;
always @(posedge clk_sys) begin
   integer reset_counter;
   reg do_erase = 1;

   reset_n <= ~|reset_counter;

   if (RESET | status[0] | status[17] | status[82] | buttons[1] | !pll_locked | !rom_loaded) begin
      if(RESET) do_erase <= 1;
      reset_counter <= 100000;
   end
   else if(prg_reset & !do_erase) begin
      do_erase <= 1;
      reset_wait <= 1;
      reset_counter <= 255;
   end
   else if (ioctl_download & (load_rom | load_cfg | load_ifr | load_efr | load_crt) & reset_counter <= 255) begin
      do_erase <= 1;
      reset_counter <= 255;
   end
   else if ((ioctl_download || inj_meminit) & ~reset_wait);
   else if (erasing) force_erase <= 0;
   else if (!reset_counter) begin
      do_erase <= 0;
      // C64: wait for $FFCF CHRIN
      // C128: wait for $FFC3 ICLOSE
      if(reset_wait && c128_addr[15:0] == (c128_n ? 'hFFCF : 'hFFC3)) reset_wait <= 0;
   end
   else begin
      reset_counter <= reset_counter - 1;
      if (reset_counter == 100 && (~status[24] | do_erase)) force_erase <= 1;
   end
end

wire  [15:0] joyA,joyB,joyC,joyD;
wire  [15:0] joy = joyA | joyB | joyC | joyD;

reg          status_set;
reg          status_in_98;
wire [127:0] status_in = {status[127:99], status_in_98, status[97:0]};
wire [127:0] status;

wire         forced_scandoubler;

wire         ioctl_wr;
wire  [24:0] ioctl_addr;
wire   [7:0] ioctl_data;
wire   [9:0] ioctl_index;
wire         ioctl_download;

reg    [3:0] sysconfig=4'b0001;
wire         cfg_chipset=sysconfig[0];
wire         cfg_force64=sysconfig[1];
wire         cfg_cpslk=sysconfig[2];
wire         cfg_azerty=sysconfig[3];

wire  [31:0] sd_lba[2];
wire   [5:0] sd_blk_cnt[2];
wire   [1:0] sd_rd;
wire   [1:0] sd_wr;
wire   [1:0] sd_ack;
wire  [15:0] sd_buff_addr;
wire   [7:0] sd_buff_dout;
wire   [7:0] sd_buff_din[2];
wire         sd_buff_wr;
wire   [1:0] img_mounted;
wire  [31:0] img_size;
wire         img_readonly;

wire  [24:0] ps2_mouse;
wire  [10:0] ps2_key;
wire   [2:0] ps2_kbd_led_status = {2'b00, (pure64 ? sftlk_sense : ~cpslk_sense)};
wire   [2:0] ps2_kbd_led_use = 3'b001;

wire         sftlk_sense;
wire         cpslk_sense;
wire         d4080_sense;
wire         noscr_sense;

wire   [1:0] buttons;
wire  [21:0] gamma_bus;

wire   [7:0] pd1,pd2,pd3,pd4;

wire  [64:0] RTC;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(2), .BLKSZ(1)) hps_io
(
   .clk_sys(clk_sys),
   .HPS_BUS(HPS_BUS),

   .joystick_0(joyA),
   .joystick_1(joyB),
   .joystick_2(joyC),
   .joystick_3(joyD),

   .paddle_0(pd1),
   .paddle_1(pd2),
   .paddle_2(pd3),
   .paddle_3(pd4),

   .status(status),
   .status_menumask({
      /* C */ ifr_attached,
      /* B */ cart_attached,
      /* A */ cfg_force64,
      /* 9 */ ~status[69],
      /* 8 */ ~status[66],
      /* 7 */ status[58],
      /* 6 */ vdcVersion,
      /* 5 */ sidVersion[1],
      /* 4 */ sidVersion[0],
      /* 3 */ tap_loaded,
      /* 2 */ status[92],
      /* 1 */ |vcrop,
      /* 0 */ status[56]
   }),
   .status_in(status_in),
   .status_set(status_set),
   .buttons(buttons),
   .forced_scandoubler(forced_scandoubler),
   .gamma_bus(gamma_bus),

   .sd_lba(sd_lba),
   .sd_blk_cnt(sd_blk_cnt),
   .sd_rd(sd_rd),
   .sd_wr(sd_wr),
   .sd_ack(sd_ack),

   .sd_buff_addr(sd_buff_addr),
   .sd_buff_dout(sd_buff_dout),
   .sd_buff_din(sd_buff_din),
   .sd_buff_wr(sd_buff_wr),
   .img_mounted(img_mounted),
   .img_size(img_size),
   .img_readonly(img_readonly),

   .ps2_key(ps2_key),
   .ps2_mouse(ps2_mouse),
   .ps2_kbd_led_status(ps2_kbd_led_status),
   .ps2_kbd_led_use(ps2_kbd_led_use),

   .RTC(RTC),

   .ioctl_download(ioctl_download),
   .ioctl_index(ioctl_index),
   .ioctl_wr(ioctl_wr),
   .ioctl_addr(ioctl_addr),
   .ioctl_dout(ioctl_data),
   .ioctl_wait(ioctl_req_wr|reset_wait|prg_reset),

   .info_req(info_req),
   .info(info)
);

function auto_config;
   input [1:0] st;
   input       cfg;
   begin
      return |st ? st[1] : cfg;
   end
endfunction
wire       ciaVersion = auto_config(status[46:45], cfg_chipset);
wire [1:0] sidVersion = {auto_config(status[16:15], cfg_chipset), auto_config(status[14:13], cfg_chipset)};
wire       vdcVersion = auto_config(status[81:80], cfg_chipset);
wire       cpslk_mode = auto_config(status[97:96], cfg_cpslk);
wire       video_mode = ~auto_config(status[100:99], status[98]);
wire       pure64     = cfg_force64 | (c128_n & status[93]);

always @(posedge clk_sys) begin
   reg d4080_sense_d;

   d4080_sense_d <= d4080_sense;
   if (RESET) begin
      status_in_98 <= status[98];
      status_set <= 0;
   end
   else if (status_set) begin
      if (status_in_98 == status[98])
         status_set <= 0;
   end
   else if (pure64 && status[98]) begin
      status_in_98 <= 0;
      status_set <= 1;
   end
   else if (d4080_sense != d4080_sense_d) begin
      status_in_98 <= ~status[98];
      status_set <= 1;
   end
   else
      status_in_98 <= status[98];
end

wire bootrom  = ioctl_index[5:0] == 0;                                 // MRA index 0 or any boot*.rom
wire load_rom = ioctl_index == {2'd0, 6'd0} || ioctl_index[5:0] == 3;  // MRA index 0, boot0.rom or OSD "load system ROMs"
wire load_drv = ioctl_index == {2'd1, 6'd0} || ioctl_index[5:0] == 4;  // boot1.rom or OSD "load drive ROMs"
wire load_ifr = ioctl_index == {2'd2, 6'd0} || ioctl_index[5:0] == 6;  // boot2.rom or OSD "load Internal Function ROM"
wire load_efr = ioctl_index == {2'd3, 6'd0};                           // boot3.rom
wire load_cfg = ioctl_index == {2'd0, 6'd1};                           // MRA index 1
wire load_prg = ioctl_index == {2'd0, 6'd2};                           // OSD "load *.PRG"
wire load_crt = ioctl_index == {2'd1, 6'd2} || ioctl_index[5:0] == 5;  // OSD "load *.CRT" or "Boot Cartridge"
wire load_reu = ioctl_index == {2'd2, 6'd2};                           // OSD "load *.REU"
wire load_tap = ioctl_index == {2'd3, 6'd2};                           // OSD "load *.TAP"
wire load_flt = ioctl_index[5:0] == 7;                                 // OSD "load Custom Filters"

wire sysRom;
wire [4:0] sysRomBank;
wire game;
wire game_mmu;
wire exrom;
wire exrom_mmu;
wire io_rom;
wire cart_ce;
wire cart_we;
wire nmi;
wire cart_oe;
wire IOF_rd;
wire  [7:0] cart_data;
wire [24:0] cart_addr;
wire        cart_floating;

cartridge #(
   .RAM_ADDR(RAM_ADDR),
   .CRM_ADDR(CRM_ADDR),
   .ROM_ADDR(ROM_ADDR),
   .IFR_ADDR(IFR_ADDR),
   .CRT_ADDR(CRT_ADDR),
   .GEO_ADDR(GEO_ADDR)
) cartridge
(
   .clk32(clk_sys),
   .reset_n(reset_n),

   .cart_loading(ioctl_download && load_crt),
   .cart_c128(cart_c128),
   .cart_id(cart_attached ? cart_id : status[52] ? 8'd99 : 8'd255),
   .cart_int_rom(cart_int_rom),
   .cart_ext_rom(cart_ext_rom),
   .cart_exrom(cart_exrom),
   .cart_game(cart_game),
   .cart_bank_laddr(cart_bank_laddr),
   .cart_bank_size(cart_bank_size),
   .cart_bank_num(cart_bank_num),
   .cart_bank_type(cart_bank_type),
   .cart_bank_raddr(ioctl_load_addr),
   .cart_bank_wr(cart_hdr_wr),
   .cart_bank_int(d7port[4:0]),

   .sysRom(sysRom),
   .sysRomBank(sysRomBank),

   .exrom(exrom),
   .exrom_in(exrom_mmu),
   .game(game),
   .game_in(game_mmu),

   .c128_n(c128_n),
   .romFL(romFL),
   .romFH(romFH),
   .romL(romL),
   .romH(romH),
   .UMAXromH(UMAXromH),
   .IOE(IOE),
   .IOF(IOF),
   .mem_write(ram_we),
   .mem_ce(ram_ce),
   .mem_ce_out(cart_ce),
   .mem_write_out(cart_we),
   .IO_rom(io_rom),
   .IO_rd(cart_oe),
   .IO_data(cart_data),
   .addr_in(c128_addr),
   .data_in(c128_data_out),
   .addr_out(cart_addr),
   .data_floating(cart_floating),

   .freeze_key(freeze_key),
   .mod_key(mod_key),
   .nmi(nmi),
   .nmi_ack(nmi_ack)
);

wire        dma_req;
wire        dma_cycle;
wire [15:0] dma_addr;
wire  [7:0] dma_dout;
wire  [7:0] dma_din;
wire        dma_we;
wire        ext_cycle;

wire [24:0] reu_ram_addr;
wire  [7:0] reu_ram_dout;
wire        reu_ram_we;

wire  [7:0] reu_dout;
wire        reu_irq;

wire        reu_oe  = IOF && reu_cfg;
wire  [1:0] reu_cfg = status[54:53];

reu #(
   .REU_ADDR(REU_ADDR)
) reu
(
   .clk(clk_sys),
   .reset(~reset_n),
   .cfg(reu_cfg),

   .dma_req(dma_req),

   .dma_cycle(dma_cycle),
   .dma_addr(dma_addr),
   .dma_dout(dma_dout),
   .dma_din(dma_din),
   .dma_we(dma_we),

   .ram_cycle(ext_cycle),
   .ram_addr(reu_ram_addr),
   .ram_dout(reu_ram_dout),
   .ram_din(sdram_data),
   .ram_we(reu_ram_we),

   .cpu_addr(c128_addr[15:0]),
   .cpu_dout(c128_data_out),
   .cpu_din(reu_dout),
   .cpu_we(ram_we),
   .cpu_cs(IOF),

   .irq(reu_irq)
);

reg ext_cycle_d;
always @(posedge clk_sys) ext_cycle_d <= ext_cycle;
wire reu_ram_ce = ~ext_cycle_d & ext_cycle & dma_req;

// rearrange joystick contacts for c64
wire [6:0] joyA_int = joy[9:8] ? 7'd0 : {joyA[6:4], joyA[0], joyA[1], joyA[2], joyA[3]};
wire [6:0] joyB_int = joy[9:8] ? 7'd0 : {joyB[6:4], joyB[0], joyB[1], joyB[2], joyB[3]};
wire [6:0] joyC_c64 = joy[9:8] ? 7'd0 : {joyC[6:4], joyC[0], joyC[1], joyC[2], joyC[3]};
wire [6:0] joyD_c64 = joy[9:8] ? 7'd0 : {joyD[6:4], joyD[0], joyD[1], joyD[2], joyD[3]};

// swap joysticks if requested
wire [6:0] joyA_c64 = status[3] ? joyB_int : joyA_int;
wire [6:0] joyB_c64 = status[3] ? joyA_int : joyB_int;

wire [7:0] paddle_1 = status[3] ? pd3 : pd1;
wire [7:0] paddle_2 = status[3] ? pd4 : pd2;
wire [7:0] paddle_3 = status[3] ? pd1 : pd3;
wire [7:0] paddle_4 = status[3] ? pd2 : pd4;

wire       paddle_1_btn = ~|joy[9:8] & (status[3] ? joyC[7] : joyA[7]);
wire       paddle_2_btn = ~|joy[9:8] & (status[3] ? joyD[7] : joyB[7]);
wire       paddle_3_btn = ~|joy[9:8] & (status[3] ? joyA[7] : joyC[7]);
wire       paddle_4_btn = ~|joy[9:8] & (status[3] ? joyB[7] : joyD[7]);

wire [1:0] pd12_mode = status[27:26];
wire [1:0] pd34_mode = status[29:28];

reg [24:0] ioctl_load_addr;
reg        ioctl_req_wr;

reg        cart_c128;
reg [15:0] cart_id;
reg [15:0] cart_bank_laddr;
reg [15:0] cart_bank_size;
reg [15:0] cart_bank_num;
reg  [7:0] cart_bank_type;
reg  [7:0] cart_exrom;
reg  [7:0] cart_game;
reg        cart_attached = 0;
reg  [3:0] cart_hdr_cnt;
reg        cart_hdr_wr;
reg [31:0] cart_blk_len;

reg        go64;
reg        force_erase;
reg        prg_reset;
reg        erasing;

reg        inj_meminit = 0;

wire       io_cycle;
reg        io_cycle_ce;
reg        io_cycle_we;
reg [24:0] io_cycle_addr;
reg  [7:0] io_cycle_data;

reg  [6:0] cart_int_rom = 0;
reg  [1:0] cart_ext_rom = 0;
reg        ifr_attached = 0;
reg        rom_loading, rom_loaded = 0;
reg        drv_loading, drv_loaded = 0;

// SDRAM layout
// -- all blocks must be aligned on that block's size boundaries unless specified otherwise,
//    so a 64k block must start at a 64k boundary, etc.
localparam RAM_ADDR = 25'h0000000;  // System RAM: 256k
localparam CRM_ADDR = 25'h0040000;  // Cartridge RAM: 64k
localparam ROM_ADDR = 25'h0060000;  // System ROM: 72k (align on 128k)       loaded from boot0.rom or MRA (required)
localparam DRV_ADDR = 25'h0080000;  // Drive ROM: 512k                       loaded from boot0.rom, boot1.rom or MRA (required)
localparam CRT_ADDR = 25'h0100000;  // Cartridge: 1M                         can be loaded from boot0.rom, boot3.rom or MRA (first 32k, optional)
localparam IFR_ADDR = 25'h0200000;  // Internal function ROM: 1M             can be loaded from boot2.rom or MRA (optional)
localparam TAP_ADDR = 25'h0300000;  // Tape buffer (not aligned)
localparam GEO_ADDR = 25'h0C00000;  // GeoRAM: 4M
localparam REU_ADDR = 25'h1000000;  // REU: 16M

localparam ROM_SIZE = 25'h0012000;  // expected size of boot0.rom
localparam DRV_SIZE = 25'h0060000;  // max size of boot1.rom
localparam EFR_SIZE = 25'h0008000;  // max size of external function rom
localparam IFR_SIZE = 25'h0100000;  // max size of internal function rom

// MRA layout
localparam MRA_ROM_START = 25'h0;
localparam MRA_ROM_END   = MRA_ROM_START+ROM_SIZE;
localparam MRA_EFR_START = 25'h18000;
localparam MRA_EFR_END   = MRA_EFR_START+EFR_SIZE;
localparam MRA_DRV_START = 25'h20000;
localparam MRA_DRV_END   = MRA_DRV_START+DRV_SIZE;
localparam MRA_IFR_START = 25'h80000;
localparam MRA_IFR_END   = MRA_IFR_START+IFR_SIZE;

always @(posedge clk_sys) begin
   reg  [4:0] erase_to;
   reg        old_download;
   reg        erase_cram;
   reg        io_cycleD;
   reg        old_meminit;
   reg [15:0] inj_end;
   reg  [7:0] inj_meminit_data;
   reg        prg_reseting;
   reg        ioctl_ignore;

   old_download <= ioctl_download;
   io_cycleD <= io_cycle;
   cart_hdr_wr <= 0;

   if (~io_cycle & io_cycleD) begin
      io_cycle_ce <= 1;
      io_cycle_we <= 0;

      io_cycle_addr <= drive_rom_addr + DRV_ADDR;

      if (tap_io_cycle)
         io_cycle_addr <= tap_play_addr + TAP_ADDR;

      if (ioctl_req_wr) begin
         ioctl_req_wr <= 0;
         ioctl_load_addr <= ioctl_load_addr + 1'b1;
         if (!load_rom || !ioctl_ignore) begin
            io_cycle_we <= 1;
            io_cycle_addr <= ioctl_load_addr;
            if (erasing) io_cycle_data <= {8{ioctl_load_addr[6]}};
            else if (inj_meminit) io_cycle_data <= inj_meminit_data;
            else io_cycle_data <= ioctl_data;
         end
      end
   end

   if (io_cycle & io_cycleD) {io_cycle_ce, io_cycle_we} <= 0;

   if (ioctl_wr) begin
      if (load_rom) begin
         if (ioctl_addr == MRA_ROM_START) begin
            ioctl_load_addr <= ROM_ADDR;
            if (bootrom && rom_loaded) begin
               ioctl_ignore = 1;
            end
            else begin
               ioctl_ignore = 0;
               rom_loaded <= 0;
               rom_loading <= 1;
            end
         end
         else if (ioctl_addr == MRA_DRV_START && bootrom) begin
            ioctl_load_addr <= DRV_ADDR;
            ioctl_ignore = drv_loaded;
            drv_loading <= ~drv_loaded;
         end
         else if (ioctl_addr == MRA_EFR_START && bootrom) begin
            ioctl_load_addr <= CRT_ADDR;
            ioctl_ignore = cart_attached;
            if (!cart_attached) begin
               cart_ext_rom <= 0;
               cart_c128 <= 1;
               cart_id <= 0;
            end
         end
         else if (ioctl_addr == MRA_IFR_START && bootrom) begin
            ioctl_load_addr <= IFR_ADDR;
            ioctl_ignore = ifr_attached;
            if (!ifr_attached) begin
               cart_int_rom <= 0;
            end
         end
         else if (ioctl_addr == MRA_ROM_END || ioctl_addr == MRA_DRV_END || ioctl_addr == MRA_EFR_END || ioctl_addr == MRA_IFR_END)
            ioctl_ignore = 1;

         if (|ioctl_data && ~&ioctl_data && !ioctl_ignore) begin
            if (ioctl_addr >= MRA_EFR_START              && ioctl_addr < MRA_EFR_END) cart_ext_rom[0] <= 1;
            if (ioctl_addr >= MRA_EFR_START + 25'h004000 && ioctl_addr < MRA_EFR_END) cart_ext_rom[1] <= 1;

            if (ioctl_addr >= MRA_IFR_START              && ioctl_addr < MRA_IFR_END) cart_int_rom[0] <= 1;
            if (ioctl_addr >= MRA_IFR_START + 25'h004000 && ioctl_addr < MRA_IFR_END) cart_int_rom[1] <= 1;
            if (ioctl_addr >= MRA_IFR_START + 25'h008000 && ioctl_addr < MRA_IFR_END) cart_int_rom[2] <= 1;
            if (ioctl_addr >= MRA_IFR_START + 25'h010000 && ioctl_addr < MRA_IFR_END) cart_int_rom[3] <= 1;
            if (ioctl_addr >= MRA_IFR_START + 25'h020000 && ioctl_addr < MRA_IFR_END) cart_int_rom[4] <= 1;
            if (ioctl_addr >= MRA_IFR_START + 25'h040000 && ioctl_addr < MRA_IFR_END) cart_int_rom[5] <= 1;
            if (ioctl_addr >= MRA_IFR_START + 25'h080000 && ioctl_addr < MRA_IFR_END) cart_int_rom[6] <= 1;
         end

         ioctl_req_wr <= 1;
      end

      if (load_drv && !(drv_loaded && bootrom)) begin
         if (ioctl_addr == 0) begin
            ioctl_load_addr <= DRV_ADDR;
            drv_loading <= 1;
            drv_loaded <= 0;
         end

         if (ioctl_addr < DRV_SIZE)
            ioctl_req_wr <= 1;
      end

      if (load_ifr) begin
         if (ioctl_addr == 0) begin
            ioctl_load_addr <= IFR_ADDR;
            ifr_attached <= 0;
            cart_int_rom <= 7'b1;
         end

         if (ioctl_addr < IFR_SIZE && |ioctl_data && ~&ioctl_data) begin
            if (ioctl_addr[14]) cart_int_rom[1:0] <= '1;
            if (ioctl_addr[15]) cart_int_rom[2:0] <= '1;
            if (ioctl_addr[16]) cart_int_rom[3:0] <= '1;
            if (ioctl_addr[17]) cart_int_rom[4:0] <= '1;
            if (ioctl_addr[18]) cart_int_rom[5:0] <= '1;
            if (ioctl_addr[19]) cart_int_rom[6:0] <= '1;
         end

         if (ioctl_addr < IFR_SIZE)
            ioctl_req_wr <= 1;
      end

      if (load_efr) begin
         if (ioctl_addr == 0) begin
            ioctl_load_addr <= CRT_ADDR;
            cart_attached <= 0;
            cart_ext_rom <= 2'b1;
            cart_c128 <= 1;
            cart_id <= 0;
         end

         if (ioctl_addr < EFR_SIZE && |ioctl_data && ~&ioctl_data) begin
            if (ioctl_addr[14]) cart_ext_rom[1:0] <= '1;
         end

         if (ioctl_addr < EFR_SIZE)
            ioctl_req_wr <= 1;
      end

      if (load_cfg) begin
         sysconfig <= ioctl_data[3:0];
      end

      if (load_prg) begin
         // PRG header
         // Load address low-byte
         if (ioctl_addr == 0)
            inj_end[7:0] <= ioctl_data;
         // Load address high-byte
         else if (ioctl_addr == 1) begin
            inj_end[15:8] <= ioctl_data;
            if (~status[50]) begin
               go64 <= ~(cfg_force64 | ioctl_data[4]);
               prg_reset <= 1;
            end
         end
         else begin
            if (ioctl_addr == 2) ioctl_load_addr <= inj_end;
            ioctl_req_wr <= 1;
            inj_end <= inj_end + 1'b1;
         end
      end

      if (load_crt) begin
         if (ioctl_addr == 0) begin
            ioctl_load_addr <= CRT_ADDR;
            cart_blk_len <= 0;
            cart_hdr_cnt <= 0;
            cart_attached <= 0;
            cart_ext_rom <= 0;
         end

         if (ioctl_addr == 8'h01) cart_c128       <= ioctl_data == 8'h31;
         if (ioctl_addr == 8'h02) cart_c128       <= cart_c128 & ioctl_data == 8'h32;
         if (ioctl_addr == 8'h03) cart_c128       <= cart_c128 & ioctl_data == 8'h38;
         if (ioctl_addr == 8'h16) cart_id[15:8]   <= ioctl_data;
         if (ioctl_addr == 8'h17) cart_id[7:0]    <= ioctl_data;
         if (ioctl_addr == 8'h18) cart_exrom[7:0] <= ioctl_data;
         if (ioctl_addr == 8'h19) cart_game[7:0]  <= ioctl_data;

         if (ioctl_addr >= 8'h40) begin
            if (cart_blk_len == 0 & cart_hdr_cnt == 0) begin
               cart_hdr_cnt <= 1;
               if (cart_c128)
                  if (ioctl_load_addr[13:0] != 0) begin
                     // align to 16KiB boundary
                     ioctl_load_addr[13:0] <= 0;
                     ioctl_load_addr[24:14] <= ioctl_load_addr[24:14] + 1'b1;
                  end
               else
                  if (ioctl_load_addr[12:0] != 0) begin
                     // align to 8KiB boundary
                     ioctl_load_addr[12:0] <= 0;
                     ioctl_load_addr[24:13] <= ioctl_load_addr[24:13] + 1'b1;
                  end
            end
            else if (cart_hdr_cnt != 0) begin
               cart_hdr_cnt <= cart_hdr_cnt + 1'b1;
               if (cart_hdr_cnt == 4)  cart_blk_len[31:24]  <= ioctl_data;
               if (cart_hdr_cnt == 5)  cart_blk_len[23:16]  <= ioctl_data;
               if (cart_hdr_cnt == 6)  cart_blk_len[15:8]   <= ioctl_data;
               if (cart_hdr_cnt == 7)  cart_blk_len[7:0]    <= ioctl_data;
               if (cart_hdr_cnt == 8)  cart_blk_len         <= cart_blk_len - 8'h10;
               if (cart_hdr_cnt == 9)  cart_bank_type       <= ioctl_data;
               if (cart_hdr_cnt == 10) cart_bank_num[15:8]  <= ioctl_data;
               if (cart_hdr_cnt == 11) cart_bank_num[7:0]   <= ioctl_data;
               if (cart_hdr_cnt == 12) cart_bank_laddr[15:8]<= ioctl_data;
               if (cart_hdr_cnt == 13) cart_bank_laddr[7:0] <= ioctl_data;
               if (cart_hdr_cnt == 14) cart_bank_size[15:8] <= ioctl_data;
               if (cart_hdr_cnt == 15) cart_bank_size[7:0]  <= ioctl_data;
               if (cart_hdr_cnt == 15) cart_hdr_wr <= 1;
            end
            else begin
               cart_ext_rom[ioctl_load_addr[14]] <= 1;
               cart_blk_len <= cart_blk_len - 1'b1;
               ioctl_req_wr <= 1;
            end
         end
      end

      if (load_tap) begin
         if (ioctl_addr == 0)  ioctl_load_addr <= TAP_ADDR;
         if (ioctl_addr == 12) tap_version <= ioctl_data[1:0];
         ioctl_req_wr <= 1;
      end

      if (load_reu) begin
         if (ioctl_addr == 0) ioctl_load_addr <= REU_ADDR;
         ioctl_req_wr <= 1;
      end
   end

   if (old_download && !ioctl_download) begin
      rom_loading <= 0;
      drv_loading <= 0;

      if (load_rom && ioctl_addr >= ROM_SIZE && rom_loading) begin
         rom_loaded <= 1;
      end
      if ((load_rom || load_drv) && drv_loading) begin
         drv_loaded <= 1;
      end
      if (load_rom || load_crt || load_efr) begin
         erase_cram <= |cart_ext_rom;
         cart_attached <= |cart_ext_rom;
      end
      if (load_rom || load_ifr) begin
         ifr_attached <= |cart_int_rom;
      end
   end

   // Wait for PRG reset to finish
   if (prg_reset && reset_wait) begin
      prg_reset <= 0;
      prg_reseting <= 1;
   end
   if (prg_reseting && !reset_wait) begin
      go64 <= 0;
      prg_reseting <= 0;
   end

   // meminit for RAM injection
   if (old_download != ioctl_download && load_prg && !inj_meminit) begin
      inj_meminit <= 1;
      ioctl_load_addr <= 0;
   end

   if (inj_meminit) begin
      if (!ioctl_req_wr) begin
         // check if done
         if (ioctl_load_addr == 'h100) begin
            inj_meminit <= 0;
         end
         else begin
            ioctl_req_wr <= 1;

            // Initialize BASIC pointers to simulate the BASIC LOAD command
            if (c128_n)
               // C64 mode
               case(ioctl_load_addr)
                  // TXT (2B-2C)
                  // Set these two bytes to $01, $08 just as they would be on reset (the BASIC LOAD command does not alter these)
                  'h2B: inj_meminit_data <= 'h01;
                  'h2C: inj_meminit_data <= 'h08;

                  // SAVE_START (AC-AD)
                  // Set these two bytes to zero just as they would be on reset (the BASIC LOAD command does not alter these)
                  'hAC, 'hAD: inj_meminit_data <= 'h00;

                  // VAR (2D-2E), ARY (2F-30), STR (31-32), LOAD_END (AE-AF)
                  // Set these just as they would be with the BASIC LOAD command (essentially they are all set to the load end address)
                  'h2D, 'h2F, 'h31, 'hAE: inj_meminit_data <= inj_end[7:0];
                  'h2E, 'h30, 'h32, 'hAF: inj_meminit_data <= inj_end[15:8];

                  default: begin
                     ioctl_req_wr <= 0;

                     // advance the address
                     ioctl_load_addr <= ioctl_load_addr + 1'b1;
                  end
               endcase
            else
               // C128 mode
               case(ioctl_load_addr)
                  // TXT (2D-2E)
                     // Set these two bytes to $01, $1C just as they would be on reset (the BASIC LOAD command does not alter these)
                  'h2D: inj_meminit_data <= 'h01;
                  'h2E: inj_meminit_data <= 'h1C;

                  // SAVE_START (AC-AD)
                  // Set these two bytes to zero just as they would be on reset (the BASIC LOAD command does not alter these)
                  'hAC, 'hAD: inj_meminit_data <= 'h00;

                  // VAR (2F-30), ARY (31-32), STR (33-34), LOAD_END (AE-AF)
                  // Set these just as they would be with the BASIC LOAD command (essentially they are all set to the load end address)
                  'h2F, 'h31, 'h33, 'hAE: inj_meminit_data <= inj_end[7:0];
                  'h30, 'h32, 'h34, 'hAF: inj_meminit_data <= inj_end[15:8];

                  default: begin
                     ioctl_req_wr <= 0;

                     // advance the address
                     ioctl_load_addr <= ioctl_load_addr + 1'b1;
                  end
               endcase
         end
      end
   end

   old_meminit <= inj_meminit;
   start_strk  <= old_meminit & ~inj_meminit;

   if (status[17]) begin
      cart_attached <= 0;
      cart_ext_rom <= 0;
   end

   if (status[82]) begin
      ifr_attached <= 0;
      cart_int_rom <= 0;
   end

   if (!erasing && force_erase) begin
      erasing <= 1;
      ioctl_load_addr <= 0;
   end

   if (erasing && !ioctl_req_wr) begin
      erase_to <= erase_to + 1'b1;
      if (&erase_to) begin
         if (ioctl_load_addr < (erase_cram ? 'h4FFFF : 'h3FFFF))
            ioctl_req_wr <= 1;
         else begin
            erasing <= 0;
            erase_cram <= 0;
         end
      end
   end
end

reg        start_strk = 0;
reg        reset_keys = 0;
reg [10:0] key = 0;
always @(posedge clk_sys) begin
   reg  [3:0] act = 0;
   reg        joy_finish = 0;
   reg [17:0] joy_last = 0;
   reg [17:0] joy_key;
   int        to;

   reset_keys <= 0;

   joy_key =(joy[9:8] == 3) ?
            (joy[0] ? 18'h005 : joy[1] ? 18'h006 : joy[2] ? 18'h004 : joy[3] ? 18'h00C  :
             joy[4] ? 18'h003 : joy[5] ? 18'h00B : joy[6] ? 18'h083 : joy[7] ? 18'h00A  : 18'h0):
            (joy[9]) ?
            (joy[0] ? 18'h016 : joy[1] ? 18'h01E : joy[2] ? 18'h026 : joy[3] ? 18'h025  :
             joy[4] ? 18'h02E : joy[5] ? 18'h045 : joy[6] ? 18'h035 : joy[7] ? 18'h031  : 18'h0):
            (joy[0] ? 18'h174 : joy[1] ? 18'h16B : joy[2] ? 18'h172 : joy[3] ? 18'h175  :
             joy[4] ? 18'h05A : joy[5] ? 18'h029 : joy[6] ? 18'h169 : joy[7] ? {9'h012, 9'h169} : 18'h0);

   if(~reset_n) {joy_finish, act} <= 0;

   if(joy[9:8]) begin
      joy_finish <= 1;
      if(!joy[7:0] && joy_last) begin
         joy_last <= 0;
         reset_keys <= 1;
      end
      else if(!joy_last[8:0] && joy_key) begin
         to <= to + 1'd1;
         if(joy_last[17:9] != joy_key[17:9]) begin
            joy_last[17:9] <= joy_key[17:9];
            key <= joy_key[17:9];
            key[9] <= 1;
            key[10] <= ~key[10];
         end
         else if(to > 640000 && joy_last[8:0] != joy_key[8:0]) begin
            joy_last[8:0] <= joy_key[8:0];
            key <= joy_key[8:0];
            key[9] <= 1;
            key[10] <= ~key[10];
         end
      end
      else begin
         to <= 0;
      end
   end
   else if(joy_finish) begin
      joy_last   <= 0;
      key        <= 0;
      key[10]    <= ps2_key[10];
      joy_finish <= 0;
      reset_keys <= 1;
   end
   else if(act) begin
      to <= to + 1;
      if(to > 1280000) begin
         to <= 0;
         act <= act + 1'd1;
         case(act)
            // PS/2 scan codes
             1: key <= 'h2d;  // R
             3: key <= 'h3c;  // U
             5: key <= 'h31;  // N
             7: key <= 'h5a;  // <RETURN>
             9: key <= 'h00;
            10: act <= 0;
         endcase
         key[9]  <= act[0];
         key[10] <= (act >= 9) ? ps2_key[10] : ~key[10];
      end
   end
   else begin
      to <= 0;
		key <= {ps2_key[10], ps2_key[9] & disk_ready, ps2_key[8:0]};
   end
   if(start_strk & ~status[50]) begin
      act <= 1;
      key <= 0;
   end
end

assign SDRAM_CKE  = 1;

wire [7:0] sdram_data;
sdram sdram
(
   .sd_addr(SDRAM_A),
   .sd_data(SDRAM_DQ),
   .sd_ba(SDRAM_BA),
   .sd_cs(SDRAM_nCS),
   .sd_we(SDRAM_nWE),
   .sd_ras(SDRAM_nRAS),
   .sd_cas(SDRAM_nCAS),
   .sd_clk(SDRAM_CLK),
   .sd_dqm({SDRAM_DQMH,SDRAM_DQML}),

   .clk(clk64),
   .init(~pll_locked),
   .refresh(refresh),
   .addr( io_cycle ? io_cycle_addr : ext_cycle ? reu_ram_addr : cart_addr     ),
   .ce  ( io_cycle ? io_cycle_ce   : ext_cycle ? reu_ram_ce   : cart_ce       ),
   .we  ( io_cycle ? io_cycle_we   : ext_cycle ? reu_ram_we   : cart_we       ),
   .din ( io_cycle ? io_cycle_data : ext_cycle ? reu_ram_dout : c128_data_out ),
   .dout( sdram_data )
);

wire  [7:0] c128_data_out;
wire [17:0] c128_addr;
wire        c64_pause;
wire        refresh;
wire        ram_ce;
wire        ram_we;
wire        nmi_ack;
wire        freeze_key;
wire        mod_key;

wire        IOE;
wire        IOF;
wire        romFL;
wire        romFH;
wire        romL;
wire        romH;
wire        UMAXromH;

wire [7:0]  d7port;
wire        d7port_trig;

wire [17:0] audio_l,audio_r;

wire        ntsc = status[2];

wire        vicHsync, vicVsync;
wire  [7:0] vicR, vicG, vicB;

wire        vdcHsync, vdcVsync;
wire  [7:0] vdcR, vdcG, vdcB;

wire        c64_iec_atn;
wire        c64_iec_clk_o;
wire        c64_iec_data_o;
wire        c64_iec_srq_n_o;
wire        c64_iec_clk_i;
wire        c64_iec_data_i;
wire        c64_iec_srq_n_i;

fpga64_sid_iec #(
`ifdef REDUCE_VDC_RAM
   .VDC_ADDR_BITS(14)
`else
   .VDC_ADDR_BITS(16)
`endif
) fpga64 (
   .clk32(clk_sys),
   .clk_vdc(clk_vdc),

   .reset_n(reset_n),
   .pause(freeze),
   .pause_out(c64_pause),

   .turbo_mode(disk_access ? 3'b000 : {status[101], status[49:48]}),
   .force64(cfg_force64),
   .pure64(pure64),
   .d4080_sel(~status[98]),
   .sys256k(status[87]),

   .vdcVersion(vdcVersion),
`ifdef REDUCE_VDC_RAM
   .vdc64k(0),
`else
   .vdc64k(status[88]|vdcVersion),
`endif
   .vdcInitRam(~status[24]),
   .vdcPalette(status[92:89]),
`ifdef VDC_XRAY
   .vdcDebug(status[127]),
`else
   .vdcDebug(0),
`endif

   .go64(go64),
   .ps2_key(key),
   .kbd_reset((~reset_n & ~status[1]) | reset_keys),
   .shift_mod(~status[60:59]),
   .azerty(cfg_azerty),
   .cpslk_mode(cpslk_mode),
   .sftlk_sense(sftlk_sense),
   .cpslk_sense(cpslk_sense),
   .d4080_sense(d4080_sense),
   .noscr_sense(noscr_sense),

   .ramAddr(c128_addr),
   .ramDout(c128_data_out),
   .ramDin(sdram_data),
   .ramDinFloat(cart_floating),
   .ramCE(ram_ce),
   .ramWE(ram_we),

   .vic_variant(cfg_force64 ? status[35:34] : 2'b01),
   .ntscmode(ntsc),
   .vicJailbars(status[95:94]),

   .vicHsync(vicHsync),
   .vicVsync(vicVsync),
   .vicR(vicR),
   .vicG(vicG),
   .vicB(vicB),

   .vdcHsync(vdcHsync),
   .vdcVsync(vdcVsync),
   .vdcR(vdcR),
   .vdcG(vdcG),
   .vdcB(vdcB),

   .game(game),
   .game_mmu(game_mmu),
   .exrom(exrom),
   .exrom_mmu(exrom_mmu),
   .UMAXromH(UMAXromH),
   .irq_n(1),
   .nmi_n(~nmi),
   .nmi_ack(nmi_ack),
   .freeze_key(freeze_key),
   .tape_play(tape_play),
   .mod_key(mod_key),
   .romFL(romFL),
   .romFH(romFH),
   .romL(romL),
   .romH(romH),
   .ioe(IOE),
   .iof(IOF),
   .io_rom(io_rom),
   .io_ext(cart_oe | reu_oe | opl_en),
   .io_data(cart_oe ? cart_data : reu_oe ? reu_dout : opl_dout),

   .sysRom(sysRom),
   .sysRomBank(sysRomBank),

   .dma_req(dma_req),
   .dma_cycle(dma_cycle),
   .dma_addr(dma_addr),
   .dma_dout(dma_dout),
   .dma_din(dma_din),
   .dma_we(dma_we),
   .irq_ext_n(~reu_irq),

   .cia_mode(ciaVersion),

   .joya({(pd12_mode && !joy[9:8]) ? joyA_c64[6:5] : 2'b00, joyA_c64[4:0] | {1'b0, pd12_mode[1] & paddle_2_btn, pd12_mode[1] & paddle_1_btn, 2'b00} | {pd12_mode[0] & mouse_btn[0], 3'b000, pd12_mode[0] & mouse_btn[1]}}),
   .joyb({(pd34_mode && !joy[9:8]) ? joyB_c64[6:5] : 2'b00, joyB_c64[4:0] | {1'b0, pd34_mode[1] & paddle_4_btn, pd34_mode[1] & paddle_3_btn, 2'b00} | {pd34_mode[0] & mouse_btn[0], 3'b000, pd34_mode[0] & mouse_btn[1]}}),

   .pot1(pd12_mode[1] ? paddle_1 : pd12_mode[0] ? mouse_x : {8{joyA_c64[5]}}),
   .pot2(pd12_mode[1] ? paddle_2 : pd12_mode[0] ? mouse_y : {8{joyA_c64[6]}}),
   .pot3(pd34_mode[1] ? paddle_3 : pd34_mode[0] ? mouse_x : {8{joyB_c64[5]}}),
   .pot4(pd34_mode[1] ? paddle_4 : pd34_mode[0] ? mouse_y : {8{joyB_c64[6]}}),

   .io_cycle(io_cycle),
   .ext_cycle(ext_cycle),
   .refresh(refresh),

   .sid_ld_clk(clk_sys),
   .sid_ld_addr(sid_ld_addr),
   .sid_ld_data(sid_ld_data),
   .sid_ld_wr(sid_ld_wr),
   .sid_mode(status[21:20]),
   .sid_filter(2'b11),
   .sid_ver(sidVersion),
   .sid_cfg({status[68:67],status[65:64]}),
   .sid_fc_off_l(status[66] ? (13'h600 - {status[72:70],7'd0}) : 13'd0),
   .sid_fc_off_r(status[69] ? (13'h600 - {status[75:73],7'd0}) : 13'd0),
	.sid_digifix(~status[37]),
   .audio_l(audio_l),
   .audio_r(audio_r),

   .iec_atn_o(c64_iec_atn),
   .iec_data_o(c64_iec_data_o),
   .iec_clk_o(c64_iec_clk_o),
   .iec_srq_n_o(c64_iec_srq_n_o),
   .iec_data_i(c64_iec_data_i),
   .iec_clk_i(c64_iec_clk_i),
   .iec_srq_n_i(c64_iec_srq_n_i),

   .pb_i(pb_i),
   .pb_o(pb_o),
   .pa2_i(pa2_i),
   .pa2_o(pa2_o),
   .pc2_n_o(pc2_n_o),
   .flag2_n_i(flag2_n_i),
   .sp2_i(sp2_i),
   .sp2_o(sp2_o),
   .sp1_i(sp1_i),
   .sp1_o(sp1_o),
   .cnt2_i(cnt2_i),
   .cnt2_o(cnt2_o),
   .cnt1_i(cnt1_i),
   .cnt1_o(cnt1_o),

   .cass_write(cass_write),
   .cass_motor(cass_motor),
   .cass_sense(~tape_adc_act & (use_tape ? cass_sense : cass_rtc)),
   .cass_read(tape_adc_act ? ~tape_adc : cass_read),

   .d7port(d7port),
   .d7port_trig(d7port_trig),

   .c128_n(c128_n),
   .z80_n(z80_n)
);

wire [7:0] mouse_x;
wire [7:0] mouse_y;
wire [1:0] mouse_btn;

c1351 mouse
(
   .clk_sys(clk_sys),
   .reset(~reset_n),

   .ps2_mouse(ps2_mouse),

   .potX(mouse_x),
   .potY(mouse_y),
   .button(mouse_btn)
);

wire       c128_n;
wire       z80_n;

wire [7:0] drive_par_i;
wire       drive_stb_i;
wire [7:0] drive_par_o;
wire       drive_stb_o;
wire       drive_iec_clk_i;
wire       drive_iec_data_i;
wire       drive_iec_srq_n_i;
wire       drive_iec_clk_o;
wire       drive_iec_data_o;
wire       drive_iec_srq_n_o;
wire       drive_reset = ~reset_n | status[6] | drv_loading;

wire [1:0] drive_led;
wire       disk_ready;

reg [1:0] drive_mounted = 0;
always @(posedge clk_sys) begin
   if(img_mounted[0]) drive_mounted[0] <= |img_size;
   if(img_mounted[1]) drive_mounted[1] <= |img_size;
end

function [1:0] map_drive_model(input [1:0] st);
   case(st)
      2'b00  : return (pure64 ? 2'b00 : 2'b10);  // Auto
      2'b01  : return 2'b00;                     // 1541
      2'b10  : return 2'b10;                     // 1571
      default: return 2'bXX;
   endcase
endfunction

wire        drive_rom_req;
wire [18:0] drive_rom_addr;
reg         drive_rom_wr;

iec_drive iec_drive
(
   .clk(clk_sys),
   .reset({drive_reset | ((!status[56:55]) ? ~drive_mounted[1] : status[56]),
           drive_reset | ((!status[58:57]) ? ~drive_mounted[0] : status[58])}),
   .drv_mode('{map_drive_model(status[84:83]), map_drive_model(status[86:85])}),

   .ce(drive_ce),

   .iec_atn_i(c64_iec_atn),
   .iec_data_i(drive_iec_data_i),
   .iec_clk_i(drive_iec_clk_i),
   .iec_fclk_i(drive_iec_srq_n_i),
   .iec_data_o(drive_iec_data_o),
   .iec_clk_o(drive_iec_clk_o),
   .iec_fclk_o(drive_iec_srq_n_o),

   .pause(c64_pause),

   .img_mounted(img_mounted),
   .img_size(img_size),
   .img_readonly(img_readonly),
   .img_type(ioctl_index[9:6]),

   .led(drive_led),
   .disk_ready(disk_ready),

   .par_data_i(drive_par_i),
   .par_stb_i(drive_stb_i),
   .par_data_o(drive_par_o),
   .par_stb_o(drive_stb_o),

   .clk_sys(clk_sys),

   .sd_lba(sd_lba),
   .sd_blk_cnt(sd_blk_cnt),
   .sd_rd(sd_rd),
   .sd_wr(sd_wr),
   .sd_ack(sd_ack),
   .sd_buff_addr(sd_buff_addr),
   .sd_buff_dout(sd_buff_dout),
   .sd_buff_din(sd_buff_din),
   .sd_buff_wr(sd_buff_wr),

   .rom_loading(drv_loading),
   .rom_req(drive_rom_req),
   .rom_addr(drive_rom_addr),
   .rom_data(sdram_data),
   .rom_wr(drive_rom_wr)
);

always @(posedge clk_sys) begin
   reg io_cycleD;
   reg [1:0] drive_rom_cycle;

   io_cycleD <= io_cycle;
   drive_rom_wr <= 0;

   if (drive_rom_req && !io_cycleD && io_cycle && !ioctl_req_wr && !tap_io_cycle && drv_loaded)
      drive_rom_cycle <= 2'd2;

   if (drive_rom_cycle) begin
      drive_rom_cycle <= drive_rom_cycle - 2'd1;
      if (drive_rom_cycle == 1)
         drive_rom_wr <= 1;
   end
end

reg drive_ce;
always @(posedge clk_sys) begin
   int sum = 0;
   int msum;

   msum <= ntsc ? 32727264 : 31527954;

   drive_ce <= 0;
   sum = sum + 16000000;
   if(sum >= msum) begin
      sum = sum - msum;
      drive_ce <= 1;
   end
end

wire disk_parport = ~status[44];

reg disk_access;
always @(posedge clk_sys) begin
   reg c64_iec_clk_old, drive_iec_clk_old, drive_stb_i_old, drive_stb_o_old;
   integer to = 0;

   c64_iec_clk_old <= c64_iec_clk_o;
   drive_iec_clk_old <= drive_iec_clk_o;
   drive_stb_i_old <= drive_stb_i;
   drive_stb_o_old <= drive_stb_o;

   if(((c64_iec_clk_old != c64_iec_clk_o) || (drive_iec_clk_old != drive_iec_clk_o)) ||
      (disk_parport && ((drive_stb_i_old != drive_stb_i) || (drive_stb_o_old != drive_stb_o))))
   begin
      disk_access <= 1;
      to <= 16000000; // 0.5s
   end
   else if(to) to <= to - 1;
   else disk_access <= 0;
end

wire ext_iec_en = status[25];

iec_io iec_io_clk
(
   .clk(clk_sys),
   .ext_en(ext_iec_en),

   .cpu_o(c64_iec_clk_o),
   .drive_o(drive_iec_clk_o),
   .ext_o(USER_IN[2]),

   .cpu_i(c64_iec_clk_i),
   .drive_i(drive_iec_clk_i),
   .ext_i(USER_OUT[2])
);

iec_io iec_io_data
(
   .clk(clk_sys),
   .ext_en(ext_iec_en),

   .cpu_o(c64_iec_data_o),
   .drive_o(drive_iec_data_o),
   .ext_o(USER_IN[4]),

   .cpu_i(c64_iec_data_i),
   .drive_i(drive_iec_data_i),
   .ext_i(USER_OUT[4])
);

iec_io iec_io_srq_n
(
   .clk(clk_sys),
   .ext_en(ext_iec_en),

   .cpu_o(c64_iec_srq_n_o),
   .drive_o(drive_iec_srq_n_o),
   .ext_o(USER_IN[6]),

   .cpu_i(c64_iec_srq_n_i),
   .drive_i(drive_iec_srq_n_i),
   .ext_i(USER_OUT[6])
);

assign USER_OUT[3] = (reset_n & ~status[6]) | ~ext_iec_en;
assign USER_OUT[5] = c64_iec_atn | ~ext_iec_en;

wire hblank;
wire vblank;
wire ilace;
wire hsync_out;
wire vsync_out;
wire ce_pix;
wire video_sel;
wire [7:0] r, g, b;

video_switch video_switch
(
   .RESET(RESET),
   .CLK_50M(CLK_50M),

   .reset_n(reset_n),
   .c64_pause(c64_pause),
   .ntsc(ntsc),
   .wide(wide),
   .mode(video_mode),
   .vdc_position(status[122]),

   .clk_vic(clk_sys),
   .vicHsync(vicHsync),
   .vicVsync(vicVsync),
   .vicR(vicR),
   .vicG(vicG),
   .vicB(vicB),

   .clk_vdc(clk_vdc),
   .vdcHsync(vdcHsync),
   .vdcVsync(vdcVsync),
   .vdcR(vdcR),
   .vdcG(vdcG),
   .vdcB(vdcB),

   .clk_video(CLK_VIDEO),
   .ce_pix(ce_pix),
   .selected(video_sel),
   .vga_disable(VGA_DISABLE),
   .hsync(hsync_out),
   .vsync(vsync_out),
   .hblank(hblank),
   .vblank(vblank),
   .ilace(ilace),
   .field1(VGA_F1),
   .r(r),
   .g(g),
   .b(b)
);

wire scandoubler = status[9:8] || forced_scandoubler;

assign VGA_SL    = status[9:8];

reg [9:0] vcrop;
reg wide;
always @(posedge CLK_VIDEO) begin
   vcrop <= 0;
   wide <= 0;
   if(HDMI_WIDTH >= (HDMI_HEIGHT + HDMI_HEIGHT[11:1]) && !scandoubler) begin
      if(HDMI_HEIGHT == 480)  vcrop <= 240;
      if(HDMI_HEIGHT == 600)  begin vcrop <= 200; wide <= vcrop_en; end
      if(HDMI_HEIGHT == 720)  vcrop <= 240;
      if(HDMI_HEIGHT == 768)  vcrop <= 256; // NTSC mode has 250 visible lines only!
      if(HDMI_HEIGHT == 800)  begin vcrop <= 200; wide <= vcrop_en; end
      if(HDMI_HEIGHT == 1080) vcrop <= 10'd216;
      if(HDMI_HEIGHT == 1200) vcrop <= 240;
   end
   else if(HDMI_WIDTH >= 1440 && !scandoubler) begin
      // 1920x1440 and 2048x1536 are 4:3 resolutions and won't fit in the previous if statement ( width > height * 1.5 )
      if(HDMI_HEIGHT == 1440) vcrop <= 240;
      if(HDMI_HEIGHT == 1536) vcrop <= 256;
   end
end

wire [1:0] ar = status[5:4];
wire vcrop_en = status[32];
wire vga_de;
video_freak video_freak
(
   .*,
   .VGA_DE_IN(vga_de),
   .ARX((!ar) ? (wide ? 12'd680 : 12'd800) : (ar - 1'd1)),
   .ARY((!ar) ? 12'd600 : 12'd0),
   .CROP_SIZE(vcrop_en ? (vcrop<<ilace) : 10'd0),
   .CROP_OFF(0),
   .SCALE(status[31:30])
);

wire freeze_sync;
reg freeze;
always @(posedge clk_sys) begin
   reg old_sync;

   old_sync <= freeze_sync;
   if(old_sync ^ freeze_sync) freeze <= OSD_STATUS & status[42];
end

assign HDMI_FREEZE = freeze;

video_mixer #(.GAMMA(1)) video_mixer
(
   .CLK_VIDEO(CLK_VIDEO),

   .hq2x(0),
   .scandoubler(scandoubler),
   .gamma_bus(gamma_bus),

   .ce_pix(ce_pix),
	.R(r),
	.G(g),
	.B(b),
   .HSync(hsync_out),
   .VSync(vsync_out),
   .HBlank(hblank),
   .VBlank(vblank),

   .HDMI_FREEZE(HDMI_FREEZE),
   .freeze_sync(freeze_sync),

   .CE_PIXEL(CE_PIXEL),
   .VGA_R(VGA_R),
   .VGA_G(VGA_G),
   .VGA_B(VGA_B),
   .VGA_VS(VGA_VS),
   .VGA_HS(VGA_HS),
   .VGA_DE(vga_de)
);

wire        opl_en = status[12];
wire [15:0] opl_out;
wire  [7:0] opl_dout;
opl3 #(.OPLCLK(47291931)) opl_inst
(
   .clk(clk_sys),
   .clk_opl(clk48),
   .rst_n(reset_n & opl_en),

   .addr(c128_addr[4]),
   .dout(opl_dout),
   .we(ram_we & IOF & opl_en & c128_addr[6] & ~c128_addr[5]),
   .din(c128_data_out),

   .sample_l(opl_out)
);

reg ioe_we, iof_we;
always @(posedge clk_sys) begin
   reg old_ioe, old_iof;

   old_ioe <= IOE;
   ioe_we <= ~old_ioe & IOE & ram_we;

   old_iof <= IOF;
   iof_we <= ~old_iof & IOF & ram_we;
end

reg [11:0] sid_ld_addr = 0;
reg [15:0] sid_ld_data = 0;
reg        sid_ld_wr   = 0;
always @(posedge clk_sys) begin
   sid_ld_wr <= 0;
   if(ioctl_wr && load_flt && ioctl_addr < 6144) begin
      if(ioctl_addr[0]) begin
         sid_ld_data[15:8] <= ioctl_data;
         sid_ld_addr <= ioctl_addr[12:1];
         sid_ld_wr <= 1;
      end
      else begin
         sid_ld_data[7:0] <= ioctl_data;
      end
   end
end

//DigiMax
reg [8:0] dac_l, dac_r;
always @(posedge clk_sys) begin
   reg [8:0] dac[4];
   reg [3:0] act;

   if(!status[41:40] || ~reset_n) begin
      dac <= '{0,0,0,0};
      act <= 0;
   end
   else if((status[41] ? iof_we : ioe_we) && ~c128_addr[2]) begin
      dac[c128_addr[1:0]] <= c128_data_out;
      if(c128_data_out) act[c128_addr[1:0]] <= 1;
   end

   // guess mono/stereo/4-chan modes
   if(act<2) begin
      dac_l <= dac[0] + dac[0];
      dac_r <= dac[0] + dac[0];
   end
   else if(act<3) begin
      dac_l <= dac[1] + dac[1];
      dac_r <= dac[0] + dac[0];
   end
   else begin
      dac_l <= dac[1] + dac[2];
      dac_r <= dac[0] + dac[3];
   end
end

localparam [3:0] comp_f1 = 4;
localparam [3:0] comp_a1 = 2;
localparam       comp_x1 = ((32767 * (comp_f1 - 1)) / ((comp_f1 * comp_a1) - 1)) + 1; // +1 to make sure it won't overflow
localparam       comp_b1 = comp_x1 * comp_a1;

function [15:0] compr; input [15:0] inp;
   reg [15:0] v, v1;
   begin
      v  = inp[15] ? (~inp) + 1'd1 : inp;
      v1 = (v < comp_x1[15:0]) ? (v * comp_a1) : (((v - comp_x1[15:0])/comp_f1) + comp_b1[15:0]);
      v  = v1;
      compr = inp[15] ? ~(v-1'd1) : v;
   end
endfunction

reg [15:0] alo,aro;
always @(posedge clk_sys) begin
   reg [16:0] alm,arm;
   reg [15:0] cout;
   reg [15:0] cin;

   cin  <= opl_out - {{3{opl_out[15]}},opl_out[15:3]};
   cout <= compr(cin);

   alm <= {cout[15],cout} + {audio_l[17],audio_l[17:2]} + {2'b0,dac_l,6'd0} + {cass_snd, 9'd0};
   arm <= {cout[15],cout} + {audio_r[17],audio_r[17:2]} + {2'b0,dac_r,6'd0} + {cass_snd, 9'd0};
   alo <= ^alm[16:15] ? {alm[16], {15{alm[15]}}} : alm[15:0];
   aro <= ^arm[16:15] ? {arm[16], {15{arm[15]}}} : arm[15:0];
end

assign AUDIO_L = alo;
assign AUDIO_R = aro;
assign AUDIO_S = 1;
assign AUDIO_MIX = status[19:18];

//------------- TAP -------------------

wire       tap_download = ioctl_download & load_tap;
wire       tap_reset    = ~reset_n | tap_download | status[23] | !tap_last_addr | cass_finish | (cass_run & ((tap_last_addr - tap_play_addr) < 80));
wire       tap_loaded   = (tap_play_addr < tap_last_addr);                                    // ^^ auto-unload if motor stopped at the very end ^^
wire       tap_io_cycle = ~tap_wrfull & tap_loaded;
wire       tap_play_btn = status[7] | tape_play;
wire       tape_play;

reg [24:0] tap_play_addr;
reg [24:0] tap_last_addr;
reg  [1:0] tap_wrreq;
wire       tap_wrfull;
reg  [1:0] tap_version;
reg        tap_start;

always @(posedge clk_sys) begin
   reg io_cycleD;
   reg read_cyc;

   io_cycleD <= io_cycle;
   tap_wrreq <= tap_wrreq << 1;

   if(tap_reset) begin
      //C1530 module requires one more byte at the end due to fifo early check.
      tap_last_addr <= tap_download ? ioctl_addr+2'd2 : 25'd0;
      tap_play_addr <= 0;
      tap_start     <= ~status[39] & tap_download;
      read_cyc      <= 0;
   end
   else begin
      tap_start <= 0;
      if (~io_cycle & io_cycleD & tap_io_cycle) read_cyc <= 1;
      if (io_cycle & io_cycleD & read_cyc) begin
         tap_play_addr <= tap_play_addr + 1'd1;
         read_cyc <= 0;
         tap_wrreq[0] <= 1;
      end
   end
end

wire cass_write;
wire cass_motor;
wire cass_sense;
wire cass_read;
wire cass_run;
wire cass_finish;
wire cass_snd = cass_read & ~cass_run & status[11] & ~cass_finish;

c1530 c1530
(
   .clk32(clk_sys),
   .restart_tape(tap_reset),
   .wav_mode(0),
   .tap_version(tap_version),
   .host_tap_in(sdram_data),
   .host_tap_wrreq(tap_wrreq[1]),
   .tap_fifo_wrfull(tap_wrfull),
   .tap_fifo_error(cass_finish),
   .cass_read(cass_read),
   .cass_write(cass_write),
   .cass_motor(cass_motor),
   .cass_sense(cass_sense),
   .cass_run(cass_run),
   .osd_play_stop_toggle(tap_play_btn | tap_start),
   .ear_input(0)
);

reg use_tape;
always @(posedge clk_sys) begin
   integer to = 0;

   if(to) to <= to - 1;
   else use_tape <= status[36];

   if(tap_loaded | ~cass_sense) begin
      use_tape <= 1;
      to <= 128000000; //4s
   end
end

reg [26:0] act_cnt;
always @(posedge clk_sys) act_cnt <= act_cnt + (cass_sense ? 4'd1 : 4'd8);
wire tape_led = tap_loaded && (act_cnt[26] ? (~(~cass_sense & cass_motor) && act_cnt[25:18] > act_cnt[7:0]) : act_cnt[25:18] <= act_cnt[7:0]);

wire tape_adc, tape_adc_act;
ltc2308_tape #(.CLK_RATE(32000000)) ltc2308_tape
(
  .clk(clk_sys),
  .ADC_BUS(ADC_BUS),
  .dout(tape_adc),
  .active(tape_adc_act)
);

//------------- USER PORT -----------------

wire [7:0] pb_i, pb_o;
wire       pa2_i, pa2_o;
wire       pc2_n_o;
wire       flag2_n_i;
wire       sp2_i, sp2_o, sp1_o, sp1_i;
wire       cnt2_i, cnt2_o, cnt1_o, cnt1_i;

always_comb begin
   pa2_i       = 1;
   flag2_n_i   = 1;
   sp1_i       = 1;
   sp2_i       = 1;
   cnt1_i      = 1;
   cnt2_i      = 1;
   pb_i        = 8'hFF;
   UART_TXD    = 1;
   UART_RTS    = 0;
   UART_DTR    = 0;
   drive_par_i = 8'hFF;
   drive_stb_i = 1;
   USER_OUT[0] = 1;
   USER_OUT[1] = 1;

   if(disk_parport & disk_access) begin
      drive_par_i = pb_o;
      drive_stb_i = pc2_n_o;
      pb_i        = drive_par_o;
      flag2_n_i   = drive_stb_o;
   end
   else if(status[43]) begin
      UART_TXD  = pa2_o & uart_int;
      flag2_n_i = uart_rxd;
      sp2_i     = uart_rxd;
      pb_i[0]   = uart_rxd;
      UART_RTS  = ~pb_o[1] & uart_int;
      UART_DTR  = ~pb_o[2] & uart_int;
      pb_i[4]   = ~uart_dsr;
      pb_i[6]   = ~uart_cts;
      pb_i[7]   = ~uart_dsr;

      USER_OUT[1] = pa2_o | uart_int;

      if(~status[51]) begin
         UART_TXD = pa2_o & sp1_o & uart_int;
         pb_i[7]  = cnt2_o;
         cnt2_i   = pb_o[7];

         USER_OUT[1] = (pa2_o & sp1_o) | uart_int;
      end
   end
   else begin
      pb_i[5:0] = {!joyD_c64[6:4], !joyC_c64[6:4], pb_o[7] ? ~joyC_c64[3:0] : ~joyD_c64[3:0]};
   end
end

wire uart_int = ~status[33];

reg uart_rxd, uart_dsr, uart_cts;
always @(posedge clk_sys) begin
   reg rxd1, rxd2, dsr1, dsr2, cts1, cts2;

   rxd1 <= uart_int ? UART_RXD : USER_IN[0]; rxd2 <= rxd1; if(rxd1 == rxd2) uart_rxd <= rxd2;
   cts1 <= UART_CTS & uart_int; cts2 <= cts1; if(cts1 == cts2) uart_cts <= cts2;
   dsr1 <= UART_DSR & uart_int; dsr2 <= dsr1; if(dsr1 == dsr2) uart_dsr <= dsr2;
end

wire rtcF83_sda;
rtcF83 #(16000000, 0) rtcF83
(
   .clk(clk_sys),
   .ce(drive_ce),
   .reset(~reset_n | use_tape),
   .RTC(RTC),
   .scl_i(cass_write),
   .sda_i(cass_motor),
   .sda_o(rtcF83_sda)
);

reg use_rtc = 0;
always @(posedge clk_sys) begin
   reg [20:0] to = 0;

   if(to) to <= to - 1'd1;
   use_rtc <= |to;

   if(cass_write) to <= '1;
end

wire cass_rtc = ~(rtcF83_sda & use_rtc & cass_motor);

// ------------------ OSD ----------------------------

reg       info_req;
reg [7:0] info;

osdinfo osdinfo
(
   .clk(clk_sys),
   .reset(RESET),
   .kbd_reset((~reset_n & ~status[1]) | reset_keys),
   .cpslk_mode(cpslk_mode),

   .rom_loaded(ioctl_download ? 2'b11 : {drv_loaded, rom_loaded}),
   .sftlk_sense(sftlk_sense),
   .cpslk_sense(cpslk_sense),
   .d4080_sense(~status[98]),
   .noscr_sense(noscr_sense),

   .info_req(info_req),
   .info(info)
);

endmodule
