////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbuconsole.v
// {{{
// Project:	FPGA library
//
// Purpose:	This is the top level file for the entire JTAG-USB to Wishbone
//		bus conversion.  (It's also the place to start debugging, should
//	things not go as planned.)  Bytes come into this routine, bytes go out,
//	and the wishbone bus (external to this routine) is commanded in between.
//
//	You may find some strong similarities between this module and the
//	wbubus module.  They two are essentially the same, with the exception
//	that this version will also multiplex a serial port together with
//	the JTAG-USB->wishbone conversion.  Graphically:
//
//	devbus  -> TCP/IP	\			/ -> WB master
//				MUXED over USB -> UART
//	console -> TCP/IP	/			\ -> wbuconsole
//
//	Doing this, however, also entails stripping the 8th bit from the UART
//	port, so the serial port so contrived can only handle 7-bit data. 
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2021, Gisselquist Technology, LLC
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
`default_nettype	none
// }}}
module	wbuconsole #(
		// {{{
		parameter	LGWATCHDOG=19,
				LGINPUT_FIFO=6,
				LGOUTPUT_FIFO=10,
		parameter [0:0] CMD_PORT_OFF_UNTIL_ACCESSED = 1'b1
		// }}}
	) (
		// {{{
		input	wire		i_clk,
		input	wire		i_reset,
		// RX
		// {{{
		input	wire		i_rx_stb,
		input	wire	[7:0]	i_rx_data,
		// }}}
		// Wishbone master
		// {{{
		output	wire		o_wb_cyc, o_wb_stb, o_wb_we,
		output	wire	[31:0]	o_wb_addr, o_wb_data,
		input	wire		i_wb_stall, i_wb_ack,
		input	wire	[31:0]	i_wb_data,
		input	wire		i_wb_err,
		// }}}
		input	wire		i_interrupt,
		// TX
		// {{{
		output	wire		o_tx_stb,
		output	wire	[7:0]	o_tx_data,
		input	wire		i_tx_busy,
		// }}}
		// CONSOLE
		// {{{
		input	wire		i_console_stb,
		input	wire	[6:0]	i_console_data,
		output	wire		o_console_busy,
		//
		output	reg		o_console_stb,
		output	reg	[6:0]	o_console_data,
		// }}}
		output	wire		o_dbg
		// }}}
	);

	// Local declarations
	// {{{
	wire		soft_reset;
	reg		r_wdt_reset;
	wire		cmd_port_active;
	wire		in_stb;
	wire	[35:0]	in_word;
	wire	w_bus_busy, fifo_in_stb, exec_stb, w_bus_reset;
	wire	[35:0]	fifo_in_word, exec_word;
	reg		ps_full;
	reg	[7:0]	ps_data;
	wire		wbu_tx_stb;
	wire	[7:0]	wbu_tx_data;
	wire		ofifo_err;
	reg	[(LGWATCHDOG-1):0]	r_wdt_timer;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Forward console inputs to the console
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	initial	o_console_stb = 1'b0;
	always @(posedge i_clk)
		o_console_stb <= (i_rx_stb)&&(i_rx_data[7] == 1'b0);

	always @(posedge i_clk)
		o_console_data <= i_rx_data[6:0];
	// }}}

	// cmd_port_active
	// {{{
	generate if (CMD_PORT_OFF_UNTIL_ACCESSED)
	begin

		reg	r_cmd_port_active;

		initial	r_cmd_port_active = 1'b0;
		always @(posedge i_clk)
		if (i_rx_stb && i_rx_data[7])
			r_cmd_port_active <= 1'b1;

		assign	cmd_port_active = r_cmd_port_active;

	end else begin

		assign	cmd_port_active = 1'b1;

	end endgenerate
	// }}}

	////////////////////////////////////////////////////////////////////////
	//
	// Decode ASCII input requests into WB bus cycle requests
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	wbuinput
	getinput(
		// {{{
		.i_clk(i_clk), .i_reset(i_reset),
		.i_stb(i_rx_stb && i_rx_data[7]), .i_byte({ 1'b0, i_rx_data[6:0] }),
		.o_soft_reset(soft_reset),
		.o_stb(in_stb), .o_codword(in_word)
		// }}}
	);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The input FIFO
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	generate if (LGINPUT_FIFO < 2)
	begin : NO_INPUT_FIFO

		assign	fifo_in_stb = in_stb;
		assign	fifo_in_word = in_word;
		assign	w_bus_reset = soft_reset;

	end else begin : INPUT_FIFO

		wire		ififo_empty_n, ififo_err;

		assign	fifo_in_stb = (~w_bus_busy)&&(ififo_empty_n);
		assign	w_bus_reset = r_wdt_reset;

		wbufifo	#(
			// {{{
			.BW(36),.LGFLEN(LGINPUT_FIFO)
			// }}}
		) padififo(
			// {{{
			.i_clk(i_clk), .i_reset(w_bus_reset),
			.i_wr(in_stb), .i_data(in_word),
			.i_rd(fifo_in_stb), .o_data(fifo_in_word),
			.o_empty_n(ififo_empty_n), .o_err(ififo_err)
			// }}}
		);

		// verilator lint_off UNUSED
		wire	gen_unused;
		assign	gen_unused = ififo_err;
		// verilator lint_on  UNUSED
	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Run the bus
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// Take requests in, Run the bus, send results out
	// This only works if no requests come in while requests
	// are pending.
	wbuexec
	runwb(
		// {{{
		.i_clk(i_clk), .i_reset(r_wdt_reset),
		.i_stb(fifo_in_stb), .i_codword(fifo_in_word),
			.o_busy(w_bus_busy),
		.o_wb_cyc(o_wb_cyc), .o_wb_stb(o_wb_stb), .o_wb_we(o_wb_we),
			.o_wb_addr(o_wb_addr), .o_wb_data(o_wb_data),
		.i_wb_stall(i_wb_stall), .i_wb_ack(i_wb_ack),
			.i_wb_data(i_wb_data), .i_wb_err(i_wb_err),
		.o_stb(exec_stb), .o_codword(exec_word)
		// }}}
	);
	// }}}

	wbuoutput #(
		LGOUTPUT_FIFO
	) wroutput(
		// {{{
		.i_clk(i_clk), .i_reset(i_reset), .i_soft_reset(w_bus_reset),
		.i_stb(exec_stb), .i_codword(exec_word),
		.i_wb_cyc(o_wb_cyc), .i_int(i_interrupt), .i_bus_busy(exec_stb),
		.o_stb(wbu_tx_stb), .o_char(wbu_tx_data), .i_tx_busy(ps_full),
		.o_fifo_err(ofifo_err)
		// }}}
	);

	////////////////////////////////////////////////////////////////////////
	//
	// Arbitrate between the two outputs, console and dbg bus
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	initial	ps_full = 1'b0;
	always @(posedge i_clk)
	if (!ps_full)
	begin
		if (cmd_port_active && wbu_tx_stb)
		begin
			ps_full <= 1'b1;
			ps_data <= { 1'b1, wbu_tx_data[6:0] };
		end else if (i_console_stb)
		begin
			ps_full <= 1'b1;
			ps_data <= { 1'b0, i_console_data[6:0] };
		end
	end else if (!i_tx_busy)
		ps_full <= 1'b0;

	assign	o_tx_stb = ps_full;
	assign	o_tx_data = ps_data;
	assign	o_console_busy = (wbu_tx_stb && cmd_port_active)||(ps_full);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Add in a watchdog timer to the bus
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	initial	r_wdt_reset = 1'b1;
	initial	r_wdt_timer = 0;
	always @(posedge i_clk)
	if (i_reset || soft_reset)
	begin
		r_wdt_timer <= 0;
		r_wdt_reset <= 1'b1;
	end else if ((~o_wb_cyc)||(i_wb_ack))
	begin
		// We're inactive, or the bus has responded: reset the timer
		// {{{
		r_wdt_timer <= 0;
		r_wdt_reset <= 1'b0;
		// }}}
	end else if (&r_wdt_timer)
	begin	// TIMEOUT!!!
		// {{{
		r_wdt_reset <= 1'b1;
		r_wdt_timer <= 0;
		// }}}
	end else begin // Tick-tock ...
		r_wdt_timer <= r_wdt_timer+{{(LGWATCHDOG-1){1'b0}},1'b1};
		r_wdt_reset <= 1'b0;
	end
	// }}}

	assign	o_dbg = w_bus_reset;

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	[1:0]	unused;
	assign	unused = { ofifo_err, wbu_tx_data[7] };
	// verilator lint_on  UNUSED
endmodule

