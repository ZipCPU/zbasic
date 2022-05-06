////////////////////////////////////////////////////////////////////////////////
//
// Filename:	axiops.v
// {{{
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	A memory unit to support a CPU based upon AXI4.  This is about
//		the simplest AXI4 interface I can design for this purpose.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2020-2022, Gisselquist Technology, LLC
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
//
`default_nettype	none
// }}}
module	axiops #(
		// {{{
		parameter	C_AXI_ADDR_WIDTH = 32,
		parameter	C_AXI_DATA_WIDTH = 32,
		parameter	C_AXI_ID_WIDTH = 1,
		parameter [((C_AXI_ID_WIDTH > 0)? C_AXI_ID_WIDTH:1)-1:0]
					AXI_ID = 0,
		//
		// SWAP_ENDIANNESS
		// {{{
		// The ZipCPU was designed to be a big endian machine.  With
		// no other adjustments, this design will make the ZipCPU
		// *little* endian, for the simple reason that the AXI bus is
		// a little endian bus.  However, if SWAP_ENDIANNESS is set,
		// the bytes within 32-bit words on the AXI bus will be swapped.
		// This will return the CPU to being a big endian CPU on a
		// little endian bus.  It will also break any design that
		// assumes the bus is presented to it in its proper order.
		// Simple things like counters or interrupt controllers will
		// therefore cease to work with this option unless they also
		// swap the endianness of the words they are given.
		parameter [0:0]	SWAP_ENDIANNESS = 1'b0,
		// }}}
		// SWAP_WSTRB
		// {{{
		// SWAP_WSTRB represents a second attempt to fix the endianness
		// issue.  It is incompatible with the SWAP_ENDIANNESS option
		// above.  If SWAP_WSTRB is set, then half words and words will
		// be placed on the bus in little endian order, but at big
		// endian addresses.  Words written to the bus will be written
		// in little endian order.  Halfwords written to the bus at
		// address 2 will be written to address 0, halfwords written to
		// address 0 will be written to address 2.  Bytes written to the
		// but at address 3 will be written to address 0, address 2
		// will be written to address 1, address 1 to address 2, and
		// address 3 to address 0.
		//
		// This may just be a half baked attempt to solve this problem,
		// since it will fail if you ever trie to access bytes or
		// halfwords at other than their intended widths.
		parameter [0:0]	SWAP_WSTRB = 1'b0,
		// }}}
		// OPT_SIGN_EXTEND
		// {{{
		// Some CPU's want memory accesses to be sign extended upon
		// return.  The ZipCPU is not one of those CPU's.  However,
		// since it's fairly easy to do so, we'll implement this logic
		// if ever OPT_SIGN_EXTEND is true so you can see how it would
		// be done if necessary.
		parameter [0:0]	OPT_SIGN_EXTEND = 1'b0,
		// }}}
		parameter [0:0]		OPT_LOCK=1'b1,
		// OPT_ALIGNMENT_ERR
		// {{{
		// If set, OPT_ALIGNMENT_ERR will generate an alignment error
		// on any attempt to write to or read from an unaligned word.
		// If not set, unaligned reads (or writes) will be expanded into
		// pairs so as to still accomplish the action requested.  The
		// bus does not guarantee protection, however, that these two
		// writes or two reads will proceed uninterrupted.  Since
		// unaligned writes and unaligned reads are no longer
		// guaranteed to be atomic by the AXI bus, it is possible that
		// any unaligned operations might yield an incoherent result.
		parameter [0:0]		OPT_ALIGNMENT_ERR = 1'b0,
		// }}}
		// OPT_LOWPOWER
		// {{{
		// If set, the design will use extra logic to guarantee that any
		// unused registers are kept at zero until they are used.  This
		// will help to guarantee the design (ideally) has fewer
		// transitions and therefore uses lower power.
		parameter [0:0]		OPT_LOWPOWER = 1'b1,
		// }}}
		parameter [3:0]	OPT_QOS = 0,
		localparam	IW = (C_AXI_ID_WIDTH > 0) ? C_AXI_ID_WIDTH:1,
		localparam	AW = C_AXI_ADDR_WIDTH,
		localparam	DW = C_AXI_DATA_WIDTH,
		localparam	AXILSB = $clog2(C_AXI_DATA_WIDTH/8)
		// }}}
	) (
		// {{{
		input	wire				S_AXI_ACLK,
		input	wire				S_AXI_ARESETN,
		input	wire				i_cpu_reset,
		//
		// CPU interface
		// {{{
		input	wire				i_stb,
		input	wire				i_lock,
		input	wire	[2:0]			i_op,
		input	wire	[AW-1:0]		i_addr,
		input	wire	[AW-1:0]		i_restart_pc,
		input	wire	[31:0]			i_data,
		input	wire	[4:0]			i_oreg,
		output	reg				o_busy,
		output	reg				o_rdbusy,
		output	reg				o_valid,
		output	reg				o_err,
		output	reg	[4:0]			o_wreg,
		output	reg	[31:0]			o_result,
		// }}}
		// AXI4 bus interface
		//
		// Writes
		// {{{
		output	reg				M_AXI_AWVALID,
		input	wire				M_AXI_AWREADY,
		output	wire	[IW-1:0]		M_AXI_AWID,
		output	reg	[AW-1:0]		M_AXI_AWADDR,
		output	wire	[7:0]			M_AXI_AWLEN,
		output	wire	[2:0]			M_AXI_AWSIZE,
		output	wire	[1:0]			M_AXI_AWBURST,
		output	wire				M_AXI_AWLOCK,
		output	wire	[3:0]			M_AXI_AWCACHE,
		output	wire	[2:0]			M_AXI_AWPROT,
		output	wire	[3:0]			M_AXI_AWQOS,
		//
		output	reg				M_AXI_WVALID,
		input	wire				M_AXI_WREADY,
		output	reg	[DW-1:0]		M_AXI_WDATA,
		output	reg	[DW/8-1:0]		M_AXI_WSTRB,
		output	wire				M_AXI_WLAST,
		//
		input	wire				M_AXI_BVALID,
		output	reg				M_AXI_BREADY,
		input	wire	[IW-1:0]		M_AXI_BID,
		input	wire	[1:0]			M_AXI_BRESP,
		// }}}
		// Reads
		// {{{
		output	reg				M_AXI_ARVALID,
		input	wire				M_AXI_ARREADY,
		output	wire	[IW-1:0]		M_AXI_ARID,
		output	reg	[AW-1:0]		M_AXI_ARADDR,
		output	wire	[7:0]			M_AXI_ARLEN,
		output	wire	[2:0]			M_AXI_ARSIZE,
		output	wire	[1:0]			M_AXI_ARBURST,
		output	wire				M_AXI_ARLOCK,
		output	wire	[3:0]			M_AXI_ARCACHE,
		output	wire	[2:0]			M_AXI_ARPROT,
		output	wire	[3:0]			M_AXI_ARQOS,
		//
		input	wire				M_AXI_RVALID,
		output	reg				M_AXI_RREADY,
		input	wire	[IW-1:0]		M_AXI_RID,
		input	wire	[DW-1:0]		M_AXI_RDATA,
		input	wire				M_AXI_RLAST,
		input	wire	[1:0]			M_AXI_RRESP
		// }}}
		// }}}
	);

	// Declarations
	// {{{
	localparam		CPU_DATA_WIDTH = 32;
	// Verilator lint_off WIDTH
	localparam	[2:0]	DSZ = $clog2(CPU_DATA_WIDTH/8);
	// Verilator lint_on  WIDTH
	localparam	[1:0]	AXI_INCR = 2'b01,
				OKAY   = 2'b00,
				EXOKAY = 2'b01;

	wire	i_clk = S_AXI_ACLK;
	// wire	i_reset = !S_AXI_ARESETN;

	reg	w_misaligned, w_misalignment_err;
	wire	misaligned_request, misaligned_aw_request,
		misaligned_response_pending, pending_err, misaligned_read;
	reg	r_flushing;
	reg	[AW-1:0]		r_pc;
	reg	[AXILSB+1:0]		r_op;
	reg	[DW-1:0]		next_wdata;
	reg	[DW/8-1:0]		next_wstrb;
	reg	[31:0]			last_result;
	// reg	[31:0]			endian_swapped_wdata;
	// reg	[31:0]			endian_swapped_result;
	reg	[2*DW/8-1:0]		shifted_wstrb_word,
					shifted_wstrb_halfword,
					shifted_wstrb_byte;
	reg	[2*DW/8-1:0]		swapped_wstrb_word,
					swapped_wstrb_halfword,
					swapped_wstrb_byte;
	reg	[DW-1:0]		axi_wdata;
	reg	[DW/8-1:0]		axi_wstrb;
	reg				axlock;
	reg	[AXILSB-1:0]		swapaddr;
	wire	[DW-1:0]		endian_swapped_rdata;
	reg	[2*DW-1:0]		pre_result;

	// }}}

	// xVALID, and xREADY
	// {{{
	initial	M_AXI_AWVALID = 1'b0;
	initial	M_AXI_WVALID = 1'b0;
	initial	M_AXI_ARVALID = 1'b0;
	initial	M_AXI_BREADY = 1'b0;
	initial	M_AXI_RREADY = 1'b0;
	always @(posedge i_clk)
	if (!S_AXI_ARESETN)
	begin
		// {{{
		M_AXI_AWVALID <= 1'b0;
		M_AXI_WVALID  <= 1'b0;
		M_AXI_ARVALID <= 1'b0;
		M_AXI_BREADY  <= 1'b0;
		M_AXI_RREADY  <= 1'b0;
		// }}}
	end else if (M_AXI_BREADY || M_AXI_RREADY)
	begin // Something is outstanding
		// {{{
		if (M_AXI_AWREADY)
			M_AXI_AWVALID <= M_AXI_AWVALID && misaligned_aw_request;
		if (M_AXI_WREADY)
			M_AXI_WVALID  <= M_AXI_WVALID && misaligned_request;
		if (M_AXI_ARREADY)
			M_AXI_ARVALID <= M_AXI_ARVALID && misaligned_request;

		if ((M_AXI_BVALID || M_AXI_RVALID) && !misaligned_response_pending)
		begin
			M_AXI_BREADY <= 1'b0;
			M_AXI_RREADY <= 1'b0;
		end
		// }}}
	end else begin // New memory operation
		// {{{
		// Initiate a request
		M_AXI_AWVALID <=  i_op[0];	// Write request
		M_AXI_WVALID  <=  i_op[0];	// Write request
		M_AXI_ARVALID <= !i_op[0];	// Read request

		// Set BREADY or RREADY to accept the response.  These will
		// remain ready until the response is returned.
		M_AXI_BREADY  <=  i_op[0];
		M_AXI_RREADY  <= !i_op[0];

		if (i_cpu_reset || o_err || !i_stb || w_misalignment_err)
		begin
			M_AXI_AWVALID <= 0;
			M_AXI_WVALID  <= 0;
			M_AXI_ARVALID <= 0;

			M_AXI_BREADY <= 0;
			M_AXI_RREADY <= 0;
		end
		// }}}
	end
	// }}}

	// axlock
	// {{{
	initial	axlock = 1'b0;
	always @(posedge i_clk)
	if (!OPT_LOCK || (!S_AXI_ARESETN && OPT_LOWPOWER))
	begin
		// {{{
		axlock <= 1'b0;
		// }}}
	end else if (M_AXI_BREADY || M_AXI_RREADY)
	begin // Something is outstanding
		// {{{
		if (OPT_LOWPOWER && (M_AXI_BVALID || M_AXI_RVALID))
			axlock <= axlock && i_lock && M_AXI_RVALID;
		// }}}
	end else begin // New memory operation
		// {{{
		// Initiate a request
		if (!OPT_LOWPOWER)
			axlock <= i_lock;
		else begin
			if (i_stb)
				axlock <= i_lock;

			if (i_cpu_reset || o_err || w_misaligned)
				axlock <= 1'b0;
		end
		// }}}
	end

	assign	M_AXI_AWLOCK = axlock;
	assign	M_AXI_ARLOCK = axlock;
	// }}}

	// r_flushing
	// {{{
	initial	r_flushing = 1'b0;
	always @(posedge i_clk)
	if (!S_AXI_ARESETN)
		// If everything is reset, then we don't need to worry about
		// or wait for any pending returns--they'll be canceled by the
		// global reset.
		r_flushing <= 1'b0;
	else if (M_AXI_BREADY || M_AXI_RREADY)
	begin
		if (i_cpu_reset)
			// If only the CPU is reset, however, we have a problem.
			// The bus hasn't been reset, and so it is still active.
			// We can't respond to any new requests from the CPU
			// until we flush any transactions that are currently
			// active.
			r_flushing <= 1'b1;
		if (M_AXI_BVALID || M_AXI_RVALID)
			// A request just came back, therefore we can clear
			// r_flushing
			r_flushing <= 1'b0;
		if (misaligned_response_pending)
			// ... unless we're in the middle of a misaligned
			// request.  In that case, there will be a second
			// return that we still need to wait for.  This request,
			// though, will clear misaligned_response_pending.
			r_flushing <= r_flushing || i_cpu_reset;
	end else
		// If nothing is active, we don't care about the CPU reset.
		// Flushing just stays at zero.
		r_flushing <= 1'b0;
	// }}}

	// M_AXI_AxADDR
	// {{{
	initial	M_AXI_AWADDR = 0;
	always @(posedge i_clk)
	if (!S_AXI_ARESETN && OPT_LOWPOWER)
		M_AXI_AWADDR <= 0;
	else if (!M_AXI_BREADY && !M_AXI_RREADY)
	begin // Initial address
		// {{{
		M_AXI_AWADDR <= i_addr;

		if (OPT_LOWPOWER && (i_cpu_reset || o_err || !i_stb || w_misalignment_err))
			M_AXI_AWADDR <= 0;

		if (SWAP_ENDIANNESS || SWAP_WSTRB)
			// When adjusting endianness, reads (or writes) are
			// always full words.  This is important since the
			// the bytes at issues may (or may not) be in their
			// expected locations
			M_AXI_AWADDR[AXILSB-1:0] <= 0;
		// }}}
	end else if ((M_AXI_AWVALID && M_AXI_AWREADY)
			||(M_AXI_ARVALID && M_AXI_ARREADY))
	begin // Subsequent addresses
		// {{{
		M_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:AXILSB]
			<= M_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:AXILSB] + 1;

		M_AXI_AWADDR[AXILSB-1:0] <= 0;

		if (OPT_LOWPOWER && ((M_AXI_RREADY && !misaligned_request)
			|| (M_AXI_BREADY && !misaligned_aw_request)))
			M_AXI_AWADDR <= 0;
		// }}}
	end

	always @(*)
		M_AXI_ARADDR = M_AXI_AWADDR;
	// }}}

	// M_AXI_AxSIZE
	// {{{
	reg	[2:0]	axsize;

	initial	axsize = DSZ;
	always @(posedge i_clk)
	if (!S_AXI_ARESETN)
		axsize <= DSZ;
	else if (!M_AXI_BREADY && !M_AXI_RREADY && (!OPT_LOWPOWER || i_stb))
	begin
		casez(i_op[2:1])
		2'b0?: begin
			axsize <= 3'b010;	// Word
			if ((|i_addr[1:0]) && !w_misaligned)
				axsize <= AXILSB[2:0];
			end
		2'b10: begin
			axsize <= 3'b001;	// Half-word
			if (i_addr[0] && !w_misaligned)
				axsize <= AXILSB[2:0];
			end
		2'b11: axsize <= 3'b000;	// Byte
		endcase

		if (SWAP_WSTRB)
			axsize <= DSZ;
	end

	assign	M_AXI_AWSIZE = axsize;
	assign	M_AXI_ARSIZE = axsize;
	// }}}

	// AxOTHER
	// {{{
	localparam [3:0]	AXI_NON_CACHABLE_BUFFERABLE = 4'h3;
	localparam [3:0]	OPT_CACHE = AXI_NON_CACHABLE_BUFFERABLE;
	localparam [2:0]	AXI_UNPRIVILEGED_NONSECURE_DATA_ACCESS = 3'h0;
	localparam [2:0]	OPT_PROT=AXI_UNPRIVILEGED_NONSECURE_DATA_ACCESS;

	assign	M_AXI_AWID    = AXI_ID;
	assign	M_AXI_AWLEN   = 0;
	assign	M_AXI_AWBURST = AXI_INCR;
	assign	M_AXI_AWCACHE = M_AXI_AWLOCK ? 0: OPT_CACHE;
	assign	M_AXI_AWPROT  = OPT_PROT;
	assign	M_AXI_AWQOS   = OPT_QOS;
	assign	M_AXI_WLAST   = 1;

	assign	M_AXI_ARID    = AXI_ID;
	assign	M_AXI_ARLEN   = 0;
	assign	M_AXI_ARBURST = AXI_INCR;
	assign	M_AXI_ARCACHE = M_AXI_ARLOCK ? 0: OPT_CACHE;
	assign	M_AXI_ARPROT  = OPT_PROT;
	assign	M_AXI_ARQOS   = OPT_QOS;
	// }}}

	// shifted_wstrb_*
	// {{{
	generate if (SWAP_WSTRB)
	begin : BIG_ENDIAN_WSTRB
		always @(*)
			shifted_wstrb_word = { 4'b1111, {(2*DW/8-4){1'b0}} }
						>> i_addr[AXILSB-1:0];

		always @(*)
			shifted_wstrb_halfword = { 2'b11, {(2*DW/8-2){1'b0}} }
						>> i_addr[AXILSB-1:0];

		always @(*)
			shifted_wstrb_byte = { 1'b1, {(2*DW/8-1){1'b0}} }
						>> i_addr[AXILSB-1:0];
	end else begin : NORMAL_SHIFTED_WSTRB
		always @(*)
		shifted_wstrb_word = { {(2*DW/8-4){1'b0}},
						4'b1111} << i_addr[AXILSB-1:0];

		always @(*)
		shifted_wstrb_halfword = { {(2*DW/8-4){1'b0}},
						4'b0011} << i_addr[AXILSB-1:0];

		always @(*)
		shifted_wstrb_byte = { {(2*DW/8-4){1'b0}},
						4'b0001} << i_addr[AXILSB-1:0];
	end endgenerate
	// }}}

	// Swapping WSTRB bits
	// {{{
	generate if (SWAP_ENDIANNESS)
	begin : SWAPPING_ENDIANNESS
		// {{{
		genvar	gw, gb;

		for(gw=0; gw<2*DW/32; gw=gw+1)
		begin : FOREACH_32B_WORD
		for(gb=0; gb<32/8; gb=gb+1)
		begin : FOREACH_BYTE

		always @(*)
		begin
			swapped_wstrb_word[gw*4+gb]
					= shifted_wstrb_word[gw*4+(3-gb)];
			swapped_wstrb_halfword[gw*4+gb]
					= shifted_wstrb_halfword[gw*4+(3-gb)];
			swapped_wstrb_byte[gw*4+gb]
					= shifted_wstrb_byte[gw*4+(3-gb)];
		end end end
		// }}}
	end else begin : KEEP_WSTRB
		// {{{

		always @(*)
			swapped_wstrb_word = shifted_wstrb_word;

		always @(*)
			swapped_wstrb_halfword = shifted_wstrb_halfword;

		always @(*)
			swapped_wstrb_byte = shifted_wstrb_byte;
		// }}}
	end endgenerate
	// }}}

	// wdata, wstrb
	// {{{
	always @(*)
		swapaddr = i_addr[AXILSB-1:0];

	initial	axi_wdata = 0;
	initial	axi_wstrb = 0;
	initial	next_wdata  = 0;
	initial	next_wstrb  = 0;
	always @(posedge i_clk)
	if (OPT_LOWPOWER && !S_AXI_ARESETN)
	begin
		// {{{
		axi_wdata <= 0;
		axi_wstrb <= 0;

		next_wdata  <= 0;
		next_wstrb  <= 0;

		r_op <= 0;
		// }}}
	end else if (i_stb)
	begin
		// {{{
		if (SWAP_WSTRB)
		begin
			casez(i_op[2:1])
			2'b10: { axi_wdata, next_wdata }
				<= { i_data[15:0], {(2*C_AXI_DATA_WIDTH-16){1'b0}} }
					>> (8*swapaddr);
			2'b11: { axi_wdata, next_wdata }
				<= { i_data[7:0], {(2*C_AXI_DATA_WIDTH-8){1'b0}} }
					>> (8*swapaddr);
			default: { axi_wdata, next_wdata }
				<= { i_data, {(2*C_AXI_DATA_WIDTH-32){1'b0}} }
					>> (8*swapaddr);
			endcase
		end else begin
			casez(i_op[2:1])
			2'b10: { next_wdata, axi_wdata }
				<= { {(2*C_AXI_DATA_WIDTH-16){1'b0}},
				i_data[15:0] } << (8*swapaddr);
			2'b11: { next_wdata, axi_wdata }
				<= { {(2*C_AXI_DATA_WIDTH-8){1'b0}},
				i_data[7:0] } << (8*swapaddr);
			default: { next_wdata, axi_wdata }
				<= { {(2*C_AXI_DATA_WIDTH-32){1'b0}},
				i_data } << (8*swapaddr);
			endcase
		end

		// next_wstrb, axi_wstrb
		// {{{
		if (SWAP_WSTRB)
		begin
			casez(i_op[2:1])
			2'b0?: { axi_wstrb, next_wstrb } <= swapped_wstrb_word;
			2'b10: { axi_wstrb, next_wstrb } <= swapped_wstrb_halfword;
			2'b11: { axi_wstrb, next_wstrb } <= swapped_wstrb_byte;
			endcase
		end else begin
			casez(i_op[2:1])
			2'b0?: { next_wstrb, axi_wstrb } <= swapped_wstrb_word;
			2'b10: { next_wstrb, axi_wstrb } <= swapped_wstrb_halfword;
			2'b11: { next_wstrb, axi_wstrb } <= swapped_wstrb_byte;
			endcase
		end
		// }}}

		r_op <= { i_op[2:1] , i_addr[AXILSB-1:0] };

		// On a read set everything to zero but only if OPT_LOWPOWER
		// is set
		// {{{
		if (OPT_LOWPOWER && !i_op[0])
			{ next_wstrb, next_wdata, axi_wstrb, axi_wdata } <= 0;

		if (w_misalignment_err)
			{ next_wstrb, next_wdata } <= 0;
		if (OPT_LOWPOWER)
		begin
			if (w_misalignment_err)
				{ axi_wdata, axi_wstrb, r_op } <= 0;
			if (o_err || i_cpu_reset)
				{ next_wdata, next_wstrb,
					axi_wdata, axi_wstrb, r_op } <= 0;
		end
		// }}}
		// }}}
	end else if ((misaligned_request || !OPT_LOWPOWER) && M_AXI_WREADY)
	begin
		// {{{
		axi_wdata <= next_wdata;
		axi_wstrb <= next_wstrb;
		if (OPT_LOWPOWER)
			{ next_wdata, next_wstrb } <= 0;
		// }}}
	end else if (OPT_LOWPOWER && M_AXI_WREADY)
	begin
		// {{{
		axi_wdata <= 0;
		axi_wstrb <= 0;
		// }}}
	end
	// }}}

	// M_AXI_WDATA, M_AXI_WSTRB
	// {{{
	generate if (SWAP_ENDIANNESS)
	begin : SWAP_WRITE_DATA_STRB
		// {{{
		genvar	gw, gb;

		for(gw=0; gw<C_AXI_DATA_WIDTH/32; gw=gw+1)
		for(gb=0; gb<32/8; gb=gb+1)
		always @(*)
		begin
			M_AXI_WDATA[32*gw + 8*gb +: 8] = axi_wdata[32*gw+8*(3-gb) +: 8];
			M_AXI_WSTRB[4*gw + gb] = axi_wstrb[4*gw+(3-gb)];
		end
		// }}}
	end else begin : KEEP_WRITE_DATA_STRB
		// {{{
		always @(*)
			{ M_AXI_WSTRB, M_AXI_WDATA } = { axi_wstrb, axi_wdata };
		// }}}
	end endgenerate
	// }}}

	// w_misaligned
	// {{{
	always @(*)
	casez(i_op[2:1])
	// Full word
	2'b0?: w_misaligned = ((i_addr[AXILSB-1:0]+3) >= (1<<AXILSB));
	// Half word
	2'b10: w_misaligned = ((i_addr[AXILSB-1:0]+1) >= (1<<AXILSB));
	// Bytes are always aligned
	2'b11: w_misaligned = 1'b0;
	endcase
	// }}}

	// w_misalignment_err
	// {{{
	always @(*)
	begin
		w_misalignment_err = OPT_ALIGNMENT_ERR && w_misaligned;
		if (OPT_LOCK && i_lock)
		begin
			casez(i_op[2:1])
			2'b0?: w_misalignment_err = (|i_addr[1:0]);
			2'b10: w_misalignment_err = i_addr[0];
			default:
				w_misalignment_err = 1'b0;
			endcase
		end
	end
	// }}}

	// misaligned_[aw_|]request, pending_err, misaligned_response_pending
	// {{{
	generate if (OPT_ALIGNMENT_ERR)
	begin
		// {{{
		assign	misaligned_request = 1'b0;

		assign	misaligned_aw_request = 1'b0;
		assign	misaligned_response_pending = 1'b0;
		assign	misaligned_read = 1'b0;
		assign	pending_err = 1'b0;
		// }}}
	end else begin
		// {{{
		reg	r_misaligned_request, r_misaligned_aw_request,
			r_misaligned_response_pending, r_misaligned_read,
			r_pending_err;

		// misaligned_request
		// {{{
		initial	r_misaligned_request = 0;
		always @(posedge i_clk)
		if (!S_AXI_ARESETN)
			r_misaligned_request <= 0;
		else if (i_stb && !o_err && !i_cpu_reset)
			r_misaligned_request <= w_misaligned
						&& !w_misalignment_err;
		else if ((M_AXI_WVALID && M_AXI_WREADY)
					|| (M_AXI_ARVALID && M_AXI_ARREADY))
			r_misaligned_request <= 1'b0;

		assign	misaligned_request = r_misaligned_request;
		// }}}

		// misaligned_aw_request
		// {{{
		initial	r_misaligned_aw_request = 0;
		always @(posedge i_clk)
		if (!S_AXI_ARESETN)
			r_misaligned_aw_request <= 0;
		else if (i_stb && !o_err && !i_cpu_reset)
			r_misaligned_aw_request <= w_misaligned && i_op[0]
					&& !w_misalignment_err;
		else if (M_AXI_AWREADY)
			r_misaligned_aw_request <= 1'b0;

		assign	misaligned_aw_request = r_misaligned_aw_request;
		// }}}

		// misaligned_response_pending
		// {{{
		initial	r_misaligned_response_pending = 0;
		always @(posedge i_clk)
		if (!S_AXI_ARESETN)
			r_misaligned_response_pending <= 0;
		else if (i_stb && !o_err && !i_cpu_reset)
			r_misaligned_response_pending <= w_misaligned
						&& !w_misalignment_err;
		else if (M_AXI_BVALID || M_AXI_RVALID)
			r_misaligned_response_pending <= 1'b0;

		assign	misaligned_response_pending
					= r_misaligned_response_pending;
		// }}}

		// misaligned_read
		// {{{
		initial	r_misaligned_read = 0;
		always @(posedge i_clk)
		if (!S_AXI_ARESETN)
			r_misaligned_read <= 0;
		else if (i_stb && !o_err && !i_cpu_reset)
			r_misaligned_read <= w_misaligned && !i_op[0]
						&& !w_misalignment_err;
		else if (M_AXI_RVALID)
			r_misaligned_read <= (misaligned_response_pending);

		assign	misaligned_read = r_misaligned_read;
		// }}}

		// pending_err
		// {{{
		initial	r_pending_err = 1'b0;
		always @(posedge i_clk)
		if (i_cpu_reset || (!M_AXI_BREADY && !M_AXI_RREADY)
				|| r_flushing)
			r_pending_err <= 1'b0;
		else if ((M_AXI_BVALID && M_AXI_BRESP[1])
				|| (M_AXI_RVALID && M_AXI_RRESP[1]))
			r_pending_err <= 1'b1;

		assign	pending_err = r_pending_err;
		// }}}

		// }}}
	end endgenerate
	// }}}

	// o_valid
	// {{{
	initial	o_valid = 1'b0;
	always @(posedge i_clk)
	if (i_cpu_reset || r_flushing)
		o_valid <= 1'b0;
	else if (axlock)
		o_valid <= (M_AXI_RVALID && M_AXI_RRESP == EXOKAY)
				|| (M_AXI_BVALID && M_AXI_BRESP == OKAY);
	else
		o_valid <= M_AXI_RVALID && !M_AXI_RRESP[1] && !pending_err
				&& !misaligned_response_pending;
	// }}}

	// o_err
	// {{{
	initial	o_err = 1'b0;
	always @(posedge i_clk)
	if (r_flushing || i_cpu_reset || o_err)
		o_err <= 1'b0;
	else if (i_stb && w_misalignment_err)
		o_err <= 1'b1;
	else if (axlock)
	begin
		o_err <= (M_AXI_BVALID && M_AXI_BRESP[1])
			 || (M_AXI_RVALID && M_AXI_RRESP != EXOKAY);
	end else if ((M_AXI_BVALID || M_AXI_RVALID)
						&& !misaligned_response_pending)
		o_err <= (M_AXI_BVALID && M_AXI_BRESP[1])
			|| (M_AXI_RVALID && M_AXI_RRESP[1])
			|| pending_err;
	else
		o_err <= 1'b0;
	// }}}

	// o_busy, o_rdbusy
	// {{{
	always @(*)
	begin
		o_busy   = M_AXI_BREADY || M_AXI_RREADY;
		o_rdbusy = (M_AXI_BREADY && axlock) || M_AXI_RREADY;
		if (r_flushing)
			o_rdbusy = 1'b0;
	end
	// }}}

	// o_wreg
	// {{{
	always @(posedge i_clk)
	if (i_stb)
	begin
		o_wreg    <= i_oreg;
		if (OPT_LOCK && i_stb && i_lock && i_op[0])
			o_wreg[3:0] <= 4'hf;
	end
	// }}}

	// r_pc
	// {{{
	always @(posedge S_AXI_ACLK)
	if (!OPT_LOCK)
		r_pc <= 0;
	else if (i_stb && i_lock && !i_op[0])
		r_pc <= i_restart_pc;
	// }}}

	// endian_swapped_rdata
	// {{{
	generate if (SWAP_ENDIANNESS)
	begin : SWAP_RDATA_ENDIANNESS
		genvar	gw, gb;

		for(gw=0; gw<C_AXI_DATA_WIDTH/32; gw=gw+1)
		for(gb=0; gb<32/8; gb=gb+1)
			assign	endian_swapped_rdata[gw*32+gb*8 +: 8]
					= M_AXI_RDATA[gw*32+(3-gb)*8 +: 8];
	end else begin : KEEP_RDATA
		assign	endian_swapped_rdata = M_AXI_RDATA;
	end endgenerate
	// }}}

	// pre_result
	// {{{
	// The purpose of the pre-result is to guarantee that the synthesis
	// tool knows we want a shift of the full 2*DW width.
	always @(*)
	begin
		if (SWAP_WSTRB)
		begin
			if (misaligned_read && !OPT_ALIGNMENT_ERR)
				pre_result={ last_result, endian_swapped_rdata }
						<< (8*r_op[AXILSB-1:0]);
			else
				pre_result = { endian_swapped_rdata, {(DW){1'b0}} }
						<< (8*r_op[AXILSB-1:0]);

			casez(r_op[AXILSB +: 2])
			2'b10: pre_result = { 16'h0,
					pre_result[(2*DW)-1:(2*DW)-16],
					{(DW){1'b0}} };
			2'b11: pre_result = { 24'h0,
					pre_result[(2*DW)-1:(2*DW)-8],
					{(DW){1'b0}} };
			default: begin end
			endcase

			pre_result[31:0] = pre_result[(2*DW-1):(2*DW-32)];

		end else begin
			if (misaligned_read && !OPT_ALIGNMENT_ERR)
				pre_result={ endian_swapped_rdata, last_result }
						>> (8*r_op[AXILSB-1:0]);
			else
				pre_result = { {(DW){1'b0}}, endian_swapped_rdata }
						>> (8*r_op[AXILSB-1:0]);
		end

		if (OPT_LOWPOWER && (!M_AXI_RVALID || M_AXI_RRESP[1]))
			pre_result = 0;
	end

	// }}}
	// last_result, o_result
	// {{{
	always @(posedge i_clk)
	if (OPT_LOWPOWER &&((!M_AXI_RREADY && (!OPT_LOCK || !M_AXI_BREADY))
			|| !S_AXI_ARESETN || r_flushing || i_cpu_reset))
		{ last_result, o_result } <= 0;
	else begin
		// {{{
		if (OPT_LOCK && M_AXI_BVALID && (!OPT_LOWPOWER
					|| (axlock && M_AXI_BRESP == OKAY)))
		begin
			o_result <= 0;
			o_result[AW-1:0] <= r_pc;
		end

		if (M_AXI_RVALID)
		begin
			// {{{
			if (OPT_LOWPOWER && (M_AXI_RRESP[1] || !misaligned_response_pending))
				last_result <= 0;
			else
				last_result <= endian_swapped_rdata;

			if (OPT_ALIGNMENT_ERR)
				last_result <= 0;

			o_result <= pre_result[31:0];

			if (OPT_SIGN_EXTEND)
			begin
				// {{{
				// Optionally sign extend the return result.
				casez(r_op[AXILSB +: 2])
				2'b10: o_result[31:16] <= {(16){pre_result[15]}};
				2'b11: o_result[31: 8] <= {(24){pre_result[7]}};
				default: begin end
				endcase
				// }}}
			end else begin
				// Fill unused return bits with zeros
				casez(r_op[AXILSB +: 2])
				2'b10: o_result[31:16] <= 0;
				2'b11: o_result[31: 8] <= 0;
				default: begin end
				endcase
			end

			if (OPT_LOWPOWER && (M_AXI_RRESP[1] || pending_err
					|| misaligned_response_pending
					|| (axlock && !M_AXI_RRESP[0])))
				o_result <= 0;
			// }}}
		end
		// }}}
	end
	// }}}

	// Make verilator happy
	// {{{
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, M_AXI_BID, M_AXI_RID, M_AXI_RLAST,
			pre_result[2*C_AXI_DATA_WIDTH-1:32] };
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
// Formal properties for this core are maintained elsewhere
`endif
// }}}
endmodule
