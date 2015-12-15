/////////////////////////// INCLUDE /////////////////////////////
`include "./globals.v"

////////////////////////////////////////////////////////////////
//
//  Module  : usb_slavefifo
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2015/11/16 
//
////////////////////////////////////////////////////////////////
// 
//  Description: interface with CY7C68013 in slave FIFO mode
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module usb_slavefifo
(
   // Interface of CY7C68013
   ifclk,
   sloe,
   slrd,
   f_empty,
   rdata,
   slwr,
   wen,
   wdata,
   f_full,
   pkend,
   fifoaddr,
   // Internal Interface
   rx_cache_vd,
   rx_cache_data,
   rx_cache_sop,
   rx_cache_eop,
   
   tx_cache_sop,
   tx_cache_addr,
   tx_cache_data
);

   ////////////////// PORT ////////////////////
   input                          ifclk;    // clock 48Mhz
   output                         slrd;     // read
   output                         slwr;     // write
   input                          f_empty;  // empty flag
   input                          f_full;   // full flag
   input  [`USB_DATA_NBIT-1:0]    rdata;    // read data
   output                         wen;      // write enable
   output [`USB_DATA_NBIT-1:0]    wdata;    // write data                                                                
   output                         sloe;     // output enable
   output                         pkend;
   output [`USB_FIFOADR_NBIT-1:0] fifoaddr; // the address to select fifo block
   
   // Write Data to RX BUFFER
   output                         rx_cache_vd;
   output [`USB_DATA_NBIT-1:0]    rx_cache_data;
   output                         rx_cache_sop;
   output                         rx_cache_eop;
   
   // Read Data From TX BUFFER
   input                          tx_cache_sop;
   output [`USB_ADDR_NBIT-1:0]    tx_cache_addr;
   input  [`USB_DATA_NBIT-1:0]    tx_cache_data;

   ////////////////// ARCH ////////////////////
   
   ////////////////// READING
   reg prev_f_empty;
   always@(posedge ifclk) begin
      prev_f_empty <= f_empty;
   end
   assign sloe =~f_empty&~tx_in_proc;
   assign slrd =~f_empty&~prev_f_empty;

   ////////////////// rx cache output
   assign rx_cache_vd   = slrd;
   assign rx_cache_data = rdata;
   assign rx_cache_sop  =~f_empty& prev_f_empty;
   assign rx_cache_eop  = f_empty&~prev_f_empty;
      
   ////////////////// WRITING
   `define ST_IDLE 2'd0
   `define ST_T0   2'd1
   `define ST_T1   2'd2
   `define ST_T2   2'd3
   
   reg [1:0] tx_st;

   reg [7:0]                tx_delay_cnt;
   reg [`USB_ADDR_NBIT-1:0] tx_cache_addr;
   reg                      p_in_proc;
   reg                      slwr;
   reg [`USB_DATA_NBIT-1:0] wdata;                                                            
      
   always@(posedge ifclk) begin
      p_in_proc  <= tx_in_proc;
      slwr       <= p_in_proc;
      case(tx_st) 
         `ST_IDLE: begin
            tx_delay_cnt <= 0;
            tx_cache_addr <= 0;
            if(tx_cache_sop)
               tx_st <= `ST_T0;
         end
         `ST_T0: begin // Check if FIFO is Full
            if(~f_full) begin
               tx_cache_addr <= tx_cache_addr + 1'b1;
               tx_delay_cnt <= 8'd1;
               tx_st <= `ST_T1;
            end
         end
         `ST_T1: begin // wait for DATA
            tx_delay_cnt <= tx_delay_cnt - 1'b1;
            tx_cache_addr <= tx_cache_addr + 1'b1;
            if(tx_delay_cnt==0) begin
               tx_delay_cnt  <= 0;
               tx_st <= `ST_T2;
            end
         end
         `ST_T2: begin
            tx_cache_addr <= tx_cache_addr + 1'b1;
            if(tx_cache_addr=={`USB_ADDR_NBIT{1'b1}}) begin
               tx_st <= `ST_IDLE;
            end
         end
         default:
            tx_st <= `ST_IDLE;
      endcase
   end
   
   reg                         wen;
   reg                         tx_in_proc;
   reg [`USB_FIFOADR_NBIT-1:0] fifoaddr; // the address to select fifo block
   always@* begin
      wdata <= tx_cache_data;
      case(tx_st) 
         `ST_IDLE: begin // wait for sop
            tx_in_proc <= `LOW;
            fifoaddr   <= slwr ? `USB_WR_FIFOADR : `USB_RD_FIFOADR;
            wen        <= `LOW;
         end
         `ST_T0: begin // wait for deactive of full flag
            tx_in_proc <= ~f_full;
            fifoaddr   <= `USB_WR_FIFOADR;
            wen        <= `HIGH;
         end
         `ST_T1: begin // set SLWR
            tx_in_proc <= `HIGH;
            fifoaddr   <= `USB_WR_FIFOADR;
            wen        <= `HIGH;
         end
         `ST_T2: begin
            tx_in_proc <= ~f_full;
            fifoaddr   <= `USB_WR_FIFOADR;
            wen        <= `HIGH;
         end
         default: begin
            tx_in_proc <= `LOW;
         end
      endcase
   end
   
   assign pkend = `LOW;

endmodule            