/////////////////////////// INCLUDE /////////////////////////////
`include "./globals.v"

////////////////////////////////////////////////////////////////
//
//  Module  : top.v
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2015/11/13 
//
////////////////////////////////////////////////////////////////
// 
//  Description: top module of USBtoMIPI Controller
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.3

/////////////////////////// MODULE //////////////////////////////
module top
(
   // Clock Source
   CLK1,
   CLK2,
   CLK3,
   // Chip Enable
   OE,
   V_1P8_EN,
   // ADF4360
   adf_clk,
   adf_data,
   adf_le,
   adf_refin,
   // MIPI Interface
   SCLK,
   SDA,
   // IO Interface
   IO_DB,
   // USB Interface
   USB_XTALIN,
   USB_FLAGB,
   USB_FLAGC,
   USB_IFCLK,
   USB_DB,
   USB_SLOE,
   USB_SLWR,
   USB_SLRD,
   USB_PKEND,
   USB_FIFOADR
);

   ////////////////// PORT ////////////////////
   input                          CLK1; // 48MHz
   input                          CLK2; // FPGA v2 - 50MHz, V3 - 26MHz
   input                          CLK3; // Clock input from ADF4360
   
   output                         adf_clk;
   output                         adf_data;
   output                         adf_le;
   input                          adf_refin;
   
   output                         OE;
   output                         V_1P8_EN;
   
   inout  [`IO_UNIT_NBIT-1:0]     IO_DB;
   
   output [3:0]                   SCLK;
   inout  [3:0]                   SDA;
                                  
   output                         USB_XTALIN; // 24MHz
   input                          USB_FLAGB;  // EP2 Empty
   input                          USB_FLAGC;  // EP6 Full
   output                         USB_IFCLK;
   inout  [`USB_DATA_NBIT-1:0]    USB_DB;
   output                         USB_SLOE;
   output                         USB_SLWR;
   output                         USB_SLRD;
   output                         USB_PKEND;
   output [`USB_FIFOADR_NBIT-1:0] USB_FIFOADR;

   ////////////////// ARCH ////////////////////
   
   ////////////////// USB PORTs
   
   assign USB_XTALIN  = usb_clk; // 24MHz, CPU clock
   assign USB_IFCLK   = ifclk;   // 48MHz, GPIF clock, invert output IFCLK
   assign USB_DB      = usb_wen ? usb_wdata : {`USB_DATA_NBIT{1'bZ}};
   assign USB_SLOE    = ~sloe;
   assign USB_SLRD    = ~slrd;
   assign USB_SLWR    = ~slwr;
   assign USB_PKEND   = ~pkend;
   assign USB_FIFOADR = fifoadr;
   
   ////////////////// Clock Generation
   
   wire ifclk;      // 48MHz
	wire mclk;       // inverted ifclk
   wire usb_clk;    // 24MHz
   wire mipi_clk;   // 52MHz
   wire fast_clk;
   wire sr_clk;
   
   wire locked_sig;
   clk_gen  main_clk_gen (
      .areset (`LOW      ),
      .inclk0 (CLK1      ),
      .c0     (ifclk     ),
      .c1     (usb_clk   ),
      .c2     (sr_clk    ),
      .locked (locked_sig)
   );
	
	assign mclk = ~ifclk;
   
`ifdef BRDV3
   mipi_clkpll_v3  
`else
   mipi_clkpll_v2  
`endif
   mipi_clk_gen (
      .inclk0 (CLK2    ),
      .c0     (mipi_clk),
		.c1     (fast_clk)
   );
   
   clk_config u_clk_config
   (
      .in_clk   (sr_clk   ),
      .in_ld    (`LOW     ),
      .out_refin(),
      .out_clk  (adf_clk  ),
      .out_data (adf_data ),
      .out_le   (adf_le   )
   );   
   
   ////////////////// USB PHY Slave FIFO Controller
   
   wire                         sloe;
   wire                         slrd;
   wire                         slwr;
   wire                         pkend;
   wire [`USB_FIFOADR_NBIT-1:0] fifoadr;
   wire                         usb_wen;
   wire [`USB_DATA_NBIT-1:0]    usb_wdata;
   wire [`USB_DATA_NBIT-1:0]    usb_rdata;
   
   assign usb_rdata = USB_DB;
            
   // slave fifo control
   wire out_ep_empty;
   wire in_ep_full  ;
   assign out_ep_empty = ~USB_FLAGB; // End Point 2 empty flag
   assign in_ep_full   = ~USB_FLAGC; // End Point 6 full flag 
   

   // RX Data From USB PHY
   wire                         rx_cache_vd  ;
   wire [`USB_DATA_NBIT-1:0]    rx_cache_data;
   wire                         rx_cache_sop ;
   wire                         rx_cache_eop ;
   // Read Data From TX BUFFER, Send to USB PHY
   wire [`USB_ADDR_NBIT-1:0]    tx_cache_addr;
   wire [`USB_DATA_NBIT-1:0]    tx_cache_data;

   usb_slavefifo u_usb_slavefifo
   (
      .ifclk        (mclk            ),
      .sloe         (sloe            ),
      .slrd         (slrd            ),
      .f_empty      (out_ep_empty    ),
      .rdata        (usb_rdata       ),
      .slwr         (slwr            ),
      .wen          (usb_wen         ),
      .wdata        (usb_wdata       ),
      .f_full       (in_ep_full      ),
      .pkend        (pkend           ),
      .fifoaddr     (fifoadr         ),
      .rx_cache_vd  (rx_cache_vd     ),
      .rx_cache_data(rx_cache_data   ),
      .rx_cache_sop (rx_cache_sop    ),
      .rx_cache_eop (rx_cache_eop    ),
      .tx_cache_sop (pktdec_tx_eop   ),
      .tx_cache_addr(tx_cache_addr   ),
      .tx_cache_data(tx_cache_data   )
   );
         
   ////////////////// Packet Instruction Decoding

   wire                      pktdec_tx_vd  ;
   wire [`USB_ADDR_NBIT:0]   pktdec_tx_addr;
   wire [`USB_DATA_NBIT-1:0] pktdec_tx_data;
   wire                      pktdec_tx_eop ;
   
   wire [`IO_UNIT_NBIT-1:0]  pktdec_o_io_dir;
   wire [`IO_UNIT_NBIT-1:0]  pktdec_i_io_db;
   wire [`IO_UNIT_NBIT-1:0]  pktdec_o_io_db;
   wire [`IO_BANK_NBIT-1:0]  pktdec_o_io_bank;
   wire [`IO_UNIT_NBIT-1:0]  o_io_db;
   
   // P1
   reg [`IO_UNIT_NBIT-1:0]  p1_o_io_dir;
   reg [`IO_UNIT_NBIT-1:0]  p1_o_io_db;
   always@(posedge mclk) begin
      if(pktdec_o_io_bank==0) begin
         p1_o_io_dir <= pktdec_o_io_dir;
         p1_o_io_db  <= pktdec_o_io_db;
      end
   end
   
   generate
   genvar i;
      for(i=0;i<`IO_UNIT_NBIT;i=i+1)
      begin:io_ctrl
         assign IO_DB[i] = p1_o_io_dir[i] ? p1_o_io_db[i] : 1'bZ;
         assign pktdec_i_io_db[i] = (pktdec_o_io_bank==0) ? IO_DB[i] : `LOW;
      end
   endgenerate

   // P2   
   reg OE=`HIGH;
   reg V_1P8_EN=`LOW;
   always@(posedge mclk) begin
      if(pktdec_o_io_bank==`IO_BANK_NBIT'd1) begin
         if(pktdec_o_io_dir[0])
            OE <= pktdec_o_io_db[0];
         if(pktdec_o_io_dir[1])
            V_1P8_EN <= pktdec_o_io_db[1];
      end
   end

   wire                       pktdec_sclk;
   reg                        pktdec_sdi;
   wire                       pktdec_sdo;
   wire                       pktdec_sdo_en;
   wire [`MIPI_BANK_NBIT-1:0] pktdec_mipi_bank;
   reg  [3:0]                 SCLK;
   reg  [3:0]                 SDA;
   
   always@* begin
      SCLK <= 4'b0000;
      SDA  <= 4'b0000;
         
      SCLK[pktdec_mipi_bank] <= pktdec_sclk;
      SDA[pktdec_mipi_bank]  <= pktdec_sdo_en ? pktdec_sdo : `HZ;
      pktdec_sdi <= SDA[pktdec_mipi_bank];
   end
      
   pkt_decode u_cmd_decode
   (
      .clk      (mclk            ),
      .fast_clk (fast_clk        ),
      .mipi_clk (mipi_clk        ),
      .o_io_dir (pktdec_o_io_dir ),
      .i_io_db  (pktdec_i_io_db  ),
      .o_io_db  (pktdec_o_io_db  ),
      .o_io_bank(pktdec_o_io_bank),
      .sclk     (pktdec_sclk     ),
      .sdi      (pktdec_sdi      ),
      .sdo      (pktdec_sdo      ),
      .sdo_en   (pktdec_sdo_en   ),
      .mipi_bank(pktdec_mipi_bank),
      .rx_vd    (rx_cache_vd     ),
      .rx_data  (rx_cache_data   ),
      .rx_sop   (rx_cache_sop    ),
      .rx_eop   (rx_cache_eop    ),
      .tx_vd    (pktdec_tx_vd    ),
      .tx_addr  (pktdec_tx_addr  ),
      .tx_data  (pktdec_tx_data  ),
      .tx_eop   (pktdec_tx_eop   )
   );
   
   ////////////////// TX BUFFER
   
   wire [`USB_DATA_NBIT-1:0] tx_buffer_rdata;

   buffered_ram#(`USB_ADDR_NBIT+1,`USB_DATA_NBIT,"./tx_buf_512x16.mif")
   tx_buffer(
      .inclk       (mclk          ),
      .in_wren     (pktdec_tx_vd  ),
      .in_wraddress(pktdec_tx_addr),
      .in_wrdata   (pktdec_tx_data),
      .in_rdaddress({pktdec_tx_addr[`USB_ADDR_NBIT],tx_cache_addr}),
      .out_rddata  (tx_cache_data )
   );   
   
endmodule