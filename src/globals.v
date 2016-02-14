////////////////////////////////////////////////////////////////
//
//  Module  : globals
//  Designer: Hoki
//  Company : HWorks
//  Date    : 2015/11/13 
//
////////////////////////////////////////////////////////////////
// 
//  Description: global definition, macro, variables
//
////////////////////////////////////////////////////////////////
// 
//  Revision: 1.0

`define HIGH 1'b1
`define LOW  1'b0

//////////////////  SDRAM
`define SDRAM_ADDR_NBIT  13
`define SDRAM_DATA_NBIT  32
`define SDRAM_DQM_NBIT   4
`define SDRAM_BA_NBIT    2
`define SDRAM_NCS_NBIT   2
                         
//////////////////  USB                   
`define USB_DATA_NBIT    16
`define USB_ADDR_NBIT    8   // 256 x 16-BIT
`define USB_FIFOADR_NBIT 2

`define USB_RD_FIFOADR   `USB_FIFOADR_NBIT'b00 // end point 2
`define USB_WR_FIFOADR   `USB_FIFOADR_NBIT'b10 // end point 6

// BUFFER
`define BUFFER_ADDR_NBIT `USB_ADDR_NBIT
`define BUFFER_DATA_NBIT `USB_DATA_NBIT

//////////////////  COMMUNICATION, BYTE INVERTED
`define MSG_STR_NBIT        `USB_DATA_NBIT
`define MSG_DATA_MAX_NBIT   96
                            
`define MSG_HEAD            `MSG_STR_NBIT'h5453  // "ST"
                            
`define MSG_TYPE_HANDSHAKE  `MSG_STR_NBIT'h3030  // "00"
`define MSG_TYPE_MIPI       `MSG_STR_NBIT'h3130  // "01"
`define MSG_TYPE_IOCTRL     `MSG_STR_NBIT'h3230  // "02"
`define MSG_TYPE_CNT        `MSG_STR_NBIT'h3330  // "03"
`define MSG_TYPE_IIC        `MSG_STR_NBIT'h3430  // "04"
`define MSG_TYPE_SPI        `MSG_STR_NBIT'h3530  // "05"
`define MSG_TYPE_IOCFG      `MSG_STR_NBIT'h3630  // "06"

`define MSG_MODE_RESERVED   `MSG_STR_NBIT'h3030  // "00"
`define MSG_MODE_SETDATA    `MSG_STR_NBIT'h3130  // "01"
`define MSG_MODE_EXEDATA    `MSG_STR_NBIT'h3230  // "02"
`define MSG_MODE_SEXDATA    `MSG_STR_NBIT'h3330  // "03"
`define MSG_MODE_IO         `MSG_STR_NBIT'h3430  // "04"

`define MSG_PASS            `MSG_STR_NBIT'h3530  // "05"
`define MSG_FAIL            `MSG_STR_NBIT'h3730  // "07"

`define MSG_END_N           8'h0A  // "\n"
`define MSG_END_R           8'h0D  // "\r"

`define MSG_FP_CODE_00      `MSG_STR_NBIT'h3030

`define MSG_FP_CODE_01      `MSG_STR_NBIT'h3130
`define MSG_FP_CODE_02      `MSG_STR_NBIT'h3230
`define MSG_FP_CODE_03      `MSG_STR_NBIT'h3330

`define MSG_FP_CODE_11      `MSG_STR_NBIT'h3131
`define MSG_FP_CODE_12      `MSG_STR_NBIT'h3231
`define MSG_FP_CODE_13      `MSG_STR_NBIT'h3331

`define MSG_FP_CODE_21      `MSG_STR_NBIT'h3132
`define MSG_FP_CODE_22      `MSG_STR_NBIT'h3232
`define MSG_FP_CODE_23      `MSG_STR_NBIT'h3332

`define MSG_FP_CODE_61      `MSG_STR_NBIT'h3136
`define MSG_FP_CODE_62      `MSG_STR_NBIT'h3236

// IO Control
`define IO_UNIT_NBIT        32
`define IO_DATA_NUM         12
`define IO_BANK_NBIT        8

// MIPI
`define MIPI_GP_NUM         4
`define MIPI_DATA_NUM       21 // 2(freq)+2(sa)+2(cmd)+4(addr)+16(data)

`define MIPI_CLKDIV_NBIT    8 // 187.5KHz ~ 24MHz
`define MIPI_SA_NBIT        4
`define MIPI_CMD_NBIT       8
`define MIPI_ADDR_NBIT      8
`define MIPI_DATA_NBIT      8

`define MIPI_BUF_ADDR_NBIT  5
`define MIPI_BUF_DATA_NBIT  `MIPI_DATA_NBIT

`define MIPI_DIV_BASEADDR   `MIPI_BUF_ADDR_NBIT'd0
`define MIPI_SA_BASEADDR    `MIPI_BUF_ADDR_NBIT'd1
`define MIPI_CMD_BASEADDR   `MIPI_BUF_ADDR_NBIT'd2
`define MIPI_ADDR_BASEADDR  `MIPI_BUF_ADDR_NBIT'd3
`define MIPI_DATA_BASEADDR  `MIPI_BUF_ADDR_NBIT'd5

`define MIPI_SSC_PAT        `MIPI_BUF_DATA_NBIT'h80

`define MIPI_CMD_EXTWR_PAT  `MIPI_CMD_NBIT'b00000000
`define MIPI_CMD_EXTRD_PAT  `MIPI_CMD_NBIT'b00100000
`define MIPI_CMD_EXT_MASK   `MIPI_CMD_NBIT'b11110000

`define MIPI_CMD_EXTWRL_PAT `MIPI_CMD_NBIT'b00110000
`define MIPI_CMD_EXTRDL_PAT `MIPI_CMD_NBIT'b00111000
`define MIPI_CMD_EXTL_MASK  `MIPI_CMD_NBIT'b11111000

`define MIPI_CMD_WR_PAT     `MIPI_CMD_NBIT'b01000000
`define MIPI_CMD_RD_PAT     `MIPI_CMD_NBIT'b01100000
`define MIPI_CMD_REG_MASK   `MIPI_CMD_NBIT'b11100000

`define MIPI_CMD_WRZERO_PAT `MIPI_CMD_NBIT'b10000000
`define MIPI_CMD_ZERO_MASK  `MIPI_CMD_NBIT'b10000000

`define MIPI_BANK_NBIT      2

// IO Configuration
`define IOCFG_DATA_NBIT     8 // 5 bits = 32 > 22
`define IOCFG_DATA_NUM      32