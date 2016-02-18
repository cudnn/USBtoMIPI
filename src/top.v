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
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module top
(
   // Clock Source
   CLK1,
   CLK2,
   // Chip Enable
   OE,
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
   input                          CLK2; // 52MHz
   
   output                         OE;
   
   inout  [`IO_UNIT_NBIT-1:0]     IO_DB;
                                     
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
   assign USB_IFCLK   = ~mclk;   // 48MHz, GPIF clock, invert output IFCLK
   assign USB_DB      = usb_wen ? usb_wdata : {`USB_DATA_NBIT{1'bZ}};
   assign USB_SLOE    = ~sloe;
   assign USB_SLRD    = ~slrd;
   assign USB_SLWR    = ~slwr;
   assign USB_PKEND   = ~pkend;
   assign USB_FIFOADR = fifoadr;
   
   ////////////////// Clock Generation
   
   wire mclk;       // 48MHz
   wire usb_clk;    // 24MHz
   wire locked_sig;
   clk_gen  main_clk_gen (
      .areset (`LOW      ),
      .inclk0 (CLK1      ),
      .c0     (mclk      ),
      .c1     (usb_clk   ),
      .locked (locked_sig)
   );
   
   wire mipi_clk;      // 50MHz
   wire freq_fast_clk; // 200MHz
   wire freq_slow_clk;
   mipi_clkpll  mipi_clk_gen (
      .inclk0 (CLK2         ),
      .c0     (mipi_clk     ),
      .c1     (freq_fast_clk),
      .c2     (freq_slow_clk)
   );
   
   assign OE = `HIGH;
   
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
      .ifclk        (mclk         ),
      .sloe         (sloe         ),
      .slrd         (slrd         ),
      .f_empty      (out_ep_empty ),
      .rdata        (usb_rdata    ),
      .slwr         (slwr         ),
      .wen          (usb_wen      ),
      .wdata        (usb_wdata    ),
      .f_full       (in_ep_full   ),
      .pkend        (pkend        ),
      .fifoaddr     (fifoadr      ),
      .rx_cache_vd  (rx_cache_vd  ),
      .rx_cache_data(rx_cache_data),
      .rx_cache_sop (rx_cache_sop ),
      .rx_cache_eop (rx_cache_eop ),
      .tx_cache_sop (pktdec_tx_eop),
      .tx_cache_addr(tx_cache_addr),
      .tx_cache_data(tx_cache_data)
   );
         
   ////////////////// Packet Instruction Decoding

   wire                      pktdec_tx_vd  ;
   wire [`USB_ADDR_NBIT:0]   pktdec_tx_addr;
   wire [`USB_DATA_NBIT-1:0] pktdec_tx_data;
   wire                      pktdec_tx_eop ;
   
   wire [`IO_UNIT_NBIT-1:0]  pktdec_o_io_dir;
   wire [`IO_UNIT_NBIT-1:0]  pktdec_i_io_db;
   wire [`IO_UNIT_NBIT-1:0]  pktdec_o_io_db;
   
   pkt_decode u_cmd_decode
   (
      .clk      (mclk           ),
      .mipi_clk (mipi_clk       ),
      .freq_clk (freq_fast_clk  ),
      .o_io_dir (pktdec_o_io_dir),
      .i_io_db  (pktdec_i_io_db ),
      .o_io_db  (pktdec_o_io_db ),
      .rx_vd    (rx_cache_vd    ),
      .rx_data  (rx_cache_data  ),
      .rx_sop   (rx_cache_sop   ),
      .rx_eop   (rx_cache_eop   ),
      .tx_vd    (pktdec_tx_vd   ),
      .tx_addr  (pktdec_tx_addr ),
      .tx_data  (pktdec_tx_data ),
      .tx_eop   (pktdec_tx_eop  )
   );
   
   generate
   genvar m;
   for(m=0;m<`IO_UNIT_NBIT;m=m+1)
      begin: u
         assign IO_DB[m] = pktdec_o_io_dir[m] ? pktdec_o_io_db[m] : 1'bZ;
         assign pktdec_i_io_db[m] = IO_DB[m];
      end
   endgenerate
   
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