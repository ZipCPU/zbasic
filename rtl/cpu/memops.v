////////////////////////////////////////////////////////////////////////////////
//
// Filename:	memops.v
// {{{
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	A memory unit to support a CPU.
//
//	In the interests of code simplicity, this memory operator is
//	susceptible to unknown results should a new command be sent to it
//	before it completes the last one.  Unpredictable results might then
//	occurr.
//
//	BIG ENDIAN
//		Note that this core assumes a big endian bus, with the MSB
//		of the bus word being the least bus address
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2022, Gisselquist Technology, LLC
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
module	memops #(
		// {{{
		parameter	ADDRESS_WIDTH=30,
		parameter [0:0]	OPT_LOCK=1'b1,
				WITH_LOCAL_BUS=1'b1,
				OPT_ALIGNMENT_ERR=1'b1,
				OPT_LOWPOWER=1'b0,
				OPT_LITTLE_ENDIAN = 1'b0,
		localparam	AW=ADDRESS_WIDTH
`ifdef	FORMAL
		, parameter	F_LGDEPTH = 2
`endif
		// }}}
	) (
		// {{{
		input	wire			i_clk, i_reset,
		// CPU interface
		// {{{
		input	wire			i_stb, i_lock,
		input	wire	[2:0]		i_op,
		input	wire	[31:0]		i_addr,
		input	wire	[31:0]		i_data,
		input	wire	[4:0]		i_oreg,
		// CPU outputs
		output	wire			o_busy,
		output	reg			o_rdbusy,
		output	reg			o_valid,
		output	reg			o_err,
		output	reg	[4:0]		o_wreg,
		output	reg	[31:0]		o_result,
		// }}}
		// Wishbone
		// {{{
		output	wire			o_wb_cyc_gbl,
		output	wire			o_wb_cyc_lcl,
		output	reg			o_wb_stb_gbl,
		output	reg			o_wb_stb_lcl,
		output	reg			o_wb_we,
		output	reg	[(AW-1):0]	o_wb_addr,
		output	reg	[31:0]		o_wb_data,
		output	reg	[3:0]		o_wb_sel,
		// Wishbone inputs
		input	wire		i_wb_stall, i_wb_ack, i_wb_err,
		input	wire	[31:0]	i_wb_data
		// }}}
		// }}}
	);

	// Declarations
	// {{{

	wire		misaligned;
	reg		r_wb_cyc_gbl, r_wb_cyc_lcl;
	reg	[3:0]	r_op;
	wire		lock_gbl, lock_lcl;
	wire		gbl_stb, lcl_stb;
	// }}}

	// misaligned
	// {{{
	generate if (OPT_ALIGNMENT_ERR)
	begin : GENERATE_ALIGNMENT_ERR
		reg	r_misaligned;

		always @(*)
		casez({ i_op[2:1], i_addr[1:0] })
		4'b01?1: r_misaligned = i_stb; // Words must be halfword aligned
		4'b0110: r_misaligned = i_stb; // Words must be word aligned
		4'b10?1: r_misaligned = i_stb; // Halfwords must be aligned
		// 4'b11??: r_misaligned <= 1'b0; Byte access are never misaligned
		default: r_misaligned = 1'b0;
		endcase

		assign	misaligned = r_misaligned;
	end else
		assign	misaligned = 1'b0;
	endgenerate
	// }}}

	// lcl_stb, gbl_stb
	// {{{
	assign	lcl_stb = (i_stb)&&(WITH_LOCAL_BUS!=0)&&(i_addr[31:24]==8'hff)
				&&(!misaligned);
	assign	gbl_stb = (i_stb)&&((WITH_LOCAL_BUS==0)||(i_addr[31:24]!=8'hff))
				&&(!misaligned);
	// }}}

	// r_wb_cyc_gbl, r_wb_cyc_lcl
	// {{{
	initial	r_wb_cyc_gbl = 1'b0;
	initial	r_wb_cyc_lcl = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		r_wb_cyc_gbl <= 1'b0;
		r_wb_cyc_lcl <= 1'b0;
	end else if ((r_wb_cyc_gbl)||(r_wb_cyc_lcl))
	begin
		if ((i_wb_ack)||(i_wb_err))
		begin
			r_wb_cyc_gbl <= 1'b0;
			r_wb_cyc_lcl <= 1'b0;
		end
	end else begin // New memory operation
		// Grab the wishbone
		r_wb_cyc_lcl <= (lcl_stb);
		r_wb_cyc_gbl <= (gbl_stb);
	end
	// }}}

	// o_wb_stb_gbl
	// {{{
	initial	o_wb_stb_gbl = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_stb_gbl <= 1'b0;
	else if ((i_wb_err)&&(r_wb_cyc_gbl))
		o_wb_stb_gbl <= 1'b0;
	else if (gbl_stb)
		o_wb_stb_gbl <= 1'b1;
	else if (o_wb_cyc_gbl)
		o_wb_stb_gbl <= (o_wb_stb_gbl)&&(i_wb_stall);
	//  }}}

	// o_wb_stb_lcl
	// {{{
	initial	o_wb_stb_lcl = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_stb_lcl <= 1'b0;
	else if ((i_wb_err)&&(r_wb_cyc_lcl))
		o_wb_stb_lcl <= 1'b0;
	else if (lcl_stb)
		o_wb_stb_lcl <= 1'b1;
	else if (o_wb_cyc_lcl)
		o_wb_stb_lcl <= (o_wb_stb_lcl)&&(i_wb_stall);
	// }}}

	// o_wb_we, o_wb_data, o_wb_sel
	// {{{
	initial	o_wb_we   = 1'b0;
	initial	o_wb_data = 0;
	initial	o_wb_sel  = 0;
	always @(posedge i_clk)
	if (i_stb)
	begin
		o_wb_we   <= i_op[0];
		if (OPT_LOWPOWER)
		begin
			casez({ OPT_LITTLE_ENDIAN, i_op[2:1], i_addr[1:0] })
			5'b0100?: o_wb_data <= { i_data[15:0], 16'h00 };
			5'b0101?: o_wb_data <= { 16'h00, i_data[15:0] };
			5'b01100: o_wb_data <= {         i_data[7:0], 24'h00 };
			5'b01101: o_wb_data <= {  8'h00, i_data[7:0], 16'h00 };
			5'b01110: o_wb_data <= { 16'h00, i_data[7:0],  8'h00 };
			5'b01111: o_wb_data <= { 24'h00, i_data[7:0] };
			//
			5'b1100?: o_wb_data <= { 16'h00, i_data[15:0] };
			5'b1101?: o_wb_data <= { i_data[15:0], 16'h00 };
			5'b11100: o_wb_data <= { 24'h00, i_data[7:0] };
			5'b11101: o_wb_data <= { 16'h00, i_data[7:0],  8'h00 };
			5'b11110: o_wb_data <= {  8'h00, i_data[7:0], 16'h00 };
			5'b11111: o_wb_data <= {         i_data[7:0], 24'h00 };
			//
			default: o_wb_data <= i_data;
			endcase
		end else
			casez({ i_op[2:1], i_addr[1:0] })
			4'b10??: o_wb_data <= { (2){ i_data[15:0] } };
			4'b11??: o_wb_data <= { (4){ i_data[7:0] } };
			default: o_wb_data <= i_data;
			endcase

		o_wb_addr <= i_addr[(AW+1):2];
		casez({ OPT_LITTLE_ENDIAN, i_op[2:1], i_addr[1:0] })
		5'b001??: o_wb_sel <= 4'b1111;
		5'b0100?: o_wb_sel <= 4'b1100;
		5'b0101?: o_wb_sel <= 4'b0011;
		5'b01100: o_wb_sel <= 4'b1000;
		5'b01101: o_wb_sel <= 4'b0100;
		5'b01110: o_wb_sel <= 4'b0010;
		5'b01111: o_wb_sel <= 4'b0001;
		//
		5'b101??: o_wb_sel <= 4'b1111;
		5'b1100?: o_wb_sel <= 4'b0011;
		5'b1101?: o_wb_sel <= 4'b1100;
		5'b11100: o_wb_sel <= 4'b0001;
		5'b11101: o_wb_sel <= 4'b0010;
		5'b11110: o_wb_sel <= 4'b0100;
		5'b11111: o_wb_sel <= 4'b1000;
		//
		default: o_wb_sel <= 4'b1111;
		endcase
		r_op <= { i_op[2:1] , i_addr[1:0] };
	end else if ((OPT_LOWPOWER)&&(!o_wb_cyc_gbl)&&(!o_wb_cyc_lcl))
	begin
		o_wb_we   <= 1'b0;
		o_wb_addr <= 0;
		o_wb_data <= 32'h0;
		o_wb_sel  <= 4'h0;
	end
	// }}}

	// o_valid
	// {{{
	initial	o_valid = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_valid <= 1'b0;
	else
		o_valid <= (((o_wb_cyc_gbl)||(o_wb_cyc_lcl))
				&&(i_wb_ack)&&(!o_wb_we));
	// }}}

	// o_err
	// {{{
	initial	o_err = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_err <= 1'b0;
	else if ((r_wb_cyc_gbl)||(r_wb_cyc_lcl))
		o_err <= i_wb_err;
	else if ((i_stb)&&(!o_busy))
		o_err <= misaligned;
	else
		o_err <= 1'b0;
	// }}}

	assign	o_busy = (r_wb_cyc_gbl)||(r_wb_cyc_lcl);

	// o_rdbusy
	// {{{
	initial	o_rdbusy = 1'b0;
	always @(posedge i_clk)
	if (i_reset|| ((o_wb_cyc_gbl || o_wb_cyc_lcl)&&(i_wb_err || i_wb_ack)))
		o_rdbusy <= 1'b0;
	else if (i_stb && !i_op[0] && !misaligned)
		o_rdbusy <= 1'b1;
	else if (o_valid)
		o_rdbusy <= 1'b0;
	// }}}

	always @(posedge i_clk)
	if (i_stb)
		o_wreg    <= i_oreg;

	// o_result
	// {{{
	always @(posedge i_clk)
	if ((OPT_LOWPOWER)&&(!i_wb_ack))
		o_result <= 32'h0;
	else begin
		casez({ OPT_LITTLE_ENDIAN, r_op })
		5'b?01??: o_result <= i_wb_data;
		//
		// Big endian
		5'b0100?: o_result <= { 16'h00, i_wb_data[31:16] };
		5'b0101?: o_result <= { 16'h00, i_wb_data[15: 0] };
		5'b01100: o_result <= { 24'h00, i_wb_data[31:24] };
		5'b01101: o_result <= { 24'h00, i_wb_data[23:16] };
		5'b01110: o_result <= { 24'h00, i_wb_data[15: 8] };
		5'b01111: o_result <= { 24'h00, i_wb_data[ 7: 0] };
		//
		// Little endian : Same bus result, just grab a different bits
		//   from the bus return to send back to the CPU.
		5'b1100?: o_result <= { 16'h00, i_wb_data[15: 0] };
		5'b1101?: o_result <= { 16'h00, i_wb_data[31:16] };
		5'b11100: o_result <= { 24'h00, i_wb_data[ 7: 0] };
		5'b11101: o_result <= { 24'h00, i_wb_data[15: 8] };
		5'b11110: o_result <= { 24'h00, i_wb_data[23:16] };
		5'b11111: o_result <= { 24'h00, i_wb_data[31:24] };
		default: o_result <= i_wb_data;
		endcase
	end
	// }}}

	// lock_gbl and lock_lcl
	// {{{
	generate
	if (OPT_LOCK)
	begin
		// {{{
		reg	r_lock_gbl, r_lock_lcl;

		initial	r_lock_gbl = 1'b0;
		initial	r_lock_lcl = 1'b0;

		always @(posedge i_clk)
		if (i_reset)
		begin
			r_lock_gbl <= 1'b0;
			r_lock_lcl <= 1'b0;
		end else if (((i_wb_err)&&((r_wb_cyc_gbl)||(r_wb_cyc_lcl)))
				||(misaligned))
		begin
			// Kill the lock if
			//	there's a bus error, or
			//	User requests a misaligned memory op
			r_lock_gbl <= 1'b0;
			r_lock_lcl <= 1'b0;
		end else begin
			// Kill the lock if
			//	i_lock goes down
			//	User starts on the global bus, then switches
			//	  to local or vice versa
			r_lock_gbl <= (i_lock)&&((r_wb_cyc_gbl)||(lock_gbl))
					&&(!lcl_stb);
			r_lock_lcl <= (i_lock)&&((r_wb_cyc_lcl)||(lock_lcl))
					&&(!gbl_stb);
		end

		assign	lock_gbl = r_lock_gbl;
		assign	lock_lcl = r_lock_lcl;

		assign	o_wb_cyc_gbl = (r_wb_cyc_gbl)||(lock_gbl);
		assign	o_wb_cyc_lcl = (r_wb_cyc_lcl)||(lock_lcl);
		// }}}
	end else begin : NO_LOCK
		// {{{
		assign	o_wb_cyc_gbl = (r_wb_cyc_gbl);
		assign	o_wb_cyc_lcl = (r_wb_cyc_lcl);

		assign	{ lock_gbl, lock_lcl } = 2'b00;

		// Make verilator happy
		// verilator lint_off UNUSED
		wire	[2:0]	lock_unused;
		assign	lock_unused = { i_lock, lock_gbl, lock_lcl };
		// verilator lint_on  UNUSED
		// }}}
	end endgenerate
	// }}}

`ifdef	VERILATOR
	always @(posedge i_clk)
	if ((r_wb_cyc_gbl)||(r_wb_cyc_lcl))
		assert(!i_stb);
`endif


	// Make verilator happy
	// {{{
	// verilator lint_off UNUSED
	generate if (AW < 22)
	begin : TOO_MANY_ADDRESS_BITS

		wire	[(21-AW):0] unused_addr;
		assign	unused_addr = i_addr[23:(AW+2)];

	end endgenerate
	// verilator lint_on  UNUSED
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
// Formal properties for this module are maintained elsewhere
`endif
// }}}
endmodule
