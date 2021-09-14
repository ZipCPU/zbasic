////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	memsim.h
// {{{
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	This creates a memory like device to act on a WISHBONE bus.
//		It doesn't exercise the bus thoroughly, but does give some
//	exercise to the bus to see whether or not the bus master can control
//	it.
//
//	This particular version differs from the memsim version within the
//	ZipCPU project in that there is a variable delay from request to
//	completion.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2021, Gisselquist Technology, LLC
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
// }}}
#ifndef	MEMSIM_H
#define	MEMSIM_H

class	MEMSIM {
public:	
	typedef	unsigned int	BUSW;
	typedef	unsigned char	uchar;

	BUSW	*m_mem, m_len, m_mask, m_head, m_tail, m_delay_mask, m_delay;
	int	*m_fifo_ack;
	BUSW	*m_fifo_data;
	

	MEMSIM(const unsigned int nwords, const unsigned int delay=27);
	~MEMSIM(void);
	void	load(const char *fname);
	void	load(const unsigned int addr, const char *buf,const size_t len);
	void	apply(const uchar wb_cyc, const uchar wb_stb,
				const uchar wb_we,
			const BUSW wb_addr, const BUSW wb_data,
				const uchar wb_sel,
			uchar &o_ack, uchar &o_stall, BUSW &o_data);
	void	operator()(const uchar wb_cyc, const uchar wb_stb,
				const uchar wb_we,
			const BUSW wb_addr, const BUSW wb_data,
				const uchar wb_sel,
			uchar &o_ack, uchar &o_stall, BUSW &o_data) {
		apply(wb_cyc, wb_stb, wb_we, wb_addr, wb_data, wb_sel, o_ack, o_stall, o_data);
	}
	BUSW &operator[](const BUSW addr) { return m_mem[addr&m_mask]; }
};

#endif
