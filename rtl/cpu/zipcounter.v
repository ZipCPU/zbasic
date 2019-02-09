////////////////////////////////////////////////////////////////////////////////
//
// Filename:	zipcounter.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:
//		A very, _very_ simple counter.  It's purpose doesn't really
//	include rollover, but it will interrupt on rollover.  It can be set,
//	although my design concept is that it can be reset.  It cannot be
//	halted.  It will always produce interrupts--whether or not they are 
//	handled interrupts is another question--that's up to the interrupt
//	controller.
//
//	My intention is to use this counter for process accounting: I should
//	be able to use this to count clock ticks of processor time assigned to
//	each task by resetting the counter at the beginning of every task
//	interval, and reading the result at the end of the interval.  As long
//	as the interval is less than 2^32 clocks, there should be no problem.
//	Similarly, this can be used to measure CPU wishbone bus stalls, 
//	prefetch stalls, or other CPU stalls (i.e. stalling as part of a JMP
//	instruction, or a read from the condition codes following a write).
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
module	zipcounter(i_clk, i_reset, i_event,
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_data,
			o_wb_ack, o_wb_stall, o_wb_data,
		o_int);
	parameter	BW = 32;
	input	wire			i_clk, i_reset, i_event;
	// Wishbone inputs
	input	wire			i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[(BW-1):0]	i_wb_data;
	// Wishbone outputs
	output	reg			o_wb_ack;
	output	wire			o_wb_stall;
	output	reg	[(BW-1):0]	o_wb_data;
	// Interrupt line
	output	reg			o_int;

	initial	o_int = 0;
	initial	o_wb_data = 32'h00;
	always @(posedge i_clk)
		if (i_reset)
			{ o_int, o_wb_data } <= 0;
		else if ((i_wb_stb)&&(i_wb_we))
			{ o_int, o_wb_data } <= { 1'b0, i_wb_data };
		else if (i_event)
			{ o_int, o_wb_data } <= o_wb_data+{{(BW-1){1'b0}},1'b1};
		else
			o_int <= 1'b0;

	initial	o_wb_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_ack <= 1'b0;
	else
		o_wb_ack <= i_wb_stb;
	assign	o_wb_stall = 1'b0;


	// Make verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = i_wb_cyc;
	// verilator lint_on  UNUSED

`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
endmodule
