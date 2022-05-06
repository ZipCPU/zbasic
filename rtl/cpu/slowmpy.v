////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	slowmpy.v
// {{{
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	This is a signed (OPT_SIGNED=1) or unsigned (OPT_SIGNED=0)
// 		multiply designed for low logic and slow data signals.  It
// 	takes one clock per bit plus two more to complete the multiply.
//
//	The OPT_SIGNED version of this algorithm was found on Wikipedia at
//	https://en.wikipedia.org/wiki/Binary_multiplier.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2018-2022, Gisselquist Technology, LLC
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
module	slowmpy #(
		// {{{
		parameter			LGNA = 6,
		parameter	[LGNA:0]	NA = 33,
		parameter	[0:0]		OPT_SIGNED = 1'b1,
		parameter	[0:0]		OPT_LOWPOWER = 1'b0,
		localparam	NB = NA // Must be = NA for OPT_SIGNED to work
		// }}}
	) (
		// {{{
		input	wire				i_clk, i_reset,
		//
		input	wire				i_stb,
		input	wire	signed	[(NA-1):0]	i_a,
		input	wire	signed	[(NB-1):0]	i_b,
		input	wire				i_aux,
		output	reg				o_busy, o_done,
		output	reg	signed	[(NA+NB-1):0]	o_p,
		output	reg				o_aux
		// }}}
	);

	// Declarations
	// {{{
	reg	[LGNA-1:0]	count;
	reg	[NA-1:0]	p_a;
	reg	[NB-1:0]	p_b;
	reg	[NA+NB-1:0]	partial;
	reg			aux;
	reg			almost_done;
	wire			pre_done;
	wire	[NA-1:0]	pwire;
	// }}}

	assign	pre_done = (count == 0);

	// almost_done
	// {{{
	initial	almost_done = 1'b0;
	always @(posedge i_clk)
		almost_done <= (!i_reset)&&(o_busy)&&(pre_done);
	// }}}

	// aux, o_done, o_busy
	// {{{
	initial	aux    = 0;
	initial	o_done = 0;
	initial	o_busy = 0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		// {{{
		aux    <= 0;
		o_done <= 0;
		o_busy <= 0;
		// }}}
	end else if (!o_busy)
	begin
		// {{{
		o_done <= 0;
		o_busy <= i_stb;
		aux    <= (!OPT_LOWPOWER || i_stb) ? i_aux : 0;
		// }}}
	end else if (almost_done)
	begin
		// {{{
		o_done <= 1;
		o_busy <= 0;
		// }}}
	end else
		o_done <= 0;
	// }}}

	assign	pwire = (p_b[0] ? p_a : 0);

	// count, partial, p_a, p_b
	// {{{
	always @(posedge i_clk)
	if (!o_busy)
	begin
		count <= NA[LGNA-1:0]-1;
		partial <= 0;
		p_a <= i_a;
		p_b <= i_b;

		if (OPT_LOWPOWER && !i_stb)
		begin
			p_a <= 0;
			p_b <= 0;
		end
	end else begin
		p_b <= (p_b >> 1);
		// partial[NA+NB-1:NB] <= partial[NA+NB
		partial[NB-2:0] <= partial[NB-1:1];
		if ((OPT_SIGNED)&&(pre_done))
			partial[NA+NB-1:NB-1] <= { 1'b0, partial[NA+NB-1:NB]} +
				{ 1'b0, pwire[NA-1], ~pwire[NA-2:0] };
		else if (OPT_SIGNED)
			partial[NA+NB-1:NB-1] <= {1'b0,partial[NA+NB-1:NB]} +
				{ 1'b0, !pwire[NA-1], pwire[NA-2:0] };
		else
			partial[NA+NB-1:NB-1] <= {1'b0, partial[NA+NB-1:NB]}
				+ ((p_b[0]) ? {1'b0,p_a} : 0);
		count <= count - 1;
	end
	// }}}

	// o_p, o_aux
	// {{{
	always @(posedge i_clk)
	if (almost_done)
	begin
		if (OPT_SIGNED)
			o_p   <= partial[NA+NB-1:0]
				+ { 1'b1, {(NA-2){1'b0}}, 1'b1, {(NB){1'b0}} };
		else
			o_p   <= partial[NA+NB-1:0];
		o_aux <= aux;
	end
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
// Formal properties for this design are maintained elsewhere
`endif
// }}}
endmodule
