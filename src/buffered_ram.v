////////////////////////////////////////////////////////////////
//
//  Module  : buffered_ram
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2015/11/23 23:11:40
//
////////////////////////////////////////////////////////////////
// 
//  Description:
//  RAM module specifically instantiated looking to pipeline optimization
//  data read has buffer both for address and for output data, in order to relax
//  timing closure; this lead two clock cycles for read transaction
//  a double bus is instantiated for simultaneous read and write, in case of read/write on
//  same address the read operation return the old value
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module buffered_ram
   (
      inclk,
      
      in_wren,
      in_wraddress,
      in_wrdata,

      in_rdaddress,

      out_rddata
   );

   ///////////////// PARAMETER ////////////////
   parameter p_addresswidth=4;               // # of address bit
   parameter p_datawidth=16;                 // # of data bit
   parameter p_init_file="UNUSED";

   ////////////////// PORT ////////////////////
   input                      inclk;
   input                      in_wren;
   input [p_addresswidth-1:0] in_wraddress;
   input [p_datawidth-1:0]    in_wrdata;

   input [p_addresswidth-1:0] in_rdaddress;

   output [p_datawidth-1:0]   out_rddata;

   ////////////////// ARCH ////////////////////
      
   altsyncram buffered_ram_altsyncram
   (
      .address_a (in_wraddress),
      .clock0 (inclk),
      .data_a (in_wrdata),
      .wren_a (in_wren),
      .address_b (in_rdaddress),
      .q_b (out_rddata),
      .aclr0 (1'b0),
      .aclr1 (1'b0),
      .addressstall_a (1'b0),
      .addressstall_b (1'b0),
      .byteena_a (1'b1),
      .byteena_b (1'b1),
      .clock1 (1'b1),
      .clocken0 (1'b1),
      .clocken1 (1'b1),
      .clocken2 (1'b1),
      .clocken3 (1'b1),
      .data_b ({p_datawidth{1'b1}}),
      .eccstatus (),
      .q_a (),
      .rden_a (1'b1),
      .rden_b (1'b1),
      .wren_b (1'b0)
   );

   defparam
      buffered_ram_altsyncram.address_aclr_b = "NONE",
      buffered_ram_altsyncram.address_reg_b = "CLOCK0",
      buffered_ram_altsyncram.clock_enable_input_a = "BYPASS",
      buffered_ram_altsyncram.clock_enable_input_b = "BYPASS",
      buffered_ram_altsyncram.clock_enable_output_b = "BYPASS",
      buffered_ram_altsyncram.intended_device_family = "Cyclone III",
      buffered_ram_altsyncram.lpm_type = "altsyncram",
      buffered_ram_altsyncram.numwords_a = 2**p_addresswidth,
      buffered_ram_altsyncram.numwords_b = 2**p_addresswidth,
      buffered_ram_altsyncram.operation_mode = "DUAL_PORT",
      buffered_ram_altsyncram.outdata_aclr_b = "NONE",
      buffered_ram_altsyncram.outdata_reg_b = "CLOCK0",
      buffered_ram_altsyncram.power_up_uninitialized = "FALSE",
      buffered_ram_altsyncram.read_during_write_mode_mixed_ports = "OLD_DATA",
      buffered_ram_altsyncram.widthad_a = p_addresswidth,
      buffered_ram_altsyncram.widthad_b = p_addresswidth,
      buffered_ram_altsyncram.width_a = p_datawidth,
      buffered_ram_altsyncram.width_b = p_datawidth,
      buffered_ram_altsyncram.width_byteena_a = 1,
      buffered_ram_altsyncram.ram_block_type = "M9K",
      buffered_ram_altsyncram.init_file = p_init_file;

endmodule