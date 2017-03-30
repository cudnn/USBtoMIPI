/////////////////////////// INCLUDE /////////////////////////////
`include "./globals.v"

////////////////////////////////////////////////////////////////
//
//  Module  : mipi.v
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2015/11/28 
//
////////////////////////////////////////////////////////////////
// 
//  Description: interface of MIPI
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module mipi
(
   clk,
   // clock cycle setting
   set,
   div,
   // control 
   start,
   done,
   num,
   cusmode,
   cusssc ,
   cusnbit,
   // BUFFER Interface
   i_buf_clk,
   i_buf_wr,
   i_buf_waddr,
   i_buf_wdata,
   i_buf_raddr,
   o_buf_rdata,
   // MIPI Interface
   sclk,
   ssc,
   sdi,
   sdo,
   sdo_en
);

   ////////////////// PORT ////////////////////
   input                            clk;     // high frequency clock input, 48MHz
   input                            set;     // set signale of clock cycle
   input  [`MIPI_CLKDIV_NBIT-1:0]   div;     // value of clock cycle
                                             // range from 2 to 255 correspond to 24MHz ~ 188KHz 
   input                            start;   // start of mipi 
   output                           done;    // done of mipi
   output [`MIPI_BUF_ADDR_NBIT-1:0] num;     // data number
   input                            cusmode; // custum mode
   input                            cusssc ;
   input  [`MIPI_DATA_NBIT*2-1:0]   cusnbit;
   
   input                            i_buf_clk  ;
   input                            i_buf_wr   ;
   input  [`MIPI_BUF_ADDR_NBIT-1:0] i_buf_waddr;
   input  [`MIPI_BUF_DATA_NBIT-1:0] i_buf_wdata;
   input  [`MIPI_BUF_ADDR_NBIT-1:0] i_buf_raddr;
   output [`MIPI_BUF_DATA_NBIT-1:0] o_buf_rdata;
     
   output                           sclk;
   output                           ssc;
   input                            sdi;
   output                           sdo;
   output                           sdo_en;
   
   ////////////////// ARCH ////////////////////
   
   ////////////////// clock division
   reg                          mipi_clk=`LOW;
   reg  [`MIPI_CLKDIV_NBIT-1:0] clk_div=`MIPI_CLKDIV_NBIT'd2;
   reg  [`MIPI_CLKDIV_NBIT-1:0] clk_cnt=`MIPI_CLKDIV_NBIT'd1;
   localparam  clk_dly=`MIPI_CLKDIV_NBIT'd0;
   
   always@(posedge clk) begin
      clk_cnt <= clk_cnt - 1'b1;
      if(clk_cnt==0)
         clk_cnt  <= clk_div-1'b1;

      if(clk_cnt+clk_dly==(clk_div>>1))
         mipi_clk <= `LOW;
      else if(clk_cnt+clk_dly==(clk_dly==0 ? 0 : clk_div))
         mipi_clk <= `HIGH;
         
      // minimum value of clock cycle is 2, means up to 24MHz
      if(set) begin
         clk_div  <= div<`MIPI_CLKDIV_NBIT'd2 ? `MIPI_CLKDIV_NBIT'd2 : div;
         clk_cnt  <= div<`MIPI_CLKDIV_NBIT'd2 ? `MIPI_CLKDIV_NBIT'd1 : div-1'b1;
         mipi_clk <= `HIGH;
      end
   end
   
   assign sclk = sclk_en&mipi_clk;
      
   ////////////////// RX
   
   // start
   reg p_start=`LOW;
   always@(posedge clk) begin
      if(start)
         p_start <= `HIGH;
      else if(clk_en)
         p_start <= `LOW;
   end
   
   wire mipi_start;
   assign mipi_start = p_start&clk_en;
   
   // DATA Buffer
   // addr: 0   1  2   3~4  5~20
   // data: div sa cmd addr data
   wire [`MIPI_BUF_DATA_NBIT-1:0] mipi_buf_rdata;
   buffered_ram_tdp#(`MIPI_BUF_ADDR_NBIT,`MIPI_BUF_DATA_NBIT)
   mipi_buffer(
      .a_inclk     (i_buf_clk),
      .a_in_wren   (i_buf_wr&~in_process),
      .a_in_address(i_buf_wr ? i_buf_waddr : i_buf_raddr),
      .a_in_wrdata (i_buf_wdata),
      .a_out_rddata(o_buf_rdata),
      .b_inclk     (clk           ),
      .b_in_wren   (mipi_buf_wr&in_process),
      .b_in_address(mipi_buf_wr ? mipi_buf_waddr : mipi_buf_raddr),
      .b_in_wrdata (mipi_buf_wdata),
      .b_out_rddata(mipi_buf_rdata)
   );
   
   // User data length
   reg  [`MIPI_BUF_ADDR_NBIT-1:0] i_wdata_num;
   always@(posedge i_buf_clk) begin
      if(i_buf_wr&~in_process)
         i_wdata_num <= i_buf_waddr - `MIPI_DATA_BASEADDR;
   end
   
   reg  [`MIPI_BUF_ADDR_NBIT-1:0] mipi_wdata_num; // clock transfer
   always@(posedge clk) begin
      mipi_wdata_num <= i_wdata_num;
      if(~cusmode&&(i_wdata_num<0))
         mipi_wdata_num <= {`MIPI_BUF_ADDR_NBIT{1'b1}};
   end
      
   // PARITY BIT
   reg  pb_strobe;
   reg  pb_data;
   wire pb_parity;
   parity parity_u
   (
      .clk     (clk),
      .en      (clk_en),
      .i_strobe(pb_strobe),
      .i_data  (pb_data),
      .o_parity(pb_parity)
   );    
   
   // FSM
   `define ST_MIPI_IDLE    3'd0
   `define ST_MIPI_START   3'd1
   `define ST_MIPI_SA      3'd2
   `define ST_MIPI_CMD     3'd3
   `define ST_MIPI_ADDR    3'd4
   `define ST_MIPI_DATA    3'd5
   `define ST_MIPI_BUSPARK 3'd6
   `define ST_MIPI_END     3'd7
   
   reg  [2:0]                     st;
   reg  [`MIPI_BUF_ADDR_NBIT-1:0] st_turns;
   reg  [3:0]                     sf_cnt;
   reg  [`MIPI_BUF_DATA_NBIT-1:0] sf_data;

   reg                            mipi_op; // 1: read; 0: write         
   reg  [`MIPI_CMD_NBIT-1:0]      mipi_cmd;
   reg  [`MIPI_BUF_ADDR_NBIT-1:0] mipi_buf_upaddr;
   reg  [`MIPI_BUF_ADDR_NBIT-1:0] mipi_buf_raddr;
   reg  [`MIPI_BUF_ADDR_NBIT-1:0] num;

   wire   clk_en;
   assign clk_en = (clk_cnt==0);
      
   always@(posedge clk) begin
      if(clk_en) begin
         case(st)
            `ST_MIPI_IDLE: begin
               mipi_buf_raddr  <= `MIPI_DIV_BASEADDR;
               st_turns        <= 0;
               sf_cnt          <= 0;
               sf_data         <= 0;
               mipi_buf_upaddr <= `MIPI_DATA_BASEADDR; // point to the address of DATA region
               mipi_op         <= `LOW;
               if(mipi_start) begin
                  st             <= `ST_MIPI_START;
                  sf_cnt         <= 4'd1; // two bits of SSC, {HIGH LOW}
                  sf_data        <= `MIPI_SSC_PAT;
                  mipi_buf_raddr <= `MIPI_SA_BASEADDR;
                  num            <= 0;
                  /////// custom mode ///////
                  if(cusmode) begin
                     sf_data        <= ~cusssc ? `MIPI_BUF_DATA_NBIT'd0 : `MIPI_SSC_PAT;
                     mipi_buf_raddr <= `MIPI_CDATA_BASEADDR;
                  end
                  ///////             ///////
               end
            end
            `ST_MIPI_START: begin
               sf_cnt  <= sf_cnt - 1'b1;
               sf_data <= sf_data<<1; // Left shift, first output MSB
               if(sf_cnt==0) begin
                  st             <= `ST_MIPI_SA;
                  sf_cnt         <= 4'd`MIPI_SA_NBIT-1'b1;
                  sf_data        <= {mipi_buf_rdata[`MIPI_SA_NBIT-1:0],{`MIPI_BUF_DATA_NBIT-`MIPI_SA_NBIT{1'b0}}}; // 4-bit slave address
                  mipi_buf_raddr <= `MIPI_CMD_BASEADDR;
                  /////// custom mode ///////
                  if(cusmode) begin 
                     st                <= `ST_MIPI_DATA;
                     sf_data           <= mipi_buf_rdata;
                     mipi_buf_raddr    <= mipi_buf_raddr + 1'b1;
                     if(cusnbit!=0) begin
                        sf_cnt         <= cusnbit[`MIPI_BUF_ADDR_NBIT-1+2:2]==0 ? cusnbit[1:0]-1'b1 : (4'd`MIPI_DATA_NBIT>>1)-1'b1;
                        st_turns       <= cusnbit[1:0]==0 ? cusnbit[`MIPI_BUF_ADDR_NBIT-1+2:2]-1'b1 : cusnbit[`MIPI_BUF_ADDR_NBIT-1+2:2];
                        mipi_buf_upaddr<= `MIPI_CDATA_BASEADDR+(cusnbit[1:0]==0 ? cusnbit[`MIPI_BUF_ADDR_NBIT-1+2:2]-1'b1 : cusnbit[`MIPI_BUF_ADDR_NBIT-1+2:2]);
                     end
                     else
                        st <= `ST_MIPI_END;                     
                  end
                  ///////             ///////
               end
            end
            `ST_MIPI_SA: begin
               sf_cnt  <= sf_cnt - 1'b1;
               sf_data <= sf_data<<1;
               if(sf_cnt==4'd`MIPI_SA_NBIT-2'd2) begin
                  mipi_cmd <= mipi_buf_rdata;
                  // register 0 write: next send {cmd[7],data[6:0]}
                  if((mipi_buf_rdata&`MIPI_CMD_ZERO_MASK)==`MIPI_CMD_WRZERO_PAT) begin
                     mipi_buf_raddr <= `MIPI_DATA_BASEADDR;
                  end
                  // register write&read: next send {cmd[7:5],address[4:0]}
                  else if((mipi_buf_rdata&`MIPI_CMD_REG_MASK)==`MIPI_CMD_WR_PAT || 
                          (mipi_buf_rdata&`MIPI_CMD_REG_MASK)==`MIPI_CMD_RD_PAT) begin
                     mipi_buf_raddr <= `MIPI_ADDR_BASEADDR + 1'b1; // Address[15:8]
                  end
                  else
                     mipi_buf_raddr <= `MIPI_ADDR_BASEADDR;
               end                  
               else if(sf_cnt==0) begin
                  st      <= `ST_MIPI_CMD;
                  sf_cnt  <= 4'd`MIPI_CMD_NBIT;
                  sf_data <= mipi_cmd; // 8-bit command
                  // register 0 write: {cmd[7],data[6:0]}
                  if((mipi_cmd&`MIPI_CMD_ZERO_MASK)==`MIPI_CMD_WRZERO_PAT) begin
                     sf_data <= {mipi_cmd[7],mipi_buf_rdata[6:0]};
                     mipi_op <= `LOW;
                  end
                  // register write&read: {cmd[7:5],address[4:0]}
                  else if((mipi_cmd&`MIPI_CMD_REG_MASK)==`MIPI_CMD_WR_PAT || 
                          (mipi_cmd&`MIPI_CMD_REG_MASK)==`MIPI_CMD_RD_PAT) begin
                     sf_data        <= {mipi_cmd[7:5],mipi_buf_rdata[4:0]};
                     mipi_buf_raddr <= `MIPI_DATA_BASEADDR;
                     mipi_op        <= mipi_cmd[5];
                  end
                  // register extended write&read long: cmd[7:0]
                  else if((mipi_cmd&`MIPI_CMD_EXTL_MASK)==`MIPI_CMD_EXTWRL_PAT || 
                          (mipi_cmd&`MIPI_CMD_EXTL_MASK)==`MIPI_CMD_EXTRDL_PAT) begin
                     mipi_buf_raddr <= `MIPI_ADDR_BASEADDR;
                     mipi_op        <= mipi_cmd[3];
                  end
                  // register extended write&read: cmd[7:0]
                  else if((mipi_cmd&`MIPI_CMD_EXT_MASK)==`MIPI_CMD_EXTWR_PAT || 
                          (mipi_cmd&`MIPI_CMD_EXT_MASK)==`MIPI_CMD_EXTRD_PAT) begin
                     mipi_buf_raddr <= `MIPI_ADDR_BASEADDR + 1'b1;
                     mipi_op        <= mipi_cmd[5];
                  end
                  else
                     st <= `ST_MIPI_IDLE;
               end
            end
            `ST_MIPI_CMD: begin
               sf_cnt  <= sf_cnt - 1'b1;
               sf_data <= sf_data<<1;
               if(sf_cnt==0) begin
                  st      <= `ST_MIPI_END;
                  sf_cnt  <= 4'd`MIPI_ADDR_NBIT;
                  sf_data <= mipi_buf_rdata;
                  // register 0 write: next st IDLE
                  if((mipi_cmd&`MIPI_CMD_ZERO_MASK)==`MIPI_CMD_WRZERO_PAT) begin
                     st  <= `ST_MIPI_END;
                     num <= `MIPI_BUF_ADDR_NBIT'd1;
                  end
                  // register write&read: next st DATA
                  else if((mipi_cmd&`MIPI_CMD_REG_MASK)==`MIPI_CMD_WR_PAT || 
                          (mipi_cmd&`MIPI_CMD_REG_MASK)==`MIPI_CMD_RD_PAT) begin
                     st       <= mipi_op ? `ST_MIPI_BUSPARK : `ST_MIPI_DATA;
                     sf_cnt   <= 4'd`MIPI_DATA_NBIT;
                     st_turns <= 4'd0; // one byte data, D0
                     num      <= `MIPI_BUF_ADDR_NBIT'd1;                     
                  end
                  // register extended write&read long: next st ADDR
                  else if((mipi_cmd&`MIPI_CMD_EXTL_MASK)==`MIPI_CMD_EXTWRL_PAT || 
                          (mipi_cmd&`MIPI_CMD_EXTL_MASK)==`MIPI_CMD_EXTRDL_PAT) begin
                     st             <= `ST_MIPI_ADDR;
                     st_turns       <= 4'd1; // two bytes address, A1 A0
                     mipi_buf_raddr <= `MIPI_ADDR_BASEADDR + 1'b1;
                     num            <= mipi_cmd[2:0] + 1'b1; 
                     if(cusmode&&(mipi_cmd&`MIPI_CMD_EXTL_MASK)==`MIPI_CMD_EXTWRL_PAT)
                        num         <= mipi_wdata_num[2:0] + 1'b1; 
                  end
                  // register extended write&read: next st ADDR
                  else if((mipi_cmd&`MIPI_CMD_EXT_MASK)==`MIPI_CMD_EXTWR_PAT || 
                          (mipi_cmd&`MIPI_CMD_EXT_MASK)==`MIPI_CMD_EXTRD_PAT) begin
                     st             <= `ST_MIPI_ADDR;
                     st_turns       <= 4'd0; // one byte address, A0
                     mipi_buf_raddr <= `MIPI_DATA_BASEADDR;
                     num            <= mipi_cmd[3:0] + 1'b1; 
                     if(~cusmode&&(mipi_cmd&`MIPI_CMD_EXT_MASK)==`MIPI_CMD_EXTWR_PAT)
                        num         <= mipi_wdata_num[3:0] + 1'b1;
                  end
               end
            end
            `ST_MIPI_ADDR: begin
               sf_cnt <= sf_cnt - 1'b1;
               sf_data <= sf_data<<1;
               if(sf_cnt==0) begin
                  sf_cnt         <= 4'd`MIPI_ADDR_NBIT;
                  sf_data        <= mipi_op ? `MIPI_BUF_DATA_NBIT'd0 : mipi_buf_rdata; // pull down sdo when reading
                  mipi_buf_raddr <= `MIPI_DATA_BASEADDR;
                  if(st_turns==0) begin
                     st     <= mipi_op ? `ST_MIPI_BUSPARK : `ST_MIPI_DATA;
                     sf_cnt <= 4'd`MIPI_DATA_NBIT;
                     if((mipi_cmd&`MIPI_CMD_EXTL_MASK)==`MIPI_CMD_EXTWRL_PAT) begin // write all the data from USER
                        st_turns        <= ~cusmode ? mipi_cmd[2:0] : mipi_wdata_num[2:0]; 
                        mipi_buf_upaddr <= `MIPI_DATA_BASEADDR + (~cusmode ? mipi_cmd[2:0] : mipi_wdata_num[2:0]);
                     end
                     else if((mipi_cmd&`MIPI_CMD_EXTL_MASK)==`MIPI_CMD_EXTRDL_PAT) begin // read data, number set by BC[2:0]
                        st_turns        <= mipi_cmd[2:0];
                        mipi_buf_upaddr <= `MIPI_DATA_BASEADDR + mipi_cmd[2:0];
                     end
                     else if((mipi_cmd&`MIPI_CMD_EXT_MASK)==`MIPI_CMD_EXTWR_PAT) begin // write all the data from USER
                        st_turns        <= ~cusmode ? mipi_cmd[3:0] : mipi_wdata_num[3:0]; 
                        mipi_buf_upaddr <= `MIPI_DATA_BASEADDR + (~cusmode ? mipi_cmd[3:0] : mipi_wdata_num[3:0]);
                     end
                     else if((mipi_cmd&`MIPI_CMD_EXT_MASK)==`MIPI_CMD_EXTRD_PAT) begin // read data, number set by BC[3:0]
                        st_turns        <= mipi_cmd[3:0];
                        mipi_buf_upaddr <= `MIPI_DATA_BASEADDR + mipi_cmd[3:0];
                     end
                     mipi_buf_raddr <= mipi_buf_raddr + 1'b1;
                  end
                  else
                     st_turns <= st_turns - 1'b1;
               end
            end
            `ST_MIPI_DATA: begin
               sf_cnt  <= sf_cnt - 1'b1;
               sf_data <= {sf_data[`MIPI_BUF_DATA_NBIT-2:0],(mipi_op ? sdi : 1'b0)};
               /////// custom mode ///////
               if(cusmode) 
                  sf_data <= {sf_data[`MIPI_BUF_DATA_NBIT-3:0],sf_data[`MIPI_BUF_DATA_NBIT-1],sdi};
               ///////             ///////
               if(sf_cnt==0) begin
                  sf_cnt   <= 4'd`MIPI_DATA_NBIT;
                  /////// custom mode ///////
                  if(cusmode) begin 
                     sf_cnt <= (st_turns==1)&&(cusnbit[1:0]!=0) ? cusnbit[1:0]-1'b1 : (4'd`MIPI_DATA_NBIT>>1)-1'b1;
                     num    <= (cusnbit[1:0]==0 ? cusnbit[`MIPI_BUF_ADDR_NBIT-1+2:2]-1'b1 : cusnbit[`MIPI_BUF_ADDR_NBIT-1+2:2]) + 1'b1 + (`MIPI_CDATA_BASEADDR-`MIPI_DATA_BASEADDR);
                  end
                  ///////             ///////
                  
                  sf_data  <= mipi_op ? `MIPI_BUF_DATA_NBIT'd0 : mipi_buf_rdata;                  
                  st_turns <= st_turns - 1'b1;
                  mipi_buf_raddr <= mipi_buf_raddr + 1'b1;
                  if(st_turns==0) begin
                     sf_cnt   <= 0;
                     st_turns <= 0;
                     st       <= `ST_MIPI_END;
                  end
               end
            end
            `ST_MIPI_BUSPARK: begin
               st      <= `ST_MIPI_DATA;
               sf_data <= 0;
            end
            `ST_MIPI_END: begin
               st <= `ST_MIPI_IDLE;
            end
            default:
               st <= `ST_MIPI_IDLE;
         endcase
      end
   end

   reg in_process;
   reg ssc;
   reg sdo;
   reg sdo_en;
   reg sclk_en;
   reg done;

   reg                            mipi_buf_wr   ;
   reg  [`MIPI_BUF_ADDR_NBIT-1:0] mipi_buf_waddr;
   reg  [`MIPI_BUF_DATA_NBIT-1:0] mipi_buf_wdata;
   
   always@* begin
      case(st)
         `ST_MIPI_IDLE: begin
            in_process     <= `LOW;
            pb_strobe      <= `LOW;
            pb_data        <= `LOW;
            ssc            <= `LOW;
            sdo            <= `LOW;
            sdo_en         <= `LOW;
            sclk_en        <= `LOW;
            done           <= `LOW;
            mipi_buf_wr    <= `LOW;
            mipi_buf_waddr <= 0;
            mipi_buf_wdata <= 0;
         end
         `ST_MIPI_START: begin
            in_process     <= `HIGH;
            pb_strobe      <= `LOW;
            pb_data        <= `LOW;
            ssc            <= sf_data[`MIPI_BUF_DATA_NBIT-1];
            sdo            <= `LOW;
            sdo_en         <= `HIGH;
            sclk_en        <= `LOW;
            done           <= `LOW;
            mipi_buf_wr    <= `LOW;
            mipi_buf_waddr <= 0;
            mipi_buf_wdata <= 0;
         end
         `ST_MIPI_SA: begin
            in_process     <= `HIGH;
            pb_strobe      <= `HIGH;
            pb_data        <= sf_data[`MIPI_BUF_DATA_NBIT-1];
            ssc            <= `LOW;
            sdo            <= sf_data[`MIPI_BUF_DATA_NBIT-1];
            sdo_en         <= `HIGH;
            sclk_en        <= `HIGH;
            done           <= `LOW;
            mipi_buf_wr    <= `LOW;
            mipi_buf_waddr <= 0;
            mipi_buf_wdata <= 0;
         end
         `ST_MIPI_CMD: begin
            in_process     <= `HIGH;
            pb_strobe      <= sf_cnt!=0;
            pb_data        <= sf_data[`MIPI_BUF_DATA_NBIT-1];
            ssc            <= `LOW;
            sdo            <= sf_cnt==0 ? pb_parity : sf_data[`MIPI_BUF_DATA_NBIT-1];
            sdo_en         <= `HIGH;
            sclk_en        <= `HIGH;
            done           <= `LOW;
            mipi_buf_wr    <= `LOW;
            mipi_buf_waddr <= 0;
            mipi_buf_wdata <= 0;
         end
         `ST_MIPI_ADDR: begin
            in_process     <= `HIGH;
            pb_strobe      <= sf_cnt!=0;
            pb_data        <= sf_data[`MIPI_BUF_DATA_NBIT-1];
            ssc            <= `LOW;
            sdo            <= sf_cnt==0 ? pb_parity : sf_data[`MIPI_BUF_DATA_NBIT-1];
            sdo_en         <= `HIGH;
            sclk_en        <= `HIGH;
            done           <= `LOW;
            mipi_buf_wr    <= `LOW;
            mipi_buf_waddr <= 0;
            mipi_buf_wdata <= 0;
         end
         `ST_MIPI_DATA: begin
            in_process     <= `HIGH;
            pb_strobe      <= sf_cnt!=0;
            pb_data        <= sf_data[`MIPI_BUF_DATA_NBIT-1];
            ssc            <= `LOW;
            sdo            <= ~mipi_op ? (sf_cnt==0 ? pb_parity : sf_data[`MIPI_BUF_DATA_NBIT-1]) : `LOW;
            sdo_en         <= ~mipi_op;
            /////// custom mode ///////
            if(cusmode) begin
               sdo         <= sf_data[`MIPI_BUF_DATA_NBIT-2];
               sdo_en      <=~sf_data[`MIPI_BUF_DATA_NBIT-1];
            end
            ///////             ///////                  
            sclk_en        <= `HIGH;
            done           <= `LOW;
            mipi_buf_wr    <= mipi_op&(sf_cnt==0);
            mipi_buf_waddr <= mipi_buf_upaddr - st_turns;
            mipi_buf_wdata <= sf_data;
         end
         `ST_MIPI_BUSPARK: begin
            in_process     <= `HIGH;
            pb_strobe      <= sf_cnt!=0;
            pb_data        <= `LOW;
            ssc            <= `LOW;
            sdo            <= `LOW;
            sdo_en         <= (clk_cnt>=(clk_div>>1)); // output LOW while the first half cycle
            sclk_en        <= `HIGH;
            done           <= `LOW;
            mipi_buf_wr    <= `LOW;
            mipi_buf_waddr <= 0;
            mipi_buf_wdata <= 0;
        end
         `ST_MIPI_END: begin
            in_process     <= `HIGH;
            pb_strobe      <= `LOW;
            pb_data        <= `LOW;
            ssc            <= `LOW;
            sdo            <= `LOW;
            sdo_en         <= (clk_cnt>=(clk_div>>1)); // as the same behavior as BUSPARK
            sclk_en        <= `HIGH;
            /////// custom mode ///////
            if(cusmode&&(mipi_buf_rdata!=`MIPI_BP_PAT)) begin
               sdo_en      <= `LOW;
               sclk_en     <= `LOW;
            end
            ///////             ///////                  
            done           <= `HIGH;
            mipi_buf_wr    <= `LOW;
            mipi_buf_waddr <= 0;
            mipi_buf_wdata <= 0;
         end
         default:;
      endcase
   end
   
endmodule

////////////////////////////////////////////////////////////////
//
//  Module  : parity
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2015/12/1 
//
////////////////////////////////////////////////////////////////
// 
//  Description: parity operation
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module parity
(
   clk,
   en,
   i_strobe,
   i_data,
   o_parity
); 

   ////////////////// PORT ////////////////////
   input  clk;
   input  en; // clock enable
   input  i_strobe;
   input  i_data;
   output o_parity;
   
   ////////////////// ARCH ////////////////////
   
   reg t_parity;
   
   always@(posedge clk) begin   
      if(en) begin
         if(i_strobe)
            t_parity <= i_data ^ t_parity;
         else
            t_parity <= `LOW;
      end
   end
   
   // Totally number of HIGH is odd, include parity bit
   assign o_parity = ~t_parity;

endmodule