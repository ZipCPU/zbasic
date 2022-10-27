////////////////////////////////////////////////////////////////////////////////
//
// Filename:	pipemem.v
// {{{
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	A memory unit to support a CPU, this time one supporting
//		pipelined wishbone memory accesses.  The goal is to be able
//	to issue one pipelined wishbone access per clock, and (given the memory
//	is fast enough) to be able to read the results back at one access per
//	clock.  This renders on-chip memory fast enough to handle single cycle
//	(pipelined) access.
//
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
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
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
module	pipemem #(
		// {{{
		parameter	ADDRESS_WIDTH=28,
		parameter	BUS_WIDTH=32,
		parameter [0:0]	OPT_LOCK=1'b1,
				WITH_LOCAL_BUS=1'b1,
				OPT_ZERO_ON_IDLE=1'b0,
				// OPT_ALIGNMENT_ERR
				OPT_ALIGNMENT_ERR=1'b0,
		localparam	AW=ADDRESS_WIDTH,
				FLN=4,
		parameter [(FLN-1):0]	OPT_MAXDEPTH=4'hd
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset,
		// CPU interface
		// {{{
		input	wire		i_pipe_stb, i_lock,
		input	wire	[2:0]	i_op,
		input	wire	[31:0]	i_addr,
		input	wire	[31:0]	i_data,
		input	wire	[4:0]	i_oreg,
		// CPU outputs
		output	wire		o_busy, o_rdbusy,
		output	wire		o_pipe_stalled,
		output	reg		o_valid,
		output	reg		o_err,
		output	reg	[4:0]	o_wreg,
		output	reg	[31:0]	o_result,
		// }}}
		// Wishbone outputs
		// {{{
		output	wire			o_wb_cyc_gbl,
		output	wire			o_wb_cyc_lcl,
		output	reg			o_wb_stb_gbl,
		output	reg			o_wb_stb_lcl, o_wb_we,
		output	reg	[(AW-1):0]	o_wb_addr,
		output	reg	[BUS_WIDTH-1:0]	o_wb_data,
		output	reg [BUS_WIDTH/8-1:0]	o_wb_sel,
		// Wishbone inputs
		input	wire			i_wb_stall, i_wb_ack, i_wb_err,
		input	wire	[BUS_WIDTH-1:0]	i_wb_data
		// }}}
		// }}}
	);

	// Declarations
	// {{{
	localparam	WBLSB = $clog2(BUS_WIDTH/8);
	// Verilator lint_off UNUSED
	localparam	F_LGDEPTH=FLN+1;
	// Verilator lint_on  UNUSED

	reg				cyc, r_wb_cyc_gbl, r_wb_cyc_lcl,
					fifo_full;
	wire				gbl_stb, lcl_stb, lcl_bus;
	reg	[(FLN-1):0]		rdaddr, wraddr;
	wire	[(FLN-1):0]		nxt_rdaddr, fifo_fill;
	reg	[4+2+WBLSB-1:0]	fifo_mem [0:15];
	reg					fifo_gie;
	wire	[4+2+WBLSB-1:0]	w_wreg;
	wire					misaligned;

	reg	[BUS_WIDTH/8-1:0]	oword_sel;
	wire	[BUS_WIDTH/8-1:0]	pre_wb_sel;
	reg	[31:0]			oword_data;
	wire	[BUS_WIDTH-1:0]		pre_wb_data, pre_result;
	// }}}

	// misaligned
	// {{{
	generate if (OPT_ALIGNMENT_ERR)
	begin : GEN_ALIGNMENT_ERR
		reg	r_mis;

		always	@(*)
		casez({ i_op[2:1], i_addr[1:0] })
		4'b01?1: r_mis = i_pipe_stb;
		4'b0110: r_mis = i_pipe_stb;
		4'b10?1: r_mis = i_pipe_stb;
		default: r_mis = i_pipe_stb;
		endcase

		assign	misaligned = r_mis;

	end else begin : NO_MISALIGNMENT_ERRS

		assign	misaligned = 1'b0;

	end endgenerate
	// }}}

	// fifo_mem
	// {{{
	always @(posedge i_clk)
		fifo_mem[wraddr] <= { i_oreg[3:0], i_op[2:1], i_addr[WBLSB-1:0] };
	// }}}

	// fifo_gie
	// {{{
	always @(posedge i_clk)
	if (i_pipe_stb)
		fifo_gie <= i_oreg[4];
	// }}}

	// wraddr
	// {{{
	initial	wraddr = 0;
	always @(posedge i_clk)
	if (i_reset)
		wraddr <= 0;
	else if (((i_wb_err)&&(cyc))||((i_pipe_stb)&&(misaligned)))
			wraddr <= 0;
	else if (i_pipe_stb)
		wraddr <= wraddr + 1'b1;
	// }}}

	// rdaddr
	// {{{
	initial	rdaddr = 0;
	always @(posedge i_clk)
	if (i_reset)
		rdaddr <= 0;
	else if (((i_wb_err)&&(cyc))||((i_pipe_stb)&&(misaligned)))
		rdaddr <= 0;
	else if ((i_wb_ack)&&(cyc))
		rdaddr <= rdaddr + 1'b1;
	// }}}

	assign	fifo_fill = wraddr - rdaddr;

	// fifo_full
	// {{{
	initial	fifo_full = 0;
	always @(posedge i_clk)
	if (i_reset || !cyc)
		fifo_full <= 0;
	else if (((i_wb_err)&&(cyc))||((i_pipe_stb)&&(misaligned)))
		fifo_full <= 0;
	else case({ i_pipe_stb, i_wb_ack })
	2'b10: fifo_full <= (fifo_fill >= OPT_MAXDEPTH-1);
	2'b01: fifo_full <= 1'b0;
	default: begin end
	endcase
	// }}}

	assign	nxt_rdaddr = rdaddr + 1'b1;

	// lcl_bus, lcl_stb, gbl_stb
	// {{{
	assign	lcl_bus = (i_addr[31:24]==8'hff)&&(WITH_LOCAL_BUS);
	assign	lcl_stb = (lcl_bus)&&(!misaligned);
	assign	gbl_stb = ((!lcl_bus)||(!WITH_LOCAL_BUS))&&(!misaligned);
			//= ((i_addr[31:8]!=24'hc00000)||(i_addr[7:5]!=3'h0));
	// }}}

	// cyc, [or]_wb_[cyc|stb]_[lcl|gbl]
	// {{{
	initial	cyc = 0;
	initial	r_wb_cyc_lcl = 0;
	initial	r_wb_cyc_gbl = 0;
	initial	o_wb_stb_lcl = 0;
	initial	o_wb_stb_gbl = 0;
	always @(posedge i_clk)
	begin
		if (cyc)
		begin
			if (((!i_wb_stall)&&(!i_pipe_stb)&&(!misaligned))
				||(i_wb_err))
			begin
				o_wb_stb_gbl <= 1'b0;
				o_wb_stb_lcl <= 1'b0;
			end

			if (((i_wb_ack)&&(nxt_rdaddr == wraddr)
					&&((!i_pipe_stb)||(misaligned)))
				||(i_wb_err))
			begin
				r_wb_cyc_gbl <= 1'b0;
				r_wb_cyc_lcl <= 1'b0;
				o_wb_stb_gbl <= 1'b0;
				o_wb_stb_lcl <= 1'b0;
				cyc <= 1'b0;
			end
		end else if (i_pipe_stb) // New memory operation
		begin // Grab the wishbone
			r_wb_cyc_lcl <= lcl_stb;
			r_wb_cyc_gbl <= gbl_stb;
			o_wb_stb_lcl <= lcl_stb;
			o_wb_stb_gbl <= gbl_stb;
			cyc <= (!misaligned);
		end

		if (i_reset)
		begin
			r_wb_cyc_gbl <= 1'b0;
			r_wb_cyc_lcl <= 1'b0;
			o_wb_stb_gbl <= 1'b0;
			o_wb_stb_lcl <= 1'b0;
			cyc <= 1'b0;
		end

		if (!WITH_LOCAL_BUS)
		begin
			r_wb_cyc_lcl <= 1'b0;
			o_wb_stb_lcl <= 1'b0;
		end
	end
	// }}}

	// pre_wb_sel
	// {{{
	always @(*)
	begin
		oword_sel = 0;
		casez({ i_op[2:1], i_addr[1:0] })
		4'b100?: oword_sel[3:0] = 4'b1100;	// Op = 5
		4'b101?: oword_sel[3:0] = 4'b0011;	// Op = 5
		4'b1100: oword_sel[3:0] = 4'b1000;	// Op = 5
		4'b1101: oword_sel[3:0] = 4'b0100;	// Op = 7
		4'b1110: oword_sel[3:0] = 4'b0010;	// Op = 7
		4'b1111: oword_sel[3:0] = 4'b0001;	// Op = 7
		default: oword_sel[3:0] = 4'b1111;	// Op = 7
		endcase
	end

	generate if (BUS_WIDTH == 32)
	begin : GEN_SEL32

		assign	pre_wb_sel = oword_sel;

	end else begin : GEN_WIDESEL32

		// If we were little endian, we'd do ...
		// assign	pre_wb_sel = (oword_sel << (4* i_addr[WBLSB-1:2]));
		assign	pre_wb_sel = {oword_sel[3:0], {(BUS_WIDTH/8-4){1'b0}} }
				>> (4* i_addr[WBLSB-1:2]);

	end endgenerate
	// }}}

	// pre_wb_data
	// {{{

	always @(*)
	casez({ i_op[2:1], i_addr[1:0] })
	4'b100?: oword_data = { i_data[15:0], 16'h00 };
	4'b101?: oword_data = { 16'h00, i_data[15:0] };
	4'b1100: oword_data = {         i_data[7:0], 24'h00 };
	4'b1101: oword_data = {  8'h00, i_data[7:0], 16'h00 };
	4'b1110: oword_data = { 16'h00, i_data[7:0],  8'h00 };
	4'b1111: oword_data = { 24'h00, i_data[7:0] };
	default: oword_data = i_data;
	endcase

	generate if (BUS_WIDTH == 32)
	begin : GEN_DATA32

		assign	pre_wb_data = oword_data;

	end else begin : GEN_WIDEDATA32

		// If we were little endian, we'd do ...
		// assign	pre_wb_sel = (word_sel << (4* i_addr[WBLSB-1:2]));
		assign	pre_wb_data = {oword_data, {(BUS_WIDTH-32){1'b0}} }
				>> (32* i_addr[WBLSB-1:2]);

	end endgenerate
	// }}}

	// o_wb_addr, o_wb_sel, and o_wb_data
	// {{{
	always @(posedge i_clk)
	if ((!cyc)||(!i_wb_stall))
	begin
		// o_wb_add
		// {{{
		if ((OPT_ZERO_ON_IDLE)&&(!i_pipe_stb))
			o_wb_addr <= 0;
		else if (lcl_bus)
			o_wb_addr <= i_addr[2 +: AW];
		else
			o_wb_addr <= i_addr[WBLSB +: AW];
		// }}}

		// o_wb_sel
		// {{{
		if ((OPT_ZERO_ON_IDLE)&&(!i_pipe_stb))
			o_wb_sel <= {(BUS_WIDTH/8){1'b0}};
		else if (lcl_bus)
			o_wb_sel <= oword_sel;
		else
			o_wb_sel <= pre_wb_sel;
		// }}}

		// o_wb_data
		// {{{
		o_wb_data <= 0;
		if ((OPT_ZERO_ON_IDLE)&&(!i_pipe_stb))
			o_wb_data <= 0;
		else if (lcl_bus)
			o_wb_data[31:0] <= oword_data;
		else
			o_wb_data <= pre_wb_data;
		// }}}
	end
	// }}}

	// o_wb_we
	// {{{
	always @(posedge i_clk)
	if ((i_pipe_stb)&&(!cyc))
		o_wb_we   <= i_op[0];
	else if ((OPT_ZERO_ON_IDLE)&&(!cyc))
		o_wb_we   <= 1'b0;
	// }}}

	// o_valid
	// {{{
	initial	o_valid = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_valid <= 1'b0;
	else
		o_valid <= (cyc)&&(i_wb_ack)&&(!o_wb_we);
	// }}}

	// o_err
	// {{{
	initial	o_err = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_err <= 1'b0;
	else
		o_err <= ((cyc)&&(i_wb_err))||((i_pipe_stb)&&(misaligned));
	// }}}

	assign	o_busy = cyc;
	assign	o_rdbusy = o_busy && !o_wb_we;

	assign	w_wreg = fifo_mem[rdaddr];

	// o_wreg
	// {{{
	always @(posedge i_clk)
		o_wreg <= { fifo_gie, w_wreg[2 + WBLSB +: 4] };
	// }}}

	// o_result
	// {{{
	generate if (BUS_WIDTH == 32)
	begin : COPY_IDATA

		assign	pre_result = i_wb_data;

	end else begin : GEN_PRERESULT

		assign	pre_result = i_wb_data << (8*w_wreg[WBLSB-1:0]);
		// Verilator coverage_off
		// Verilator lint_off UNUSED
		wire	unused_preresult;
		assign	unused_preresult = &{1'b0, pre_result[BUS_WIDTH-33:0] };
		// Verilator lint_on  UNUSED
		// Verilator coverage_on
	end endgenerate

	always @(posedge i_clk)
	if ((OPT_ZERO_ON_IDLE)&&((!cyc)||((!i_wb_ack)&&(!i_wb_err))))
		o_result <= 0;
	else if ((o_wb_cyc_lcl && WITH_LOCAL_BUS) || (BUS_WIDTH == 32))
	begin
		casez({ w_wreg[WBLSB +: 2], w_wreg[1:0] })
		4'b1100: o_result <= { 24'h00, i_wb_data[31:24] };
		4'b1101: o_result <= { 24'h00, i_wb_data[23:16] };
		4'b1110: o_result <= { 24'h00, i_wb_data[15: 8] };
		4'b1111: o_result <= { 24'h00, i_wb_data[ 7: 0] };
		4'b100?: o_result <= { 16'h00, i_wb_data[31:16] };
		4'b101?: o_result <= { 16'h00, i_wb_data[15: 0] };
		default: o_result <= i_wb_data[31:0];
		endcase
	end else begin
		casez(w_wreg[WBLSB +: 2])
		2'b11: o_result <= { 24'h00, pre_result[BUS_WIDTH-1:BUS_WIDTH-8] };
		2'b10: o_result <= { 16'h00, pre_result[BUS_WIDTH-1:BUS_WIDTH-16] };
		default: o_result <= pre_result[BUS_WIDTH-1:BUS_WIDTH-32];
		endcase
	end
	// }}}

	// o_pipe_stalled
	// {{{
	assign	o_pipe_stalled = ((cyc)&&(fifo_full))||((cyc)
			&&((i_wb_stall)||((!o_wb_stb_lcl)&&(!o_wb_stb_gbl))));
	// }}}

	// lock_gbl, lock_lcl
	// {{{
	generate
	if (OPT_LOCK)
	begin : LOCK_REGISTER
		// {{{
		reg	lock_gbl, lock_lcl;

		initial	lock_gbl = 1'b0;
		initial	lock_lcl = 1'b0;
		always @(posedge i_clk)
		begin
			lock_gbl <= r_wb_cyc_gbl || lock_gbl;
			lock_lcl <= r_wb_cyc_lcl || lock_lcl;

			if (i_reset || (i_wb_err && cyc)
				|| (i_pipe_stb && misaligned)
				|| !i_lock)
			begin
				lock_gbl <= 1'b0;
				lock_lcl <= 1'b0;
			end

			if (!WITH_LOCAL_BUS)
				lock_lcl <= 1'b0;
		end

		assign	o_wb_cyc_gbl = (r_wb_cyc_gbl)||(lock_gbl);
		assign	o_wb_cyc_lcl = (r_wb_cyc_lcl)||(lock_lcl);
		// }}}
	end else begin : NO_LOCK
		// {{{
		assign	o_wb_cyc_gbl = (r_wb_cyc_gbl);
		assign	o_wb_cyc_lcl = (r_wb_cyc_lcl);

		// Verilator coverage_off
		// verilator lint_off UNUSED
		wire	unused_lock;
		assign	unused_lock = &{ 1'b0, i_lock };
		// verilator lint_on  UNUSED
		// Verilator coverage_on
		// }}}
	end endgenerate
	// }}}

	// Make verilator happy
	// {{{
	// Verilator coverage_off
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = { 1'b0 };
	// verilator lint_on  UNUSED
	// Verilator coverage_on
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal property section
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif // FORMAL
// }}}
endmodule
