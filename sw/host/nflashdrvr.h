////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	flashdrvr.h
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	Flash driver.  Encapsulates writing, both erasing sectors and
//		the programming pages, to the flash device.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2018, Gisselquist Technology, LLC
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
//
#ifndef	FLASHDRVR_H
#define	FLASHDRVR_H

#include "regdefs.h"

#define	CFG_USERMODE	(1<<12)
#define	CFG_QSPEED	(1<<11)
// #define	CFG_DSPEED (1<<10) // This controller  doesn't support DUAL
#define	CFG_WEDIR	(1<<9)
#define	CFG_USER_CS_n	(1<<8)

static const unsigned	F_RESET = (CFG_USERMODE|0x0ff),
			F_EMPTY = (CFG_USERMODE|0x000),
			F_WRR   = (CFG_USERMODE|0x001),
			F_PP    = (CFG_USERMODE|0x002),
			F_QPP   = (CFG_USERMODE|0x032),
			F_READ  = (CFG_USERMODE|0x003),
			F_WRDI  = (CFG_USERMODE|0x004),
			F_RDSR1 = (CFG_USERMODE|0x005),
			F_WREN  = (CFG_USERMODE|0x006),
			F_MFRID = (CFG_USERMODE|0x09f),
			F_SE    = (CFG_USERMODE|0x0d8),
			F_END   = (CFG_USERMODE|CFG_USER_CS_n);

class	FLASHDRVR {
private:
	DEVBUS	*m_fpga;
	bool	m_debug;

	//
	void	take_offline(void);
	void	place_online(void);
	void	restore_dualio(void);
	void	restore_quadio(void);
	static void restore_dualio(DEVBUS *fpga);
	static void restore_quadio(DEVBUS *fpga);
	//
	bool	verify_config(void);
	void	set_config(void);
	void	flwait(void);
public:
	FLASHDRVR(DEVBUS *fpga) : m_fpga(fpga), m_debug(true) {}
	bool	erase_sector(const unsigned sector, const bool verify_erase=true);
	bool	page_program(const unsigned addr, const unsigned len,
			const char *data, const bool verify_write=true);
	bool	write(const unsigned addr, const unsigned len,
			const char *data, const bool verify=false);

	unsigned	flashid(void);

	static void take_offline(DEVBUS *fpga);
	static void place_online(DEVBUS *fpga);
};

#endif
