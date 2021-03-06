////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbucompress.v
//
// Project:	FPGA library
//
// Purpose:	When reading many words that are identical, it makes no sense
//		to spend the time transmitting the same thing over and over
//	again, especially on a slow channel.  Hence this routine uses a table
//	lookup to see if the word to be transmitted was one from the recent
//	past.  If so, the word is replaced with an address of the recently
//	transmitted word.  Mind you, the table lookup takes one clock per table
//	entry, so even if a word is in the table it might not be found in time.
//	If the word is not in the table, or if it isn't found due to a lack of
//	time, the word is placed into the table while incrementing every other
//	table address.
//
//	Oh, and on a new address--the table is reset and starts over.  This way,
//	any time the host software changes, the host software will always start
//	by issuing a new address--hence the table is reset for every new piece
//	of software that may wish to communicate.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
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
`default_nettype none
//
// All input words are valid codewords.  If we can, we make them
// better here.
module	wbucompress(i_clk, i_reset, i_stb, i_codword, i_busy, o_stb, o_cword,
		o_busy);
	parameter	DW=32, CW=36, TBITS=10;
	input	wire			i_clk, i_reset, i_stb;
	input	wire	[(CW-1):0]	i_codword;
	input	wire			i_busy;
	output	reg			o_stb;
	output	wire	[(CW-1):0]	o_cword;
	output	wire			o_busy;

	//
	//
	// First stage is to compress the address.
	// This stage requires one clock.
	//
	//	ISTB,ICODWORD
	//	ISTB2,IWRD2	ASTB,AWORD
	//	ISTB3,IWRD3	ASTB2,AWRD2	I_BUSY(1)
	//	ISTB3,IWRD3	ASTB2,AWRD2	I_BUSY(1)
	//	ISTB3,IWRD3	ASTB2,AWRD2	I_BUSY(1)
	//	ISTB3,IWRD3	ASTB2,AWRD2
	//	ISTB4,IWRD4	ASTB3,AWRD3	I_BUSY(2)
	//	ISTB4,IWRD4	ASTB3,AWRD3	I_BUSY(2)
	//	ISTB4,IWRD4	ASTB3,AWRD3	I_BUSY(2)
	reg		aword_valid;
	reg	[35:0]	a_addrword;
	wire	[31:0]	w_addr;
	wire	[3:0]	addr_zcheck;
	reg		tbl_busy;

	////////////////////////////////////////////////////////////////////////
	//
	// Address compression stage
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	assign	w_addr = i_codword[31:0];
	assign	addr_zcheck[0] = (w_addr[11: 6] == 0);
	assign	addr_zcheck[1] = (w_addr[17:12] == 0);
	assign	addr_zcheck[2] = (w_addr[23:18] == 0);
	assign	addr_zcheck[3] = (w_addr[31:24] == 0);

	assign	o_busy = aword_valid && tbl_busy;

	always @(posedge i_clk)
	if (!aword_valid || !tbl_busy)
	begin
		if (i_codword[35:32] != 4'h2)
			a_addrword <= i_codword;
		else casez(addr_zcheck)
		4'b1111: a_addrword <= { 6'hc, w_addr[ 5:0], 24'h00 };
		4'b1110: a_addrword <= { 6'hd, w_addr[11:0], 18'h00 };
		4'b110?: a_addrword <= { 6'he, w_addr[17:0], 12'h00 };
		4'b10??: a_addrword <= { 6'hf, w_addr[23:0],  6'h00 };
		default: a_addrword <= i_codword;
		endcase
	end

	// aword_valid is the output of the address compression stage
	initial	aword_valid = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		aword_valid <= 1'b0;
	else if (i_stb)
		aword_valid <= 1'b1;
	else if (!tbl_busy)
		aword_valid <= 1'b0;

	////////////////////////////////////////////////////////////////////////
	wire			w_accepted;
	reg	[35:0]		r_word;
	reg	[(TBITS-1):0]	tbl_addr;
	reg			tbl_filled;
	reg	[31:0]		compression_tbl	[0:((1<<TBITS)-1)];
	reg	[(TBITS-1):0]	rd_addr;
	reg			pmatch;
	reg			dmatch, // Match, on clock 'd'
				vaddr;	// Was the address valid then?
	reg	[(DW-1):0]	cword;
	reg	[(TBITS-1):0]	maddr;
	reg			matched;	// Have we matched already?
	reg			zmatch, hmatch;
	reg	[9:0]		adr_dbld;
	reg	[2:0]		adr_hlfd;
	reg	[(CW-1):0]	r_cword; // Record our result
	reg	[TBITS-1:0]	dffaddr;
	reg			clear_table;
	reg			addr_within_table;
	wire			w_match;



	integer	k;

	//
	//
	// The next stage attempts to replace data codewords with previous
	// codewords that may have been sent.  The memory is only allowed
	// to be as old as the last new address command.  In this fashion,
	// any program that wishes to talk to the device can start with a
	// known compression table by simply setting the address and then
	// reading from the device.
	//

	// We start over any time a new value shows up, and
	// the follow-on isn't busy and can take it.  Likewise,
	// we reset the writer on the compression any time a
	// i_clr value comes through (i.e., ~i_cyc or new
	// address)

	assign	w_accepted = (o_stb)&&(!tbl_busy);
	always @(*)
		tbl_busy = (o_stb && i_busy);

	always @(posedge i_clk)
	if (!tbl_busy)
		r_word <= a_addrword;


	//
	// First step of the compression is keeping track of a compression
	// table.  And the first part of that is keeping track of what address
	// to write into the compression table, and whether or not the entire
	// table is full or not.  This logic follows:
	//
	// First part, write the compression table

	always @(*)
	if (i_reset)
		clear_table = 1;
	else begin
		// If we send a new address, then reset the table to empty
		//
		//
		// Reset on new address (0010xx) and on new compressed
		// addresses (0011ll).

		clear_table = (o_stb && !i_busy && (o_cword[35:33] == 3'b001));
	end

	initial	tbl_addr = 0;
	always @(posedge i_clk)
	if (clear_table)
		tbl_addr <= 0;
	else if (w_accepted)
	begin
		// Otherwise, on any valid return result that wasn't
		// from our table, for whatever reason (such as didn't
		// have the clocks to find it, etc.), increment the
		// address to add another value into our table
		if (o_cword[35:33] == 3'b111)
			tbl_addr <= tbl_addr + {{(TBITS-1){1'b0}},1'b1};
	end

	initial	tbl_filled = 1'b0;
	always @(posedge i_clk)
	if (clear_table)
		tbl_filled <= 1'b0;
	else if (tbl_addr == 10'h3ff)
		tbl_filled <= 1'b1;

	// Now that we know where we are writing into the table, and what
	// values of the table are valid, we need to actually write into
	// the table.
	//
	// We can keep this logic really simple by writing on every clock
	// and writing junk on many of those clocks, but we'll need to remember
	// that the value of the table at tbl_addr is unreliable until tbl_addr
	// changes.
	//
	initial begin
		for(k=0; k<(1<<TBITS); k=k+1)
			compression_tbl[k] = 0;
	end

	// Write new values into the compression table
	always @(posedge i_clk)
		compression_tbl[tbl_addr] <= { r_word[32:31], r_word[29:0] };

	// Now that we have a working table, can we use it?
	// On any new word, we'll start looking through our codewords.
	// If we find any that matches, we're there.  We might (or might not)
	// make it through the table first.  That's irrelevant.  We just look
	// while we can.

	initial	rd_addr = 0;
	always @(posedge i_clk)
	if (clear_table)
	begin
		rd_addr <= -1;
	end else if (!o_stb || !i_busy)
	begin
		rd_addr <= tbl_addr-((o_stb && o_cword[35:33] == 3'b111)? 0:1);
	end else begin
		rd_addr <= rd_addr - 1;
	end

	initial	dmatch = 0;
	always @(posedge i_clk)
	begin
		// First clock, read the value from the compression table
		cword <= compression_tbl[rd_addr];

		// Second clock, check for a match
		dmatch <= (cword == { r_word[32:31], r_word[29:0] })
				&& pmatch && !matched && vaddr;
		maddr  <= dffaddr;

		if (!o_stb || !i_busy)
			dmatch <= 1'b0;
	end

	//
	// The address difference is what we'll use to encode our table
	// address.  It's designed to match tbl_addr - rd_addr.  The smallest
	// valid dffaddr is 1, since tbl_addr is a junk address written on
	// every clock.
	initial	dffaddr = 0;
	always @(posedge i_clk)
	if (clear_table || !o_stb || !i_busy)
		dffaddr <= 1;
	else
		dffaddr <= dffaddr + 1;

	//
	// Is the value within the table even valid?  Let's check that here.
	// It will be valid if the read address is strictly less than the
	// table address (in an unsigned way).  However, our table address
	// wraps.  Therefore we used tbl_filled to tell us if the table
	// address has wrapped, and in that case the address will always
	// have valid information within it.
	initial	vaddr = 0;
	always @(posedge i_clk)
	if (i_reset || !i_busy)
		vaddr <= 0;
	else
		vaddr <= ( {1'b0, rd_addr} < {tbl_filled, tbl_addr} );

	//
	// Is our address (indicated by the address difference, dffaddr),
	// within the realm of what we can represent/return?  Likewise, if we
	// wander outside of the realms of our table, make sure we don't
	// come back in and declare a success.
	initial	addr_within_table = 1;
	always @(posedge i_clk)
	if (i_reset || !i_busy)
		addr_within_table <= 1;
	else if (addr_within_table)
		addr_within_table <= (dffaddr <= 10'd521);


	// pmatch indicates a *possible* match.  It's basically a shift
	// register indicating what/when things are valid--or at least it
	// was.  As of the last round of editing, pmatch is now only a single
	// valid bit.
	//
	initial	pmatch = 0;
	always @(posedge i_clk)
	if (i_reset)
		pmatch <= 0;
	else if (!tbl_busy)
		pmatch <= 0; // rd_addr is set on this clock
	else
		// cword is set on the next clock, pmatch = 3'b001
		// dmatch is set on the next clock, pmatch = 3'b011
		pmatch <= 1;

	assign	w_match = (addr_within_table && dmatch && r_word[35:33]==3'b111);

	//
	// matched records whether or not we've already matched, and so we
	// shouldn't therefore match again.
	//
	initial	matched = 0;
	always @(posedge i_clk)
	if (i_reset)
		matched <= 0;
	else if (!i_busy || !o_stb)	// Reset upon any write
		matched <= 1'b0;
	else if (!matched)
		// To be a match, the table must not be empty,
		matched <= w_match;

	//
	// zmatch and hmatch are address helper values.  They tell us if the
	// current item we are matching is the last item written (zmatch), one
	// of the last nine items written (hmatch), or none of the above--since
	// each of these have different encodings
	initial	{ zmatch, hmatch } = 0;
	always @(posedge i_clk)
	if (i_reset || (!o_stb || !i_busy) || !pmatch)
		{ zmatch, hmatch } <= 0;
	else begin
		zmatch    <= (dffaddr == 10'h2);
		hmatch    <= (dffaddr < 10'd11);
	end

	//
	// matchaddr holds the value we intend to encode into the table
	//
	always @(posedge i_clk)
	if (!matched && !w_match)
	begin
		// Since optimizing the core, it's no longer needed.  We'll
		// reconstruct it in the formal properties as f_matchaddr
		// matchaddr <= maddr;

		// Calcualte our encodings
		adr_hlfd <= maddr[2:0]- 3'd2;
		adr_dbld <= maddr - 10'd10;
	end

	always @(posedge i_clk)
	if (!tbl_busy)		// Reset whenever word gets written
		r_cword <= a_addrword;
	else if (!matched && w_match)
	begin
		r_cword <= r_word;
		if (zmatch) // matchaddr == 1
			r_cword[35:30] <= { 5'h3, r_word[30] };
		else if (hmatch) // 2 <= matchaddr <= 9
			r_cword[35:30] <= { 2'b10, adr_hlfd, r_word[30] };
		else // if (adr_diff < 10'd521)
			r_cword[35:24] <= { 2'b01, adr_dbld[8:6],
					r_word[30], adr_dbld[5:0] };
	end

	initial	o_stb = 0;
	always @(posedge i_clk)
	if (i_reset)
		o_stb <= 0;
	else if (aword_valid)
		o_stb <= 1;
	else if (!i_busy)
		o_stb <= 0;

	assign	o_cword = r_cword;

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = adr_dbld[9];
	// verilator lint_on  UNUSED
endmodule

