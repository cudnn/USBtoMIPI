/////////////////////////// INCLUDE /////////////////////////////
`include "./globals.v"

////////////////////////////////////////////////////////////////
//
//  Module  : freq_m
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2016/2/17 14:12:35
//
////////////////////////////////////////////////////////////////
// 
//  Description: - measure frequence on one IO
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module freq_m
(
   clk,
   start,
   i_cnt,
   i_timeout,
   i_io,
  
   o_freq,
   done
);

   ////////////////// PORT ////////////////////
   input                         clk; // high frequency
   
   input                         start;
   input  [`FREQ_CNT_NBIT-1:0]   i_cnt;
   input  [`FREQ_TO_NBIT-1:0]    i_timeout;
   input                         i_io;
   
   output [`FREQ_DATA_NBIT-1:0]  o_freq;
   output                        done; 
   
   ////////////////// ARCH ////////////////////
   
   // two flip-flop the input io
   reg [1:0] f_io;
   reg       prev_io;
   always@(posedge clk) begin
      f_io <= {f_io[0],i_io};
      prev_io <= f_io[1];
   end
   
   // posedge of io
   wire   io_posedge;
   assign io_posedge = f_io[1]&~prev_io;
   
   // counting posedge of io
   reg [`FREQ_CNT_NBIT-1:0]  r_cnt={`FREQ_CNT_NBIT{1'b1}};
   reg [`FREQ_TO_NBIT-1:0]   r_timeout;
   reg                       m_inproc;

   reg [`FREQ_DATA_NBIT-1:0] freq_cnt;
   reg                       freq_inproc;
   
   always@(posedge clk) begin
      if(m_inproc) begin
         if(io_posedge) begin
            if(~freq_inproc)
               freq_inproc <= `HIGH;
            else
               r_cnt <= r_cnt - 1'b1;
         end
      end

      if(m_inproc&freq_inproc)
         freq_cnt <= freq_cnt + 1'b1;
            
      if(start) begin
         r_cnt <= i_cnt;
         r_timeout <= i_timeout;
         freq_cnt <= 0;
         m_inproc <= `HIGH;
         freq_inproc<= `LOW;
      end
      else if(r_cnt==0 || freq_cnt[`FREQ_DATA_NBIT-1:`FREQ_DATA_NBIT-`FREQ_TO_NBIT]>r_timeout) begin
         m_inproc <= `LOW; // finish counting or timeout, stop counting
         freq_inproc<= `LOW;
      end
   end

   reg [`FREQ_DATA_NBIT-1:0]  o_freq;
   reg                        done; 
   reg                        prev_m_inproc;
   always@(posedge clk) begin
      prev_m_inproc <= m_inproc;
      if(prev_m_inproc&~m_inproc)
         done <= `HIGH;
      else if(start)
         done <= `LOW;
         
      if(m_inproc)
         o_freq <= freq_cnt;
   end
            
endmodule            