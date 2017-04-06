/////////////////////////// INCLUDE /////////////////////////////
`include "./globals.v"

////////////////////////////////////////////////////////////////
//
//  Module  : pkt_decode
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2015/11/18 21:35:04
//
////////////////////////////////////////////////////////////////
// 
//  Description: - decode the received command
//               - send tx command
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module pkt_decode
(
   clk,
   fast_clk,
   // IO
   o_io_dir,
   i_io_db,
   o_io_db,
   o_io_bank,
   // MIPI Interface
   mipi_clk,
   mipi_bank,
   sclk,
   sdi,
   sdo,
   sdo_en,
   // Interface with RX BUFFER
   rx_vd,
   rx_data,
   rx_sop,
   rx_eop ,
   // Interface with TX BUFFER
   tx_vd,
   tx_addr,
   tx_data,
   tx_eop
); 

   ////////////////// PORT ////////////////////
   input                        clk;      // main clock 48MHz
   input                        fast_clk; // fast clock
   input                        mipi_clk; // mipi clock 52MHz
                                
   output [`IO_UNIT_NBIT-1:0]   o_io_dir;
   input  [`IO_UNIT_NBIT-1:0]   i_io_db;
   output [`IO_UNIT_NBIT-1:0]   o_io_db;
   output [`IO_BANK_NBIT-1:0]   o_io_bank;
                                
   output [`MIPI_BANK_NBIT-1:0] mipi_bank;
   output                       sclk;
   input                        sdi;
   output                       sdo;
   output                       sdo_en;
                                
   input                        rx_vd  ;
   input  [`USB_DATA_NBIT-1:0]  rx_data;
   input                        rx_sop ;
   input                        rx_eop ;
                                
   output                       tx_vd;
   output [`USB_ADDR_NBIT:0]    tx_addr;
   output [`USB_DATA_NBIT-1:0]  tx_data;
   output                       tx_eop;

   ////////////////// ARCH ////////////////////

   ////////////////// RX STATEMENT
   `define ST_MSG_IDLE   3'b000
   `define ST_MSG_HEAD   3'b001
   `define ST_MSG_TYPE   3'b010
   `define ST_MSG_MODE   3'b011
   `define ST_MSG_CHADDR 3'b100
   `define ST_MSG_DATA   3'b101
   `define ST_MSG_END    3'b111

   reg [2:0] rx_st;
   
   // RX Message Structure: {HEAD,TYPE,MODE,CHANNEL_ADDRESS,DATA}
   reg [`MSG_STR_NBIT-1:0]       rx_msg_type; // "00": handshake;
                                              // "01": mipi;
                                              // "02": io
   reg [`MSG_STR_NBIT-1:0]       rx_msg_mode; // "00": reserved;
                                              // "01": reveive data;
                                              // "02": execute data;
                                              // "03": receive and execute data
   reg [`MSG_STR_NBIT-1:0]       rx_msg_ch_addr;
   reg [`IO_BANK_NBIT-1:0]       rx_ch_addr;  // "00" ~ "FF"
   
   reg [`MSG_DATA_MAX_NBIT-1:0]  rx_msg_data;
   reg [`USB_ADDR_NBIT-1:0]      rx_msg_addr;
   reg                           rx_msg_err ;
   reg                           rx_msg_eop ;

   // convert rx data(DATA Region) from char to int
   wire [`USB_DATA_NBIT/2-1:0] atoi_rx_data;
   wire                        atoi_err;
   atoi#(`USB_DATA_NBIT/2) atoi_u 
   (
      .i_char({rx_data[`USB_DATA_NBIT/2-1:0],
               rx_data[`USB_DATA_NBIT-1:`USB_DATA_NBIT/2]}), // invert h and l
      .o_int (atoi_rx_data),
      .o_err (atoi_err    )
   );   
   
   // decode rx command
   always@(posedge clk) begin
      
      // Statement
      rx_msg_eop <= `LOW;
      case(rx_st)
         `ST_MSG_IDLE : begin
            if(rx_sop) begin
               rx_st          <= `ST_MSG_HEAD;
               rx_msg_type    <= 0;
               rx_msg_mode    <= 0;
               rx_ch_addr     <= 0;
               rx_msg_addr    <= 0;
               rx_msg_err     <= `LOW;
               rx_msg_data    <= 0;
               rx_msg_ch_addr <=0;
            end
         end
         `ST_MSG_HEAD: begin
            // Detect HEAD
            if(rx_vd&rx_data==`MSG_HEAD) begin
               rx_st        <= `ST_MSG_TYPE;
            end
         end
         `ST_MSG_TYPE: begin
            if(rx_vd) begin
               // Three TYPE Supported:
               // - "00": HANDSHAKE
               // - "01": MIPI
               // - "02": IO CONTROL
               rx_msg_type  <= rx_data;
               rx_st        <= `ST_MSG_MODE;
            end
         end
         `ST_MSG_MODE : begin
            if(rx_vd) begin
               if(rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_N || rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_R) begin
                  rx_ch_addr   <= 0;
                  rx_msg_mode  <= 0;
                  rx_st        <= `ST_MSG_END;
               end
               else begin
                  rx_msg_mode  <= rx_data;
                  rx_st        <= `ST_MSG_CHADDR;
               end
            end
         end
         `ST_MSG_CHADDR: begin
            if(rx_vd) begin
               if(rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_N || rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_R) begin
                  rx_ch_addr <= 0;
                  rx_msg_ch_addr <= 0;
                  rx_st <= `ST_MSG_END;
               end
               else begin   
                  rx_ch_addr <= atoi_rx_data;
                  rx_msg_err <= atoi_err;
                  rx_msg_ch_addr <= rx_data;
                  rx_st      <= `ST_MSG_DATA;
               end
            end
         end
         `ST_MSG_DATA: begin
            if(rx_vd) begin
               if(rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_N || rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_R)
                  rx_st <= `ST_MSG_END;
               else begin
                  rx_msg_addr <= rx_msg_addr + 1'b1;
                  rx_msg_data <= {rx_msg_data[`MSG_DATA_MAX_NBIT-`USB_DATA_NBIT/2-1:0],atoi_rx_data}; 
                  rx_msg_err  <= atoi_err;
               end
            end
            if(rx_eop) begin
               rx_msg_eop <= `HIGH;
               rx_st      <= `ST_MSG_IDLE;
            end
         end
         `ST_MSG_END: begin
            // wait until all usb data are received
            if(rx_eop) begin
               rx_msg_eop <= `HIGH;
               rx_st      <= `ST_MSG_IDLE;
            end
         end
         default:
            rx_st <= `ST_MSG_IDLE;
      endcase
   end
   
   ////////////////// Instruction Execute
   reg  [`MSG_STR_NBIT-1:0]       tx_msg_type;
   reg  [`MSG_STR_NBIT-1:0]       tx_msg_pf;
   reg  [`MSG_STR_NBIT-1:0]       tx_pf_code;
   reg                            tx_buf_baddr; // base address of BUFFER
                             
   // HANDSHAKE              
   reg                            proc_handshake_start;
                                  
   // IO CONTROL                  
   reg                            proc_io_start;
   reg                            proc_io_set  ;
   reg                            proc_io_exe  ;
   
   // MIPI                   
   reg                            proc_mipi_start;
   reg  [`MIPI_CMD_NBIT-1:0]      proc_mipi_cmd;
   reg                            proc_mipi_set;
   reg                            proc_mipi_exe;
   reg  [2:0]                     t_mipi_done; // clock domain transfer
   reg  [`MIPI_CLKDIV_NBIT-1:0]   m_mipi_div;
   reg                            m_mipi_div_set;
   reg  [`MIPI_DLY_NBIT-1:0]      m_mipi_sclk_dly;
   reg                            m_mipi_sclk_dly_set;
   reg  [`MIPI_DLY_NBIT-1:0]      m_mipi_sdout_dly;
   reg                            m_mipi_sdout_dly_set;
   reg  [`MIPI_DLY_NBIT-1:0]      m_mipi_sdin_dly;
   reg                            m_mipi_sdin_dly_set;
   reg                            m_mipi_start;
   reg  [`MIPI_BANK_NBIT-1:0]     mipi_bank;
   reg                            mipi_cus_mode;
   reg                            mipi_cus_ssc;
   reg  [`MIPI_DATA_NBIT*2-1:0]   mipi_cus_nbit;
   reg                            mipi_cus_bp;
   reg                            m_cus_bp;
   
   always@(posedge clk) begin
      proc_handshake_start <= `LOW;

      proc_mipi_start      <= `LOW;
      mipi_buf_wr          <= `LOW;
      t_mipi_done          <= {t_mipi_done[1:0],mipi_done};
      m_mipi_sdin_dly_set  <= `LOW;
      m_mipi_sdout_dly_set <= `LOW;
      m_mipi_sclk_dly_set  <= `LOW;

      proc_io_start        <= `LOW;
      proc_io_set          <= `LOW;
      proc_io_exe          <= `LOW;
      case(rx_msg_type)
         `MSG_TYPE_HANDSHAKE: begin
            proc_handshake_start <= rx_msg_eop;
            tx_msg_type          <= `MSG_TYPE_HANDSHAKE;
            tx_msg_pf            <= `MSG_PASS;
            tx_pf_code           <= `MSG_FP_CODE_01; // pass code 01: handshake succeed
            tx_buf_baddr         <= `LOW;
         end
         `MSG_TYPE_MIPI: begin
            tx_msg_type    <= `MSG_TYPE_MIPI;
            tx_buf_baddr   <= `HIGH;
            mipi_buf_wr    <= rx_vd&
                            ~(rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_N || rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_R)&
                             (rx_st==`ST_MSG_DATA)&
                              proc_mipi_set;
            mipi_buf_waddr <= rx_msg_addr[`MIPI_BUF_ADDR_NBIT-1:0];
            mipi_buf_wdata <= atoi_rx_data;
            if(rx_vd&(rx_st==`ST_MSG_DATA)) begin
               if(rx_msg_addr==`MIPI_DIV_BASEADDR) begin
                  m_mipi_div_set <= (rx_msg_mode!=`MSG_MODE_EXEDATA);
                  m_mipi_div     <= atoi_rx_data;
               end
               if(rx_msg_addr==`MIPI_DLY_BASEADDR) begin
                  m_mipi_sclk_dly_set <= (rx_msg_mode!=`MSG_MODE_EXEDATA);
                  m_mipi_sclk_dly     <= atoi_rx_data;
               end               
               if(rx_msg_addr==`MIPI_DLY_BASEADDR+1) begin
                  m_mipi_sdout_dly_set <= (rx_msg_mode!=`MSG_MODE_EXEDATA);
                  m_mipi_sdout_dly     <= atoi_rx_data;
               end               
               if(rx_msg_addr==`MIPI_DLY_BASEADDR+2) begin
                  m_mipi_sdin_dly_set <= (rx_msg_mode!=`MSG_MODE_EXEDATA);
                  m_mipi_sdin_dly     <= atoi_rx_data;
               end               
               if(rx_msg_addr==`MIPI_SSC_BASEADDR) begin
                  mipi_cus_ssc <= atoi_rx_data[0]; // HIGH - SSC enable, LOW - SSC disable
               end
               if(rx_msg_addr==`MIPI_CMD_BASEADDR) begin
                  proc_mipi_cmd <= atoi_rx_data;
                  mipi_cus_mode<= (atoi_rx_data&`MIPI_CMD_EXT_MASK) ==`MIPI_CMD_CUS_PAT;
               end                   
               if(rx_msg_addr==`MIPI_LEN_BASEADDR) begin
                  mipi_cus_nbit <= atoi_rx_data; // data length, nbit
               end
               m_cus_bp <= (atoi_rx_data==`MIPI_BP_PAT);
               if(rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_N || rx_data[`MSG_STR_NBIT/2-1:0]==`MSG_END_R)
                  mipi_cus_bp <= m_cus_bp;
            end
            
            // set data
            if(rx_msg_mode==`MSG_MODE_SETDATA) begin
               tx_msg_pf     <= rx_msg_err ? `MSG_FAIL       : `MSG_PASS;
               tx_pf_code    <= rx_msg_err ? `MSG_FP_CODE_03 : `MSG_FP_CODE_01; // 01: succeed; 03: error data received
               if(rx_st==`ST_MSG_CHADDR)
                  proc_mipi_set <= ~rx_msg_err;
               else if(rx_msg_eop)
                  proc_mipi_set <= `LOW;
               proc_mipi_start <= rx_msg_eop;   
            end
            // execute data, control IO with current data
            else if(rx_msg_mode==`MSG_MODE_EXEDATA) begin
               tx_msg_pf       <= rx_msg_err ? `MSG_FAIL       : `MSG_PASS;
               tx_pf_code      <= rx_msg_err ? `MSG_FP_CODE_13 : `MSG_FP_CODE_11; // 11: succeed; 13: error data received
               proc_mipi_exe   <= ~rx_msg_err&rx_msg_eop;
               proc_mipi_start <= ~rx_msg_err ? t_mipi_done[2:1]==2'b01 : rx_msg_eop;
            end
            // set and execute data, control IO with new data
            else if(rx_msg_mode==`MSG_MODE_SEXDATA) begin
               tx_msg_pf       <= rx_msg_err ? `MSG_FAIL       : `MSG_PASS;
               tx_pf_code      <= rx_msg_err ? `MSG_FP_CODE_23 : `MSG_FP_CODE_21; // 21: succeed; 23: error data received
               if(rx_st==`ST_MSG_CHADDR)
                  proc_mipi_set <= ~rx_msg_err;
               else if(rx_msg_eop)
                  proc_mipi_set <= `LOW;
               proc_mipi_exe   <= ~rx_msg_err&rx_msg_eop;
               proc_mipi_start <= ~rx_msg_err ? t_mipi_done[2:1]==2'b01 : rx_msg_eop;
            end
            // Error Mode String
            else begin
               tx_msg_pf  <= `MSG_FAIL;
               tx_pf_code <= `MSG_FP_CODE_00; // 00: error mode received
               proc_mipi_start <= rx_msg_eop;
            end       
            
            if(proc_mipi_start) begin
               m_mipi_start <= `LOW;
               m_mipi_div_set <= `LOW;
            end
            else if(proc_mipi_exe) begin
               if((proc_mipi_cmd&`MIPI_CMD_ZERO_MASK)==`MIPI_CMD_WRZERO_PAT ||
                  (proc_mipi_cmd&`MIPI_CMD_REG_MASK) ==`MIPI_CMD_WR_PAT     || 
                  (proc_mipi_cmd&`MIPI_CMD_REG_MASK) ==`MIPI_CMD_RD_PAT     ||
                  (proc_mipi_cmd&`MIPI_CMD_EXTL_MASK)==`MIPI_CMD_EXTWRL_PAT || 
                  (proc_mipi_cmd&`MIPI_CMD_EXTL_MASK)==`MIPI_CMD_EXTRDL_PAT ||
                  (proc_mipi_cmd&`MIPI_CMD_EXT_MASK) ==`MIPI_CMD_EXTWR_PAT  || 
                  (proc_mipi_cmd&`MIPI_CMD_EXT_MASK) ==`MIPI_CMD_EXTRD_PAT  ||
                  (proc_mipi_cmd&`MIPI_CMD_EXT_MASK) ==`MIPI_CMD_CUS_PAT) begin
                  m_mipi_start <= `HIGH;
                  mipi_bank    <= rx_ch_addr[`MIPI_BANK_NBIT-1:0];
               end
            end            
         end
         `MSG_TYPE_IOCTRL: begin
            proc_io_start <= rx_msg_eop;
            if(rx_msg_eop) begin
               // set data
               if(rx_msg_mode==`MSG_MODE_SETDATA) begin
                  if(rx_msg_addr==`IO_DATA_NUM) begin
                     tx_msg_pf   <= rx_msg_err ? `MSG_FAIL       : `MSG_PASS;
                     tx_pf_code  <= rx_msg_err ? `MSG_FP_CODE_03 : `MSG_FP_CODE_01; // 01: succeed; 03: error data received
                     proc_io_set <= ~rx_msg_err;
                  end
                  else begin
                     tx_msg_pf  <= `MSG_FAIL;
                     tx_pf_code <= `MSG_FP_CODE_02; // fail code 02: error data length
                  end
               end
               // execute data, control IO with current data
               else if(rx_msg_mode==`MSG_MODE_EXEDATA) begin
                  if(rx_msg_addr==0) begin
                     tx_msg_pf  <= `MSG_PASS;
                     tx_pf_code <= `MSG_FP_CODE_11; // 11: succeed
                     proc_io_exe <= `HIGH;
                  end
                  else begin
                     tx_msg_pf  <= `MSG_FAIL;
                     tx_pf_code <= `MSG_FP_CODE_12; // fail code 12: error data length
                  end
               end
               // set and execute data, control IO with new data
               else if(rx_msg_mode==`MSG_MODE_SEXDATA) begin
                  if(rx_msg_addr==`IO_DATA_NUM) begin
                     tx_msg_pf   <= rx_msg_err ? `MSG_FAIL       : `MSG_PASS;
                     tx_pf_code  <= rx_msg_err ? `MSG_FP_CODE_23 : `MSG_FP_CODE_21; // 21: succeed; 23: error data received
                     proc_io_set <= ~rx_msg_err;
                     proc_io_exe <= ~rx_msg_err;
                  end
                  else begin
                     tx_msg_pf  <= `MSG_FAIL;
                     tx_pf_code <= `MSG_FP_CODE_22;
                  end
               end
               else if(rx_msg_mode==`MSG_MODE_RTN) begin
                  tx_msg_pf   <= rx_msg_err ? `MSG_FAIL       : `MSG_PASS;
                  tx_pf_code  <= rx_msg_err ? `MSG_FP_CODE_23 : `MSG_FP_CODE_21; // 21: succeed; 23: error data received
               end
               // Error Mode String
               else begin
                  tx_msg_pf  <= `MSG_FAIL;
                  tx_pf_code <= `MSG_FP_CODE_00; // 00: error mode received
               end
            end
            tx_msg_type  <= `MSG_TYPE_IOCTRL;
            tx_buf_baddr <= `HIGH;
         end
         default:;
      endcase
   end            
   
   ////////////////// IO Control Process
   wire [`IO_UNIT_NBIT-1:0]   new_io_dir ;
   wire [`IO_UNIT_NBIT-1:0]   new_io_mask;
   wire [`IO_UNIT_NBIT-1:0]   new_io_data;
   // dir: 0-input; 1-output
   // mask: 0-don't mask; 1-mask
   // when bit is masked, it performs as input tri-stated: dir=0 and data=0
   assign new_io_mask = rx_msg_data[`IO_UNIT_NBIT*3-1:`IO_UNIT_NBIT*2];  
   generate
   genvar i;
      for(i=0;i<`IO_UNIT_NBIT;i=i+1)
      begin:u
         assign new_io_dir[i]  = new_io_mask[i] ? proc_io_dir[i] : rx_msg_data[i+`IO_UNIT_NBIT];
         assign new_io_data[i] = new_io_mask[i] ? proc_io_data[i] : (new_io_dir[i] ? rx_msg_data[i] : i_io_db[i]);
      end
   endgenerate
   
   reg [`IO_UNIT_NBIT-1:0]   proc_io_dir ;
   reg [`IO_UNIT_NBIT-1:0]   proc_io_mask;
   reg [`IO_UNIT_NBIT-1:0]   proc_io_data;
   reg [`IO_UNIT_NBIT-1:0]   o_io_db ;
   reg [`IO_UNIT_NBIT-1:0]   o_io_dir;
   reg [`IO_BANK_NBIT-1:0]   o_io_bank;

   always@(posedge clk) begin
      if(proc_io_start) begin
         // set data
         if(proc_io_set) begin
            proc_io_dir  <= new_io_dir ;
            proc_io_mask <= new_io_mask;
            proc_io_data <= new_io_data; 
         end
         // execute data
         if(proc_io_exe) begin
            o_io_db   <= proc_io_set ? new_io_data : proc_io_data;
            o_io_dir  <= proc_io_set ? new_io_dir  : proc_io_dir;
            o_io_bank <= rx_ch_addr;
         end
      end
   end
   
   ////////////////// MIPI Process
   // Standard MIPI Instruction: ST 01 01/02/03 00~FF XX(FREQ) XXXXXX(Delay) XX(SA)  XX(CMD) XXXX(ADDR)   XX~XX(DATA)
   // Custom Instruction:        ST 01 01/02/03 00~FF XX(FREQ) XXXXXX(Delay) XX(SSC) 10(CMD) XX(LENGTH) XX~XX(DATA) XX(BP)
   
   reg                            mipi_buf_wr   ;
   reg  [`MIPI_BUF_ADDR_NBIT-1:0] mipi_buf_waddr;
   reg  [`MIPI_BUF_DATA_NBIT-1:0] mipi_buf_wdata;
   reg  [`MIPI_CLKDIV_NBIT-1:0]   mipi_div;
   reg                            mipi_div_set;
   reg                            mipi_start;
   wire                           mipi_done;
   reg  [`MIPI_BUF_ADDR_NBIT-1:0] mipi_buf_raddr;
   wire [`MIPI_BUF_DATA_NBIT-1:0] mipi_buf_rdata;
   
   `define ST_MSG_PF  3'b011
   `define ST_PF_CODE 3'b110

   always@(posedge clk) begin
      if(tx_st==`ST_MSG_PF || tx_st==`ST_PF_CODE || tx_st==`ST_MSG_CHADDR || tx_st==`ST_MSG_DATA)
         mipi_buf_raddr <= mipi_buf_raddr + 1'b1;
      else
         mipi_buf_raddr <= 0;
   end
   
   reg [2:0]                      d_mipi_div_set;
   reg [2:0]                      d_mipi_start  ;
   
   always@(posedge mipi_clk) begin
      d_mipi_div_set <= {d_mipi_div_set[1:0],m_mipi_div_set};
      d_mipi_start   <= {d_mipi_start  [1:0],m_mipi_start  };
      
      mipi_div_set   <= `LOW;
      mipi_start     <= `LOW;
      if(d_mipi_div_set[2:1]==2'b01)
         mipi_div_set <= `HIGH;
      if(d_mipi_start[2:1]==2'b01)
         mipi_start <= `HIGH;
      mipi_div <= m_mipi_div;
   end
   
   wire [`MIPI_BUF_ADDR_NBIT-1:0] mipi_data_num;
   
   wire                       mipi_sclk;
   wire                       mipi_ssc;
   wire                       mipi_sdi;
   wire                       mipi_sdo;
   wire                       mipi_sdo_en;
      
   mipi mipi_u
   (
      .clk        (mipi_clk      ),
      .set        (mipi_div_set  ),
      .div        (mipi_div      ),
      .start      (mipi_start    ),
      .done       (mipi_done     ),
      .data_num   (mipi_data_num ),
      .cusmode    (mipi_cus_mode ),
      .cusssc     (mipi_cus_ssc  ),
      .cusnbit    (mipi_cus_nbit ),
      .cusbp      (mipi_cus_bp   ),
      .i_buf_clk  (clk           ),
      .i_buf_wr   (mipi_buf_wr   ),
      .i_buf_waddr(mipi_buf_waddr),
      .i_buf_wdata(mipi_buf_wdata),
      .i_buf_raddr(mipi_buf_raddr),
      .o_buf_rdata(mipi_buf_rdata),
      .sclk       (mipi_sclk     ),
      .ssc        (mipi_ssc      ),
      .sdi        (mipi_sdi      ),
      .sdo        (mipi_sdo      ),
      .sdo_en     (mipi_sdo_en   )
   );
   
   // mipi sclk&sdo&sdi delay
   wire [`MIPI_IODELAY_NBIT-1:0] m_sclk_delay =  m_mipi_sclk_dly[`MIPI_IODELAY_NBIT-1:0];
   iodelay #(1,`MIPI_IODELAY_NBIT)
   sclk_delay (
      .clk        (fast_clk           ),
      .rst_n      (`HIGH              ),
      .in_dio     (mipi_sclk          ),
      .in_delay_we(m_mipi_sclk_dly_set),
      .in_delay   (m_sclk_delay       ),
      .out_dio    (sclk               )
   );
   
   wire [`MIPI_IODELAY_NBIT-1:0] m_sdo_delay = m_mipi_sdout_dly[`MIPI_IODELAY_NBIT-1:0];
   wire                          mipi_sdo_delay;
   wire                          mipi_sdo_en_delay;
   iodelay #(2,`MIPI_IODELAY_NBIT) 
   sdo_delay (
      .clk        (fast_clk              ),
      .rst_n      (`HIGH                 ),
      .in_dio     ({mipi_sdo,mipi_sdo_en}),
      .in_delay_we(m_mipi_sdout_dly_set  ),
      .in_delay   (m_sdo_delay           ),
      .out_dio    ({mipi_sdo_delay,mipi_sdo_en_delay})
   );
   
   assign sdo = mipi_sdo_delay|mipi_ssc;
   assign sdo_en = mipi_sdo_en_delay|mipi_sdo_en;
   
   wire [`MIPI_IODELAY_NBIT-1:0] m_sdi_delay = m_mipi_sdin_dly[`MIPI_IODELAY_NBIT-1:0];
   iodelay #(1,`MIPI_IODELAY_NBIT) 
   sdi_delay (
      .clk        (fast_clk           ),
      .rst_n      (`HIGH              ),
      .in_dio     (sdi                ),
      .in_delay_we(m_mipi_sdin_dly_set),
      .in_delay   (m_sdi_delay        ),
      .out_dio    (mipi_sdi           )
   );
   
   ////////////////// TX STATEMENT         
   
   wire   tx_msg_sop;
   assign tx_msg_sop = proc_handshake_start|proc_io_start|proc_mipi_start;
   
   reg                      tx_vd;
   reg [`USB_DATA_NBIT-1:0] tx_data;
   reg                      tx_eop;

   reg  [`USB_ADDR_NBIT-1:0] tx_buf_addr; // low address of BUFFER
   wire [`USB_ADDR_NBIT:0]   tx_addr;
   assign tx_addr = {tx_buf_baddr,tx_buf_addr};

   reg [2:0] tx_st=`ST_MSG_IDLE;
   
   reg [`MSG_DATA_MAX_NBIT-1:0] tx_msg_data;
   reg [`USB_ADDR_NBIT-1:0]     tx_msg_addr;

   // convert tx data(DATA Region) from int to char
   wire [`USB_DATA_NBIT/2-1:0] int_tx_data;
   wire [`USB_DATA_NBIT-1:0]   char_tx_data;
   assign int_tx_data = tx_msg_data[`MSG_DATA_MAX_NBIT-1:`MSG_DATA_MAX_NBIT-`USB_DATA_NBIT/2];
   itoa#(`USB_DATA_NBIT/2) itoa_u
   (
      .i_int (int_tx_data),
      .o_char({char_tx_data[`USB_DATA_NBIT/2-1:0],
               char_tx_data[`USB_DATA_NBIT-1:`USB_DATA_NBIT/2]}) // invert h and l
   );
   
   always@(posedge clk) begin
      tx_vd <= `LOW;
      tx_eop <= `LOW;
      case(tx_st) 
         `ST_MSG_IDLE: begin
            tx_buf_addr <= 0;
            tx_msg_addr <= 0;
            if(tx_msg_sop)
               tx_st <= `ST_MSG_HEAD;
         end
         `ST_MSG_HEAD: begin
            tx_vd <= `HIGH;
            tx_buf_addr <= 0;
            tx_data <= `MSG_HEAD;
            tx_st <= `ST_MSG_TYPE;
         end
         `ST_MSG_TYPE: begin
            tx_vd <= `HIGH;
            tx_buf_addr <= tx_buf_addr + 1'b1;
            tx_data <= tx_msg_type;
            tx_st <= `ST_MSG_PF;
         end
         `ST_MSG_PF: begin
            tx_vd   <= `HIGH;
            tx_buf_addr <= tx_buf_addr + 1'b1;
            tx_data <= tx_msg_pf;
            tx_st   <= `ST_PF_CODE;
         end
         `ST_PF_CODE: begin
            tx_vd       <= `HIGH;
            tx_data     <= tx_pf_code;
            tx_buf_addr <= tx_buf_addr + 1'b1;
            tx_st       <= `ST_MSG_CHADDR;
            if(tx_msg_type==`MSG_TYPE_HANDSHAKE) begin
               tx_st   <= `ST_MSG_IDLE;
               tx_eop  <= `HIGH;
            end
         end
         `ST_MSG_CHADDR: begin
            tx_vd       <= `HIGH;
            tx_data     <= rx_msg_ch_addr;
            tx_buf_addr <= tx_buf_addr + 1'b1;
            if(tx_msg_type==`MSG_TYPE_IOCTRL) begin
               tx_st       <= `ST_MSG_DATA;
               tx_msg_data <= {proc_io_mask,proc_io_dir,proc_io_data};
               tx_msg_addr <= `USB_ADDR_NBIT'd`IO_DATA_NUM-1'b1;
            end
            else if(tx_msg_type==`MSG_TYPE_MIPI) begin
               tx_st       <= `ST_MSG_DATA;
               tx_msg_data <= {mipi_buf_rdata,{`MSG_DATA_MAX_NBIT-`USB_DATA_NBIT/2{1'b0}}};
               tx_msg_addr <= `MIPI_DATA_BASEADDR+mipi_data_num-1'b1;
            end
         end
         `ST_MSG_DATA: begin
            tx_msg_data <= tx_msg_type==`MSG_TYPE_MIPI ? {mipi_buf_rdata,{`MSG_DATA_MAX_NBIT-`USB_DATA_NBIT/2{1'b0}}} : tx_msg_data<<(`USB_DATA_NBIT/2);
            tx_msg_addr <= tx_msg_addr - 1'b1;
            tx_vd       <= `HIGH;
            tx_buf_addr <= tx_buf_addr + 1'b1;
            tx_data     <= char_tx_data;
            if(tx_msg_addr==0)
               tx_st <= `ST_MSG_END;
         end
         `ST_MSG_END: begin
            tx_vd       <= `HIGH;
            tx_data     <= 0;
            tx_buf_addr <= tx_buf_addr + 1'b1;
            if(tx_msg_addr=={`USB_ADDR_NBIT{1'b1}}) begin
               tx_data     <= {`MSG_END_N,`MSG_END_R};
               tx_msg_addr <= 0;
            end
            if(tx_buf_addr=={`USB_ADDR_NBIT{1'b1}}) begin
               tx_vd   <= `LOW;
               tx_st   <= `ST_MSG_IDLE;
               tx_eop  <= `HIGH;
            end
         end
         default:
            tx_st <= `ST_MSG_IDLE;
      endcase
   end    
            
endmodule

////////////////////////////////////////////////////////////////
//
//  Module  : atoi
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2015/11/27 
//
////////////////////////////////////////////////////////////////
// 
//  Description: convert ascii char to hexadecimal integer  
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module atoi
(
   i_char,
   o_int,
   o_err
);

   ///////////////// PARAMETER ////////////////
   parameter  p_int_nbit =8;
   localparam p_char_nbit=p_int_nbit*2;
   
   ////////////////// PORT ////////////////////
   input  [p_char_nbit-1:0]  i_char; 
   output [p_int_nbit-1:0]   o_int;  
   output                    o_err;
   
   ////////////////// ARCH ////////////////////
   wire [7:0] char[0:p_int_nbit/4-1];
   reg  [7:0] char_offset[0:p_int_nbit/4-1];
   wire [7:0] t_int[0:p_int_nbit/4-1];
   reg  [p_int_nbit/4-1:0] char_err;
   
   generate
   genvar i;
      for(i=0;i<p_int_nbit/4;i=i+1)
      begin:u
         assign char[i] = i_char[8*i+7:8*i];
         
         always@* begin
            char_err[i] <= `LOW;
            
            // ASCII "0" ~ "9" -- INT 0 ~ 9
            if(char[i]>="0" && char[i]<="9")
               char_offset[i] <= "0";
            // ASCII "a" ~ "f" -- INT 10 ~ 15
            else if(char[i]>="a" && char[i]<="f")
               char_offset[i] <= "a" - 8'd10;
            // ASCII "A" ~ "F" -- INT 10 ~ 15
            else if(char[i]>="A" && char[i]<="F")
               char_offset[i] <= "A" - 8'd10;
            else begin
               char_offset[i] <= 0;
               char_err[i] <= `HIGH;
            end
         end
         
         assign t_int[i] = char[i] - char_offset[i];
         
         assign o_int[4*i+3:4*i] = t_int[i][3:0];
      end
   endgenerate
   
   assign o_err = |char_err;
      
endmodule

////////////////////////////////////////////////////////////////
//
//  Module  : itoa
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2015/11/27 
//
////////////////////////////////////////////////////////////////
// 
//  Description: convert hexadecimal integer to ascii char
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

/////////////////////////// MODULE //////////////////////////////
module itoa
(
   i_int,
   o_char
);

   ///////////////// PARAMETER ////////////////
   parameter  p_int_nbit=8;
   localparam p_char_nbit = p_int_nbit*2;
   
   ////////////////// PORT ////////////////////
   input  [p_int_nbit-1:0]  i_int;
   output [p_char_nbit-1:0] o_char;
   
   ////////////////// ARCH ////////////////////
   wire [3:0] t_int[0:p_int_nbit/4-1];
   reg  [7:0] char_offset[0:p_int_nbit/4-1];
   wire [7:0] char[0:p_int_nbit/4-1];

   generate
   genvar i;
      for(i=0;i<p_int_nbit/4;i=i+1)
      begin:u
         assign t_int[i] = i_int[4*i+3:4*i];
         
         always@* begin
            // INT 0 ~ 9 -- ASCII "0" ~ "9"
            if(t_int[i]>=0 && t_int[i]<=9)
               char_offset[i] <= "0";
            // INT 10 ~ 15 -- ASCII "A" ~ "F"
            else
               char_offset[i] <= "A" - 8'd10;
         end
         
         assign char[i] = {4'h0,t_int[i]} + char_offset[i];
         
         assign o_char[8*i+7:8*i] = char[i];
      end
   endgenerate
   
endmodule