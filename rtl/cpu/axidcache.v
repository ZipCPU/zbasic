////////////////////////////////////////////////////////////////////////////////
//
// Filename:	axidcache.v
// {{{
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	A data cache built using AXI as the underlying protocol
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2020-2021, Gisselquist Technology, LLC
// {{{
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
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype none
// }}}
module	axidcache #(
		// {{{
		// AXI Setup: address width, data width, ID width, and ID
		// {{{
		parameter	C_AXI_ADDR_WIDTH = 32,
		parameter	C_AXI_DATA_WIDTH = 64,
		parameter	C_AXI_ID_WIDTH = 1,
		parameter [C_AXI_ID_WIDTH-1:0]	AXI_ID = 0,
		// }}}
		// LGCACHELEN
		// {{{
		// The log (base 2) of the cache size in bytes.
		parameter	LGCACHELEN = 8 + $clog2(C_AXI_DATA_WIDTH/8),
		localparam LGCACHEWORDS= LGCACHELEN-$clog2(C_AXI_DATA_WIDTH/8),
		// }}}
		// LGNLINES
		// {{{
		// The log (base 2) of the number of cache lines.  A cache line
		// is the minimum amount of data read on a miss.  Each cache
		// line has a valid signal and a tag associated with it.
		parameter	LGNLINES = (LGCACHEWORDS-3),
		// }}}
		parameter	NAUX = 5,
		// Verilator lint_off UNUSED
		localparam	LGPIPE = 2,
		parameter [0:0]	OPT_PIPE = 1'b0,
		// Verilator lint_on  UNUSED
		parameter [0:0]	OPT_LOWPOWER = 1'b0,
		// Local parameters, mostly abbreviations
		// {{{
		// Verilator lint_off UNUSED
		localparam [0:0]	OPT_LOCK = 1'b0,
		// Verilator lint_on  UNUSED
		localparam [0:0]	OPT_DUAL_READ_PORT = 1'b1,
		localparam [1:0]	DC_IDLE  = 2'b00,
					DC_WRITE = 2'b01,
					DC_READS = 2'b10,
					DC_READC = 2'b11,
		localparam	AW = C_AXI_ADDR_WIDTH,
		localparam	DW = C_AXI_DATA_WIDTH,
		localparam	IW = C_AXI_ID_WIDTH,
		localparam	AXILSB = $clog2(C_AXI_DATA_WIDTH/8),
		localparam	CS = LGCACHELEN - AXILSB, // Cache size, in wrds
		localparam	LS = CS-LGNLINES,	// Cache lines, lg_2
		localparam	TW = AW-(CS+AXILSB)	// Tag width
		// }}}
		// }}}
	) (
		// {{{
		input	wire		S_AXI_ACLK, S_AXI_ARESETN,
		input	wire		i_cpu_reset, i_clear,
		// Interface from the CPU
		// {{{
		input	wire		i_pipe_stb, i_lock,
		input	wire	[2:0]	i_op,
		input	wire [AW-1:0]	i_addr,
		input	wire [31:0]	i_data,
		input	wire [NAUX-1:0]	i_oreg,
		// Outputs, going back to the CPU
		output	reg 		o_busy, o_rdbusy,
		output	reg 		o_pipe_stalled,
		output	reg 		o_valid, o_err,
		output	reg [NAUX-1:0]	o_wreg,
		output	reg [31:0]	o_data,
		// }}}
		// AXI bus interface
		// {{{
		// Write address
		// {{{
		output	wire		M_AXI_AWVALID,
		input	wire		M_AXI_AWREADY,
		output	wire [IW-1:0]	M_AXI_AWID,
		output	wire [AW-1:0]	M_AXI_AWADDR,
		output	wire [7:0]	M_AXI_AWLEN,
		output	wire [2:0]	M_AXI_AWSIZE,
		output	wire [1:0]	M_AXI_AWBURST,
		output	wire 		M_AXI_AWLOCK,
		output	wire [3:0]	M_AXI_AWCACHE,
		output	wire [2:0]	M_AXI_AWPROT,
		output	wire [3:0]	M_AXI_AWQOS,
		// }}}
		// Write data
		// {{{
		output	wire		M_AXI_WVALID,
		input	wire		M_AXI_WREADY,
		output	wire [DW-1:0]	M_AXI_WDATA,
		output	wire [DW/8-1:0]	M_AXI_WSTRB,
		output	wire 		M_AXI_WLAST,
		// }}}
		// Write return
		// {{{
		input	wire		M_AXI_BVALID,
		output	wire		M_AXI_BREADY,
		input	wire [IW-1:0]	M_AXI_BID,
		input	wire	[1:0]	M_AXI_BRESP,
		// }}}
		// Read address
		// {{{
		output	wire		M_AXI_ARVALID,
		input	wire		M_AXI_ARREADY,
		output	wire [IW-1:0]	M_AXI_ARID,
		output	wire [AW-1:0]	M_AXI_ARADDR,
		output	wire [7:0]	M_AXI_ARLEN,
		output	wire [2:0]	M_AXI_ARSIZE,
		output	wire [1:0]	M_AXI_ARBURST,
		output	wire 		M_AXI_ARLOCK,
		output	wire [3:0]	M_AXI_ARCACHE,
		output	wire [2:0]	M_AXI_ARPROT,
		output	wire [3:0]	M_AXI_ARQOS,
		// }}}
		// Read data returned
		// {{{
		input	wire		M_AXI_RVALID,
		output	wire		M_AXI_RREADY,
		input	wire [IW-1:0]	M_AXI_RID,
		input	wire [DW-1:0]	M_AXI_RDATA,
		input	wire		M_AXI_RLAST,
		input	wire	[1:0]	M_AXI_RRESP
		// }}}
		// }}}
		// }}}
	);

	// Declarations
	// {{{

	// The cache itself
	// {{{
	reg	[(1<<(CS-LS))-1:0]	cache_valid;
	reg	[TW-1:0]	cache_tag	[0:(1<<LGNLINES)-1];
	reg	[DW-1:0]	cache_mem	[0:(1<<CS)-1];
	reg	[DW-1:0]	cached_iword, cached_rword;
	// }}}

	reg			misaligned;

	wire			cache_miss_inow, address_is_cachable;

	reg	[AW-AXILSB-1:0]	r_addr;
	wire	[CS-LS-1:0]	i_cline, r_cline;
	wire	[CS-1:0]	i_caddr, r_caddr;
	reg	[TW-1:0]	last_tag, r_itag, r_rtag, w_tag;
	reg	[CS-LS-1:0]	last_tag_line;
	wire	[TW-1:0]	r_ctag, i_ctag;

	reg			r_iv, r_rv, r_check, w_v;
	reg			zero_noutstanding, last_ack;
	reg	[1:0]		noutstanding;
	reg	[CS-1:0]	wcache_addr;
	reg	[DW-1:0]	wcache_data;
	reg	[DW/8-1:0]	wcache_strb;
	reg	[TW-1:0]	wcache_tag;
	integer			ik;

	reg			set_vflag, good_cache_read;
	reg	[1:0]		state;

	reg			r_dvalid, r_svalid, r_cachable,
				r_cache_miss, flushing, r_rd_pending,
				last_tag_valid, w_cache_miss;
	reg	[DW-1:0]	pre_data, shifted_data;
	reg	[AXILSB+1:0]	req_data;

	reg			axi_awvalid, axi_wvalid;
	reg	[AW-1:0]	axi_awaddr;
	reg	[DW-1:0]	axi_wdata;
	reg	[DW/8-1:0]	axi_wstrb;

	reg			axi_arvalid;
	reg	[AW-1:0]	axi_araddr;
	reg	[7:0]		axi_arlen;
	reg	[2:0]		axi_arsize;
	// }}}

	// Fixed AXI outputs that aren't changing
	// {{{
	assign	M_AXI_AWID = AXI_ID;
	assign	M_AXI_ARID = AXI_ID;
	assign	M_AXI_AWLEN = 0;	// All writes are one beat only
	assign	M_AXI_AWSIZE = 2;	// Write thru cache: All writes are 32-b

	assign	M_AXI_AWBURST = 2'b01;	// INCR addressing only
	assign	M_AXI_ARBURST = 2'b01;

	assign	M_AXI_AWLOCK = 1'b0;	// No lock support (yet)
	assign	M_AXI_ARLOCK = 1'b0;

	assign	M_AXI_AWCACHE = 4'b011;
	assign	M_AXI_ARCACHE = 4'b011;

	assign	M_AXI_AWPROT = 3'b0;	// == 3'b001 if GIE is clear, 3'b000 if
	assign	M_AXI_ARPROT = 3'b0;	// not

	assign	M_AXI_AWQOS = 0;
	assign	M_AXI_ARQOS = 0;

	assign	M_AXI_WLAST = 1;

	assign	M_AXI_BREADY = 1;
	assign	M_AXI_RREADY = 1;
	// }}}

	// Misalignment detection
	// {{{
	always @(*)
	begin
		misaligned = checklsb(i_op[2:1], i_addr[AXILSB-1:0]);
		/*
		mislsb = { 1'b0, i_addr[AXILSB-1:0] };
		case(i_op[2:1])
		2'b10:		mislsb = mislsb + 1;
		2'b11:		mislsb = mislsb + 0;
		default:	mislsb = mislsb + 3;
		endcase

		misaligned = mislsb[AXILSB];
		*/
	end

	function checklsb;
		input [1:0]	 op;
		input [AXILSB-1:0] addr;

		reg [AXILSB:0]	mislsbfn;

		mislsbfn = { 1'b0, addr };
		case(op[1:0])
		2'b10:		mislsbfn = mislsbfn + 1;
		2'b11:		mislsbfn = mislsbfn + 0;
		default:	mislsbfn = mislsbfn + 3;
		endcase

		checklsb = mislsbfn[AXILSB];
	endfunction
	// }}}
	
	// Address decoding
	//  {{{
	assign	i_cline = i_addr[LS+AXILSB +: (CS-LS)];	// Cache line
	assign	i_caddr = i_addr[AXILSB +: CS];		// Cache address
	assign	i_ctag  = i_addr[AW-1:CS+AXILSB];	// Associated tag

	// Unlike i_addr, r_addr doesn't include the AXI LSB's
	assign	r_cline = r_addr[CS-1:LS];	// Cache line
	assign	r_caddr = r_addr[CS-1:0];	// Cache address
	assign	r_ctag  = r_addr[AW-AXILSB-1 : CS];	// Associated tag

	assign	cache_miss_inow = (!last_tag_valid
			|| last_tag != i_ctag
			|| last_tag_line != i_cline);
	// }}}

	// Cache lookup
	// {{{
	always @(posedge S_AXI_ACLK)
		r_check <= i_pipe_stb;

	always @(posedge S_AXI_ACLK)
	if (i_pipe_stb)
		r_itag  <= cache_tag[i_cline];

	always @(posedge S_AXI_ACLK)
	if (o_pipe_stalled)
		r_rtag  <= cache_tag[r_cline];

	always @(posedge S_AXI_ACLK)
	if (i_pipe_stb)
		r_iv  <= cache_valid[i_cline];

	always @(posedge S_AXI_ACLK)
		r_rv  <= cache_valid[r_cline] && r_rd_pending;

	always @(*)
		w_v = (r_check) ? r_iv : r_rv;

	always @(*)
		w_tag = (r_check) ? r_itag : r_rtag;

	// Cachability checking
	iscachable chkaddress(i_addr[AW-1:2], address_is_cachable);

	initial	r_rd_pending = 0;
	initial	r_cache_miss = 0;
	initial	last_tag_valid = 0;
	initial	r_dvalid = 0;
	always @(posedge S_AXI_ACLK)
	begin
		r_svalid <= (i_pipe_stb && !i_op[0] && address_is_cachable
			&& !misaligned
			&& !cache_miss_inow && (wcache_strb == 0));

		if (!o_pipe_stalled)
			r_addr <= i_addr[AW-1:AXILSB];

		if (!o_pipe_stalled && !r_rd_pending)
		begin
			r_cachable <= (!i_op[0] && address_is_cachable && i_pipe_stb);
			r_rd_pending <= (i_pipe_stb && !i_op[0]
					&& address_is_cachable
					&& !misaligned
					&& (cache_miss_inow || (|wcache_strb)));
		end else if (r_rd_pending)
		begin
			r_rd_pending <= (w_tag != r_ctag || !w_v);
		end

		if (M_AXI_RVALID && M_AXI_RRESP[1])
			r_rd_pending <= 1'b0;

		// r_rd <= (i_pipe_stb && !i_op[0]);

		r_dvalid <= !r_svalid && !r_dvalid
				&& (w_tag == r_ctag) && w_v
				&& r_cachable && r_rd_pending;

		if (w_tag == r_ctag && w_v && r_cachable && r_rd_pending)
		begin
			last_tag_valid <= 1'b1;
			last_tag_line <= r_cline;
			last_tag      <= r_ctag;
		end else if (state == DC_READC)
			//	&& (last_tag == r_ctag)
			//	&& (M_AXI_RVALID))
			last_tag_valid <= 1'b0;

		r_cache_miss <= (r_cachable && !r_svalid
				&& (r_rd_pending && !r_svalid)
				&& (w_tag != r_ctag || !w_v));

		if (i_clear)
			last_tag_valid <= 0;

		if (!S_AXI_ARESETN || i_cpu_reset)
		begin
			r_cachable <= 1'b0;
			r_svalid <= 1'b0;
			r_dvalid <= 1'b0;
			r_cache_miss <= 1'b0;
			r_rd_pending <= 0;
			last_tag_valid <= 0;
		end
	end
	// }}}

	// Transaction counting
	// {{{
	initial	noutstanding = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		noutstanding <= 0;
	else case( { ((M_AXI_AWVALID && M_AXI_AWREADY)
					||(M_AXI_ARVALID && M_AXI_ARREADY)),
			((M_AXI_RVALID && M_AXI_RLAST) || M_AXI_BVALID)
			})
	2'b10: noutstanding <= noutstanding + 1;
	2'b01: noutstanding <= noutstanding - 1;
	default: begin end
	endcase

	always @(*)
		zero_noutstanding = (noutstanding == 0);
	always @(*)
		last_ack = (noutstanding <= 1)&&(!M_AXI_ARVALID && !M_AXI_AWVALID);

	initial	flushing = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		flushing <= 0;
	else if (i_cpu_reset && (!last_ack || M_AXI_ARVALID || M_AXI_AWVALID))
		flushing <= 1;
	else if (M_AXI_RVALID)
		flushing <= (i_cpu_reset || flushing || M_AXI_RRESP[1]) && (!M_AXI_RLAST || !last_ack);
	else if (M_AXI_BVALID)
		flushing <= (i_cpu_reset || flushing || M_AXI_BRESP[1]) && !last_ack;
	else if (!zero_noutstanding)
		flushing <= (i_cpu_reset || flushing);
	else if (zero_noutstanding && !M_AXI_ARVALID && !M_AXI_AWVALID)
		flushing <= 0;
	// }}}

	// Read handling
	// {{{
	// Read state machine
	// {{{
	initial	state = DC_IDLE;
	initial	set_vflag = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
	begin
		// {{{
		cache_valid <= 0;
		// end_of_line <= 1'b0;
		// last_line_stb <= 1'b0;
		state <= DC_IDLE;
		set_vflag <= 1'b0;
		// }}}
	end else begin
		// {{{
		set_vflag <= 1'b0;
		if (set_vflag)
			cache_valid[r_cline] <= 1'b1;

		case(state)
		DC_IDLE: begin
			// {{{
			good_cache_read <= 1'b1;
			if (i_pipe_stb && i_op[0] && !misaligned)
				state <= DC_WRITE;
			else if (w_cache_miss)
				state <= DC_READC;
			else if (i_pipe_stb && !i_op[0] && !address_is_cachable
					&& !misaligned)
				state <= DC_READS;

			if (i_cpu_reset)
				state <= DC_IDLE;
			end
			// }}}
		DC_READC: begin
			// {{{
			if (M_AXI_RVALID)
			begin
				good_cache_read
					<= good_cache_read && !M_AXI_RRESP[1];
				cache_valid[r_cline] <= 1'b0;
			end
			if (M_AXI_RVALID && M_AXI_RLAST)
			begin
				state <= DC_IDLE;
				set_vflag <= !i_cpu_reset && !i_clear && !flushing && !M_AXI_RRESP[1] && good_cache_read;
			end end
			// }}}
		DC_READS: begin
			// {{{
			if (M_AXI_RVALID && last_ack)
				state <= DC_IDLE;
			end
			// }}}
		DC_WRITE: begin
			// {{{
			if (M_AXI_BVALID && M_AXI_BREADY && last_ack)
				state <= DC_IDLE;
			end
			// }}}
		endcase

		if (i_clear || i_cpu_reset)
			cache_valid <= 0;
		// }}}
	end
	// }}}

	// M_AXI_ARVALID, axi_arvalid
	// {{{
	reg	[1:0]	suppress_miss;
	always @(posedge S_AXI_ACLK)
		suppress_miss <= { suppress_miss[0] || set_vflag, set_vflag };
	always @(*)
		w_cache_miss = r_cache_miss && state == DC_IDLE && !r_dvalid && !o_err && wcache_strb == 0 && !suppress_miss[1];

	initial	axi_arvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		axi_arvalid <= 0;
	else if (!M_AXI_ARVALID || M_AXI_ARREADY)
	begin
		axi_arvalid <= 1'b0;
		if (i_pipe_stb && !i_op[0] && !misaligned && !address_is_cachable)
			axi_arvalid <= 1;
		if (w_cache_miss)
			axi_arvalid <= 1;
		if (i_cpu_reset)
			axi_arvalid <= 0;
	end

	assign	M_AXI_ARVALID = axi_arvalid;
	// }}}

	// M_AXI_ARADDR, M_AXI_ARSIZE, M_AXI_ARLEN
	// {{{
	initial	axi_araddr = 0;
	initial	axi_arsize = 3'd2;
	initial	axi_arlen  = 0;
	always @(posedge S_AXI_ACLK)
	if (OPT_LOWPOWER && !S_AXI_ARESETN)
	begin
		// {{{
		axi_araddr <= 0;
		axi_arsize <= 3'd2;
		axi_arlen  <= 0;
		// }}}
	end else if (!M_AXI_ARVALID || M_AXI_ARREADY)
	begin
		axi_arlen  <= 0;
		if (r_cache_miss)
		begin
			// {{{
			axi_araddr <= { r_ctag, r_cline, {(LS+AXILSB){1'b0}} };
			axi_arlen  <= (1 << LS) - 1;
			axi_arsize <= AXILSB[2:0];
			// }}}
		end else begin
			// {{{
			axi_araddr <= i_addr;
			axi_arlen  <= 0;
			casez(i_op[2:1])
			2'b0?: axi_arsize <= 3'd2;
			2'b10: axi_arsize <= 3'd1;
			2'b11: axi_arsize <= 3'd0;
			default:  axi_arsize <= 3'd2;
			endcase
			// }}}
		end

		if (OPT_LOWPOWER && (!r_cache_miss
			&& (!i_pipe_stb || misaligned)))
		begin
			// {{{
			axi_araddr <= 0;
			axi_arsize <= 3'd2;
			// }}}
		end
	end

	assign	M_AXI_ARADDR = axi_araddr;
	assign	M_AXI_ARLEN  = axi_arlen;
	assign	M_AXI_ARSIZE = axi_arsize;
	// }}}
	// }}}

	// Writes always go straight to the bus
	// {{{

	// M_AXI_AWVALID, axi_awvalid
	// {{{
	initial	axi_awvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		axi_awvalid <= 1'b0;
	else if (!M_AXI_AWVALID || M_AXI_AWREADY)
	begin
		axi_awvalid <= i_pipe_stb && i_op[0] && !misaligned;
		if (M_AXI_BVALID && M_AXI_BRESP[1])
			axi_awvalid <= 1'b0;
		if (i_cpu_reset || flushing)
			axi_awvalid <= 1'b0;
	end

	assign	M_AXI_AWVALID = axi_awvalid;
	// }}}

	// M_AXI_AWADDR
	// {{{
	initial	axi_awaddr = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN && OPT_LOWPOWER)
	begin
		axi_awaddr <= 0;
	end else if (!M_AXI_AWVALID || M_AXI_AWREADY)
	begin
		axi_awaddr <= i_addr;

		if (!i_pipe_stb || !i_op[0] || misaligned)
			axi_awaddr <= 0;
	end

	assign	M_AXI_AWADDR = axi_awaddr;
	// }}}

	// M_AXI_WVALID
	// {{{
	initial	axi_wvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		axi_wvalid <= 0;
	else if (!M_AXI_WVALID || M_AXI_WREADY)
	begin
		axi_wvalid <= i_pipe_stb && i_op[0] && !misaligned;
		if (M_AXI_BVALID && M_AXI_BRESP[1])
			axi_wvalid <= 1'b0;
		if (i_cpu_reset || flushing)
			axi_wvalid <= 1'b0;
	end

	assign	M_AXI_WVALID = axi_wvalid;
	// }}}

	// M_AXI_WDATA, M_AXI_WSTRB
	// {{{
	initial	axi_wdata = 0;
	initial	axi_wstrb = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN && OPT_LOWPOWER)
	begin
		axi_wdata <= 0;
		axi_wstrb <= 0;
	end else if (!M_AXI_WVALID || M_AXI_WREADY)
	begin

		// WDATA
		// {{{
		casez(i_op[2:1])
		// Write a 16b half-word
		2'b10: axi_wdata <= { {(C_AXI_DATA_WIDTH-16){1'b0}},
				i_data[15:0] } << (8*i_addr[AXILSB-1:0]);
		// Write an 8b half-word
		2'b11: axi_wdata <= { {(C_AXI_DATA_WIDTH-8){1'b0}},
				i_data[7:0] } << (8*i_addr[AXILSB-1:0]);
		default: axi_wdata <= { {(C_AXI_DATA_WIDTH-32){1'b0}},
				i_data } << (8*i_addr[AXILSB-1:0]);
		endcase
		// }}}

		// WSTRB
		// {{{
		casez(i_op[2:1])
		// Write a 16b half-word
		2'b10: axi_wstrb <= { {(C_AXI_DATA_WIDTH/8-4){1'b0}},
				4'b0011 } << (i_addr[AXILSB-1:0]);
		// Write an 8b half-word
		2'b11: axi_wstrb <= { {(C_AXI_DATA_WIDTH/8-4){1'b0}},
				4'b0001 } << (i_addr[AXILSB-1:0]);
		default: axi_wstrb <= { {(C_AXI_DATA_WIDTH/8-4){1'b0}},
				4'b1111 } << (i_addr[AXILSB-1:0]);
		endcase
		// }}}

		// OPT_LOWPOWER: Clear if nothing is being used
		// {{{
		if (OPT_LOWPOWER && ((!i_pipe_stb || i_op[0] || misaligned)
			|| (M_AXI_BVALID && M_AXI_BRESP[1])
			|| (i_cpu_reset || flushing)))
		begin
			axi_wdata <= 0;
			axi_wstrb <= 0;
		end
		// }}}
	end

	assign	M_AXI_WDATA = axi_wdata;
	assign	M_AXI_WSTRB = axi_wstrb;
	// }}}
	// }}}

	// Writes take a clock to go to the cache
	// {{{
	reg	[CS-1:0]	read_addr;

	always @(posedge S_AXI_ACLK)
	begin
		wcache_strb <= 0;

		if (i_pipe_stb)
			read_addr <= { i_addr[LGCACHELEN-1:AXILSB+LS], {(LS){1'b0}} };
		if (state == DC_READC)
		begin
			// {{{
			// Write returning read data to the cache
			if (M_AXI_RVALID)
				read_addr[LS-1:0]
					<= read_addr[LS-1:0] + 1;
			read_addr[CS-1:LS] <= r_cline;
			wcache_addr <= read_addr;
			wcache_data <= M_AXI_RDATA;
			wcache_strb <= -1;
			if (!M_AXI_RVALID || flushing || i_cpu_reset
				|| M_AXI_RRESP[1])
				wcache_strb <= 0;
			wcache_tag  <= w_tag;
			// }}}
		end else begin
			// {{{
			wcache_data <= { {(DW-32){1'b0}}, i_data } << (8*i_addr[AXILSB-1:0]);
			if (i_pipe_stb)
				{ wcache_tag, wcache_addr } <= i_addr[AW-1:AXILSB];
			else
				wcache_addr[LS-1:0] <= 0;

			// wcache_data
			// {{{
			casez(i_op[2:1])
			// Write a 16b half-word
			2'b10: wcache_data <= { {(C_AXI_DATA_WIDTH-16){1'b0}},
					i_data[15:0] } << (8*i_addr[AXILSB-1:0]);
			// Write an 8b half-word
			2'b11: wcache_data <= { {(C_AXI_DATA_WIDTH-8){1'b0}},
					i_data[7:0] } << (8*i_addr[AXILSB-1:0]);
			default: wcache_data <= { {(C_AXI_DATA_WIDTH-32){1'b0}},
					i_data } << (8*i_addr[AXILSB-1:0]);
			endcase
			// }}}

			// wcache_strb
			// {{{
			casez(i_op[2:1])
			// Write a 16b half-word
			2'b10: wcache_strb<= { {(C_AXI_DATA_WIDTH/8-4){1'b0}},
					4'h3 } << (i_addr[AXILSB-1:0]);
			// Write an 8b byte
			2'b11: wcache_strb<= { {(C_AXI_DATA_WIDTH/8-4){1'b0}},
					4'h1 } << (i_addr[AXILSB-1:0]);
			default: wcache_strb<={{(C_AXI_DATA_WIDTH/8-4){1'b0}},
					4'hf } << (i_addr[AXILSB-1:0]);
			endcase
			// }}}

			if (!i_pipe_stb || !i_op[0] || misaligned)
				wcache_strb <= 0;
			// }}}
		end
	end
	// }}}

	// Actually write to the cache
	// {{{
	always @(posedge S_AXI_ACLK)
	if (state != DC_WRITE || (r_iv && wcache_tag == r_itag))
	begin
		for(ik=0; ik<DW/8; ik=ik+1)
		if (wcache_strb[ik])
			cache_mem[wcache_addr][8*ik +: 8] <= wcache_data[8*ik +: 8];
	end
	// }}}

	// Update the cache tag
	// {{{
	always @(posedge S_AXI_ACLK)
	if (!flushing && M_AXI_RVALID && state == DC_READC)
		cache_tag[r_cline] <= r_ctag;
	// }}}

	// o_busy
	// {{{
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		o_busy <= 1'b0;
	else if (flushing || (i_pipe_stb && !misaligned))
		o_busy <= 1'b1;
	else if (state  == DC_READS && M_AXI_RVALID && last_ack)
		o_busy <= 1'b0;
	// else if (state  == DC_READC && M_AXI_RVALID && M_AXI_RLAST)
	else if (r_dvalid || r_svalid)
		o_busy <= 1'b0;
	else if (M_AXI_BVALID && last_ack)
		o_busy <= 1'b0;
	// }}}

	// o_rdbusy
	// {{{
	initial	o_rdbusy = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		o_rdbusy <= 1'b0;
	else if (i_cpu_reset)
		o_rdbusy <= 1'b0;
	else if (i_pipe_stb && !i_op[0] && !misaligned)
		o_rdbusy <= 1'b1;
	else if (state == DC_READS && M_AXI_RVALID)
		o_rdbusy <= 1'b0;
	else if (state == DC_READC && M_AXI_RVALID && M_AXI_RRESP[1])
		o_rdbusy <= 1'b0;
	else if (r_svalid || r_dvalid)
		o_rdbusy <= 1'b0;
	// }}}

	// o_pipe_stalled
	// {{{
	always @(*)
	// if (!OPT_PIPE)
		o_pipe_stalled = o_busy;
	// else
	//	o_pipe_stalled = // more complex
	// }}}

	// o_wreg
	// {{{
	// generate if (!OPT_PIPE)
	always @(posedge S_AXI_ACLK)
	if (i_pipe_stb)
		o_wreg <= i_oreg;
	// }}}

	// req_data
	// {{{
	always @(posedge S_AXI_ACLK)
	if (i_pipe_stb)
		req_data <= { i_op[2:1], i_addr[AXILSB-1:0] };
	// }}}

	// o_err
	// {{{
	initial	o_err = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		o_err <= 1'b0;
	else if (i_cpu_reset || flushing)
		o_err <= 1'b0;
	else begin
		o_err <= 1'b0;
		if (M_AXI_RVALID && M_AXI_RRESP[1])
			o_err <= 1'b1;
		if (M_AXI_BVALID && M_AXI_BRESP[1])
			o_err <= 1'b1;
		if (i_pipe_stb && misaligned)
			o_err <= 1'b1;
	end
	// }}}

	// Read from the cache
	// {{{
	generate if (OPT_DUAL_READ_PORT)
	begin
		always @(posedge S_AXI_ACLK)
			cached_iword <= cache_mem[i_caddr];

		always @(posedge S_AXI_ACLK)
			cached_rword <= cache_mem[r_caddr];
	end else begin

		always @(posedge S_AXI_ACLK)
			cached_rword <= cache_mem[(o_busy) ? r_caddr : i_caddr];

		always @(*)
			cached_iword = cached_rword;
	end endgenerate
	// }}}

	// o_data, pre_data
	// {{{
	always @(*)
	if (r_svalid)
		pre_data = cached_iword;
	else if (state == DC_READS)
		pre_data = M_AXI_RDATA;
	else
		pre_data = cached_rword;

	always @(*)
		shifted_data = pre_data >> (8*req_data[AXILSB-1:0]);

	// o_data
	always @(posedge S_AXI_ACLK)
	begin
		o_data <= shifted_data[31:0];
		casez(req_data[AXILSB +: 2])
		2'b10: o_data[31:16] <= 0;
		2'b11: o_data[31: 8] <= 0;
		default: begin end
		endcase
	end
	// }}}

	// o_valid
	// {{{
	initial	o_valid = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (i_cpu_reset || flushing)
		o_valid <= 1'b0;
	else if (state == DC_READS)
		o_valid <= M_AXI_RVALID && !M_AXI_RRESP[1];
	else
		o_valid <= r_svalid || r_dvalid;
	// }}}

	// Make Verilator happy
	// {{{
	// Verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, M_AXI_BID, M_AXI_RID, r_addr, M_AXI_RRESP[0],
				M_AXI_BRESP[0], i_lock, OPT_PIPE,
				shifted_data };
	// Verilator lint_on UNUSED
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
