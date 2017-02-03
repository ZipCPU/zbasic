////////////////////////////////////////////////////////////////////////////////
//
// Filename:	ioslave.v
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	This handles a bunch of small, simple I/O registers.  To be
//		included here, the I/O register must take exactly a single
//	clock to access and never stall.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2016-2017, Gisselquist Technology, LLC
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
`include "builddate.v"
module	ioslave(i_clk,
		// Wishbone control
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
			o_wb_ack, o_wb_stall, o_wb_data,
		// Other registers
		i_bus_err_addr);
	parameter	NGPO=15, NGPI=15;
	input			i_clk;
	// Wishbone control
	//	inputs...
	input			i_wb_cyc, i_wb_stb, i_wb_we;
	input		[3:0]	i_wb_addr;
	input		[31:0]	i_wb_data;
	//	outputs...
	output	reg		o_wb_ack;
	output	wire		o_wb_stall;
	output	wire	[31:0]	o_wb_data;
	// Other registers
	input		[31:0]	i_bus_err_addr;

	wire		[31:0]	date_data;

	reg	[31:0]	r_wb_data, pwrcount;
	always @(posedge i_clk)
	begin
		//
		if ((i_wb_stb)&&(~i_wb_we))
		begin
			casez(i_wb_addr[1:0])
			2'h0: r_wb_data <= `DATESTAMP;
			2'h1: r_wb_data <= pwrcount;
			2'h2: r_wb_data <= i_bus_err_addr;
			// 2'h3: r_wb_data <= date_data;
			default: r_wb_data <= 32'h0000;
			endcase
		end
	end

	// The ticks since power up register
	initial	pwrcount = 32'h00;
	always @(posedge i_clk)
		if (!pwrcount[31])
			pwrcount <= pwrcount+1;
		else
			pwrcount[30:0] <= pwrcount[30:0] + 1'b1;


	always @(posedge i_clk)
		o_wb_ack <= (i_wb_stb)&&(i_wb_cyc);
	assign	o_wb_stall = 1'b0;

	assign	o_wb_data = r_wb_data;

	//
	//
endmodule
