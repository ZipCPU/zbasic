////////////////////////////////////////////////////////////////////////////////
//
// Filename:	busmaster.v
//
// Project:	ZipCPU-generic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	This is the top level project file as far as Verilator is
//		concerned.  In particular, no high impedence values are allowed
//	at this level or below, so you can't say x = 1'bz or any such.
//
//	It is my hope and purpose that I might use this top level file to 
//	
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2016, Gisselquist Technology, LLC
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
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
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
`ifdef	VERILATOR
`define	NO_ZIP_WBU_DELAY
`endif

`define	FLASH_ACCESS
`define SDCARD_ACCESS
`define DEBUG_ACCESS
//
// If only one bus master is ever trying to access the bus, such as the CPU,
// then we don't need any delays on the bus.  Otherwise, the two masters tend
// to need a clocks worth of delay or so.
`ifndef	DEBUG_ACCESS
`define	NO_ZIP_WBU_DELAY
`endif
//

//
// Any scopes?
//
// Position #4: The Zip CPU scope
//
`define	ZIP_SCOPE

module	busmaster(i_clk, i_rst,
`ifdef	DEBUG_ACCESS
		i_rx_stb, i_rx_data, o_tx_stb, o_tx_data, i_tx_busy,
`endif
		// The SPI Flash lines
		o_qspi_cs_n, o_qspi_sck, o_qspi_dat, i_qspi_dat, o_qspi_mod,
		// SD Card
		o_sd_sck, o_sd_cmd, o_sd_data,
			i_sd_cmd, i_sd_data, i_sd_detect,
		// Console port
		i_rx_uart, o_tx_uart);
	parameter	ZIP_ADDRESS_WIDTH=24,
			LGMEMSZ = 24, LGFLASHSZ = 22,
			ZA=ZIP_ADDRESS_WIDTH;
	input			i_clk, i_rst;
`ifdef	DEBUG_ACCESS
	// The debug port
	input			i_rx_stb;
	input		[7:0]	i_rx_data;
	output	wire		o_tx_stb;
	output	wire	[7:0]	o_tx_data;
	input			i_tx_busy;
`endif
	// SPI flash control
	output	wire		o_qspi_cs_n, o_qspi_sck;
	output	wire	[3:0]	o_qspi_dat;
	input		[3:0]	i_qspi_dat;
	output	wire	[1:0]	o_qspi_mod;
	// The SD Card
	output	wire		o_sd_sck, o_sd_cmd;
	output	wire	[3:0]	o_sd_data;
	input			i_sd_cmd;
	input		[3:0]	i_sd_data;
	input			i_sd_detect;
	// Our console port
	input			i_rx_uart;
	output	wire		o_tx_uart;


	//
	//
	// Master wishbone wires
	//
	//
	wire		wb_cyc, wb_stb, wb_we, wb_stall, wb_ack, wb_err;
	wire	[31:0]	wb_data, wb_idata, wb_addr;

	//
	//
	// First BUS master source: The JTAG
	//
	//
	wire	[31:0]	dwb_idata;

	// Wires going to devices
	wire		wbu_cyc, wbu_stb, wbu_we;
	wire	[31:0]	wbu_addr, wbu_data;
	// and then coming from devices
	wire		wbu_ack, wbu_stall, wbu_err;
	wire	[31:0]	wbu_idata;
	// And then headed back home
	wire	w_interrupt;
	assign	w_interrupt = flash_interrupt;
	// Oh, and the debug control for the ZIP CPU
	wire		wbu_zip_sel, zip_dbg_ack, zip_dbg_stall;
	wire	[31:0]	zip_dbg_data;
`ifdef	DEBUG_ACCESS
	assign	wbu_zip_sel =((wbu_cyc)&&(wbu_addr[24]));
	wbubus	genbus(i_clk, i_rx_stb, i_rx_data,
			wbu_cyc, wbu_stb, wbu_we, wbu_addr, wbu_data,
`ifdef	INCLUDE_ZIPCPU
			((~wbu_zip_sel)&&(wbu_ack))
				||((wbu_zip_sel)&&(zip_dbg_ack)),
			((~wbu_zip_sel)&&(wbu_stall))
				||((wbu_zip_sel)&&(zip_dbg_stall)),
				wbu_err, (wbu_zip_sel)?zip_dbg_data:dwb_idata,
`else
			wbu_ack, wbu_stall,
				wbu_err, dwb_idata,
`endif
			w_interrupt,
			o_tx_stb, o_tx_data, i_tx_busy);
`else
	assign	wbu_cyc     = 1'b0;
	assign	wbu_stb     = 1'b0;
	assign	wbu_we      = 1'b0;
	assign	wbu_addr    = 32'h0;
	assign	wbu_data    = 32'h0;
	assign	wbu_zip_sel = 1'b0;
`endif


	//
	//
	// Second BUS master source: The ZipCPU
	//
	//
	wire		zip_cyc, zip_stb, zip_we, zip_cpu_int;
	wire	[(ZA-1):0]	w_zip_addr;
	wire	[31:0]	zip_addr, zip_data;
	// and then coming from devices
	wire		zip_ack, zip_stall, zip_err;
	wire	dwb_we, dwb_stb, dwb_cyc, dwb_ack, dwb_stall, dwb_err;
	wire	[31:0]	dwb_addr, dwb_odata;
	wire	[8:0]	w_ints_to_zip_cpu;
`ifdef	ZIP_SCOPE
	wire	[31:0]	zip_debug;
`endif

	zipsystem #(24'h2000,ZA,10,1,9)
		zippy(i_clk, 1'b0,
			// Zippys wishbone interface
			zip_cyc, zip_stb, zip_we, w_zip_addr, zip_data,
				zip_ack, zip_stall, dwb_idata, zip_err,
			w_ints_to_zip_cpu, zip_cpu_int,
			// Debug wishbone interface
			((wbu_cyc)&&(wbu_zip_sel)),
				((wbu_stb)&&(wbu_zip_sel)),wbu_we, wbu_addr[0],
				wbu_data,
				zip_dbg_ack, zip_dbg_stall, zip_dbg_data
`ifdef	ZIP_SCOPE
			, zip_debug
`endif
			);
	generate
	if (ZA < 32)
		assign	zip_addr = { {(32-ZA){1'b0}}, w_zip_addr };
	else
		assign	zip_addr = w_zip_addr;
	endgenerate


	//
	//
	// And an arbiter to decide who gets to access the bus
	//
	//
`ifdef	DEBUG_ACCESS
	wbpriarbiter #(32,32) wbu_zip_arbiter(i_clk,
		// The ZIP CPU Master -- gets priority in the arbiter
		zip_cyc, zip_stb, zip_we, zip_addr, zip_data,
			zip_ack, zip_stall, zip_err,
		// The JTAG interface Master, secondary priority,
		// will suffer a 1clk delay in arbitration
		(wbu_cyc)&&(~wbu_zip_sel), (wbu_stb)&&(~wbu_zip_sel), wbu_we,
			wbu_addr, wbu_data,
			wbu_ack, wbu_stall, wbu_err,
		// Common bus returns
		dwb_cyc, dwb_stb, dwb_we, dwb_addr, dwb_odata,
			dwb_ack, dwb_stall, dwb_err);
`else
	// But ... if there is no wbubus (TTY-based debug bus controller), then
	// we dont need the arbiter, so we can just assign values to the
	// results.
	assign	dwb_cyc = zip_cyc;
	assign	dwb_stb = zip_stb;
	assign	dwb_we  = zip_we;
	assign	dwb_addr= zip_addr;
	assign	dwb_odata = zip_data;
	assign	zip_ack   = dwb_ack;
	assign	zip_stall = dwb_stall;
	assign	zip_err   = dwb_err;
	// dwb_idata goes to both, so it doesnt go through the arbiter
`endif

	// 
	// 
	// And because the ZIP CPU and the Arbiter create an unacceptable
	// delay, we fail timing.  So we add in a delay cycle ...
	// 
	// 
`ifdef	NO_ZIP_WBU_DELAY
	assign	wb_cyc    = dwb_cyc;
	assign	wb_stb    = dwb_stb;
	assign	wb_we     = dwb_we;
	assign	wb_addr   = dwb_addr;
	assign	wb_data   = dwb_odata;
	assign	dwb_idata = wb_idata;
	assign	dwb_ack   = wb_ack;
	assign	dwb_stall = wb_stall;
	assign	dwb_err   = wb_err;
`else
	busdelay	wbu_zip_delay(i_clk,
			dwb_cyc, dwb_stb, dwb_we, dwb_addr, dwb_odata,
				dwb_ack, dwb_stall, dwb_idata, dwb_err,
			wb_cyc, wb_stb, wb_we, wb_addr, wb_data,
				wb_ack, wb_stall, wb_idata, wb_err);
`endif


	wire	io_sel, scop_sel, uart_sel, rtc_sel, flctl_sel, sdcard_sel,
			flash_sel, mem_sel;
	wire	io_ack, scop_ack, uart_ack, rtc_ack, flash_ack, sdcard_ack,
			mem_ack;
	wire	io_stall, scop_stall, uart_stall, rtc_stall, flash_stall,
			sdcard_stall, mem_stall;

	// Signals to build/detect bus errors
	wire	none_sel, many_sel, many_ack;

	wire	[31:0]	io_data, scop_data, uart_data, rtc_data, flash_data,
			sdcard_data, mem_data;
	reg	[31:0]	bus_err_addr;
	//
	// wb_ack
	//
	// The returning wishbone ack is equal to the OR of every component that
	// might possibly produce an acknowledgement, gated by the CYC line.  To
	// add new components, OR their acknowledgements in here.
	//
	// Note the reference to none_sel.  If nothing is selected, the result
	// is an error.  Here, we do nothing more than insure that the erroneous
	// request produces an ACK ... if it was ever made, rather than stalling
	// the bus.
	//

	assign	wb_ack = (wb_cyc)&&((io_ack)||(scop_ack)||(uart_ack)
				||(rtc_ack)||(flash_ack)||(sdcard_ack)
				||(mem_ack)
				||((none_sel)&&(1'b1)));

	//
	// wb_stall
	//
	// The returning wishbone stall line really depends upon what device
	// is requested.  Thus, if a particular device is selected, we return 
	// the stall line for that device.
	//
	// To add a new device, simply and that devices select and stall lines
	// together, and OR the result with the massive OR logic below.
	//
	assign	wb_stall = ((io_sel)&&(io_stall))
			||((scop_sel)&&(scop_stall))
			||((uart_sel)&&(uart_stall))
			||((rtc_sel)&&(rtc_stall))
			||((flash_sel||flctl_sel)&&(flash_stall))
			||((sdcard_sel)&&(sdcard_stall))
			||((mem_sel)&&(mem_stall));

	//
	// wb_idata
	//
	// This is the data returned on the bus.  Here, we select between a 
	// series of bus sources to select what data to return.  The basic 
	// logic is simply this: the data we return is the data for which the
	// ACK line is high. 
	//
	// The last item on the list is chosen by default if no other ACK's are
	// true.  Although we might choose to return zeros in that case, by
	// returning something we can skimp a touch on the logic.
	//
	// To add another device, add another ack check, and another closing
	// parenthesis.
	//
	assign	wb_idata =  (io_ack) ? io_data
				: ((scop_ack) ? scop_data
				: ((uart_ack) ? uart_data
				: ((rtc_ack)  ? rtc_data
				: ((flash_ack)  ? flash_data
				: ((sdcard_ack) ? sdcard_data
				: mem_data)))));

	//
	// wb_err
	//
	// This is the bus error signal.  It should never be true, but practice
	// teaches us otherwise.  Here, we allow for three basic errors:
	//
	// 1. STB is true, but no devices are selected
	//
	//	This is the null pointer reference bug.  If you try to access
	//	something on the bus, at an address with no mapping, the bus
	//	should produce an error--such as if you try to access something
	//	at zero.
	//
	// 2. STB is true, and more than one device is selected
	//
	//	(This can be turned off, if you design this file well.  For
	//	this line to be true means you have a design flaw.)
	//
	// 3. If more than one ACK is every true at any given time.
	//
	//	This is a bug of bus usage, combined with a subtle flaw in the
	//	WB pipeline definition.  You can issue bus requests, one per
	//	clock, and if you cross device boundaries with your requests,
	//	you may have things come back out of order (not detected here)
	//	or colliding on return (detected here).  The solution to this
	//	problem is to make certain that any burst request does not cross
	//	device boundaries.  This is a requirement of whoever (or
	//	whatever) drives the bus.
	//
	assign	wb_err = ((wb_stb)&&(none_sel || many_sel))
				|| ((wb_cyc)&&(many_ack));

	// Addresses ...
	//
	// dev_sel
	//
	// The device select lines
	//
	//

	wire	[8:0]	skipaddr;
	assign	skipaddr = { wb_addr[LGMEMSZ], wb_addr[LGFLASHSZ], wb_addr[7],
				wb_addr[6:1] };
	//
	// This might not be the most efficient way in hardware, but it will
	// work for our purposes here
	//
	assign	io_sel   = (skipaddr[8:3] == 6'b00_1000);
	assign	scop_sel = (skipaddr[8:0] == 9'b00_1001_000);
	assign	uart_sel = (skipaddr[8:1] == 8'b00_1010_00);
	assign	rtc_sel  = (skipaddr[8:1] == 8'b00_1010_00);
	assign	flctl_sel= (skipaddr[8:1] == 8'b00_1010_00);
	assign	sdcard_sel=(skipaddr[8:1] == 8'b00_1101_00);
	assign	flash_sel= (skipaddr[8:7] == 2'b01);
	assign	mem_sel  = (skipaddr[8]   == 1'b1);

	//
	// none_sel
	//
	// This wire is true if wb_stb is true and no device is selected.  This
	// is an error condition, but here we present the logic to test for it.
	//
	//
	// If you add another device, add another OR into the select lines
	// associated with this term.
	//
	assign	none_sel =((wb_stb)&&(!
			(io_sel
			||scop_sel
			||uart_sel
			||rtc_sel
			||flctl_sel
			||sdcard_sel
			||flash_sel
			||mem_sel)));

	//
	// many_sel
	//
	// This should *never* be true .... unless you mess up your address
	// decoding logic.  Since I've done that before, I test/check for it
	// here.
	//
	// To add a new device here, simply add it to the list.  Make certain
	// that the width of the add, however, is greater than the number
	// of devices below.  Hence, for 3 devices, you will need an add
	// at least 3 bits in width, for 7 devices you will need at least 4
	// bits, etc.
	//
	// Because this add uses the {} operator, the individual components to
	// it are by default unsigned ... just as we would like.
	//
	// There's probably another easier/better/faster/cheaper way to do this,
	// but I haven't found any such that are also easier to adjust with
	// new devices.  I'm open to options.
	//
	assign	many_sel =((wb_stb)&&(
			 {3'h0, io_sel}
			+{3'h0, scop_sel}
			+{3'h0, uart_sel}
			+{3'h0, rtc_sel}
			+{3'h0, flctl_sel}
			+{3'h0, sdcard_sel}
			+{3'h0, flash_sel}
			+{3'h0, mem_sel} > 1));

	//
	// many_ack
	//
	// This is like none_sel, but it is applied to the ACK line, and gated
	// by wb_cyc -- so that random things on the address line won't set this
	// off.  
	//
	// To add more items here, just do as you did for many_sel, but here
	// with the (new) dev_ack line.
	//
	assign	many_ack =((wb_cyc)&&(
			 {3'h0, io_ack}
			+{3'h0, scop_ack}
			+{3'h0, uart_ack}
			+{3'h0, rtc_ack}
			// FLCTL acks through the flash, so one less check here
			+{3'h0, sdcard_ack}
			+{3'h0, flash_ack}
			+{3'h0, mem_ack} > 1));

	//
	// bus_err_addr
	//
	// We'd like to know, after the fact, what (if any) address caused a
	// bus error.  So ... if we get a bus error, let's record the address
	// on the bus for later analysis.
	//
	always @(posedge i_clk)
		if (wb_err)
			bus_err_addr <= wb_addr;

	//
	// Interrupt processing
	//
	// The I/O slave contains an interrupt processor on it.  It will tell
	// us if any interrupts take place.  However, two of the interrupts
	// we are interested in: FLASH (erase/program op complete) and SCOPE
	// (trigger has gone off, and the SCOPE has stopped recording), are
	// known out here rather than within the I/O slave.
	//
	// To add more interrupts, you can just add more parameters to the
	// ioslave for the new interrupts.  Just be aware ... if you do so
	// here, you'll have to look into reading those interrupts properly
	// from the I/O slave as well.
	// 
	wire		flash_interrupt, sdcard_interrupt, scop_interrupt,
			uart_rx_int, uart_tx_int, rtc_int, pps_int,
			uart_rxfifo_int, uart_txfifo_int;

	assign	w_ints_to_zip_cpu = {
		flash_interrupt, sdcard_interrupt, scop_interrupt,
			uart_rxfifo_int, uart_txfifo_int,
			uart_rx_int, uart_tx_int, rtc_int, pps_int
		};

	// The simple I/O processor, herein called an ioslave
	ioslave runio(i_clk,
			wb_cyc, (wb_stb)&&(io_sel), wb_we, wb_addr[3:0],
				wb_data, io_ack, io_stall, io_data,
			bus_err_addr);

	//
	//	UART device: our console
	//
	wire	[31:0]	uart_debug;
	wbuart	consoleport(i_clk, 1'b0,
			wb_cyc, (wb_stb)&&(uart_sel), wb_we,
					{ ~wb_addr[2], wb_addr[0]}, wb_data,
			uart_ack, uart_stall, uart_data,
			i_rx_uart, o_tx_uart,
			uart_rx_int, uart_tx_int,
			uart_rxfifo_int, uart_txfifo_int);


	//
	//	FLASH MEMORY CONFIGURATION ACCESS
	//
	wire	spi_user, sdcard_grant, flash_grant;
`ifdef	FLASH_SCOPE
	// If we're going to keep track of debug data via a scope, we'll need
	// a variable to keep track of it within
	wire	[31:0]	flash_debug;
`endif
`ifdef	FLASH_ACCESS
	assign	flash_sel = (!wb_addr[24])&&(wb_addr[22]);
	wbqspiflash #(24)	flashmem(i_clk,
		wb_cyc,(wb_stb)&&(flash_sel),(wb_stb)&&(flctl_sel),wb_we,
			wb_addr[21:0], wb_data,
		flash_ack, flash_stall, flash_data,
		o_qspi_sck, o_qspi_cs_n, o_qspi_mod, o_qspi_dat, i_qspi_dat,
		flash_interrupt);
`else
	reg	r_flash_ack;
	initial	r_flash_ack = 1'b0;
	always @(posedge i_clk)
		r_flash_ack <= (wb_stb)&&((flash_sel)||(flctl_sel));

	assign	flash_ack = r_flash_ack;
	assign	flash_stall = 1'b0;
	assign	flash_data = 32'h0000;
	assign	flash_interrupt = 1'b0;

	assign	o_qspi_sck   = 1'b1;
	assign	o_qspi_cs_n  = 1'b1;
	assign	o_qspi_mod   = 2'b01;
	assign	o_qspi_dat   = 4'b1111;
`endif

	//
	//	SDCARD
	//
	wire	sdcard_cs_n, sdcard_sck, sdcard_mosi;
	wire	[31:0]	sdspi_scope;
`ifdef	SDCARD_ACCESS
	wire	w_sd_cs_n, w_sd_mosi, w_sd_miso;

	sdspi	sdcard_controller(i_clk,
		// Wishbone interface
		wb_cyc, (wb_stb)&&(sdcard_sel), wb_we, wb_addr[1:0], wb_data,
		//	return
			sdcard_ack, sdcard_stall, sdcard_data,
		// SPI interface
		sdcard_cs_n, sdcard_sck, sdcard_mosi, w_sd_miso,
		sdcard_interrupt, 1'b1, sdspi_scope);
	assign	w_sd_miso = i_sd_data[0];
	assign	o_sd_data = { w_sd_cs_n, 3'b111 };
	assign	o_sd_cmd  = w_sd_mosi;
`else
	reg	r_sdcard_ack;
	initial	r_sdcard_ack = 1'b0;
	always @(posedge i_clk)
		r_sdcard_ack <= (wb_stb)&&(sdcard_sel);
	assign	sdcard_stall = 1'b0;
	assign	sdcard_ack = r_sdcard_ack;
	assign	sdcard_data = 32'h0000;
	assign	sdcard_interrupt= 1'b0;

	assign	o_sd_sck = 1'b1;
	assign	o_sd_cmd = 1'b1;
	assign	o_sd_data = 4'b1111;
`endif	// SDCARD_ACCESS

	//
	//	RAM MEMORY ACCESS
	//
	memdev	#(LGMEMSZ) ram(i_clk, wb_cyc, (wb_stb)&&(mem_sel), wb_we,
			wb_addr[(LGMEMSZ-1):0], wb_data,
			mem_ack, mem_stall, mem_data);


	//
	//
	//	WISHBONE SCOPES
	//
	//
	// These make a microcosm of the entire busmaster interconnect
	// interface.  Therefore, let's start with their various select lines.
	wire	scop_one_sel, zip_scop_sel;

	assign	scop_one_sel = (scop_sel)&&(wb_addr[1]==1'b0);
	assign	zip_scop_sel = (scop_sel)&&(wb_addr[1]==1'b1);


	//
	// The first scope is the flash scope.  To actually get this scope
	// up and running, you'll need to uncomment the o_debug data from the
	// wbspiflash module, and make certain it gets added to the port list,
	// etc.  Once done, you can then enable FLASH_SCOPE and read/record
	// values from that interaction.
	//
	wire	[31:0]	scop_one_data;
	wire	scop_one_ack, scop_one_stall, scop_one_interrupt;

	assign	scop_one_data = 32'h00;
	assign	scop_one_ack  = (wb_stb)&&(scop_one_sel);
	assign	scop_one_stall = 1'b0;
	assign	scop_one_interrupt = 1'b0;


	wire	[31:0]	scop_zip_data;
	wire		scop_zip_ack, scop_zip_stall, scop_zip_interrupt;
`ifdef	ZIP_SCOPE
	wire	zip_trigger;
	assign	zip_trigger = zip_debug[31];
	wbscope	#(5'hd) zipscope(i_clk, 1'b1, zip_trigger,
			zip_debug,
		// Wishbone interface
		i_clk, wb_cyc, ((wb_stb)&&(zip_scop_sel)), wb_we, wb_addr[0],
			wb_data,
			scop_zip_ack, scop_zip_stall, scop_zip_data,
		scop_zip_interrupt);
`else
	assign	scop_zip_data = 32'h00;
	assign	scop_zip_ack  = (wb_stb)&&(scop_sel)&&(wb_addr[1]==2'b1);
	assign	scop_zip_stall = 1'b0;
	assign	scop_zip_interrupt = 1'b0;
`endif


	// Merge the various scopes back together for their response over the
	// wishbone bus:
	//
	// First, combine their interrupt lines into a combined scope interrupt
	// line.
	//
	// To add more scopes ... simple OR the new interrupt lines
	// together with these others in this list.
	//

	assign	scop_interrupt = scop_one_interrupt || scop_zip_interrupt;
	//
	// scop_ack
	//
	// The is the acknolegement returned by the scope.  To generate this,
	// just OR all of the various acknowledgement lines together.  To add
	// more scopes, just increase the number of things ORd together here.
	//
	assign	scop_ack   = scop_one_ack   || scop_zip_ack;

	//
	// scop_stall
	//
	// As written, the scopes NEVER stall.  This is more for form than
	// anything else.  We allow a future scope developer to make a scope
	// that might stall, and so we deal with stalls here.
	//
	// In particular, the stall logic is basically this:
	// 	if the nth scope is selected, then return the stall line from
	//		the nth scope.
	// We don't check whether or not the scope is selected at all here, 
	// since the master stall line check using scop_stall checks that above.
	// Note that we aren't testing whether or not the address matches the
	// last stall to return its result, it will just be returned by default
	// if no other addresses match.
	//
	// To add new scopes, just add their respective stall lines to the
	// list.  Note, though, in so doing that the address comparison will
	// need to be expanded from a single bit to more bits.
	//
	// (Adding scopes is expensive in terms of block RAM, therefore, I like
	// to keep the number of scopes to a minimum, and just rebuild the
	// design when I need more.)
	//
	assign	scop_stall = scop_one_stall | scop_zip_stall;
	//
	// scop_data
	//
	// This is very similar to wb_idata above.  If a given item produces
	// an ack, return the data from that item.
	//
	assign	scop_data  = (scop_one_ack) ? scop_one_data : scop_zip_data;

endmodule

// 0x8684 interrupts ...???
