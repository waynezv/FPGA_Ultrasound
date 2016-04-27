`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/04/04 16:21:41
// Design Name: 
// Module Name: data_acquis_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module data_acquis_controller (
input  logic clk_100,

input  logic otg_oc,

inout logic [55:0] PS_GPIO,

output logic [3:0] GPIO_LED,

output logic [3:0] vga4_blue,
output logic [3:0] vga4_green,
output logic [3:0] vga4_red,
output  logic vga_hsync,
output  logic vga_vsync,

output  logic audio_mclk,
output  logic audio_dac,
input   logic audio_adc,
input   logic audio_bclk,
input   logic audio_lrclk,

output logic smb_sclk,
inout  logic smb_sdata,
output logic [1:0] smbus_addr,

// 
input logic RST,
output logic RST_INDICATE,

input logic START_TX,
output logic TX_INDICATE,

input logic START_RX,
output logic RX_INDICATE,

// for PMOD DA4                    
output logic DA4_SYNC,
output logic DA4_CLK,
output logic DA4_SDA,

output logic DA4_2_SYNC,
output logic DA4_2_CLK,
output logic DA4_2_SDA,

// for PMOD AD2                       
inout logic AD2_SCL,
inout logic AD2_SDA,

output logic SDA_ALT_IN,
output logic SCL_ALT_IN
);

//+--------------------------------------------------------------------------------------------+
//+                                 Wires and Regs Definition                                  +
//+--------------------------------------------------------------------------------------------+
// Commander commands
logic clk_indicator;

assign RST_INDICATE = RST;

always_ff @(posedge clk_indicator) begin
    TX_INDICATE <= START_TX;
    RX_INDICATE <= START_RX;
end

// Wires and registers related to Xillybus
logic bus_clk;
logic quiesce; // asserted 1 when xillybus not turned on or has turned off

// Wires and registers related to signal generator
logic sig_clk;
logic [11:0] wSig0;

assign sig_clk = da_clk;
    
// Wires and registers related to PMOD DA4
logic da_clk;
logic fTxDone;
logic fRstTXCtrl;

//assign fRstTXCtrl = RST || sig_clk; // ??
// DA output clock
assign DA4_CLK = da_clk;
assign DA4_2_CLK = da_clk;

// Wires and registers related to PMOD AD2
logic fRstRXCtrl;
logic fRxDone;
logic [15:0] rAdSig0;

//assign fRstRXCtrl = RST || ~sig_clk; // ??

// The PmodAD2 has dual SDA and SCL lines for daisy chaining TWI bus devices. If 
// these other pins are brought low accadentially, then the device will refuse to
// transmit data. To prevent this, we drive them as high impedance if they are 
// connected. If they are disconnected, they are left floating and the system
// should still work.
assign SDA_ALT_IN = 'bz;
assign SCL_ALT_IN = 'bz;

// Wires and registers related to DSP
logic [31:0] processed_data;

// Wires and registers related to data capturing
logic capture_clk;
logic [31:0] capture_data;
logic        capture_en;
logic        capture_full;  

assign capture_clk = bus_clk;
    
// Memory arrays
logic [7:0] demoarray[0:31];
    
logic [7:0] litearray0[0:31];
logic [7:0] litearray1[0:31];
logic [7:0] litearray2[0:31];
logic [7:0] litearray3[0:31];
    
// Wires related to /dev/xillybus_mem_8
logic      user_r_mem_8_rden;
logic      user_r_mem_8_empty;
logic [7:0] user_r_mem_8_data;
logic      user_r_mem_8_eof;
logic      user_r_mem_8_open;

logic      user_w_mem_8_wren;
logic      user_w_mem_8_full;
logic [7:0] user_w_mem_8_data;
logic       user_w_mem_8_open;

logic [4:0] user_mem_8_addr;
logic       user_mem_8_addr_update;

// Wires related to /dev/xillybus_read_32
logic        user_r_read_32_rden;
logic        user_r_read_32_empty;
logic [31:0] user_r_read_32_data;
logic        user_r_read_32_eof;
logic        user_r_read_32_open;
   
// Wires related to /dev/xillybus_read_8
logic        user_r_read_8_rden;
logic        user_r_read_8_empty;
logic [7:0]  user_r_read_8_data;
logic        user_r_read_8_eof;
logic        user_r_read_8_open;

// Wires related to /dev/xillybus_write_32
logic        user_w_write_32_wren;
logic        user_w_write_32_full;
logic [31:0] user_w_write_32_data;
logic        user_w_write_32_open;

    // Data from the write_32 is discarded. Ignore wren and data, and never assert full.
    assign user_w_write_32_full = 0;

// Wires related to /dev/xillybus_write_8
logic        user_w_write_8_wren;
logic        user_w_write_8_full;
logic [7:0]  user_w_write_8_data;
logic        user_w_write_8_open;

// Wires related to /dev/xillybus_audio
logic        user_r_audio_rden;
logic        user_r_audio_empty;
logic [31:0] user_r_audio_data;
logic        user_r_audio_eof;
logic        user_r_audio_open;

logic        user_w_audio_wren;
logic        user_w_audio_full;
logic [31:0] user_w_audio_data;
logic        user_w_audio_open;

// Wires related to /dev/xillybus_smb
logic        user_r_smb_rden;
logic        user_r_smb_empty;
logic [7:0]  user_r_smb_data;
logic        user_r_smb_eof;
logic        user_r_smb_open;

logic        user_w_smb_wren;
logic        user_w_smb_full;
logic [7:0]  user_w_smb_data;
logic        user_w_smb_open;

// Wires related to Xillybus Lite
logic        user_clk;
logic        user_wren;
logic [3:0]  user_wstrb;
logic        user_rden;
logic [31:0] user_rd_data;
logic [31:0] user_wr_data;
logic [31:0] user_addr;
logic        user_irq;

    assign user_irq = 0;
//+--------------------------------------------------------------------------------------------+
//+                            Control Combinations and Sequences                              +
//+--------------------------------------------------------------------------------------------+
always @(posedge user_clk) begin
 if (user_wstrb[0])
   litearray0[user_addr[6:2]] <= user_wr_data[7:0];

 if (user_wstrb[1])
   litearray1[user_addr[6:2]] <= user_wr_data[15:8];

 if (user_wstrb[2])
   litearray2[user_addr[6:2]] <= user_wr_data[23:16];

 if (user_wstrb[3])
   litearray3[user_addr[6:2]] <= user_wr_data[31:24];
 
 if (user_rden)
   user_rd_data <= { litearray3[user_addr[6:2]],
                     litearray2[user_addr[6:2]],
                     litearray1[user_addr[6:2]],
                     litearray0[user_addr[6:2]] };
  end

// A simple inferred RAM
always @(posedge bus_clk)
  begin
 if (user_w_mem_8_wren)
   demoarray[user_mem_8_addr] <= user_w_mem_8_data;
 
 if (user_r_mem_8_rden)
   user_r_mem_8_data <= demoarray[user_mem_8_addr];      
  end

assign  user_r_mem_8_empty = 0;
assign  user_r_mem_8_eof = 0;
assign  user_w_mem_8_full = 0;

//+--------------------------------------------------------------------------------------------+
//+                                 User Modules Instantiation                                 +
//+--------------------------------------------------------------------------------------------+
ad_rcv_intfc adRcvFc (.clk(clk_100),
                     .rst(RST)
                     );

clk_divider clkDiv (
                    .clk_100(clk_100),
                    .rst(RST),
                    .sclk_10M(da_clk),
                    .sclk_40k(clk_indicator)
                    );

signal_generator sigGen (
                         .t(adRcvFc.sig_gen),
                         .START(START_RX),
                         .clk(sig_clk), 
                         .rst(RST),
                         .sig(wSig0)
                        );                  
pmodDA4 pDa4 ( 
               .t(adRcvFc.da),
               .datClk(da_clk),
               .rst(RST),
               .SYNC(DA4_SYNC),
               .SDA(DA4_SDA),
               .wData(wSig0)
                );

pmodDA4 pDa4_2 ( 
               .t(adRcvFc.da),
               .datClk(da_clk),
               .rst(RST),
               .SYNC(DA4_2_SYNC),
               .SDA(DA4_2_SDA),
               .wData(wSig0)
                );
                                                     
//pmodAD2 pAd2 (
//                .t(adRcvFc.ad),
//                .CLK(da_clk),
//                .RST(RST),
//                .SDA(AD2_SDA),
//                .SCL(AD2_SCL),
//                .WDA(rAdSig0)
//                );
//logic ad_rst;
//assign ad_rst = ~RST; // hight reset
pmodAD2_ctrl pAd2 (
//                .t(adRcvFc.ad),
                .START(START_RX),
                .mainClk(clk_100), // system clock
                .busClk(bus_clk),
                .SDA_mst(AD2_SDA),
                .SCL_mst(AD2_SCL), // 100 KHz ??
                .wData0(rAdSig0),
//                .RST(ad_rst),
//                .RST(RST),
                .RxDone(fRxDone)
                );
                
ad_processor adProc(.t(adRcvFc.ad_proc),
                    .bus_clk(bus_clk),
                    .proc_en(fRxDone),
                    .ad_data_in(rAdSig0),
                    .ad_data_procOut(processed_data)
                    );
                                  
ad_2_fifo_sender ad2FiSd(.p(adRcvFc.ad_2_fifo),
                         .START(START_RX)
                         );
                         
xilly_reader xilRd( .capture_clk(capture_clk),
                    .t(adRcvFc.xil_read),
                    .user_r_read_32_open(user_r_read_32_open),
                    .user_r_read_32_empty(user_r_read_32_empty),
                    .capture_full(capture_full),
                    .d(processed_data), 
                    .capture_en(capture_en),  
                    .capture_data(capture_data),
                    .user_r_read_32_eof(user_r_read_32_eof)
                    );
                    
//+--------------------------------------------------------------------------------------------+
//+                                 Necessary Initialization                                   +
//+--------------------------------------------------------------------------------------------+
xillybus xillybus_ins (
                       // Ports related to /dev/xillybus_mem_8
                       // FPGA to CPU signals:
                       .user_r_mem_8_rden(user_r_mem_8_rden),
                       .user_r_mem_8_empty(user_r_mem_8_empty),
                       .user_r_mem_8_data(user_r_mem_8_data),
                       .user_r_mem_8_eof(user_r_mem_8_eof),
                       .user_r_mem_8_open(user_r_mem_8_open),
                   
                       // CPU to FPGA signals:
                       .user_w_mem_8_wren(user_w_mem_8_wren),
                       .user_w_mem_8_full(user_w_mem_8_full),
                       .user_w_mem_8_data(user_w_mem_8_data),
                       .user_w_mem_8_open(user_w_mem_8_open),
                   
                       // Address signals:
                       .user_mem_8_addr(user_mem_8_addr),
                       .user_mem_8_addr_update(user_mem_8_addr_update),
                   
                   
                       // Ports related to /dev/xillybus_read_32
                       // FPGA to CPU signals:
                       .user_r_read_32_rden(user_r_read_32_rden),
                       .user_r_read_32_empty(user_r_read_32_empty),
                       .user_r_read_32_data(user_r_read_32_data),
                       .user_r_read_32_eof(user_r_read_32_eof),
                       .user_r_read_32_open(user_r_read_32_open),
                   
                   
                       // Ports related to /dev/xillybus_read_8
                       // FPGA to CPU signals:
                       .user_r_read_8_rden(user_r_read_8_rden),
                       .user_r_read_8_empty(user_r_read_8_empty),
                       .user_r_read_8_data(user_r_read_8_data),
                       .user_r_read_8_eof(user_r_read_8_eof),
                       .user_r_read_8_open(user_r_read_8_open),
                   
                   
                       // Ports related to /dev/xillybus_write_32
                       // CPU to FPGA signals:
                       .user_w_write_32_wren(user_w_write_32_wren),
                       .user_w_write_32_full(user_w_write_32_full),
                       .user_w_write_32_data(user_w_write_32_data),
                       .user_w_write_32_open(user_w_write_32_open),
                   
                   
                       // Ports related to /dev/xillybus_write_8
                       // CPU to FPGA signals:
                       .user_w_write_8_wren(user_w_write_8_wren),
                       .user_w_write_8_full(user_w_write_8_full),
                       .user_w_write_8_data(user_w_write_8_data),
                       .user_w_write_8_open(user_w_write_8_open),
                   
                       // Ports related to /dev/xillybus_audio
                       // FPGA to CPU signals:
                       .user_r_audio_rden(user_r_audio_rden),
                       .user_r_audio_empty(user_r_audio_empty),
                       .user_r_audio_data(user_r_audio_data),
                       .user_r_audio_eof(user_r_audio_eof),
                       .user_r_audio_open(user_r_audio_open),
                   
                       // CPU to FPGA signals:
                       .user_w_audio_wren(user_w_audio_wren),
                       .user_w_audio_full(user_w_audio_full),
                       .user_w_audio_data(user_w_audio_data),
                       .user_w_audio_open(user_w_audio_open),
                   
                       // Ports related to /dev/xillybus_smb
                       // FPGA to CPU signals:
                       .user_r_smb_rden(user_r_smb_rden),
                       .user_r_smb_empty(user_r_smb_empty),
                       .user_r_smb_data(user_r_smb_data),
                       .user_r_smb_eof(user_r_smb_eof),
                       .user_r_smb_open(user_r_smb_open),
                   
                       // CPU to FPGA signals:
                       .user_w_smb_wren(user_w_smb_wren),
                       .user_w_smb_full(user_w_smb_full),
                       .user_w_smb_data(user_w_smb_data),
                       .user_w_smb_open(user_w_smb_open),
                   
                       // Xillybus Lite signals:
                       .user_clk ( user_clk ),
                       .user_wren ( user_wren ),
                       .user_wstrb ( user_wstrb ),
                       .user_rden ( user_rden ),
                       .user_rd_data ( user_rd_data ),
                       .user_wr_data ( user_wr_data ),
                       .user_addr ( user_addr ),
                       .user_irq ( user_irq ),
                                               
                       // General signals
                       .clk_100(clk_100),
                       .otg_oc(otg_oc),
                       .PS_GPIO(PS_GPIO),
                       .GPIO_LED(GPIO_LED),
                       .bus_clk(bus_clk),
                       .quiesce(quiesce),
                   
                       // VGA port related outputs
                                   
                       .vga4_blue(vga4_blue),
                       .vga4_green(vga4_green),
                       .vga4_red(vga4_red),
                       .vga_hsync(vga_hsync),
                       .vga_vsync(vga_vsync)
                   );
                    
fifo_32x512 fifo_32 (
                    .clk(capture_clk),
                    .srst(!user_w_write_32_open && !user_r_read_32_open),
                    .din(capture_data),
                    .wr_en(capture_en),
                    .rd_en(user_r_read_32_rden),
                    .dout(user_r_read_32_data),
                    .full(capture_full),
                    .empty(user_r_read_32_empty)
                    );

//+--------------------------------------------------------------------------------------------+
//+                                   Other Initialization                                     +
//+--------------------------------------------------------------------------------------------+
logic rst, wr_clk, rd_clk, wr_en, rd_en, dout, full, empty, prog_full;
logic [35:0] din;
vga_fifo vga_fifo( .*);

   // 8-bit loopback
   fifo_8x2048 fifo_8
     (
      .clk(bus_clk),
      .srst(!user_w_write_8_open && !user_r_read_8_open),
      .din(user_w_write_8_data),
      .wr_en(user_w_write_8_wren),
      .rd_en(user_r_read_8_rden),
      .dout(user_r_read_8_data),
      .full(user_w_write_8_full),
      .empty(user_r_read_8_empty)
      );

   assign  user_r_read_8_eof = 0;
   
   // audio
   i2s_audio audio
     (
      .bus_clk(bus_clk),
      .clk_100(clk_100),
      .quiesce(quiesce),

      .audio_mclk(audio_mclk),
      .audio_dac(audio_dac),
      .audio_adc(audio_adc),
      .audio_bclk(audio_bclk),
      .audio_lrclk(audio_lrclk),
      
      .user_r_audio_rden(user_r_audio_rden),
      .user_r_audio_empty(user_r_audio_empty),
      .user_r_audio_data(user_r_audio_data),
      .user_r_audio_eof(user_r_audio_eof),
      .user_r_audio_open(user_r_audio_open),
      
      .user_w_audio_wren(user_w_audio_wren),
      .user_w_audio_full(user_w_audio_full),
      .user_w_audio_data(user_w_audio_data),
      .user_w_audio_open(user_w_audio_open)
      );
   
   // smbus
   smbus smbus
     (
      .bus_clk(bus_clk),
      .quiesce(quiesce),

      .smb_sclk(smb_sclk),
      .smb_sdata(smb_sdata),
      .smbus_addr(smbus_addr),

      .user_r_smb_rden(user_r_smb_rden),
      .user_r_smb_empty(user_r_smb_empty),
      .user_r_smb_data(user_r_smb_data),
      .user_r_smb_eof(user_r_smb_eof),
      .user_r_smb_open(user_r_smb_open),
      
      .user_w_smb_wren(user_w_smb_wren),
      .user_w_smb_full(user_w_smb_full),
      .user_w_smb_data(user_w_smb_data),
      .user_w_smb_open(user_w_smb_open)
      );
      
endmodule
