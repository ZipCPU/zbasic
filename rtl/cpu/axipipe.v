////////////////////////////////////////////////////////////////////////////////
//
// Filename:	axipipe.v
// {{{
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	A memory unit to support a CPU based upon AXI-lite.  Unlike the
//		axilops core, this one will permit multiple requests to be
//	outstanding at any given time.
//
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
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
// }}}
module	axipipe #(
		// {{{
		parameter	C_AXI_ADDR_WIDTH = 30,
		parameter	C_AXI_DATA_WIDTH = 32,
		parameter	C_AXI_ID_WIDTH = 1,
		parameter	[((C_AXI_ID_WIDTH>0)? C_AXI_ID_WIDTH:1)-1:0]
				AXI_ID = 0,
		localparam	AW = C_AXI_ADDR_WIDTH,
		localparam	DW = C_AXI_DATA_WIDTH,
		localparam	IW =(C_AXI_ID_WIDTH > 0) ? C_AXI_ID_WIDTH : 1,
		//
		// parameter [0:0]	SWAP_ENDIANNESS = 1'b0,
		parameter [0:0]	SWAP_WSTRB = 1'b0,
		parameter [0:0]	OPT_SIGN_EXTEND = 1'b0,
		// AXI locks are a challenge, and require support from the
		// CPU.  Specifically, we have to be able to unroll and re-do
		// the load instruction on any atomic access failure.  For that
		// reason, we'll ignore the lock request initially.
		parameter [0:0]	OPT_LOCK=1'b1,
		parameter [0:0]	OPT_ALIGNMENT_ERR = 1'b0,
		parameter [0:0]	OPT_LOWPOWER = 1'b1,
		parameter [3:0]	OPT_QOS = 0
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
		output	reg				o_pipe_stalled,
		output	reg				o_rdbusy,
		output	reg				o_valid,
		output	reg				o_err,
		output	reg	[4:0]			o_wreg,
		output	reg	[31:0]			o_result,
		// }}}
		//
		// AXI4 bus interface
		// {{{
		// Writes
		// {{{
		output	reg			M_AXI_AWVALID,
		input	wire			M_AXI_AWREADY,
		output	wire	[IW-1:0]	M_AXI_AWID,
		output	reg	[AW-1:0]	M_AXI_AWADDR,
		output	wire	[7:0]		M_AXI_AWLEN,
		output	wire	[2:0]		M_AXI_AWSIZE,
		output	wire	[1:0]		M_AXI_AWBURST,
		output	wire			M_AXI_AWLOCK,
		output	wire	[3:0]		M_AXI_AWCACHE,
		output	wire	[2:0]		M_AXI_AWPROT,
		output	wire	[3:0]		M_AXI_AWQOS,
		//
		output	reg			M_AXI_WVALID,
		input	wire			M_AXI_WREADY,
		output	reg	[DW-1:0]	M_AXI_WDATA,
		output	reg	[DW/8-1:0]	M_AXI_WSTRB,
		output	wire			M_AXI_WLAST,
		//
		input	wire			M_AXI_BVALID,
		input	wire	[IW-1:0]	M_AXI_BID,
		output	wire			M_AXI_BREADY,
		input	wire [1:0]		M_AXI_BRESP,
		// }}}
		// Reads
		// {{{
		output	reg			M_AXI_ARVALID,
		input	wire			M_AXI_ARREADY,
		output	wire	[IW-1:0]	M_AXI_ARID,
		output	reg	[AW-1:0]	M_AXI_ARADDR,
		output	wire	[7:0]		M_AXI_ARLEN,
		output	wire	[2:0]		M_AXI_ARSIZE,
		output	wire	[1:0]		M_AXI_ARBURST,
		output	wire			M_AXI_ARLOCK,
		output	wire	[3:0]		M_AXI_ARCACHE,
		output	wire	[2:0]		M_AXI_ARPROT,
		output	wire	[3:0]		M_AXI_ARQOS,
		//
		input	wire			M_AXI_RVALID,
		output	wire			M_AXI_RREADY,
		input	wire	[IW-1:0]	M_AXI_RID,
		input	wire	[DW-1:0]	M_AXI_RDATA,
		input	wire			M_AXI_RLAST,
		input	wire	[1:0]		M_AXI_RRESP
		// }}}
		// }}}
		// }}}
	);

	// Declarations
	// {{{
	localparam	AXILSB = $clog2(C_AXI_DATA_WIDTH/8);
	localparam [2:0] DSZ = AXILSB[2:0];
	localparam	LGPIPE = 4;
	localparam	FIFO_WIDTH = AXILSB+1+2+4 + 1;
	localparam	[1:0]	AXI_INCR = 2'b01,
				OKAY = 2'b00,
				EXOKAY = 2'b01;
			//	SLVERR
			//	DECERR

	wire	i_clk = S_AXI_ACLK;

	reg	w_misaligned;
	wire	misaligned_request, misaligned_aw_request, pending_err;
	reg	w_misalignment_err;
	reg	[C_AXI_DATA_WIDTH-1:0]	next_wdata;
	reg [C_AXI_DATA_WIDTH/8-1:0]	next_wstrb;

	reg	[AW-1:0]		r_pc;
	reg				r_lock;
	reg	[2:0]			axi_size;

	reg				none_outstanding, bus_abort,
					read_abort, write_abort;
	reg	[LGPIPE:0]		beats_outstanding;
	reg				r_flushing, flush_request,
					r_pipe_stalled;
	reg	[LGPIPE:0]		flushcount, new_flushcount;
	reg	[LGPIPE:0]		wraddr, rdaddr;
	reg	[3:0]			ar_oreg;
	reg	[1:0]			ar_op;
	reg	[AXILSB-1:0]		adr_lsb;
	reg	[FIFO_WIDTH-1:0]	fifo_data	[0:((1<<LGPIPE)-1)];
	reg	[FIFO_WIDTH-1:0]	fifo_read_data;
	wire				fifo_read_op, fifo_misaligned;
	reg				fifo_gie;
	wire	[1:0]			fifo_op;
	wire	[3:0]			fifo_return_reg;
	wire	[AXILSB-1:0]		fifo_lsb;
	reg [2*C_AXI_DATA_WIDTH-1:0]	wide_return, wide_wdata;
	reg [2*C_AXI_DATA_WIDTH/8-1:0]	wide_wstrb;
	reg	[C_AXI_DATA_WIDTH-1:0]	misdata;


	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Transaction issue
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// AWVALID
	// {{{
	initial	M_AXI_AWVALID = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		M_AXI_AWVALID <= 0;
	else if (!M_AXI_AWVALID || M_AXI_AWREADY)
	begin
		if (i_stb && i_op[0])
			M_AXI_AWVALID <= !w_misalignment_err;
		else
			M_AXI_AWVALID <= M_AXI_AWVALID && misaligned_aw_request;

		if (write_abort && !misaligned_aw_request)
			M_AXI_AWVALID <= 0;
	end
	// }}}

	// WVALID
	// {{{
	initial	M_AXI_WVALID = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		M_AXI_WVALID <= 0;
	else if (!M_AXI_WVALID || M_AXI_WREADY)
	begin
		if (i_stb && i_op[0])
			M_AXI_WVALID <= !w_misalignment_err;
		else
			M_AXI_WVALID <= M_AXI_WVALID && misaligned_request;

		if (write_abort && !misaligned_request)
			M_AXI_WVALID <= 0;
	end
	// }}}

	// ARVALID
	// {{{
	initial	M_AXI_ARVALID = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		M_AXI_ARVALID <= 0;
	else if (!M_AXI_ARVALID || M_AXI_ARREADY)
	begin
		if (i_stb && !i_op[0])
			M_AXI_ARVALID <= !w_misalignment_err;
		else
			M_AXI_ARVALID <= M_AXI_ARVALID && misaligned_request;

		if (read_abort && !misaligned_request)
			M_AXI_ARVALID <= 0;
	end
	// }}}

	// r_lock, M_AXI_AxLOCK
	// {{{
	initial	r_lock = 1'b0;
	always @(posedge i_clk)
	if (!OPT_LOCK || !S_AXI_ARESETN)
		r_lock <= 1'b0;
	else if ((!M_AXI_ARVALID || M_AXI_ARREADY)
			&&(!M_AXI_AWVALID || M_AXI_AWREADY))
	begin
		if (!M_AXI_AWVALID && !M_AXI_ARVALID && !M_AXI_WVALID
				&& beats_outstanding <= ((M_AXI_RVALID||M_AXI_BVALID)? 1:0))
			r_lock <= 1'b0;
		if (i_stb)
			r_lock <= i_lock && !w_misalignment_err;
		if (i_cpu_reset || r_flushing)
			r_lock <= 1'b0;
	end

	assign	M_AXI_AWLOCK = r_lock;
	assign	M_AXI_ARLOCK = r_lock;
	// }}}

	// axi_size, M_AXI_AxSIZE
	// {{{
	initial	axi_size = DSZ;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		axi_size <= DSZ;
	else if (i_stb)
	begin
		if (SWAP_WSTRB)
			axi_size <= AXILSB[2:0];
		else begin
			casez(i_op[2:1])
			2'b0?: begin
				axi_size <= 3'b010;
				if ((|i_addr[1:0]) && !w_misaligned)
					axi_size <= AXILSB[2:0];
				end
			2'b10: begin
				axi_size <= 3'b001;
				if (i_addr[0] && !w_misaligned)
					axi_size <= AXILSB[2:0];
				end
			2'b11: axi_size <= 3'b000;
			// default: begin end
			endcase
		end
	end

	assign	M_AXI_AWSIZE = axi_size;
	assign	M_AXI_ARSIZE = axi_size;
	// }}}

	// o_busy,
	// {{{
	// True if the bus is busy doing ... something, whatever it might be.
	// If the bus is busy, the CPU will avoid issuing further interactions
	// to the bus other than pipelined interactions.
	initial	o_busy = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		o_busy <= 0;
	else if (i_stb && !w_misalignment_err && !bus_abort)
		o_busy <= 1;
	else if (M_AXI_AWVALID || M_AXI_WVALID || M_AXI_ARVALID)
		o_busy <= 1;
	else if (beats_outstanding > ((M_AXI_RVALID || M_AXI_BVALID) ? 1:0))
		o_busy <= 1;
	else
		o_busy <= 0;
	// }}}

	// Read busy
	// {{{
	// True if the CPU should expect some kind of pending response from a
	// read, and so should stall for that purpose.  False otherwise.
	initial	o_rdbusy = 0;
	always @(posedge S_AXI_ACLK)
	if (i_cpu_reset || r_flushing)
		o_rdbusy <= 0;
	else if ((i_stb && w_misalignment_err) || bus_abort)
		o_rdbusy <= 0;
	else if (i_stb && (!i_op[0] || (OPT_LOCK && i_lock)))
		o_rdbusy <= 1;
	else if (OPT_LOCK)
	begin
		if (M_AXI_AWVALID || M_AXI_ARVALID || M_AXI_WVALID)
			o_rdbusy <= o_rdbusy;
		else if (o_rdbusy)
			o_rdbusy <= (beats_outstanding > ((M_AXI_RVALID||M_AXI_BVALID) ? 1:0));
	end else if (o_rdbusy && !M_AXI_ARVALID)
		o_rdbusy <= (beats_outstanding > (M_AXI_RVALID ? 1:0));
	// }}}

	// o_pipe_stalled, r_pipe_stalled
	// {{{
	// True if the CPU should expect some kind of pending response from a
	// read, and so should stall for that purpose.  False otherwise.
	generate if (OPT_ALIGNMENT_ERR)
	begin : FULL_PIPE_STALL
		// {{{
		// Here, we stall if the FIFO is ever full.  In this case,
		// any new beat will count as only one item to the FIFO, and
		// so we can run all the way to full.
		reg	[LGPIPE:0]		beats_committed;

		always @(*)
			beats_committed = beats_outstanding
				+ ((i_stb && !w_misalignment_err) ? 1:0)
				+ ((M_AXI_AWVALID || M_AXI_WVALID
						|| M_AXI_ARVALID) ? 1:0);

		initial	r_pipe_stalled = 0;
		always @(posedge S_AXI_ACLK)
		if (i_cpu_reset)
			r_pipe_stalled <= 0;
		else if (M_AXI_RVALID || M_AXI_BVALID)
			r_pipe_stalled <= 0;
		else if (i_stb && i_lock && !w_misalignment_err)
			r_pipe_stalled <= 1;
		else if (OPT_LOCK && r_lock)
			r_pipe_stalled <= (beats_committed > 0);
		else
			r_pipe_stalled <= (beats_committed >= (1<<LGPIPE));
		// }}}
	end else begin : PENULTIMATE_FULL_STALL
		// {{{
		// If we allow for misaligned reads and writes, than we have
		// to stall the CPU just before the FIFO is full, lest the
		// CPU send us a value that needs two items to be placed into
		// the FIO.
		reg	[LGPIPE:0]		beats_committed;

		always @(*)
		begin
			beats_committed = beats_outstanding + (i_stb ? 1:0)
				+ ((M_AXI_AWVALID || M_AXI_WVALID
						|| M_AXI_ARVALID) ? 1:0)
				- ((M_AXI_BVALID || M_AXI_RVALID) ? 1:0);
		end

		initial	r_pipe_stalled = 0;
		always @(posedge S_AXI_ACLK)
		if (i_cpu_reset || bus_abort)
			r_pipe_stalled <= 0;
		else begin
			r_pipe_stalled <= 0;
			if (r_lock && (M_AXI_AWVALID || M_AXI_WVALID || M_AXI_ARVALID))
				r_pipe_stalled <= 1;
			if (r_lock && (beats_outstanding > ((M_AXI_RVALID || M_AXI_BVALID) ? 1:0)))
				r_pipe_stalled <= 1;
			if (i_stb && (w_misaligned && !w_misalignment_err) && !o_pipe_stalled)
				r_pipe_stalled <= 1'b1;
			if (misaligned_request && (M_AXI_WVALID && !M_AXI_WREADY))
				r_pipe_stalled <= 1'b1;
			if (misaligned_request && (M_AXI_ARVALID && !M_AXI_ARREADY))
				r_pipe_stalled <= 1'b1;
			if (misaligned_aw_request && (M_AXI_AWVALID && !M_AXI_AWREADY))
				r_pipe_stalled <= 1'b1;
			if (beats_committed >= (1<<LGPIPE)-2)
				r_pipe_stalled <= 1'b1;
			if (i_stb && i_lock && !w_misalignment_err)
				r_pipe_stalled <= 1'b1;
		end
		// }}}
	end endgenerate

	always @(*)
	begin
		o_pipe_stalled = r_pipe_stalled || r_flushing;
		// if (r_lock && o_busy) o_pipe_stalled = 1;
		if (M_AXI_AWVALID && (!M_AXI_AWREADY || misaligned_aw_request))
			o_pipe_stalled = 1;
		if (M_AXI_WVALID && (!M_AXI_WREADY || misaligned_request))
			o_pipe_stalled = 1;
		if (M_AXI_ARVALID && (!M_AXI_ARREADY || misaligned_request))
			o_pipe_stalled = 1;
	end
	// }}}

	// Count the number of outstanding beats
	// {{{
	// This is the true count.  It is not affected by the number of
	// items the CPU believes is on the bus or not.
	initial	beats_outstanding = 0;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		beats_outstanding <= 0;
	else casez({M_AXI_AWVALID && M_AXI_AWREADY,
		M_AXI_WVALID && M_AXI_WREADY,
		M_AXI_ARVALID && M_AXI_ARREADY,
		M_AXI_RVALID || M_AXI_BVALID})
	4'b0001: beats_outstanding <= beats_outstanding - 1;
	4'b??10: beats_outstanding <= beats_outstanding + 1;
	4'b1100: beats_outstanding <= beats_outstanding + 1;
	4'b1000: if (!M_AXI_WVALID || (misaligned_aw_request && !misaligned_request))
			beats_outstanding <= beats_outstanding + 1;
	4'b0100: if (!M_AXI_AWVALID || (misaligned_request && !misaligned_aw_request))
			beats_outstanding <= beats_outstanding + 1;
	4'b10?1: if ((M_AXI_WVALID && (OPT_ALIGNMENT_ERR
				|| (misaligned_request == misaligned_aw_request)))
			|| (!misaligned_aw_request && misaligned_request))
			beats_outstanding <= beats_outstanding - 1;
	4'b0101: if ((M_AXI_AWVALID && (OPT_ALIGNMENT_ERR
				|| (misaligned_request == misaligned_aw_request)))
			|| (!misaligned_request && misaligned_aw_request))
			beats_outstanding <= beats_outstanding - 1;
	default: begin end
	endcase

	initial	none_outstanding = 1;
	always @(posedge S_AXI_ACLK)
	if (!S_AXI_ARESETN)
		none_outstanding <= 1;
	else casez({M_AXI_AWVALID && M_AXI_AWREADY,
		M_AXI_WVALID && M_AXI_WREADY,
		M_AXI_ARVALID && M_AXI_ARREADY,
		M_AXI_RVALID || M_AXI_BVALID})
	4'b0001: none_outstanding <= (beats_outstanding <= 1);
	4'b??10: none_outstanding <= 0;
	4'b1100: none_outstanding <= 0;
	4'b1000: if (!M_AXI_WVALID || (misaligned_aw_request && !misaligned_request))
			none_outstanding <= 0;
	4'b0100: if (!M_AXI_AWVALID || (misaligned_request && !misaligned_aw_request))
			none_outstanding <= 0;
	4'b10?1: if ((M_AXI_WVALID && (OPT_ALIGNMENT_ERR
				|| (misaligned_request == misaligned_aw_request)))
			|| (!misaligned_aw_request && misaligned_request))
			none_outstanding <= (beats_outstanding <= 1);
	4'b0101: if ((M_AXI_AWVALID && (OPT_ALIGNMENT_ERR
				|| (misaligned_request == misaligned_aw_request)))
			|| (!misaligned_request && misaligned_aw_request))
			none_outstanding <= (beats_outstanding <= 1);
	default: begin end
	endcase
	// }}}

	// bus_abort
	// {{{
	// When do we abandon everything and start aborting bus transactions?
	always @(*)
	begin
		bus_abort = 0;
		if (i_cpu_reset || o_err)
			bus_abort = 1;
		if (M_AXI_BVALID && M_AXI_BRESP[1])
			bus_abort = 1;
		if (M_AXI_RVALID && M_AXI_RRESP[1])
			bus_abort = 1;

		write_abort = 0;
		if (i_cpu_reset || o_err)
			write_abort = 1;
		if (M_AXI_BVALID && M_AXI_BRESP[1])
			write_abort = 1;

		read_abort = 0;
		if (i_cpu_reset || o_err)
			read_abort = 1;
		if (M_AXI_RVALID && M_AXI_RRESP[1])
			read_abort = 1;
	end
	// }}}

	// Flushing
	// {{{

	// new_flushcount
	// {{{
	always @(*)
	begin
		case({((M_AXI_AWVALID || M_AXI_WVALID) || M_AXI_ARVALID),
			(M_AXI_BVALID || M_AXI_RVALID) })
		2'b01: new_flushcount = beats_outstanding - 1;
		2'b10: new_flushcount = beats_outstanding + 1;
		default: new_flushcount = beats_outstanding;
		endcase

		if (!OPT_ALIGNMENT_ERR && (misaligned_request || misaligned_aw_request))
			new_flushcount = new_flushcount + 1;
	end
	// }}}

	initial	r_flushing    = 1'b0;
	initial	flushcount    = 0;
	initial	flush_request = 0;
	always @(posedge i_clk)
	if (!S_AXI_ARESETN)
	begin
		// {{{
		r_flushing <= 1'b0;
		flush_request <= 0;
		flushcount    <= 0;
		// }}}
	end else if (i_cpu_reset || bus_abort || (i_stb && w_misalignment_err))
	begin
		// {{{
		r_flushing <= (new_flushcount != 0);
		flushcount <= new_flushcount;
		flush_request <= (M_AXI_ARVALID && (!M_AXI_ARREADY || misaligned_request))
			|| (M_AXI_AWVALID && (!M_AXI_AWREADY || misaligned_aw_request))
			|| (M_AXI_WVALID && (!M_AXI_WREADY || misaligned_request));
		// }}}
	end else if (r_flushing)
	begin
		// {{{
		if (M_AXI_BVALID || M_AXI_RVALID)
		begin
			flushcount <= flushcount - 1;
			r_flushing <= (flushcount > 1);
		end

		casez({M_AXI_AWVALID && (M_AXI_AWREADY && !misaligned_aw_request),
				(M_AXI_WVALID && M_AXI_WREADY && !misaligned_request),
				(M_AXI_ARVALID && M_AXI_ARREADY && !misaligned_request) })
		3'b001: flush_request <= 0;
		3'b10?: flush_request <= M_AXI_WVALID;
		3'b01?: flush_request <= M_AXI_AWVALID;
		3'b11?: flush_request <= 0;
		default: begin end
		endcase
		// }}}
	end
	// }}}

	// Bus addressing
	// {{{
	initial	M_AXI_AWADDR = 0;
	always @(posedge i_clk)
	if (i_stb)
	begin
		M_AXI_AWADDR <= i_addr[AW-1:0];
		if (SWAP_WSTRB)
			M_AXI_AWADDR[AXILSB-1:0] <= 0;
	end else if (!OPT_ALIGNMENT_ERR
		&& ((M_AXI_AWVALID && M_AXI_AWREADY) // && misaligned_aw_request
		|| (M_AXI_ARVALID && M_AXI_ARREADY))) // && misaligned_request))
	begin
		M_AXI_AWADDR[AW-1:AXILSB] <= M_AXI_AWADDR[AW-1:AXILSB] + 1;
		M_AXI_AWADDR[AXILSB-1:0] <= 0;
	end

	always @(*)
		M_AXI_ARADDR = M_AXI_AWADDR;
	// }}}

	// Is this request misaligned?
	// {{{
	always @(*)
	casez(i_op[2:1])
	// Full word
	2'b0?: w_misaligned = (i_addr[AXILSB-1:0]+3) >= (1<<AXILSB);
	// Half word
	2'b10: w_misaligned = (i_addr[AXILSB-1:0]+1) >= (1<<AXILSB);
	// Bytes are always aligned
	2'b11: w_misaligned = 1'b0;
	endcase

	always @(*)
	begin
		w_misalignment_err = w_misaligned && OPT_ALIGNMENT_ERR;
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

	// wide_wdata, wide_wstrb
	// {{{
	always @(*)
	if (SWAP_WSTRB)
	begin : BACKWARDS_ORDER
		// {{{
		casez(i_op[2:1])
		2'b10: wide_wdata
			= { i_data[15:0], {(2*C_AXI_DATA_WIDTH-16){1'b0}} }
				>> (i_addr[AXILSB-1:0] * 8);
		2'b11: wide_wdata
			= { i_data[7:0], {(2*C_AXI_DATA_WIDTH-8){1'b0}} }
				>> (i_addr[AXILSB-1:0] * 8);
		default: wide_wdata
			= ({ i_data, {(2*C_AXI_DATA_WIDTH-32){ 1'b0 }} }
				>> (i_addr[AXILSB-1:0] * 8));
		endcase

		casez(i_op[2:1])
		2'b0?: wide_wstrb
			= { 4'b1111, {(2*C_AXI_DATA_WIDTH/8-4){1'b0}} } >> i_addr[AXILSB-1:0];
		2'b10: wide_wstrb
			= { 2'b11, {(2*C_AXI_DATA_WIDTH/8-2){1'b0}} } >> i_addr[AXILSB-1:0];
		2'b11: wide_wstrb
			= { 1'b1, {(2*C_AXI_DATA_WIDTH/8-1){1'b0}} } >> i_addr[AXILSB-1:0];
		endcase
		// }}}
	end else begin : LITTLE_ENDIAN_DATA
		// {{{
		casez(i_op[2:1])
		2'b10: wide_wdata
			= { {(2*C_AXI_DATA_WIDTH-16){1'b0}}, i_data[15:0] }
					<< (8*i_addr[AXILSB-1:0]);
		2'b11: wide_wdata
			= { {(2*C_AXI_DATA_WIDTH-8){1'b0}}, i_data[7:0] }
					<< (8*i_addr[AXILSB-1:0]);
		default: wide_wdata
			= { {(C_AXI_DATA_WIDTH){1'b0}}, i_data }
					<< (8*i_addr[AXILSB-1:0]);
		endcase

		casez(i_op[2:1])
		2'b0?: wide_wstrb
			= { {(2*C_AXI_DATA_WIDTH/8-4){1'b0}}, 4'b1111} << i_addr[AXILSB-1:0];
		2'b10: wide_wstrb
			= { {(2*C_AXI_DATA_WIDTH/8-4){1'b0}}, 4'b0011} << i_addr[AXILSB-1:0];
		2'b11: wide_wstrb
			= { {(2*C_AXI_DATA_WIDTH/8-4){1'b0}}, 4'b0001} << i_addr[AXILSB-1:0];
		endcase
		// }}}
	end
	// }}}

	// WDATA and WSTRB
	// {{{
	initial	M_AXI_WDATA = 0;
	initial	M_AXI_WSTRB = 0;
	initial	next_wdata  = 0;
	initial	next_wstrb  = 0;
	always @(posedge i_clk)
	if (i_stb)
	begin
		if (SWAP_WSTRB)
		begin : BACKWARDS_ORDER_REG
			// {{{
			{ M_AXI_WDATA, next_wdata } <= wide_wdata;
			{ M_AXI_WSTRB, next_wstrb } <= wide_wstrb;
			// }}}
		end else begin
			// {{{
			{ next_wdata, M_AXI_WDATA } <= wide_wdata;
			{ next_wstrb, M_AXI_WSTRB } <= wide_wstrb;
			// }}}
		end

		if (OPT_ALIGNMENT_ERR)
			{ next_wstrb, next_wdata } <= 0;

	end else if ((OPT_LOWPOWER || !OPT_ALIGNMENT_ERR) && M_AXI_WREADY)
	begin
		M_AXI_WDATA <= next_wdata;
		M_AXI_WSTRB <= next_wstrb;
		if (OPT_LOWPOWER)
			{ next_wdata, next_wstrb } <= 0;
	end
	// }}}

	generate if (OPT_ALIGNMENT_ERR)
	begin
		// {{{
		// Generate an error on any misaligned request
		assign	misaligned_request = 1'b0;

		assign	misaligned_aw_request = 1'b0;
		assign	pending_err = 1'b0;
		// }}}
	end else begin
		// {{{
		reg	r_misaligned_request, r_misaligned_aw_request,
			r_pending_err;

		// misaligned_request
		// {{{
		initial	r_misaligned_request = 0;
		always @(posedge i_clk)
		if (!S_AXI_ARESETN)
			r_misaligned_request <= 0;
		else if (i_stb && !o_err && !i_cpu_reset && !bus_abort)
			r_misaligned_request <= w_misaligned && !w_misalignment_err;
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
		else if (i_stb && !o_err && !i_cpu_reset && !write_abort)
			r_misaligned_aw_request <= w_misaligned && i_op[0] && !w_misalignment_err;
		else if (M_AXI_AWREADY)
			r_misaligned_aw_request <= 1'b0;

		assign	misaligned_aw_request = r_misaligned_aw_request;
		// }}}

		// pending_err
		// {{{
		initial	r_pending_err = 1'b0;
		always @(posedge i_clk)
		if (i_cpu_reset || i_stb || o_err || r_flushing)
			r_pending_err <= 1'b0;
		else if ((M_AXI_BVALID && M_AXI_BRESP[1])
				|| (M_AXI_RVALID && M_AXI_RRESP[1]))
			r_pending_err <= 1'b1;

		assign	pending_err = r_pending_err;
		// }}}
		// }}}
	end endgenerate

	// AxOTHER
	// {{{
	localparam [3:0]	AXI_NON_CACHABLE_BUFFERABLE = 4'h3;
	localparam [3:0]	OPT_CACHE = AXI_NON_CACHABLE_BUFFERABLE;
	localparam [2:0]	AXI_UNPRIVILEGED_NONSECURE_DATA_ACCESS = 3'h0;
	localparam [2:0]	OPT_PROT=AXI_UNPRIVILEGED_NONSECURE_DATA_ACCESS;

	assign	M_AXI_AWID    = AXI_ID;
	assign	M_AXI_AWLEN   = 0;
	assign	M_AXI_AWBURST = AXI_INCR;
	assign	M_AXI_AWCACHE = M_AXI_AWLOCK ? 0:OPT_CACHE;
	assign	M_AXI_AWPROT  = OPT_PROT;
	assign	M_AXI_AWQOS   = OPT_QOS;
	assign	M_AXI_WLAST   = 1;

	assign	M_AXI_ARID    = AXI_ID;
	assign	M_AXI_ARLEN   = 0;
	assign	M_AXI_ARBURST = AXI_INCR;
	assign	M_AXI_ARCACHE = M_AXI_ARLOCK ? 0:OPT_CACHE;
	assign	M_AXI_ARPROT  = OPT_PROT;
	assign	M_AXI_ARQOS   = OPT_QOS;
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Read transaction FIFO
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// wraddr
	// {{{
	initial	wraddr = 0;
	always @(posedge S_AXI_ACLK)
	if (bus_abort || flush_request)	// bus_abort includes i_cpu_reset
		wraddr <= 0;
	else if ((M_AXI_ARVALID && M_AXI_ARREADY) || (M_AXI_WVALID && M_AXI_WREADY))
		wraddr <= wraddr + 1;
	// }}}

	// rdaddr
	// {{{
	initial	rdaddr = 0;
	always @(posedge S_AXI_ACLK)
	if (bus_abort || r_flushing)
		rdaddr <= 0;
	else if (M_AXI_RVALID||M_AXI_BVALID)
		rdaddr <= rdaddr + 1;
	// }}}

	// ar_oreg, ar_op, adr_lsb
	// {{{
	always @(posedge S_AXI_ACLK)
	if (i_stb)
		{ fifo_gie, ar_oreg, ar_op, adr_lsb } <= { i_oreg, i_op[2:1], i_addr[AXILSB-1:0] };
	else if ((M_AXI_ARVALID && M_AXI_ARREADY)||(M_AXI_WVALID && M_AXI_WREADY))
		adr_lsb <= 0;
	// }}}

	// fifo_data
	// {{{
	always @(posedge S_AXI_ACLK)
	if ((M_AXI_ARVALID && M_AXI_ARREADY) || (M_AXI_WVALID && M_AXI_WREADY))
		fifo_data[wraddr[LGPIPE-1:0]] <= { M_AXI_ARVALID, ar_oreg,ar_op,
				misaligned_request, adr_lsb };

	always @(*)
		fifo_read_data = fifo_data[rdaddr[LGPIPE-1:0]];

	assign	{ fifo_read_op, fifo_return_reg, fifo_op,
			fifo_misaligned, fifo_lsb } = fifo_read_data;
	// }}}

	// r_pc
	// {{{
	always @(posedge S_AXI_ACLK)
	if (!OPT_LOCK)
		r_pc <= 0;
	else if (i_stb && i_lock && !i_op[0])
		r_pc <= i_restart_pc;
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Read return generation
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// o_valid
	// {{{
	initial	o_valid = 1'b0;
	always @(posedge i_clk)
	if (i_cpu_reset || r_flushing)
		o_valid <= 1'b0;
	else if (OPT_LOCK && r_lock)
		o_valid <= (M_AXI_RVALID && M_AXI_RRESP == EXOKAY)
			||(M_AXI_BVALID && M_AXI_BRESP == OKAY);
	else if (OPT_ALIGNMENT_ERR && i_stb && w_misaligned)
		o_valid <= 1'b0;
	else
		o_valid <= M_AXI_RVALID && !M_AXI_RRESP[1] // && !pending_err
				&& !fifo_misaligned;
	// }}}

	// o_wreg
	// {{{
	always @(posedge i_clk)
	begin
		o_wreg <= { fifo_gie, fifo_return_reg };
		if (OPT_LOCK && r_lock && M_AXI_BVALID)
			o_wreg[3:0] <= 4'hf;
	end
	// }}}

	// o_result, misdata
	// {{{
	// Need to realign any returning data
	// wide_return
	// {{{
	always @(*)
	begin
		if (SWAP_WSTRB)
		begin
			if (fifo_misaligned && !OPT_ALIGNMENT_ERR)
				wide_return = { misdata, M_AXI_RDATA }
							<< (8*fifo_lsb);
			else
				wide_return = { M_AXI_RDATA, {(DW){1'b0}} }
							<< (8*fifo_lsb);

			casez(fifo_op[1:0])
			2'b10: wide_return = { {(16){1'b0}},
					wide_return[(2*DW)-1:(2*DW)-16],
					{(2*DW-32){1'b0}} };
			2'b11: wide_return = { {(24){1'b0}},
						wide_return[(2*DW)-1:(2*DW)-8],
					{(2*DW-32){1'b0}} };
			default: begin end
			endcase

			wide_return[31:0] = wide_return[(2*DW-1):(2*DW-32)];
		end else begin
			if (fifo_misaligned && !OPT_ALIGNMENT_ERR)
				wide_return = { M_AXI_RDATA, misdata } >> (8*fifo_lsb);
			else
				wide_return = { {(C_AXI_DATA_WIDTH){1'b0}}, M_AXI_RDATA }
					>> (8*fifo_lsb);
		end

		if (OPT_LOWPOWER && (!M_AXI_RVALID || M_AXI_RRESP[1]))
			wide_return = 0;
	end
	// }}}

	// misdata
	// {{{
	always @(posedge i_clk)
	if (OPT_ALIGNMENT_ERR)
		misdata <= 0;
	else if (M_AXI_RVALID)
	begin
		if (fifo_misaligned)
			misdata <= M_AXI_RDATA;
		else
			misdata <= 0;
	end
	// }}}

	// o_result
	// {{{
	always @(posedge i_clk)
	if (OPT_LOWPOWER && (!S_AXI_ARESETN || r_flushing || i_cpu_reset))
		o_result <= 0;
	else if (OPT_LOCK && M_AXI_BVALID && (!OPT_LOWPOWER || (r_lock && M_AXI_BRESP == OKAY)))
	begin
		o_result <= 0;
		o_result[AW-1:0] <= r_pc;
	end else if (!OPT_LOWPOWER || M_AXI_RVALID)
	begin

		o_result <= wide_return[31:0];

		if (OPT_SIGN_EXTEND)
		begin
			// {{{
			case(fifo_op)
			2'b10: o_result[31:16] <= {(16){wide_return[15]}};
			2'b11: o_result[31: 8] <= {(24){wide_return[ 7]}};
			endcase
			// }}}
		end else if (fifo_op[1])
		begin
			// {{{
			if (fifo_op[0])
				o_result[31: 8] <= 0;
			else
				o_result[31:16] <= 0;
			// }}}
		end

		if (OPT_LOWPOWER&&(i_cpu_reset || r_flushing))
			o_result <= 0;
	end
	// }}}
	// }}}

	// o_err - report bus errors back to the CPU
	// {{{
	initial	o_err = 1'b0;
	always @(posedge i_clk)
	if (i_cpu_reset || r_flushing || o_err)
		o_err <= 1'b0;
	else if (i_stb && w_misalignment_err)
		o_err <= 1'b1;
	else if (OPT_LOCK && r_lock)
		o_err <= (M_AXI_BVALID && M_AXI_BRESP[1])
			||(M_AXI_RVALID && M_AXI_RRESP != EXOKAY);
	else if (M_AXI_BVALID || M_AXI_RVALID)
		o_err <= (M_AXI_BVALID && M_AXI_BRESP[1])
			|| (M_AXI_RVALID && M_AXI_RRESP[1]);
	else
		o_err <= 1'b0;
	// }}}

	// Return xREADY -- always ready
	// {{{
	assign	M_AXI_RREADY = 1;
	assign	M_AXI_BREADY = 1;
	// }}}

	// }}}

	// Make verilator happy
	// {{{
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, M_AXI_RRESP[0], M_AXI_BRESP[0],
			M_AXI_BID, M_AXI_RID, M_AXI_RLAST,
			// i_addr[31:C_AXI_ADDR_WIDTH],
			(&i_addr), wide_return[2*C_AXI_DATA_WIDTH-1:32],
			pending_err, fifo_read_op,
			none_outstanding };
	// verilator lint_on  UNUSED
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
// Formal properties for this core are maintained elsewhere
`endif
// }}}
endmodule
