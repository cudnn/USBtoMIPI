/////////////////////////// INCLUDE /////////////////////////////
`include "./globals.v"

////////////////////////////////////////////////////////////////
//
//  Module  : io_map
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2016/2/20 14:12:47
//
////////////////////////////////////////////////////////////////
// 
//  Description: - io mapping based on configuration
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module io_map
(
   i_cfg,
   
   i_ioctrl_db,
   o_ioctrl_dir,
   o_ioctrl_db,
   
   mipi_sclk,
   mipi_sdi,
   mipi_sdo,
   mipi_sdo_en,
   
   freq_io,
   
   i_io_db,
   o_io_dir,
   o_io_db
);

   ////////////////// PORT ////////////////////
   input  [`IOCFG_DATA_NUM*`IOCFG_DATA_NBIT-1:0] i_cfg;
   
   output [`IO_UNIT_NBIT-1:0] i_ioctrl_db;
   input  [`IO_UNIT_NBIT-1:0] o_ioctrl_dir;
   input  [`IO_UNIT_NBIT-1:0] o_ioctrl_db;
   
   input  [`MIPI_GP_NUM-1:0]  mipi_sclk;
   output [`MIPI_GP_NUM-1:0]  mipi_sdi;
   input  [`MIPI_GP_NUM-1:0]  mipi_sdo;
   input  [`MIPI_GP_NUM-1:0]  mipi_sdo_en;
   
   output [`FREQ_GP_NUM-1:0]  freq_io;
   
   input  [`IO_UNIT_NBIT-1:0] i_io_db;
   output [`IO_UNIT_NBIT-1:0] o_io_dir;
   output [`IO_UNIT_NBIT-1:0] o_io_db;
   
   ////////////////// ARCH ////////////////////

   // Pn: P1 P2 P3
   reg [`IO_UNIT_NBIT-1:0]   t_io_dir;
   reg [`IO_UNIT_NBIT-1:0]   t_io_db;
   reg [`IO_UNIT_NBIT-1:0]   t_ioctrl_db;
   // mipi
   reg  [`MIPI_GP_NUM-1:0]  t_sdi[`IO_UNIT_NBIT-1:0];
   wire [`IO_UNIT_NBIT-1:0] v_sdi[`MIPI_GP_NUM-1:0];
   // freq
   reg  [`FREQ_GP_NUM-1:0]  t_freq_io[`IO_UNIT_NBIT-1:0];
   wire [`IO_UNIT_NBIT-1:0] v_freq_io[`FREQ_GP_NUM-1:0];
   
   generate
   genvar m;
   for(m=0;m<`IO_UNIT_NBIT;m=m+1)
   begin: io_mapping
      always@* begin
         // P1
         case(i_cfg[(`IO_UNIT_NBIT-m)*`IOCFG_DATA_NBIT-1:(`IO_UNIT_NBIT-m-1)*`IOCFG_DATA_NBIT])
            `IOCFG_DATA_NBIT'h0: begin
               // default, IO, inout
               t_io_db[m]     <= o_ioctrl_db[m];
               t_io_dir[m]    <= o_ioctrl_dir[m];
               t_ioctrl_db[m] <= i_io_db[m];
               // latch
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h1: begin 
               // mipi_clk[0], output
               t_io_db[m]     <= mipi_sclk[0];
               t_io_dir[m]    <= `HIGH;
               // latch
               t_ioctrl_db[m] <= `LOW;
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h2: begin 
               // mipi_clk[1], output
               t_io_db[m]     <= mipi_sclk[1];
               t_io_dir[m]    <= `HIGH;
               // latch
               t_ioctrl_db[m] <= `LOW;
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h3: begin 
               // mipi_clk[2], output
               t_io_db[m]     <= mipi_sclk[2];
               t_io_dir[m]    <= `HIGH;
               // latch
               t_ioctrl_db[m] <= `LOW;
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h4: begin 
               // mipi_clk[3], output
               t_io_db[m]     <= mipi_sclk[3];
               t_io_dir[m]    <= `HIGH;
               // latch
               t_ioctrl_db[m] <= `LOW;
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h5: begin 
               // mipi_sda[0], inout
               t_io_db[m]     <= mipi_sdo[0];
               t_io_dir[m]    <= mipi_sdo_en[0];
               t_sdi[m]       <= {{`MIPI_GP_NUM-1{1'b0}},i_io_db[m]};
               // latch
               t_ioctrl_db[m] <= `LOW;
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h6: begin 
               // mipi_sda[1], inout
               t_io_db[m]     <= mipi_sdo[1];
               t_io_dir[m]    <= mipi_sdo_en[1];
               t_sdi[m]       <= {{`MIPI_GP_NUM-2{1'b0}},i_io_db[m],1'b0};
               // latch
               t_ioctrl_db[m] <= `LOW;
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h7: begin 
               // mipi_sda[2], inout
               t_io_db[m]     <= mipi_sdo[2];
               t_io_dir[m]    <= mipi_sdo_en[2];
               t_sdi[m]       <= {{`MIPI_GP_NUM-3{1'b0}},i_io_db[m],2'b00};
               // latch
               t_ioctrl_db[m] <= `LOW;
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h8: begin 
               // mipi_sda[3], inout
               t_io_db[m]     <= mipi_sdo[3];
               t_io_dir[m]    <= mipi_sdo_en[3];
               t_sdi[m]       <= {{`MIPI_GP_NUM-4{1'b0}},i_io_db[m],3'b000};
               // latch
               t_ioctrl_db[m] <= `LOW;
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h19: begin
               // counter[0], input
               t_freq_io[m]   <= {{`FREQ_GP_NUM-1{1'b0}},i_io_db[m]};
               t_io_dir[m]    <= `LOW;
               // latch
               t_io_db[m]     <= `LOW;
               t_ioctrl_db[m] <= `LOW;
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h20: begin
               // counter[1], input
               t_freq_io[m]   <= {{`FREQ_GP_NUM-2{1'b0}},i_io_db[m],1'b0};
               t_io_dir[m]    <= `LOW;
               // latch
               t_io_db[m]     <= `LOW;
               t_ioctrl_db[m] <= `LOW;
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h21: begin
               // counter[2], input
               t_freq_io[m]   <= {{`FREQ_GP_NUM-3{1'b0}},i_io_db[m],2'b00};
               t_io_dir[m]    <= `LOW;
               // latch
               t_io_db[m]     <= `LOW;
               t_ioctrl_db[m] <= `LOW;
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
            end
            `IOCFG_DATA_NBIT'h22: begin
               // counter[3], input
               t_freq_io[m]   <= {{`FREQ_GP_NUM-4{1'b0}},i_io_db[m],3'b000};
               t_io_dir[m]    <= `LOW;
               // latch
               t_io_db[m]     <= `LOW;
               t_ioctrl_db[m] <= `LOW;
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
            end
            default: begin
               // default, IO, inout
               t_io_db[m]     <= o_ioctrl_db[m];
               t_io_dir[m]    <= o_ioctrl_dir[m];
               t_ioctrl_db[m] <= i_io_db[m];
               // latch
               t_sdi[m]       <= {`MIPI_GP_NUM{1'b0}};
               t_freq_io[m]   <= {`FREQ_GP_NUM{1'b0}};
            end
         endcase
      end
		assign o_io_dir[m] = t_io_dir[m];
		assign o_io_db[m]  = t_io_db[m];
		assign i_ioctrl_db[m] = t_ioctrl_db[m];
		assign {v_sdi[3][m],v_sdi[2][m],v_sdi[1][m],v_sdi[0][m]} = t_sdi[m];
		assign {v_freq_io[3][m],v_freq_io[2][m],v_freq_io[1][m],v_freq_io[0][m]} = t_freq_io[m];
   end
   endgenerate
   
   generate
   genvar s;
   for(s=0;s<`MIPI_GP_NUM;s=s+1)
   begin: sdi_assign
      assign mipi_sdi[s] = |v_sdi[s];
      assign freq_io[s] = |v_freq_io[s];
   end
   endgenerate
   
endmodule   