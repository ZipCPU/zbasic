////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbubus.v
// {{{
// Project:	FPGA library
//
// Purpose:	This is the top level file for the entire JTAG-USB to Wishbone
//		bus conversion.  (It's also the place to start debugging, should
//	things not go as planned.)  Bytes come into this routine, bytes go out,
//	and the wishbone bus (external to this routine) is commanded in between.
//
//
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
module	wbubus #(
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
		input	wire		i_tx_busy
		// }}}
		// , output	wire		o_dbg;
		// }}}
	);

	// Local declarations
	// {{{
	wire		soft_reset;
	reg		r_wdt_reset;
	wire		cmd_port_active, w_tx_stb;
	wire		in_stb;
	wire	[35:0]	in_word;
	wire	w_bus_busy, fifo_in_stb, exec_stb, w_bus_reset;
	wire	[35:0]	fifo_in_word, exec_word;
	wire		ofifo_err;
	reg	[(LGWATCHDOG-1):0]	r_wdt_timer;
	// wire	[30:0]	out_dbg;
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
		.i_stb(i_rx_stb), .i_byte(i_rx_data),
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
		.o_stb(w_tx_stb), .o_char(o_tx_data), .i_tx_busy(i_tx_busy),
		.o_fifo_err(ofifo_err)
		// }}}
	);

	assign	o_tx_stb = w_tx_stb && cmd_port_active;

	// verilator lint_off UNUSED
	wire	ofifo_unused;
	assign	ofifo_unused = ofifo_err;
	// verilator lint_on  UNUSED

	// Add in a watchdog timer to the bus
	// {{{
	initial	r_wdt_reset = 1'b0;
	initial	r_wdt_timer = 0;
	always @(posedge i_clk)
	begin
		if ((~o_wb_cyc)||(i_wb_ack))
		begin
			r_wdt_timer <= 0;
			r_wdt_reset <= 1'b0;
		end else if (&r_wdt_timer)
		begin
			r_wdt_reset <= 1'b1;
			r_wdt_timer <= 0;
		end else begin
			r_wdt_timer <= r_wdt_timer+{{(LGWATCHDOG-1){1'b0}},1'b1};
			r_wdt_reset <= 1'b0;
		end

		if (soft_reset)
			r_wdt_reset <= 1'b1;
	end
	// }}}

endmodule

