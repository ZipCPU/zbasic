////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbdmac.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	Wishbone DMA controller
//
//	This module is controllable via the wishbone, and moves values from
//	one location in the wishbone address space to another.  The amount of
//	memory moved at any given time can be up to 4kB, or equivalently 1kW.
//	Four registers control this DMA controller: a control/status register,
//	a length register, a source WB address and a destination WB address.
//	These register may be read at any time, but they may only be written
//	to when the controller is idle.
//
//	The meanings of three of the setup registers should be self explanatory:
//		- The length register controls the total number of words to
//			transfer.
//		- The source address register controls where the DMA controller
//			reads from.  This address may or may not be incremented
//			after each read, depending upon the setting in the
//			control/status register.
//		- The destination address register, which controls where the DMA
//			controller writes to.  This address may or may not be
//			incremented after each write, also depending upon the
//			setting in the control/status register.
//
//	It is the control/status register, at local address zero, that needs
//	more definition:
//
//	Bits:
//	31	R	Write protect	If this is set to one, it means the
//				write protect bit is set and the controller
//				is therefore idle.  This bit will be set upon
//				completing any transfer.
//	30	R	Error.		The controller stopped mid-transfer
//					after receiving a bus error.
//	29	R/W	inc_s_n		If set to one, the source address
//				will not increment from one read to the next.
//	28	R/W	inc_d_n		If set to one, the destination address
//				will not increment from one write to the next.
//	27	R	Always 0
//	26..16	R	nread		Indicates how many words have been read,
//				and not necessarily written (yet).  This
//				combined with the cfg_len parameter should tell
//				exactly where the controller is at mid-transfer.
//	27..16	W	WriteProtect	When a 12'h3db is written to these
//				bits, the write protect bit will be cleared.
//				
//	15	R/W	on_dev_trigger	When set to '1', the controller will
//				wait for an external interrupt before starting.
//	14..10	R/W	device_id	This determines which external interrupt
//				will trigger a transfer.
//	9..0	R/W	transfer_len	How many bytes to transfer at one time.
//				The minimum transfer length is one, while zero
//				is mapped to a transfer length of 1kW.
//
//	Write 32'hffed00 to halt an ongoing transaction, completing anything
//	remaining, or 32'hafed00 to abort the current transaction leaving
//	any unfinished read/write in an undetermined state.
//
//
//	To use this, follow this checklist:
//	1. Wait for any prior DMA operation to complete
//		(Read address 0, wait 'till either top bit is set or cfg_len==0)
//	2. Write values into length, source and destination address. 
//		(writei(3, &vals) should be sufficient for this.)
//	3. Enable the DMAC interrupt in whatever interrupt controller is present
//		on the system.
//	4. Write the final start command to the setup/control/status register:
//		Set inc_s_n, inc_d_n, on_dev_trigger, dev_trigger,
//			appropriately for your task
//		Write 12'h3db to the upper word.
//		Set the lower word to either all zeros, or a smaller transfer
//		length if desired.
//	5. wait() for the interrupt and the operation to complete.
//		Prior to completion, number of items successfully transferred
//		be read from the length register.  If the internal buffer is
//		being used, then you can read how much has been read into that
//		buffer by reading from bits 25..16 of this control/status
//		register.
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
`define	DMA_IDLE	3'b000
`define	DMA_WAIT	3'b001
`define	DMA_READ_REQ	3'b010
`define	DMA_READ_ACK	3'b011
`define	DMA_PRE_WRITE	3'b100
`define	DMA_WRITE_REQ	3'b101
`define	DMA_WRITE_ACK	3'b110

module wbdmac(i_clk, i_reset,
		i_swb_cyc, i_swb_stb, i_swb_we, i_swb_addr, i_swb_data,
			o_swb_ack, o_swb_stall, o_swb_data,
		o_mwb_cyc, o_mwb_stb, o_mwb_we, o_mwb_addr, o_mwb_data,
			i_mwb_ack, i_mwb_stall, i_mwb_data, i_mwb_err,
		i_dev_ints,
		o_interrupt);
	parameter	ADDRESS_WIDTH=30, LGMEMLEN = 10, DW=32;
	localparam	LGDV=5;
	localparam	AW=ADDRESS_WIDTH;
	input	wire		i_clk, i_reset;
	// Slave/control wishbone inputs
	input	wire		i_swb_cyc, i_swb_stb, i_swb_we;
	input	wire	[1:0]	i_swb_addr;
	input	wire [(DW-1):0]	i_swb_data;
	// Slave/control wishbone outputs
	output	reg		o_swb_ack;
	output	wire		o_swb_stall;
	output	reg [(DW-1):0]	o_swb_data;
	// Master/DMA wishbone control
	output	wire		o_mwb_cyc, o_mwb_stb, o_mwb_we;
	output	reg [(AW-1):0]	o_mwb_addr;
	output	reg [(DW-1):0]	o_mwb_data;
	// Master/DMA wishbone responses from the bus
	input	wire		i_mwb_ack, i_mwb_stall;
	input	wire [(DW-1):0]	i_mwb_data;
	input	wire		i_mwb_err;
	// The interrupt device interrupt lines
	input	wire [(DW-1):0]	i_dev_ints;
	// An interrupt to be set upon completion
	output	reg		o_interrupt;
	// Need to release the bus for a higher priority user
	//	This logic had lots of problems, so it is being
	//	removed.  If you want to make sure the bus is available
	//	for a higher priority user, adjust the transfer length
	//	accordingly.
	//
	// input			i_other_busmaster_requests_bus;
	//

	wire	s_cyc, s_stb, s_we;
	wire	[1:0]	s_addr;
	wire	[31:0]	s_data;
`define	DELAY_ACCESS
`ifdef	DELAY_ACCESS
	reg	r_s_cyc, r_s_stb, r_s_we;
	reg	[1:0]	r_s_addr;
	reg	[31:0]	r_s_data;

	always @(posedge i_clk)
		r_s_cyc <= i_swb_cyc;
	always @(posedge i_clk)
	if (i_reset)
		r_s_stb <= 1'b0;
	else
		r_s_stb <= i_swb_stb;
	always @(posedge i_clk)
		r_s_we  <= i_swb_we;
	always @(posedge i_clk)
		r_s_addr<= i_swb_addr;
	always @(posedge i_clk)
		r_s_data<= i_swb_data;

	assign	s_cyc = r_s_cyc;
	assign	s_stb = r_s_stb;
	assign	s_we  = r_s_we;
	assign	s_addr= r_s_addr;
	assign	s_data= r_s_data;
`else
	assign	s_cyc = i_swb_cyc;
	assign	s_stb = i_swb_stb;
	assign	s_we  = i_swb_we;
	assign	s_addr= i_swb_addr;
	assign	s_data= i_swb_data;
`endif

	reg	[2:0]		dma_state;
	reg			cfg_err, cfg_len_nonzero;
	reg	[(AW-1):0]	cfg_waddr, cfg_raddr, cfg_len;
	reg [(LGMEMLEN-1):0]	cfg_blocklen_sub_one;
	reg			cfg_incs, cfg_incd;
	reg	[(LGDV-1):0]	cfg_dev_trigger;
	reg			cfg_on_dev_trigger;

	// Single block operations: We'll read, then write, up to a single
	// memory block here.

	reg	[(DW-1):0]	dma_mem	[0:(((1<<LGMEMLEN))-1)];
	reg	[(LGMEMLEN):0]	nread, nwritten, nwacks, nracks;
	wire	[(AW-1):0]	bus_nracks;
	assign	bus_nracks = { {(AW-LGMEMLEN-1){1'b0}}, nracks };

	reg	last_read_request, last_read_ack,
		last_write_request, last_write_ack;
	reg	trigger, abort, user_halt;

	initial	dma_state = `DMA_IDLE;
	initial	o_interrupt = 1'b0;
	initial	cfg_blocklen_sub_one = {(LGMEMLEN){1'b1}};
	initial	cfg_on_dev_trigger = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		dma_state <= `DMA_IDLE;
		cfg_on_dev_trigger <= 1'b0;
		cfg_incs  <= 1'b0;
		cfg_incd  <= 1'b0;
	end else case(dma_state)
	`DMA_IDLE: begin
		o_mwb_addr <= cfg_raddr;

		// When the slave wishbone writes, and we are in this 
		// (ready) configuration, then allow the DMA to be controlled
		// and thus to start.
		if ((s_stb)&&(s_we))
		begin
			case(s_addr)
			2'b00: begin
				if ((s_data[27:16] == 12'hfed)
					&&(s_data[31:30] == 2'b00)
						&&(cfg_len_nonzero))
					dma_state <= `DMA_WAIT;
				cfg_blocklen_sub_one
					<= s_data[(LGMEMLEN-1):0]
					+ {(LGMEMLEN){1'b1}};
					// i.e. -1;
				cfg_dev_trigger    <= s_data[14:10];
				cfg_on_dev_trigger <= s_data[15];
				cfg_incs  <= !s_data[29];
				cfg_incd  <= !s_data[28];
				end
			2'b01: begin end // This is done elsewhere
			2'b10: cfg_raddr <=  s_data[(AW+2-1):2];
			2'b11: cfg_waddr <=  s_data[(AW+2-1):2];
			endcase
		end end
	`DMA_WAIT: begin
		o_mwb_addr <= cfg_raddr;
		if (abort)
			dma_state <= `DMA_IDLE;
		else if (user_halt)
			dma_state <= `DMA_IDLE;
		else if (trigger)
			dma_state <= `DMA_READ_REQ;
		end
	`DMA_READ_REQ: begin
		if (!i_mwb_stall)
		begin
			// Number of read acknowledgements needed
			if ((last_read_request)||(user_halt))
	//((nracks == {1'b0, cfg_blocklen_sub_one})||(bus_nracks == cfg_len-1))
				// Wishbone interruptus
				dma_state <= `DMA_READ_ACK;
			if (cfg_incs)
				o_mwb_addr <= o_mwb_addr
						+ {{(AW-1){1'b0}},1'b1};
		end

		if ((i_mwb_err)||(abort))
			dma_state <= `DMA_IDLE;
		else if (i_mwb_ack)
		begin
			if (cfg_incs)
				cfg_raddr  <= cfg_raddr
						+ {{(AW-1){1'b0}},1'b1};
			if (last_read_ack)
				dma_state <= `DMA_PRE_WRITE;
		end end
	`DMA_READ_ACK: begin
		if ((i_mwb_err)||(abort))
			dma_state <= `DMA_IDLE;
		else if (i_mwb_ack)
		begin
			if (last_read_ack) // (nread+1 == nracks)
				dma_state  <= `DMA_PRE_WRITE;
			if (user_halt)
				dma_state <= `DMA_IDLE;
			if (cfg_incs)
				cfg_raddr  <= cfg_raddr
						+ {{(AW-1){1'b0}},1'b1};
		end
		end
	`DMA_PRE_WRITE: begin
		o_mwb_addr <= cfg_waddr;
		dma_state <= (abort)?`DMA_IDLE:`DMA_WRITE_REQ;
		end
	`DMA_WRITE_REQ: begin
		if (!i_mwb_stall)
		begin
			if (last_write_request) // (nwritten == nread-1)
				// Wishbone interruptus
				dma_state <= `DMA_WRITE_ACK;
			if (cfg_incd)
			begin
				o_mwb_addr <= o_mwb_addr
						+ {{(AW-1){1'b0}},1'b1};
				cfg_waddr  <= cfg_waddr
						+ {{(AW-1){1'b0}},1'b1};
			end
		end

		if ((i_mwb_err)||(abort))
			dma_state <= `DMA_IDLE;
		else if ((i_mwb_ack)&&(last_write_ack))
			dma_state <= (cfg_len <= 1)?`DMA_IDLE:`DMA_WAIT;
		else if (!cfg_len_nonzero)
			dma_state <= `DMA_IDLE;
		end
	`DMA_WRITE_ACK: begin
		if ((i_mwb_err)||(abort))
			dma_state <= `DMA_IDLE;
		else if ((i_mwb_ack)&&(last_write_ack))
			// (nwacks+1 == nwritten)
			dma_state <= (cfg_len <= 1)?`DMA_IDLE:`DMA_WAIT;
		else if (!cfg_len_nonzero)
			dma_state <= `DMA_IDLE;
		end
	default:
		dma_state <= `DMA_IDLE;
	endcase

	initial	o_interrupt = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_interrupt <= 1'b0;
	else
		o_interrupt <= ((dma_state == `DMA_WRITE_ACK)&&(i_mwb_ack)
					&&(last_write_ack)
					&&(cfg_len == {{(AW-1){1'b0}},1'b1}))
				||((dma_state != `DMA_IDLE)&&(i_mwb_err));


	initial	cfg_len     = 0;
	initial	cfg_len_nonzero = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		cfg_len <= 0;
		cfg_len_nonzero <= 1'b0;
	end else if ((dma_state == `DMA_IDLE)
			&&(s_stb)&&(s_we)&&(s_addr == 2'b01))
	begin
		cfg_len   <=  s_data[(AW-1):0];
		cfg_len_nonzero <= (|s_data[(AW-1):0]);
	end else if ((o_mwb_cyc)&&(o_mwb_we)&&(i_mwb_ack))
	begin
		cfg_len <= cfg_len - 1'b1;
		cfg_len_nonzero <= (cfg_len > 1);
	end

	initial	nracks   = 0;
	always @(posedge i_clk)
	if (i_reset)
		nracks <= 0;
	else if ((dma_state == `DMA_IDLE)||(dma_state == `DMA_WAIT))
		nracks <= 0;
	else if ((o_mwb_stb)&&(!o_mwb_we)&&(!i_mwb_stall))
		nracks <= nracks + 1'b1;

	initial	nread   = 0;
	always @(posedge i_clk)
	if (i_reset)
		nread <= 0;
	else if ((dma_state == `DMA_IDLE)||(dma_state == `DMA_WAIT))
		nread <= 0;
	else if ((!o_mwb_we)&&(i_mwb_ack))
		nread <= nread + 1'b1;

	initial	nwritten = 0;
	always @(posedge i_clk)
	if (i_reset)
		nwritten <= 0;
	else if ((!o_mwb_cyc)||(!o_mwb_we))
		nwritten <= 0;
	else if ((o_mwb_stb)&&(!i_mwb_stall))
		nwritten <= nwritten + 1'b1;

	initial	nwacks   = 0;
	always @(posedge i_clk)
	if (i_reset)
		nwacks <= 0;
	else if ((!o_mwb_cyc)||(!o_mwb_we))
		nwacks <= 0;
	else if (i_mwb_ack)
		nwacks <= nwacks + 1'b1;

	initial	cfg_err = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		cfg_err <= 1'b0;
	else if (dma_state == `DMA_IDLE)
	begin
		if ((s_stb)&&(s_we)&&(s_addr==2'b00))
			cfg_err <= 1'b0;
	end else if (((i_mwb_err)&&(o_mwb_cyc))||(abort))
		cfg_err <= 1'b1;

	initial	last_read_request = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		last_read_request <= 1'b0;
	else if ((dma_state == `DMA_WAIT)||(dma_state == `DMA_READ_REQ))
	begin
		if ((!i_mwb_stall)&&(dma_state == `DMA_READ_REQ))
		begin
			last_read_request <=
			(nracks + 1 == { 1'b0, cfg_blocklen_sub_one})
				||(bus_nracks == cfg_len-2);
		end else
			last_read_request <=
				(nracks== { 1'b0, cfg_blocklen_sub_one})
				||(bus_nracks == cfg_len-1);
	end else
		last_read_request <= 1'b0;


	wire	[(LGMEMLEN):0]	next_nread;
	assign	next_nread = nread + 1'b1;

	initial	last_read_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		last_read_ack <= 0;
	else if (dma_state == `DMA_READ_REQ)
	begin
		if ((i_mwb_ack)&&((!o_mwb_stb)||(i_mwb_stall)))
			last_read_ack <= (next_nread == { 1'b0, cfg_blocklen_sub_one });
		else
			last_read_ack <= (nread == { 1'b0, cfg_blocklen_sub_one });
	end else if (dma_state == `DMA_READ_ACK)
	begin
		if ((i_mwb_ack)&&((!o_mwb_stb)||(i_mwb_stall)))
			last_read_ack <= (nread+2 == nracks);
		else
			last_read_ack <= (next_nread == nracks);
	end else
		last_read_ack <= 1'b0;

	initial	last_write_request = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		last_write_request <= 1'b0;
	else if (dma_state == `DMA_PRE_WRITE)
		last_write_request <= (nread <= 1);
	else if (dma_state == `DMA_WRITE_REQ)
	begin
		if (i_mwb_stall)
			last_write_request <= (nwritten >= nread-1);
		else
			last_write_request <= (nwritten >= nread-2);
	end else
		last_write_request <= 1'b0;

	initial	last_write_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		last_write_ack <= 1'b0;
	else if((dma_state == `DMA_WRITE_REQ)||(dma_state == `DMA_WRITE_ACK))
	begin
		if ((i_mwb_ack)&&((!o_mwb_stb)||(i_mwb_stall)))
			last_write_ack <= (nwacks+2 == nwritten);
		else
			last_write_ack <= (nwacks+1 == nwritten);
	end else
		last_write_ack <= 1'b0;


	assign	o_mwb_cyc = (dma_state == `DMA_READ_REQ)
			||(dma_state == `DMA_READ_ACK)
			||(dma_state == `DMA_WRITE_REQ)
			||(dma_state == `DMA_WRITE_ACK);

	assign	o_mwb_stb = (dma_state == `DMA_READ_REQ)
			||(dma_state == `DMA_WRITE_REQ);

	assign	o_mwb_we = (dma_state == `DMA_PRE_WRITE)
			||(dma_state == `DMA_WRITE_REQ)
			||(dma_state == `DMA_WRITE_ACK);

	//
	// This is tricky.  In order for Vivado to consider dma_mem to be a 
	// proper memory, it must have a simple address fed into it.  Hence
	// the read_address (rdaddr) register.  The problem is that this
	// register must always be one greater than the address we actually
	// want to read from, unless we are idling.  So ... the math is touchy.
	//
	reg	[(LGMEMLEN-1):0]	rdaddr;

	initial	rdaddr = 0;
	always @(posedge i_clk)
	if (i_reset)
		rdaddr <= 0;
	else if((dma_state == `DMA_IDLE)||(dma_state == `DMA_WAIT)
			||(dma_state == `DMA_WRITE_ACK))
		rdaddr <= 0;
	else if ((dma_state == `DMA_PRE_WRITE)
			||((dma_state==`DMA_WRITE_REQ)&&(!i_mwb_stall)))
		rdaddr <= rdaddr + {{(LGMEMLEN-1){1'b0}},1'b1};

	always @(posedge i_clk)
	if (i_reset)
		o_mwb_data <= 0;
	else if ((dma_state != `DMA_WRITE_REQ)||(!i_mwb_stall))
		o_mwb_data <= dma_mem[rdaddr];
	always @(posedge i_clk)
		if((dma_state == `DMA_READ_REQ)||(dma_state == `DMA_READ_ACK))
			dma_mem[nread[(LGMEMLEN-1):0]] <= i_mwb_data;

	always @(posedge i_clk)
	if (i_reset)
		o_swb_data <= 0;
	else casez(s_addr)
		2'b00: o_swb_data <= {	(dma_state != `DMA_IDLE), cfg_err,
					!cfg_incs, !cfg_incd,
					1'b0, nread,
					cfg_on_dev_trigger, cfg_dev_trigger,
					cfg_blocklen_sub_one
					};
		2'b01: o_swb_data <= { {(DW-AW){1'b0}}, cfg_len  };
		2'b10: o_swb_data <= { {(DW-2-AW){1'b0}}, cfg_raddr, 2'b00 };
		2'b11: o_swb_data <= { {(DW-2-AW){1'b0}}, cfg_waddr, 2'b00 };
	endcase

	// This causes us to wait a minimum of two clocks before starting: One
	// to go into the wait state, and then one while in the wait state to
	// develop the trigger.
	initial	trigger = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		trigger <= 1'b0;
	else
		trigger <=  (dma_state == `DMA_WAIT)
				&&((!cfg_on_dev_trigger)
					||(i_dev_ints[cfg_dev_trigger]));

	// Ack any access.  We'll quietly ignore any access where we are busy,
	// but ack it anyway.  In other words, before writing to the device,
	// double check that it isn't busy, and then write.
	initial	o_swb_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_swb_ack <= 1'b0;
	else if (!i_swb_cyc)
		o_swb_ack <= 1'b0;
	else
		o_swb_ack <= (s_stb);

	assign	o_swb_stall = 1'b0;

	initial	abort = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		abort <= 1'b0;
	else if (dma_state == `DMA_IDLE)
		abort <= 1'b0;
	else
		abort <= ((s_stb)&&(s_we)
			&&(s_addr == 2'b00)
			&&(s_data == 32'hffed0000));

	initial	user_halt = 1'b0;
	always @(posedge i_clk)
		user_halt <= ((user_halt)&&(dma_state != `DMA_IDLE))
			||((s_stb)&&(s_we)&&(dma_state != `DMA_IDLE)
				&&(s_addr == 2'b00)
				&&(s_data == 32'hafed0000));


	// Make verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = s_cyc;
	// verilator lint_on  UNUSED
`ifdef	FORMAL
// The formal properties for this module are maintained elsewhere
`endif
endmodule
