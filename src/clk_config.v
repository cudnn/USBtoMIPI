/////////////////////////// INCLUDE /////////////////////////////
`include "../src/globals.v"

////////////////////////////////////////////////////////////////
//
//  Module  : clk_config
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2016/8/18 16:01:06
//
////////////////////////////////////////////////////////////////
// 
//  Description: Clock Generator: ADF4360
//               initial process
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// DEFINE /////////////////////////////
`define  IDLE         3'b000
`define  ST_CONTROL   3'b001
`define  ST_R_COUNTER 3'b011
`define  ST_INTERVAL  3'b010
`define  ST_N_COUNTER 3'b110
`define  ST_WAIT      3'b111

/////////////////////////// MODULE //////////////////////////////
module clk_config
(
   in_clk  ,
   in_ld   ,
   out_refin,
   out_clk ,
   out_data,
   out_le
);

   ///////////////// PARAMETER ////////////////
   parameter P_CLK_DIV   = 8;
   parameter P_R_COUNTER = {2'b00,2'b11,1'b0,1'b0,2'b11,14'd4,2'b01}; // R counter: 1 - 16383
   parameter P_CONTROL   = {2'b00,2'b00,6'b000000,2'b11,1'b0,1'b0,1'b0,1'b1,3'b011,1'b0,2'b01,2'b00};     
   parameter P_N_COUNTER = {2'b00,1'b0,13'd4,1'b0,5'd4,2'b10}; // B counter: 3 - 8191, A counter: 2 - 31 

   ////////////////// 
   // Fvco    = B * Frefin / R'
   // R'      = R/R_DIV;
   // Fdivout = Fvco / A
   ////////////////// 
      
   ////////////////// PORT ////////////////////
   input  in_clk  ;
   input  in_ld   ;
   output out_refin;
   output out_clk ;  // serial clock output, up to 20MHz
   output out_data;  // serial data output
   output out_le  ;  // serial load enable

   ////////////////// ARCH ////////////////////

   ////////////////// Clock Division
   reg   [7:0]    div_cnt;
   reg            div_clk;
   always@(posedge in_clk) begin
      div_cnt <= div_cnt + 1'b1;
      if(div_cnt==P_CLK_DIV-1)
         div_cnt <= 0;
      
      if(div_cnt==P_CLK_DIV/2-1 || div_cnt==P_CLK_DIV-1)
         div_clk <= ~div_clk;
   end
   
   ////////////////// Initial
   reg  init_start=`HIGH;
   reg  [7:0]  init_cnt=0;
   reg  [2:0]  st; 
   reg  [23:0] sf_data;
   reg  [31:0] sf_cnt;
   always@(posedge div_clk) begin
      if(in_ld)
         init_start <= `LOW;

      case(st) 
         `IDLE: begin
            sf_data <= 0;
            sf_cnt <= 0;
            if(init_start) begin
               st <= `ST_R_COUNTER;
               sf_data <= P_R_COUNTER;
               sf_cnt <= 16'd25;
            end
         end
         `ST_R_COUNTER: begin
            sf_data <= sf_data<<1;
            sf_cnt <= sf_cnt - 1'b1;
            if(sf_cnt==0) begin
               sf_data <= P_CONTROL;
               sf_cnt <= 16'd25;
               st <= `ST_CONTROL;
            end
         end
         `ST_CONTROL: begin
            sf_data <= sf_data<<1;
            sf_cnt <= sf_cnt - 1'b1;
            if(sf_cnt==0) begin
               sf_data <= P_N_COUNTER;
               sf_cnt <= 32'h00004E20; // Delay between CONTROL and N_COUNTER, >= 15ms
               st <= `ST_INTERVAL;
            end
         end
         `ST_INTERVAL: begin
            sf_cnt <= sf_cnt - 1'b1;
            if(sf_cnt==0) begin
               sf_cnt <= 16'd25;
               st <= `ST_N_COUNTER;
            end
         end
         `ST_N_COUNTER: begin
            sf_data <= sf_data<<1;
            sf_cnt  <= sf_cnt - 1'b1;
            if(sf_cnt==0) begin
               st <= `ST_WAIT;
               init_cnt <= init_cnt + 1'b1;
               sf_cnt <= 32'h1; //32'h000FFFFF; // wait for 1s
            end
         end
         `ST_WAIT: begin
            sf_cnt <= sf_cnt - 1'b1;
            if(sf_cnt==0) begin
               st <= `IDLE;
//               init_start <= `LOW;
            end
         end
         default:
            st <= `IDLE;
      endcase
   end
   
   reg  div_clk_en;
   reg  out_data;
   reg  out_le;
   
   assign out_clk = ~div_clk&div_clk_en;
   assign out_refin = in_clk;
   
   always@* begin
      case(st) 
         `IDLE: begin
            div_clk_en <= `LOW;
            out_data   <= `LOW;
            out_le     <= `LOW;
         end
         `ST_R_COUNTER: begin
            div_clk_en <= (sf_cnt>1);
            out_data   <= sf_data[23];
            out_le     <= (sf_cnt==0);
         end
         `ST_CONTROL: begin
            div_clk_en <= (sf_cnt>1);
            out_data   <= sf_data[23];
            out_le     <= (sf_cnt==0);
         end
         `ST_INTERVAL: begin
            div_clk_en <= `LOW;
            out_data   <= `LOW;
            out_le     <= `LOW;
         end
         `ST_N_COUNTER: begin
            div_clk_en <= (sf_cnt>1);
            out_data   <= sf_data[23];
            out_le     <= (sf_cnt==0);
         end
         `ST_WAIT: begin
            div_clk_en <= `LOW;
            out_data   <= `LOW;
            out_le     <= `LOW;
         end
         default: begin
            div_clk_en <= `LOW;
            out_data   <= `LOW;
            out_le     <= `LOW;
         end
      endcase
   end

endmodule