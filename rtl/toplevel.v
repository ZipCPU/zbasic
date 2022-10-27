////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./toplevel.v
//
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
//
// Copyright (C) 2017-2020, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
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
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none


//
// Here we declare our toplevel.v (toplevel) design module.
// All design logic must take place beneath this top level.
//
// The port declarations just copy data from the @TOP.PORTLIST
// key, or equivalently from the @MAIN.PORTLIST key if
// @TOP.PORTLIST is absent.  For those peripherals that don't need
// any top level logic, the @MAIN.PORTLIST should be sufficent,
// so the @TOP.PORTLIST key may be left undefined.
//
// The only exception is that any clocks with CLOCK.TOP tags will
// also appear in this list
//
module	toplevel(i_clk,
		// A reset wire for the ZipCPU
		i_cpu_resetn,
		// UART/host to wishbone interface
		i_wbu_uart_rx, o_wbu_uart_tx,
		// SD Card
		o_sd_sck, io_sd_cmd, io_sd, i_sd_cd,
		// GPIO ports
		i_gpio, o_gpio,
		// Top level Quad-SPI I/O ports
		o_qspi_cs_n, io_qspi_dat);
	//
	// Declaring any top level parameters.
	//
	// These declarations just copy data from the @TOP.PARAM key,
	// or from the @MAIN.PARAM key if @TOP.PARAM is absent.  For
	// those peripherals that don't do anything at the top level,
	// the @MAIN.PARAM key should be sufficient, so the @TOP.PARAM
	// key may be left undefined.
	//
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
	//
	// Declaring our input and output ports.  We listed these above,
	// now we are declaring them here.
	//
	// These declarations just copy data from the @TOP.IODECLS key,
	// or from the @MAIN.IODECL key if @TOP.IODECL is absent.  For
	// those peripherals that don't do anything at the top level,
	// the @MAIN.IODECL key should be sufficient, so the @TOP.IODECL
	// key may be left undefined.
	//
	// We start with any @CLOCK.TOP keys
	//
	input	wire		i_clk;
	// A reset wire for the ZipCPU
	input	wire		i_cpu_resetn;
	input	wire		i_wbu_uart_rx;
	output	wire		o_wbu_uart_tx;
	// SD Card
	output	wire		o_sd_sck;
	inout	wire		io_sd_cmd;
	inout	wire	[3:0]	io_sd;
	input	wire		i_sd_cd;
	// GPIO wires
	localparam	NGPI = 11, NGPO=11;
	// GPIO ports
	input	wire	[(11-1):0]	i_gpio;
	output	wire	[(11-1):0]	o_gpio;
	// Quad SPI flash
	output	wire		o_qspi_cs_n;
	inout	wire	[3:0]	io_qspi_dat;


	//
	// Declaring component data, internal wires and registers
	//
	// These declarations just copy data from the @TOP.DEFNS key
	// within the component data files.
	//
	wire		w_sd_cmd;
	wire	[3:0]	w_sd_data;

	wire		i_sd_cmd;
	wire	[3:0]	i_sd;
	wire		s_clk, s_reset;
	wire		w_qspi_sck, w_qspi_cs_n;
	wire	[1:0]	qspi_bmod;
	wire	[3:0]	qspi_dat;


	//
	// Time to call the main module within main.v.  Remember, the purpose
	// of the main.v module is to contain all of our portable logic.
	// Things that are Xilinx (or even Altera) specific, or for that
	// matter anything that requires something other than on-off logic,
	// such as the high impedence states required by many wires, is
	// kept in this (toplevel.v) module.  Everything else goes in
	// main.v.
	//
	// We automatically place s_clk, and s_reset here.  You may need
	// to define those above.  (You did, didn't you?)  Other
	// component descriptions come from the keys @TOP.MAIN (if it
	// exists), or @MAIN.PORTLIST if it does not.
	//

	main	thedesign(s_clk, s_reset,
		// Reset wire for the ZipCPU
		(!i_cpu_resetn),
		// UART/host to wishbone interface
		i_wbu_uart_rx, o_wbu_uart_tx,
		// SD Card
		o_sd_sck, w_sd_cmd, w_sd_data, io_sd_cmd, io_sd, i_sd_cd,
		// GPIO wires
		i_gpio, o_gpio,
		// Quad SPI flash
		w_qspi_cs_n, w_qspi_sck, qspi_dat, io_qspi_dat, qspi_bmod);


	//
	// Our final section to the toplevel is used to provide all of
	// that special logic that couldnt fit in main.  This logic is
	// given by the @TOP.INSERT tag in our data files.
	//


	//
	//
	// Wires for setting up the SD Card Controller
	//
	//
	// assign io_sd_cmd = w_sd_cmd ? 1'bz:1'b0;
	// assign io_sd[0] = w_sd_data[0]? 1'bz:1'b0;
	// assign io_sd[1] = w_sd_data[1]? 1'bz:1'b0;
	// assign io_sd[2] = w_sd_data[2]? 1'bz:1'b0;
	// assign io_sd[3] = w_sd_data[3]? 1'bz:1'b0;


	// IOBUF sd_cmd_buf(.T(w_sd_cmd),.O(i_sd_cmd), .I(1'b0), .IO(io_sd_cmd));
	IOBUF sd_dat0_bf(.T(1'b1),.O(i_sd[0]),.I(1'b1),.IO(io_sd[0]));
	IOBUF sd_dat1_bf(.T(1'b1),.O(i_sd[1]),.I(1'b1),.IO(io_sd[1]));
	IOBUF sd_dat2_bf(.T(1'b1),.O(i_sd[2]),.I(1'b1),.IO(io_sd[2]));
	// IOBUF sd_dat3_bf(.T(w_sd_data[3]),.O(i_sd[3]),.I(1'b0),.IO(io_sd[3]));

	IOBUF sd_cmd_buf(.T(1'b0),.O(i_sd_cmd), .I(w_sd_cmd), .IO(io_sd_cmd));
	IOBUF sd_dat3_bf(.T(1'b0),.O(i_sd[3]),.I(w_sd_data[3]),.IO(io_sd[3]));
	


	assign	s_clk = i_clk;
	assign	s_reset = 1'b0; // This design requires local, not global resets

	//
	//
	// Wires for setting up the QSPI flash wishbone peripheral
	//
	//
	// QSPI)BMOD, Quad SPI bus mode, Bus modes are:
	//	0?	Normal serial mode, one bit in one bit out
	//	10	Quad SPI mode, going out
	//	11	Quad SPI mode coming from the device (read mode)
	assign io_qspi_dat = (~qspi_bmod[1])?({2'b11,1'bz,qspi_dat[0]})
				:((qspi_bmod[0])?(4'bzzzz):(qspi_dat[3:0]));
	assign	o_qspi_cs_n = w_qspi_cs_n;

	// The following primitive is necessary in many designs order to gain
	// access to the o_qspi_sck pin.  It's not necessary on the Arty,
	// simply because they provide two pins that can drive the QSPI
	// clock pin.
	wire	[3:0]	su_nc;	// Startup primitive, no connect
	STARTUPE2 #(
		// Leave PROG_USR false to avoid activating the program
		// event security feature.  Notes state that such a feature
		// requires encrypted bitstreams.
		.PROG_USR("FALSE"),
		// Sets the configuration clock frequency (in ns) for
		// simulation.
		.SIM_CCLK_FREQ(0.0)
	) STARTUPE2_inst (
	// CFGCLK, 1'b output: Configuration main clock output -- no connect
	.CFGCLK(su_nc[0]),
	// CFGMCLK, 1'b output: Configuration internal oscillator clock output
	.CFGMCLK(su_nc[1]),
	// EOS, 1'b output: Active high output indicating the End Of Startup.
	.EOS(su_nc[2]),
	// PREQ, 1'b output: PROGRAM request to fabric output
	//	Only enabled if PROG_USR is set.  This lets the fabric know
	//	that a request has been made (either JTAG or pin pulled low)
	//	to program the device
	.PREQ(su_nc[3]),
	// CLK, 1'b input: User start-up clock input
	.CLK(1'b0),
	// GSR, 1'b input: Global Set/Reset input
	.GSR(1'b0),
	// GTS, 1'b input: Global 3-state input
	.GTS(1'b0),
	// KEYCLEARB, 1'b input: Clear AES Decrypter Key input from BBRAM
	.KEYCLEARB(1'b0),
	// PACK, 1-bit input: PROGRAM acknowledge input
	//	This pin is only enabled if PROG_USR is set.  This allows the
	//	FPGA to acknowledge a request for reprogram to allow the FPGA
	//	to get itself into a reprogrammable state first.
	.PACK(1'b0),
	// USRCLKO, 1-bit input: User CCLK input -- This is why I am using this
	// module at all.
	.USRCCLKO(w_qspi_sck),
	// USRCCLKTS, 1'b input: User CCLK 3-state enable input
	//	An active high here places the clock into a high impedence
	//	state.  Since we wish to use the clock as an active output
	//	always, we drive this pin low.
	.USRCCLKTS(1'b0),
	// USRDONEO, 1'b input: User DONE pin output control
	//	Set this to "high" to make sure that the DONE LED pin is
	//	high.
	.USRDONEO(1'b1),
	// USRDONETS, 1'b input: User DONE 3-state enable output
	//	This enables the FPGA DONE pin to be active.  Setting this
	//	active high sets the DONE pin to high impedence, setting it
	//	low allows the output of this pin to be as stated above.
	.USRDONETS(1'b1)
	);




endmodule // end of toplevel.v module definition
