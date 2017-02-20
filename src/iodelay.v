/////////////////////////// INCLUDE /////////////////////////////
`include "./globals.v"

////////////////////////////////////////////////////////////////
//
//  Module  : iodelay.v
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2017/1/3
//
////////////////////////////////////////////////////////////////
// 
//  Description: MIPI IO delay module
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// DEFINE /////////////////////////////

/////////////////////////// MODULE //////////////////////////////
module iodelay
(
   clk,
   rst_n,
   in_dio,
   in_delay,
   in_delay_we,
   out_dio
);

   ///////////////// PARAMETER ////////////////
   parameter P_DATA_NBIT  = 1;
   parameter P_DELAY_NBIT = `MIPI_IODELAY_NBIT;

   ////////////////// PORT ////////////////////
   input                      clk;
   input                      rst_n;
   input  [P_DATA_NBIT-1:0]   in_dio;
   input  [P_DELAY_NBIT-1:0]  in_delay;
   input                      in_delay_we;
   output [P_DATA_NBIT-1:0]   out_dio;

   ////////////////// ARCH ////////////////////

   reg [P_DELAY_NBIT-1:0] io_delay_num;
   reg [2:0]              p_delay_we;
   
   always@(posedge clk) begin
      if(~rst_n) begin
         p_delay_we <= 0;
         io_delay_num <= 0;
      end
      else begin
         p_delay_we <= {p_delay_we[1:0],in_delay_we};
         if(p_delay_we[2:1]==2'b01)
            io_delay_num <= in_delay;
      end
   end

   reg [P_DATA_NBIT-1:0]  io_delay[0:2**P_DELAY_NBIT-1];
   always@(in_dio)
      io_delay[0] <= in_dio;
   generate
   genvar i;
   for(i=1;i<2**P_DELAY_NBIT;i=i+1) begin:u
      always@(posedge clk) begin
         if(~rst_n) begin
            io_delay[i] <= 0;
         end
         else begin
            io_delay[i] <= io_delay[i-1];
         end
      end
   end
   endgenerate
   
   assign out_dio = io_delay[io_delay_num];   
   
endmodule