`timescale	1ps / 1ps
////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./main.v
// {{{
// Project:	ZBasic, a generic toplevel implementation using the full ZipCPU
//
// DO NOT EDIT THIS FILE!
// Computer Generated: This file is computer generated by AUTOFPGA. DO NOT EDIT.
// DO NOT EDIT THIS FILE!
//
// CmdLine:	autofpga autofpga -d -o . clock.txt global.txt version.txt buserr.txt pic.txt pwrcount.txt gpio.txt rtclight.txt rtcdate.txt busconsole.txt bkram.txt flash.txt zipmaster.txt sdspi.txt mem_flash_bkram.txt mem_bkram_only.txt
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2017-2021, Gisselquist Technology, LLC
// {{{
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}
`default_nettype	none
////////////////////////////////////////////////////////////////////////////////
//
// Macro defines
// {{{
//
//
// Here is a list of defines which may be used, post auto-design
// (not post-build), to turn particular peripherals (and bus masters)
// on and off.  In particular, to turn off support for a particular
// design component, just comment out its respective `define below.
//
// These lines are taken from the respective @ACCESS tags for each of our
// components.  If a component doesn't have an @ACCESS tag, it will not
// be listed here.
//
// First, the independent access fields for any bus masters
`define	WBUBUS_MASTER
// And then for the independent peripherals
`define	INCLUDE_ZIPCPU
`define	BKRAM_ACCESS
`define	VERSION_ACCESS
`define	SDSPI_ACCESS
`define	RTC_ACCESS
`define	BUSCONSOLE_ACCESS
`define	BUSPIC_ACCESS
`define	PWRCOUNT_ACCESS
`define	GPIO_ACCESS
`define	FLASH_ACCESS
//
//
// The list of those things that have @DEPENDS tags
//
//
//
// Dependencies
// Any core with both an @ACCESS and a @DEPENDS tag will show up here.
// The @DEPENDS tag will turn into a series of ifdef's, with the @ACCESS
// being defined only if all of the ifdef's are true//
`ifdef	RTC_ACCESS
`define	RTCDATE_ACCESS
`endif	// RTC_ACCESS
`ifdef	FLASH_ACCESS
`define	FLASHCFG_ACCESS
`endif	// FLASH_ACCESS
//
// End of dependency list
//
//
// }}}
////////////////////////////////////////////////////////////////////////////////
//
// Any include files
// {{{
// These are drawn from anything with a MAIN.INCLUDE definition.
`include "builddate.v"
// }}}
//
// Finally, we define our main module itself.  We start with the list of
// I/O ports, or wires, passed into (or out of) the main function.
//
// These fields are copied verbatim from the respective I/O port lists,
// from the fields given by @MAIN.PORTLIST
//
module	main(i_clk, i_reset,
	// {{{
		i_cpu_reset,
		// UART/host to wishbone interface
		i_wbu_uart_rx, o_wbu_uart_tx,
		// The SD-Card wires
		o_sd_sck, o_sd_cmd, o_sd_data, i_sd_cmd, i_sd_data, i_sd_detect,
		// GPIO ports
		i_gpio, o_gpio,
		// The Universal QSPI Flash
		o_qspi_cs_n, o_qspi_sck, o_qspi_dat, i_qspi_dat, o_qspi_mod
	// }}}
	);
////////////////////////////////////////////////////////////////////////////////
//
// Any parameter definitions
// {{{
// These are drawn from anything with a MAIN.PARAM definition.
// As they aren't connected to the toplevel at all, it would
// be best to use localparam over parameter, but here we don't
// check
	//
	//
	// Variables/definitions needed by the ZipCPU BUS master
	//
	//
	// A 32-bit address indicating where the ZipCPU should start running
	// from
	localparam	RESET_ADDRESS = 20971520;
	//
	// The number of valid bits on the bus
	localparam	ZIP_ADDRESS_WIDTH = 23; // Zip-CPU address width
	//
	// Number of ZipCPU interrupts
	localparam	ZIP_INTS = 16;
	//
	// ZIP_START_HALTED
	//
	// A boolean, indicating whether or not the ZipCPU be halted on startup?
	localparam	ZIP_START_HALTED=1'b1;
	//
	// WBUBUS parameters
	//
	// Baudrate :   1000000
	// Clock    : 100000000
	localparam [23:0] BUSUART = 24'h64;	//   1000000 baud
	localparam	DBGBUSBITS = $clog2(BUSUART);
	//
	// Maximum command is 6 bytes, where each byte takes 10 baud clocks
	// and each baud clock requires DBGBUSBITS to represent.  Here,
	// we'll add one more for good measure.
	localparam	DBGBUSWATCHDOG_RAW = DBGBUSBITS + 9;
	localparam	DBGBUSWATCHDOG = (DBGBUSWATCHDOG_RAW > 19)
				? DBGBUSWATCHDOG_RAW : 19;
	//
	// Initial calendar DATE
	//
`ifdef	VERSION_ACCESS
	parameter	INITIAL_DATE = `DATESTAMP;
`else
	parameter	INITIAL_DATE = 30'h20000101;
`endif
// }}}
////////////////////////////////////////////////////////////////////////////////
//
// Port declarations
// {{{
// The next step is to declare all of the various ports that were just
// listed above.  
//
// The following declarations are taken from the values of the various
// @MAIN.IODECL keys.
//
	input	wire		i_clk;
	// verilator lint_off UNUSED
	input	wire		i_reset;
	// verilator lint_on UNUSED
	input	wire		i_cpu_reset;
	input	wire		i_wbu_uart_rx;
	output	wire		o_wbu_uart_tx;
	// SD-Card declarations
	output	wire		o_sd_sck, o_sd_cmd;
	output	wire	[3:0]	o_sd_data;
	// verilator lint_off UNUSED
	input	wire		i_sd_cmd;
	input	wire	[3:0]	i_sd_data;
	// verilator lint_on  UNUSED
	input	wire		i_sd_detect;
	localparam	NGPI = 11, NGPO=11;
	// GPIO ports
	input		[(NGPI-1):0]	i_gpio;
	output	wire	[(NGPO-1):0]	o_gpio;
	// The Universal QSPI flash
	output	wire		o_qspi_cs_n, o_qspi_sck;
	output	wire	[3:0]	o_qspi_dat;
	input	wire	[3:0]	i_qspi_dat;
	output	wire	[1:0]	o_qspi_mod;
// }}}
	// Make Verilator happy
	// {{{
	// Defining bus wires for lots of components often ends up with unused
	// wires lying around.  We'll turn off Ver1lator's lint warning
	// here that checks for unused wires.
	// }}}
	// verilator lint_off UNUSED
	////////////////////////////////////////////////////////////////////////
	//
	// Declaring interrupt lines
	// {{{
	// These declarations come from the various components values
	// given under the @INT.<interrupt name>.WIRE key.
	//
	wire	zip_cpu_int;	// zip.INT.ZIP.WIRE
	wire	sdcard_int;	// sdcard.INT.SDCARD.WIRE
	wire	rtc_int;	// rtc.INT.RTC.WIRE
	wire	uartrxf_int;	// uart.INT.UARTRXF.WIRE
	wire	uarttx_int;	// uart.INT.UARTTX.WIRE
	wire	uarttxf_int;	// uart.INT.UARTTXF.WIRE
	wire	uartrx_int;	// uart.INT.UARTRX.WIRE
	wire	w_bus_int;	// buspic.INT.BUS.WIRE
	wire	gpio_int;	// gpio.INT.GPIO.WIRE
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Component declarations
	// {{{
	// These declarations come from the @MAIN.DEFNS keys found in the
	// various components comprising the design.
	//
	// ZipSystem/ZipCPU connection definitions
	// All we define here is a set of scope wires
	wire	[31:0]	zip_debug;
	wire		zip_trigger;
	wire	[ZIP_INTS-1:0] zip_int_vector;
// BUILDTIME doesnt need to include builddate.v a second time
// `include "builddate.v"
	//
	//
	// UART interface
	//
	//
	wire	[7:0]	wbu_rx_data, wbu_tx_data;
	wire		wbu_rx_stb;
	wire		wbu_tx_stb, wbu_tx_busy;

	wire	w_ck_uart, w_uart_tx;
	// Definitions for the WB-UART converter.  We really only need one
	// (more) non-bus wire--one to use to select if we are interacting
	// with the ZipCPU or not.
	wire	[0:0]	wbubus_dbg;
`ifndef	INCLUDE_ZIPCPU
	//
	// The bus-console depends upon the zip_dbg wires.  If there is no
	// ZipCPU defining them, we'll need to define them here anyway.
	//
	wire		zip_dbg_stall, zip_dbg_ack;
	wire	[31:0]	zip_dbg_data;
`endif
	wire[31:0]	sdspi_debug;
	// This clock step is designed to match 100000000 Hz
	localparam	[31:0]	RTC_CLKSTEP = 32'h002af31d;
	wire	rtc_ppd;
	wire	ck_pps;
	// Console definitions
	wire		w_console_rx_stb, w_console_tx_stb, w_console_busy;
	wire	[6:0]	w_console_rx_data, w_console_tx_data;
	wire	[31:0]	uart_debug;
	reg	[24-1:0]	r_buserr_addr;
	reg	[31:0]	r_pwrcount_data;
	wire	sd_reset;
	// Definitions for the flash debug port
	wire		flash_dbg_trigger;
	wire	[31:0]	flash_debug;

// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Declaring interrupt vector wires
	// {{{
	// These declarations come from the various components having
	// PIC and PIC.MAX keys.
	//
	wire	[14:0]	sys_int_vector;
	wire	[14:0]	alt_int_vector;
	wire	[14:0]	bus_int_vector;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Declare bus signals
	// {{{
	////////////////////////////////////////////////////////////////////////

	// Bus wb
	// {{{
	// Wishbone definitions for bus wb, component zip
	// Verilator lint_off UNUSED
	wire		wb_zip_cyc, wb_zip_stb, wb_zip_we;
	wire	[22:0]	wb_zip_addr;
	wire	[31:0]	wb_zip_data;
	wire	[3:0]	wb_zip_sel;
	wire		wb_zip_stall, wb_zip_ack, wb_zip_err;
	wire	[31:0]	wb_zip_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb, component wbu_arbiter
	// Verilator lint_off UNUSED
	wire		wb_wbu_arbiter_cyc, wb_wbu_arbiter_stb, wb_wbu_arbiter_we;
	wire	[22:0]	wb_wbu_arbiter_addr;
	wire	[31:0]	wb_wbu_arbiter_data;
	wire	[3:0]	wb_wbu_arbiter_sel;
	wire		wb_wbu_arbiter_stall, wb_wbu_arbiter_ack, wb_wbu_arbiter_err;
	wire	[31:0]	wb_wbu_arbiter_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb(SIO), component buildtime
	// Verilator lint_off UNUSED
	wire		wb_buildtime_cyc, wb_buildtime_stb, wb_buildtime_we;
	wire	[22:0]	wb_buildtime_addr;
	wire	[31:0]	wb_buildtime_data;
	wire	[3:0]	wb_buildtime_sel;
	wire		wb_buildtime_stall, wb_buildtime_ack, wb_buildtime_err;
	wire	[31:0]	wb_buildtime_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb(SIO), component buserr
	// Verilator lint_off UNUSED
	wire		wb_buserr_cyc, wb_buserr_stb, wb_buserr_we;
	wire	[22:0]	wb_buserr_addr;
	wire	[31:0]	wb_buserr_data;
	wire	[3:0]	wb_buserr_sel;
	wire		wb_buserr_stall, wb_buserr_ack, wb_buserr_err;
	wire	[31:0]	wb_buserr_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb(SIO), component buspic
	// Verilator lint_off UNUSED
	wire		wb_buspic_cyc, wb_buspic_stb, wb_buspic_we;
	wire	[22:0]	wb_buspic_addr;
	wire	[31:0]	wb_buspic_data;
	wire	[3:0]	wb_buspic_sel;
	wire		wb_buspic_stall, wb_buspic_ack, wb_buspic_err;
	wire	[31:0]	wb_buspic_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb(SIO), component gpio
	// Verilator lint_off UNUSED
	wire		wb_gpio_cyc, wb_gpio_stb, wb_gpio_we;
	wire	[22:0]	wb_gpio_addr;
	wire	[31:0]	wb_gpio_data;
	wire	[3:0]	wb_gpio_sel;
	wire		wb_gpio_stall, wb_gpio_ack, wb_gpio_err;
	wire	[31:0]	wb_gpio_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb(SIO), component pwrcount
	// Verilator lint_off UNUSED
	wire		wb_pwrcount_cyc, wb_pwrcount_stb, wb_pwrcount_we;
	wire	[22:0]	wb_pwrcount_addr;
	wire	[31:0]	wb_pwrcount_data;
	wire	[3:0]	wb_pwrcount_sel;
	wire		wb_pwrcount_stall, wb_pwrcount_ack, wb_pwrcount_err;
	wire	[31:0]	wb_pwrcount_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb(SIO), component rtcdate
	// Verilator lint_off UNUSED
	wire		wb_rtcdate_cyc, wb_rtcdate_stb, wb_rtcdate_we;
	wire	[22:0]	wb_rtcdate_addr;
	wire	[31:0]	wb_rtcdate_data;
	wire	[3:0]	wb_rtcdate_sel;
	wire		wb_rtcdate_stall, wb_rtcdate_ack, wb_rtcdate_err;
	wire	[31:0]	wb_rtcdate_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb(SIO), component version
	// Verilator lint_off UNUSED
	wire		wb_version_cyc, wb_version_stb, wb_version_we;
	wire	[22:0]	wb_version_addr;
	wire	[31:0]	wb_version_data;
	wire	[3:0]	wb_version_sel;
	wire		wb_version_stall, wb_version_ack, wb_version_err;
	wire	[31:0]	wb_version_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb, component flashcfg
	// Verilator lint_off UNUSED
	wire		wb_flashcfg_cyc, wb_flashcfg_stb, wb_flashcfg_we;
	wire	[22:0]	wb_flashcfg_addr;
	wire	[31:0]	wb_flashcfg_data;
	wire	[3:0]	wb_flashcfg_sel;
	wire		wb_flashcfg_stall, wb_flashcfg_ack, wb_flashcfg_err;
	wire	[31:0]	wb_flashcfg_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb, component sdcard
	// Verilator lint_off UNUSED
	wire		wb_sdcard_cyc, wb_sdcard_stb, wb_sdcard_we;
	wire	[22:0]	wb_sdcard_addr;
	wire	[31:0]	wb_sdcard_data;
	wire	[3:0]	wb_sdcard_sel;
	wire		wb_sdcard_stall, wb_sdcard_ack, wb_sdcard_err;
	wire	[31:0]	wb_sdcard_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb, component uart
	// Verilator lint_off UNUSED
	wire		wb_uart_cyc, wb_uart_stb, wb_uart_we;
	wire	[22:0]	wb_uart_addr;
	wire	[31:0]	wb_uart_data;
	wire	[3:0]	wb_uart_sel;
	wire		wb_uart_stall, wb_uart_ack, wb_uart_err;
	wire	[31:0]	wb_uart_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb, component rtc
	// Verilator lint_off UNUSED
	wire		wb_rtc_cyc, wb_rtc_stb, wb_rtc_we;
	wire	[22:0]	wb_rtc_addr;
	wire	[31:0]	wb_rtc_data;
	wire	[3:0]	wb_rtc_sel;
	wire		wb_rtc_stall, wb_rtc_ack, wb_rtc_err;
	wire	[31:0]	wb_rtc_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb, component wb_sio
	// Verilator lint_off UNUSED
	wire		wb_sio_cyc, wb_sio_stb, wb_sio_we;
	wire	[22:0]	wb_sio_addr;
	wire	[31:0]	wb_sio_data;
	wire	[3:0]	wb_sio_sel;
	wire		wb_sio_stall, wb_sio_ack, wb_sio_err;
	wire	[31:0]	wb_sio_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb, component bkram
	// Verilator lint_off UNUSED
	wire		wb_bkram_cyc, wb_bkram_stb, wb_bkram_we;
	wire	[22:0]	wb_bkram_addr;
	wire	[31:0]	wb_bkram_data;
	wire	[3:0]	wb_bkram_sel;
	wire		wb_bkram_stall, wb_bkram_ack, wb_bkram_err;
	wire	[31:0]	wb_bkram_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wb, component flash
	// Verilator lint_off UNUSED
	wire		wb_flash_cyc, wb_flash_stb, wb_flash_we;
	wire	[22:0]	wb_flash_addr;
	wire	[31:0]	wb_flash_data;
	wire	[3:0]	wb_flash_sel;
	wire		wb_flash_stall, wb_flash_ack, wb_flash_err;
	wire	[31:0]	wb_flash_idata;
	// Verilator lint_on UNUSED
	// }}}
	// Bus wbu
	// {{{
	// Wishbone definitions for bus wbu, component wbu
	// Verilator lint_off UNUSED
	wire		wbu_cyc, wbu_stb, wbu_we;
	wire	[23:0]	wbu_addr;
	wire	[31:0]	wbu_data;
	wire	[3:0]	wbu_sel;
	wire		wbu_stall, wbu_ack, wbu_err;
	wire	[31:0]	wbu_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wbu, component wbu_arbiter
	// Verilator lint_off UNUSED
	wire		wbu_wbu_arbiter_cyc, wbu_wbu_arbiter_stb, wbu_wbu_arbiter_we;
	wire	[23:0]	wbu_wbu_arbiter_addr;
	wire	[31:0]	wbu_wbu_arbiter_data;
	wire	[3:0]	wbu_wbu_arbiter_sel;
	wire		wbu_wbu_arbiter_stall, wbu_wbu_arbiter_ack, wbu_wbu_arbiter_err;
	wire	[31:0]	wbu_wbu_arbiter_idata;
	// Verilator lint_on UNUSED
	// Wishbone definitions for bus wbu, component zip
	// Verilator lint_off UNUSED
	wire		wbu_zip_cyc, wbu_zip_stb, wbu_zip_we;
	wire	[23:0]	wbu_zip_addr;
	wire	[31:0]	wbu_zip_data;
	wire	[3:0]	wbu_zip_sel;
	wire		wbu_zip_stall, wbu_zip_ack, wbu_zip_err;
	wire	[31:0]	wbu_zip_idata;
	// Verilator lint_on UNUSED
	// }}}
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Peripheral address decoding, bus handling
	// {{{
	//
	// BUS-LOGIC for wb
	// {{{
	//
	// wb Bus logic to handle SINGLE slaves
	//
	reg		r_wb_sio_ack;
	reg	[31:0]	r_wb_sio_data;

	assign	wb_sio_stall = 1'b0;

	initial r_wb_sio_ack = 1'b0;
	always	@(posedge i_clk)
		r_wb_sio_ack <= (wb_sio_stb);
	assign	wb_sio_ack = r_wb_sio_ack;

	always	@(posedge i_clk)
	casez( wb_sio_addr[2:0] )
	3'h0: r_wb_sio_data <= wb_buildtime_idata;
	3'h1: r_wb_sio_data <= wb_buserr_idata;
	3'h2: r_wb_sio_data <= wb_buspic_idata;
	3'h3: r_wb_sio_data <= wb_gpio_idata;
	3'h4: r_wb_sio_data <= wb_pwrcount_idata;
	3'h5: r_wb_sio_data <= wb_rtcdate_idata;
	3'h6: r_wb_sio_data <= wb_version_idata;
	default: r_wb_sio_data <= wb_version_idata;
	endcase
	assign	wb_sio_idata = r_wb_sio_data;


	//
	// Now to translate this logic to the various SIO slaves
	//
	// In this case, the SIO bus has the prefix wb_sio
	// and all of the slaves have various wires beginning
	// with their own respective bus prefixes.
	// Our goal here is to make certain that all of
	// the slave bus inputs match the SIO bus wires
	assign	wb_buildtime_cyc = wb_sio_cyc;
	assign	wb_buildtime_stb = wb_sio_stb && (wb_sio_addr[ 2: 0] ==  3'h0);  // 0x000000
	assign	wb_buildtime_we  = wb_sio_we;
	assign	wb_buildtime_data= wb_sio_data;
	assign	wb_buildtime_sel = wb_sio_sel;
	assign	wb_buserr_cyc = wb_sio_cyc;
	assign	wb_buserr_stb = wb_sio_stb && (wb_sio_addr[ 2: 0] ==  3'h1);  // 0x000004
	assign	wb_buserr_we  = wb_sio_we;
	assign	wb_buserr_data= wb_sio_data;
	assign	wb_buserr_sel = wb_sio_sel;
	assign	wb_buspic_cyc = wb_sio_cyc;
	assign	wb_buspic_stb = wb_sio_stb && (wb_sio_addr[ 2: 0] ==  3'h2);  // 0x000008
	assign	wb_buspic_we  = wb_sio_we;
	assign	wb_buspic_data= wb_sio_data;
	assign	wb_buspic_sel = wb_sio_sel;
	assign	wb_gpio_cyc = wb_sio_cyc;
	assign	wb_gpio_stb = wb_sio_stb && (wb_sio_addr[ 2: 0] ==  3'h3);  // 0x00000c
	assign	wb_gpio_we  = wb_sio_we;
	assign	wb_gpio_data= wb_sio_data;
	assign	wb_gpio_sel = wb_sio_sel;
	assign	wb_pwrcount_cyc = wb_sio_cyc;
	assign	wb_pwrcount_stb = wb_sio_stb && (wb_sio_addr[ 2: 0] ==  3'h4);  // 0x000010
	assign	wb_pwrcount_we  = wb_sio_we;
	assign	wb_pwrcount_data= wb_sio_data;
	assign	wb_pwrcount_sel = wb_sio_sel;
	assign	wb_rtcdate_cyc = wb_sio_cyc;
	assign	wb_rtcdate_stb = wb_sio_stb && (wb_sio_addr[ 2: 0] ==  3'h5);  // 0x000014
	assign	wb_rtcdate_we  = wb_sio_we;
	assign	wb_rtcdate_data= wb_sio_data;
	assign	wb_rtcdate_sel = wb_sio_sel;
	assign	wb_version_cyc = wb_sio_cyc;
	assign	wb_version_stb = wb_sio_stb && (wb_sio_addr[ 2: 0] ==  3'h6);  // 0x000018
	assign	wb_version_we  = wb_sio_we;
	assign	wb_version_data= wb_sio_data;
	assign	wb_version_sel = wb_sio_sel;
	//
	// No class DOUBLE peripherals on the "wb" bus
	//

	assign	wb_flashcfg_err= 1'b0;
	assign	wb_sdcard_err= 1'b0;
	assign	wb_uart_err= 1'b0;
	assign	wb_rtc_err= 1'b0;
	assign	wb_sio_err= 1'b0;
	assign	wb_bkram_err= 1'b0;
	assign	wb_flash_err= 1'b0;
	//
	// Connect the wb bus components together using the wbxbar()
	//
	//
	wbxbar #(
		.NM(2), .NS(7), .AW(23), .DW(32),
		.SLAVE_ADDR({
			// Address width    = 23
			// Address LSBs     = 2
			// Slave name width = 8
			{ 23'h400000 }, //    flash: 0x1000000
			{ 23'h300000 }, //    bkram: 0x0c00000
			{ 23'h280000 }, //   wb_sio: 0x0a00000
			{ 23'h200000 }, //      rtc: 0x0800000
			{ 23'h180000 }, //     uart: 0x0600000
			{ 23'h100000 }, //   sdcard: 0x0400000
			{ 23'h080000 }  // flashcfg: 0x0200000
		}),
		.SLAVE_MASK({
			// Address width    = 23
			// Address LSBs     = 2
			// Slave name width = 8
			{ 23'h400000 }, //    flash
			{ 23'h780000 }, //    bkram
			{ 23'h780000 }, //   wb_sio
			{ 23'h780000 }, //      rtc
			{ 23'h780000 }, //     uart
			{ 23'h780000 }, //   sdcard
			{ 23'h780000 }  // flashcfg
		}),
		.OPT_DBLBUFFER(1'b1))
	wb_xbar(
		.i_clk(i_clk), .i_reset(i_reset),
		.i_mcyc({
			wb_wbu_arbiter_cyc,
			wb_zip_cyc
		}),
		.i_mstb({
			wb_wbu_arbiter_stb,
			wb_zip_stb
		}),
		.i_mwe({
			wb_wbu_arbiter_we,
			wb_zip_we
		}),
		.i_maddr({
			wb_wbu_arbiter_addr,
			wb_zip_addr
		}),
		.i_mdata({
			wb_wbu_arbiter_data,
			wb_zip_data
		}),
		.i_msel({
			wb_wbu_arbiter_sel,
			wb_zip_sel
		}),
		.o_mstall({
			wb_wbu_arbiter_stall,
			wb_zip_stall
		}),
		.o_mack({
			wb_wbu_arbiter_ack,
			wb_zip_ack
		}),
		.o_mdata({
			wb_wbu_arbiter_idata,
			wb_zip_idata
		}),
		.o_merr({
			wb_wbu_arbiter_err,
			wb_zip_err
		}),
		// Slave connections
		.o_scyc({
			wb_flash_cyc,
			wb_bkram_cyc,
			wb_sio_cyc,
			wb_rtc_cyc,
			wb_uart_cyc,
			wb_sdcard_cyc,
			wb_flashcfg_cyc
		}),
		.o_sstb({
			wb_flash_stb,
			wb_bkram_stb,
			wb_sio_stb,
			wb_rtc_stb,
			wb_uart_stb,
			wb_sdcard_stb,
			wb_flashcfg_stb
		}),
		.o_swe({
			wb_flash_we,
			wb_bkram_we,
			wb_sio_we,
			wb_rtc_we,
			wb_uart_we,
			wb_sdcard_we,
			wb_flashcfg_we
		}),
		.o_saddr({
			wb_flash_addr,
			wb_bkram_addr,
			wb_sio_addr,
			wb_rtc_addr,
			wb_uart_addr,
			wb_sdcard_addr,
			wb_flashcfg_addr
		}),
		.o_sdata({
			wb_flash_data,
			wb_bkram_data,
			wb_sio_data,
			wb_rtc_data,
			wb_uart_data,
			wb_sdcard_data,
			wb_flashcfg_data
		}),
		.o_ssel({
			wb_flash_sel,
			wb_bkram_sel,
			wb_sio_sel,
			wb_rtc_sel,
			wb_uart_sel,
			wb_sdcard_sel,
			wb_flashcfg_sel
		}),
		.i_sstall({
			wb_flash_stall,
			wb_bkram_stall,
			wb_sio_stall,
			wb_rtc_stall,
			wb_uart_stall,
			wb_sdcard_stall,
			wb_flashcfg_stall
		}),
		.i_sack({
			wb_flash_ack,
			wb_bkram_ack,
			wb_sio_ack,
			wb_rtc_ack,
			wb_uart_ack,
			wb_sdcard_ack,
			wb_flashcfg_ack
		}),
		.i_sdata({
			wb_flash_idata,
			wb_bkram_idata,
			wb_sio_idata,
			wb_rtc_idata,
			wb_uart_idata,
			wb_sdcard_idata,
			wb_flashcfg_idata
		}),
		.i_serr({
			wb_flash_err,
			wb_bkram_err,
			wb_sio_err,
			wb_rtc_err,
			wb_uart_err,
			wb_sdcard_err,
			wb_flashcfg_err
		})
		);

	// End of bus logic for wb
	// }}}
	//
	// BUS-LOGIC for wbu
	// {{{
	//
	// No class SINGLE peripherals on the "wbu" bus
	//

	//
	// No class DOUBLE peripherals on the "wbu" bus
	//

	// info: @ERROR.WIRE for wbu_arbiter matches the buses error name, wbu_wbu_arbiter_err
	assign	wbu_zip_err= 1'b0;
	//
	// Connect the wbu bus components together using the wbxbar()
	//
	//
	wbxbar #(
		.NM(1), .NS(2), .AW(24), .DW(32),
		.SLAVE_ADDR({
			// Address width    = 24
			// Address LSBs     = 2
			// Slave name width = 11
			{ 24'h800000 }, //         zip: 0x2000000
			{ 24'h000000 }  // wbu_arbiter: 0x0000000
		}),
		.SLAVE_MASK({
			// Address width    = 24
			// Address LSBs     = 2
			// Slave name width = 11
			{ 24'h800000 }, //         zip
			{ 24'h800000 }  // wbu_arbiter
		}),
		.OPT_DBLBUFFER(1'b1))
	wbu_xbar(
		.i_clk(i_clk), .i_reset(i_reset),
		.i_mcyc({
			wbu_cyc
		}),
		.i_mstb({
			wbu_stb
		}),
		.i_mwe({
			wbu_we
		}),
		.i_maddr({
			wbu_addr
		}),
		.i_mdata({
			wbu_data
		}),
		.i_msel({
			wbu_sel
		}),
		.o_mstall({
			wbu_stall
		}),
		.o_mack({
			wbu_ack
		}),
		.o_mdata({
			wbu_idata
		}),
		.o_merr({
			wbu_err
		}),
		// Slave connections
		.o_scyc({
			wbu_zip_cyc,
			wbu_wbu_arbiter_cyc
		}),
		.o_sstb({
			wbu_zip_stb,
			wbu_wbu_arbiter_stb
		}),
		.o_swe({
			wbu_zip_we,
			wbu_wbu_arbiter_we
		}),
		.o_saddr({
			wbu_zip_addr,
			wbu_wbu_arbiter_addr
		}),
		.o_sdata({
			wbu_zip_data,
			wbu_wbu_arbiter_data
		}),
		.o_ssel({
			wbu_zip_sel,
			wbu_wbu_arbiter_sel
		}),
		.i_sstall({
			wbu_zip_stall,
			wbu_wbu_arbiter_stall
		}),
		.i_sack({
			wbu_zip_ack,
			wbu_wbu_arbiter_ack
		}),
		.i_sdata({
			wbu_zip_idata,
			wbu_wbu_arbiter_idata
		}),
		.i_serr({
			wbu_zip_err,
			wbu_wbu_arbiter_err
		})
		);

	// End of bus logic for wbu
	// }}}
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Declare the interrupt busses
	// {{{
	// Interrupt busses are defined by anything with a @PIC tag.
	// The @PIC.BUS tag defines the name of the wire bus below,
	// while the @PIC.MAX tag determines the size of the bus width.
	//
	// For your peripheral to be assigned to this bus, it must have an
	// @INT.NAME.WIRE= tag to define the wire name of the interrupt line,
	// and an @INT.NAME.PIC= tag matching the @PIC.BUS tag of the bus
	// your interrupt will be assigned to.  If an @INT.NAME.ID tag also
	// exists, then your interrupt will be assigned to the position given
	// by the ID# in that tag.
	//
	assign	sys_int_vector = {
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		uarttxf_int,
		uartrxf_int,
		sdcard_int,
		w_bus_int,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0
	};
	assign	alt_int_vector = {
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		uartrx_int,
		uarttx_int,
		rtc_int,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0
	};
	assign	bus_int_vector = {
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		1'b0,
		gpio_int,
		sdcard_int
	};
	// }}}
	////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////
	//
	// @MAIN.INSERT and @MAIN.ALT
	// {{{
	////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////
	//
	//
	// Now we turn to defining all of the parts and pieces of what
	// each of the various peripherals does, and what logic it needs.
	//
	// This information comes from the @MAIN.INSERT and @MAIN.ALT tags.
	// If an @ACCESS tag is available, an ifdef is created to handle
	// having the access and not.  If the @ACCESS tag is `defined above
	// then the @MAIN.INSERT code is executed.  If not, the @MAIN.ALT
	// code is exeucted, together with any other cleanup settings that
	// might need to take place--such as returning zeros to the bus,
	// or making sure all of the various interrupt wires are set to
	// zero if the component is not included.
	//
`ifdef	INCLUDE_ZIPCPU
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	// The ZipCPU/ZipSystem BUS master
	// {{{
	//
	assign	zip_int_vector = { alt_int_vector[14:8], sys_int_vector[14:6] };
	zipsystem #(
		// {{{
		.RESET_ADDRESS(RESET_ADDRESS),
		.ADDRESS_WIDTH(ZIP_ADDRESS_WIDTH+2),
		.OPT_LGICACHE(12), .OPT_LGDCACHE(12),
		.START_HALTED(ZIP_START_HALTED),
		.RESET_DURATION(20),
		.EXTERNAL_INTERRUPTS(ZIP_INTS)
		// }}}
	) swic(
		// {{{
		i_clk, (i_reset)||(i_cpu_reset),
			// Zippys wishbone interface
			wb_zip_cyc, wb_zip_stb, wb_zip_we,
			wb_zip_addr[23-1:0],
			wb_zip_data, // 32 bits wide
			wb_zip_sel,  // 32/8 bits wide
		wb_zip_stall, wb_zip_ack, wb_zip_idata,wb_zip_err,
			zip_int_vector, zip_cpu_int,
			// Debug wishbone interface
			wbu_zip_cyc, wbu_zip_stb, wbu_zip_we,
			wbu_zip_addr[7-1:0],
			wbu_zip_data, // 32 bits wide
			wbu_zip_sel,  // 32/8 bits wide
		wbu_zip_stall, wbu_zip_ack, wbu_zip_idata,
			zip_debug
		// }}}
	);

	assign	zip_trigger = zip_debug[31];
	// }}}
	// }}}
`else	// INCLUDE_ZIPCPU
	// {{{
	// Null bus master
	// {{{
	// }}}
	// Null bus slave
	// {{{

	//
	// In the case that there is no wbu_zip peripheral
	// responding on the wbu bus
	assign	wbu_zip_ack   = 1'b0;
	assign	wbu_zip_err   = (wbu_zip_stb);
	assign	wbu_zip_stall = 0;
	assign	wbu_zip_idata = 0;

	// }}}
	// Null interrupt definitions
	// {{{
	assign	zip_cpu_int = 1'b0;	// zip.INT.ZIP.WIRE
	// }}}
	// }}}
`endif	// INCLUDE_ZIPCPU

	assign	wb_buildtime_idata = `BUILDTIME;
	assign	wb_buildtime_ack = wb_buildtime_stb;
	assign	wb_buildtime_stall = 1'b0;
`ifdef	BKRAM_ACCESS
	// {{{
	memdev #(.LGMEMSZ(20), .EXTRACLOCK(1))
		bkrami(i_clk, i_reset,
			wb_bkram_cyc, wb_bkram_stb, wb_bkram_we,
			wb_bkram_addr[18-1:0],
			wb_bkram_data, // 32 bits wide
			wb_bkram_sel,  // 32/8 bits wide
		wb_bkram_stall, wb_bkram_ack, wb_bkram_idata);
	// }}}
`else	// BKRAM_ACCESS
	// {{{
	// Null bus slave
	// {{{

	//
	// In the case that there is no wb_bkram peripheral
	// responding on the wb bus
	assign	wb_bkram_ack   = 1'b0;
	assign	wb_bkram_err   = (wb_bkram_stb);
	assign	wb_bkram_stall = 0;
	assign	wb_bkram_idata = 0;

	// }}}
	// }}}
`endif	// BKRAM_ACCESS

`ifdef	VERSION_ACCESS
	// {{{
	assign	wb_version_idata = `DATESTAMP;
	assign	wb_version_ack = wb_version_stb;
	assign	wb_version_stall = 1'b0;
	// }}}
`else	// VERSION_ACCESS
	// {{{
	// }}}
`endif	// VERSION_ACCESS

`ifdef	WBUBUS_MASTER
	// {{{
	// The Host USB interface, to be used by the WB-UART bus
	rxuartlite	#(.TIMER_BITS(DBGBUSBITS),
				.CLOCKS_PER_BAUD(BUSUART[DBGBUSBITS-1:0]))
		rcv(i_clk, i_wbu_uart_rx,
				wbu_rx_stb, wbu_rx_data);
	txuartlite	#(.TIMING_BITS(DBGBUSBITS[4:0]),
				.CLOCKS_PER_BAUD(BUSUART[DBGBUSBITS-1:0]))
		txv(i_clk,
				wbu_tx_stb,
				wbu_tx_data,
				o_wbu_uart_tx,
				wbu_tx_busy);

`ifdef	INCLUDE_ZIPCPU
`else
	assign	zip_dbg_ack   = 1'b0;
	assign	zip_dbg_stall = 1'b0;
	assign	zip_dbg_data  = 0;
`endif
`ifndef	BUSPIC_ACCESS
	wire	w_bus_int;
	assign	w_bus_int = 1'b0;
`endif
	// Verilator lint_off UNUSED
	wire	[31:0]	wbu_tmp_addr;
	// Verilator lint_on  UNUSED
	wbuconsole #(.LGWATCHDOG(DBGBUSWATCHDOG))
	genbus(i_clk, 1'b0, wbu_rx_stb, wbu_rx_data,
			wbu_cyc, wbu_stb, wbu_we, wbu_tmp_addr, wbu_data,
			wbu_stall, wbu_ack,
			wbu_idata,
			wbu_err,
			w_bus_int,
			wbu_tx_stb, wbu_tx_data, wbu_tx_busy,
			//
			w_console_tx_stb, w_console_tx_data, w_console_busy,
			w_console_rx_stb, w_console_rx_data,
			//
			wbubus_dbg[0]);
	assign	wbu_sel = 4'hf;
	assign	wbu_addr = wbu_tmp_addr[(24-1):0];
	// }}}
`else	// WBUBUS_MASTER
	// {{{
	// Null bus master
	// {{{
	// }}}
	// }}}
`endif	// WBUBUS_MASTER

`ifdef	SDSPI_ACCESS
	// {{{
	// SPI mapping
	wire	w_sd_cs_n, w_sd_mosi, w_sd_miso;

	sdspi	sdcardi(i_clk, sd_reset,
		wb_sdcard_cyc, wb_sdcard_stb, wb_sdcard_we,
			wb_sdcard_addr[2-1:0],
			wb_sdcard_data, // 32 bits wide
			wb_sdcard_sel,  // 32/8 bits wide
		wb_sdcard_stall, wb_sdcard_ack, wb_sdcard_idata,
		w_sd_cs_n, o_sd_sck, w_sd_mosi, w_sd_miso, i_sd_detect,
		sdcard_int, 1'b1, sdspi_debug);

	assign	w_sd_miso = i_sd_data[0];
	assign	o_sd_data = { w_sd_cs_n, 3'b111 };
	assign	o_sd_cmd  = w_sd_mosi;
	// }}}
`else	// SDSPI_ACCESS
	// {{{
	assign	o_sd_sck   = 1'b1;
	assign	o_sd_cmd   = 1'b1;
	assign	o_sd_data  = 4'hf;
	// Null bus slave
	// {{{

	//
	// In the case that there is no wb_sdcard peripheral
	// responding on the wb bus
	assign	wb_sdcard_ack   = 1'b0;
	assign	wb_sdcard_err   = (wb_sdcard_stb);
	assign	wb_sdcard_stall = 0;
	assign	wb_sdcard_idata = 0;

	// }}}
	// Null interrupt definitions
	// {{{
	assign	sdcard_int = 1'b0;	// sdcard.INT.SDCARD.WIRE
	// }}}
	// }}}
`endif	// SDSPI_ACCESS

`ifdef	RTC_ACCESS
	// {{{
	rtclight #(.DEFAULT_SPEED(32'h2af31d),
		.OPT_TIMER(1'b1),
		.OPT_STOPWATCH(1'b1),
		.OPT_ALARM(1'b0),
		.OPT_FIXED_SPEED(1'b1))
	thertc(i_clk, i_reset, wb_rtc_cyc, wb_rtc_stb, wb_rtc_we,
			wb_rtc_addr[3-1:0],
			wb_rtc_data, // 32 bits wide
			wb_rtc_sel,  // 32/8 bits wide
		wb_rtc_stall, wb_rtc_ack, wb_rtc_idata,
		rtc_int, ck_pps, rtc_ppd);
	// }}}
`else	// RTC_ACCESS
	// {{{
	assign	ck_pps = 1'b0;
	// Null bus slave
	// {{{

	//
	// In the case that there is no wb_rtc peripheral
	// responding on the wb bus
	assign	wb_rtc_ack   = 1'b0;
	assign	wb_rtc_err   = (wb_rtc_stb);
	assign	wb_rtc_stall = 0;
	assign	wb_rtc_idata = 0;

	// }}}
	// Null interrupt definitions
	// {{{
	assign	rtc_int = 1'b0;	// rtc.INT.RTC.WIRE
	// }}}
	// }}}
`endif	// RTC_ACCESS

`ifdef	BUSCONSOLE_ACCESS
	// {{{
	wbconsole #(.LGFLEN(6)) console(i_clk, 1'b0,
			wb_uart_cyc, wb_uart_stb, wb_uart_we,
			wb_uart_addr[2-1:0],
			wb_uart_data, // 32 bits wide
			wb_uart_sel,  // 32/8 bits wide
		wb_uart_stall, wb_uart_ack, wb_uart_idata,
			w_console_tx_stb, w_console_tx_data, w_console_busy,
			w_console_rx_stb, w_console_rx_data,
			uartrx_int, uarttx_int, uartrxf_int, uarttxf_int,
			uart_debug);
	// }}}
`else	// BUSCONSOLE_ACCESS
	// {{{
	// Null bus slave
	// {{{

	//
	// In the case that there is no wb_uart peripheral
	// responding on the wb bus
	assign	wb_uart_ack   = 1'b0;
	assign	wb_uart_err   = (wb_uart_stb);
	assign	wb_uart_stall = 0;
	assign	wb_uart_idata = 0;

	// }}}
	// Null interrupt definitions
	// {{{
	assign	uartrxf_int = 1'b0;	// uart.INT.UARTRXF.WIRE
	assign	uarttx_int = 1'b0;	// uart.INT.UARTTX.WIRE
	assign	uarttxf_int = 1'b0;	// uart.INT.UARTTXF.WIRE
	assign	uartrx_int = 1'b0;	// uart.INT.UARTRX.WIRE
	// }}}
	// }}}
`endif	// BUSCONSOLE_ACCESS

`ifdef	BUSPIC_ACCESS
	// {{{
	//
	// The BUS Interrupt controller
	//
	icontrol #(15)	buspici(i_clk, 1'b0,
			wb_buspic_cyc, wb_buspic_stb, wb_buspic_we,
			wb_buspic_data, // 32 bits wide
			wb_buspic_sel,  // 32/8 bits wide
		wb_buspic_stall, wb_buspic_ack, wb_buspic_idata,
			bus_int_vector, w_bus_int);
	// }}}
`else	// BUSPIC_ACCESS
	// {{{
	// Null interrupt definitions
	// {{{
	assign	w_bus_int = 1'b0;	// buspic.INT.BUS.WIRE
	// }}}
	// }}}
`endif	// BUSPIC_ACCESS

	always @(posedge i_clk)
	if (wb_zip_err)
	begin
		r_buserr_addr <= 0;
		r_buserr_addr[23-1:0] <= wb_zip_addr[23-1:0];
	end else if (wbu_err)
	begin
		r_buserr_addr <= 0;
		r_buserr_addr[24-1:0] <= wbu_addr[24-1:0];
	end
	assign	wb_buserr_stall= 1'b0;
	assign	wb_buserr_ack  = wb_buserr_stb;
	assign	wb_buserr_idata = { {(30-24){1'b0}},
			r_buserr_addr, 2'b00 };
`ifdef	PWRCOUNT_ACCESS
	// {{{
	initial	r_pwrcount_data = 32'h0;
	always @(posedge i_clk)
	if (r_pwrcount_data[31])
		r_pwrcount_data[30:0] <= r_pwrcount_data[30:0] + 1'b1;
	else
		r_pwrcount_data[31:0] <= r_pwrcount_data[31:0] + 1'b1;

	assign	wb_pwrcount_stall = 1'b0;
	assign	wb_pwrcount_ack   = wb_pwrcount_stb;
	assign	wb_pwrcount_idata = r_pwrcount_data;
	// }}}
`else	// PWRCOUNT_ACCESS
	// {{{
	// }}}
`endif	// PWRCOUNT_ACCESS

	assign	wb_wbu_arbiter_cyc  = wbu_wbu_arbiter_cyc;
	assign	wb_wbu_arbiter_stb  = wbu_wbu_arbiter_stb;
	assign	wb_wbu_arbiter_we   = wbu_wbu_arbiter_we;
	assign	wb_wbu_arbiter_addr = wbu_wbu_arbiter_addr[23-1:0];
	assign	wb_wbu_arbiter_data = wbu_wbu_arbiter_data;
	assign	wb_wbu_arbiter_sel  = wbu_wbu_arbiter_sel;
	//
	assign	wbu_wbu_arbiter_stall = wb_wbu_arbiter_stall;
	assign	wbu_wbu_arbiter_ack   = wb_wbu_arbiter_ack;
	assign	wbu_wbu_arbiter_idata = wb_wbu_arbiter_idata;
	assign	wbu_wbu_arbiter_err   = wb_wbu_arbiter_err;

`ifdef	RTCDATE_ACCESS
	// {{{
	//
	// The Calendar DATE
	//
	rtcdate	#(.INITIAL_DATE(INITIAL_DATE[29:0]))
	rtcdatei(i_clk, rtc_ppd,
		wb_rtcdate_cyc, wb_rtcdate_stb, wb_rtcdate_we,
			wb_rtcdate_data, // 32 bits wide
			wb_rtcdate_sel,  // 32/8 bits wide
		wb_rtcdate_stall, wb_rtcdate_ack, wb_rtcdate_idata);
	// }}}
`else	// RTCDATE_ACCESS
	// {{{
	// }}}
`endif	// RTCDATE_ACCESS

`ifdef	GPIO_ACCESS
	// {{{
	//
	// GPIO
	//
	// This interface should allow us to control up to 16 GPIO inputs, and
	// another 16 GPIO outputs.  The interrupt trips when any of the inputs
	// changes.  (Sorry, which input isn't (yet) selectable.)
	//
	localparam	INITIAL_GPIO = 11'h0;
	wbgpio	#(NGPI, NGPO, INITIAL_GPIO)
		gpioi(i_clk, wb_gpio_cyc, wb_gpio_stb, wb_gpio_we,
			wb_gpio_data, // 32 bits wide
			wb_gpio_sel,  // 32/8 bits wide
		wb_gpio_stall, wb_gpio_ack, wb_gpio_idata,
			i_gpio, o_gpio, gpio_int);

	assign	sd_reset = o_gpio[0];
	// }}}
`else	// GPIO_ACCESS
	// {{{
	// Null interrupt definitions
	// {{{
	assign	gpio_int = 1'b0;	// gpio.INT.GPIO.WIRE
	// }}}
	// }}}
`endif	// GPIO_ACCESS

`ifdef	FLASHCFG_ACCESS
	// {{{
	// The Flash control interface is defined by the flash instantiation
	// hence we don't need to do anything to define it here.
	// }}}
`else	// FLASHCFG_ACCESS
	// {{{
	// Null bus slave
	// {{{

	//
	// In the case that there is no wb_flashcfg peripheral
	// responding on the wb bus
	assign	wb_flashcfg_ack   = 1'b0;
	assign	wb_flashcfg_err   = (wb_flashcfg_stb);
	assign	wb_flashcfg_stall = 0;
	assign	wb_flashcfg_idata = 0;

	// }}}
	// }}}
`endif	// FLASHCFG_ACCESS

`ifdef	FLASH_ACCESS
	// {{{
	qflexpress #(.LGFLASHSZ(24), .OPT_CLKDIV(1),
		.OPT_ENDIANSWAP(0),
		.NDUMMY(6), .RDDELAY(0),
		.OPT_STARTUP_FILE("spansion.hex"),
`ifdef	FLASHCFG_ACCESS
		.OPT_CFG(1'b1)
`else
		.OPT_CFG(1'b0)
`endif
		)
		flashi(i_clk, i_reset,
			// Primary memory reading inputs
			wb_flash_cyc, wb_flash_stb, wb_flash_we,
			wb_flash_addr[22-1:0],
			wb_flash_data, // 32 bits wide
			wb_flash_sel,  // 32/8 bits wide
		wb_flash_stall, wb_flash_ack, wb_flash_idata,
			// Configuration bus ports
			wb_flashcfg_cyc, wb_flashcfg_stb, wb_flashcfg_we,
			wb_flashcfg_data, // 32 bits wide
			wb_flashcfg_sel,  // 32/8 bits wide
		wb_flashcfg_stall, wb_flashcfg_ack, wb_flashcfg_idata,
			o_qspi_sck, o_qspi_cs_n, o_qspi_mod, o_qspi_dat, i_qspi_dat,
			flash_dbg_trigger, flash_debug);
	// }}}
`else	// FLASH_ACCESS
	// {{{
	assign	o_qspi_sck  = 1'b1;
	assign	o_qspi_cs_n = 1'b1;
	assign	o_qspi_mod  = 2'b01;
	assign	o_qspi_dat  = 4'b1111;
	// Verilator lint_off UNUSED
	wire	flash_unused = &{ 1'b0, i_qspi_dat };
	// Verilator lint_on UNUSED
	// Null bus slave
	// {{{

	//
	// In the case that there is no wb_flash peripheral
	// responding on the wb bus
	assign	wb_flash_ack   = 1'b0;
	assign	wb_flash_err   = (wb_flash_stb);
	assign	wb_flash_stall = 0;
	assign	wb_flash_idata = 0;

	// }}}
	// }}}
`endif	// FLASH_ACCESS

	// }}}
endmodule // main.v
