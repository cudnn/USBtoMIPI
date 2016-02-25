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
   o_cnt,
   o_err,
   done
);

   ////////////////// PORT ////////////////////
   input                         clk; // high frequency
   
   input                         start;
   input  [`FREQ_CNT_NBIT-1:0]   i_cnt;
   input  [`FREQ_TO_NBIT-1:0]    i_timeout;
   input                         i_io;
   
   output [`FREQ_DATA_NBIT-1:0]  o_freq;
   output [`FREQ_CNT_NBIT-1:0]   o_cnt;
   output                        o_err;
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
         freq_cnt <= freq_cnt + 1'b1;
         if(io_posedge) begin
            if(~freq_inproc) begin
               freq_inproc <= `HIGH;
               freq_cnt    <= 0;
            end
            else
               r_cnt <= r_cnt + 1'b1;
         end
         
         if(r_cnt==i_cnt || freq_cnt[`FREQ_DATA_NBIT-1:`FREQ_DATA_NBIT-`FREQ_TO_NBIT]>r_timeout) begin
            m_inproc <= `LOW; // finish counting or timeout, stop counting
         end
      end
      else
         freq_inproc<= `LOW;      
      
      if(start) begin
         r_timeout   <= i_timeout;
         m_inproc    <= `HIGH;
         freq_inproc <= `LOW;
         r_cnt       <= 0;
         freq_cnt    <= 0;
      end
   end

   reg                        done; 
   reg                        prev_m_inproc;
   reg [`FREQ_DATA_NBIT-1:0]  o_freq;
   reg [`FREQ_CNT_NBIT-1:0]   o_cnt;
   reg                        o_err;
   
   always@(posedge clk) begin
      prev_m_inproc <= m_inproc;
      // negedge of inproc, done
      if(prev_m_inproc&~m_inproc) begin
         o_err <= (r_cnt!=i_cnt);
         done  <= `HIGH;
      end
      else if(start) begin
         o_err <= `LOW;
         done  <= `LOW;
      end
         
      if(m_inproc) begin
         o_freq <= freq_cnt;
         o_cnt  <= r_cnt;
      end
   end
            
endmodule            