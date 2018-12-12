////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	flashdrvr.cpp
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	Flash driver.  Encapsulates the erasing and programming (i.e.
//		writing) necessary to set the values in a flash device.
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
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "regdefs.h"
#include "devbus.h"
#include "nflashdrvr.h"
#include "byteswap.h"

void	FLASHDRVR::take_offline(void) {
	take_offline(m_fpga);
}

void	FLASHDRVR::take_offline(DEVBUS *fpga) {

	fpga->writeio(R_FLASHCFG, F_END);
	fpga->writeio(R_FLASHCFG, F_RESET);
	fpga->writeio(R_FLASHCFG, F_RESET);
	fpga->writeio(R_FLASHCFG, F_END);
}

void	FLASHDRVR::restore_quadio(void) {
	restore_quadio(m_fpga);
}

void	FLASHDRVR::restore_quadio(DEVBUS *fpga) {
	//static const	uint32_t	DUAL_IO_READ     = CFG_USERMODE|0xbb;
	static	const	uint32_t	QUAD_IO_READ     = CFG_USERMODE|0xeb;

	fpga->writeio(R_FLASHCFG, QUAD_IO_READ);
	// 3 address bytes
	fpga->writeio(R_FLASHCFG, CFG_USERMODE | CFG_QSPEED | CFG_WEDIR);
	fpga->writeio(R_FLASHCFG, CFG_USERMODE | CFG_QSPEED | CFG_WEDIR);
	fpga->writeio(R_FLASHCFG, CFG_USERMODE | CFG_QSPEED | CFG_WEDIR);
	// Mode byte
	fpga->writeio(R_FLASHCFG, CFG_USERMODE | CFG_QSPEED | CFG_WEDIR | 0xa0);
	// Read a dummy byte
	fpga->writeio(R_FLASHCFG, CFG_USERMODE | CFG_QSPEED );
	// Read two valid bytes to throw away
	fpga->writeio(R_FLASHCFG, CFG_USERMODE | CFG_QSPEED );
	fpga->writeio(R_FLASHCFG, CFG_USERMODE | CFG_QSPEED );
	// Close the interface
	fpga->writeio(R_FLASHCFG, CFG_USER_CS_n);
}

void	FLASHDRVR::flwait(void) {
	const	int	WIP = 1;	// Write in progress bit
	DEVBUS::BUSW	sr;

	m_fpga->writeio(R_FLASHCFG, F_END);
	m_fpga->writeio(R_FLASHCFG, F_RDSR1);
	do {
		m_fpga->writeio(R_FLASHCFG, F_EMPTY);
		sr = m_fpga->readio(R_FLASHCFG);
	} while(sr&WIP);
	m_fpga->writeio(R_FLASHCFG, F_END);
}

bool	FLASHDRVR::erase_sector(const unsigned sector, const bool verify_erase) {
	unsigned	flashaddr = sector & 0x0ffffff;

	take_offline();

	// Write enable
	m_fpga->writeio(R_FLASHCFG, F_END);
	m_fpga->writeio(R_FLASHCFG, F_WREN);
	m_fpga->writeio(R_FLASHCFG, F_END);

	DEVBUS::BUSW	page[SZPAGEW];

	// printf("EREG before   : %08x\n", m_fpga->readio(R_QSPI_EREG));
	printf("Erasing sector: %06x\n", flashaddr);

	m_fpga->writeio(R_FLASHCFG, F_SE);
	m_fpga->writeio(R_FLASHCFG, CFG_USERMODE | ((flashaddr>>16)&0x0ff));
	m_fpga->writeio(R_FLASHCFG, CFG_USERMODE | ((flashaddr>> 8)&0x0ff));
	m_fpga->writeio(R_FLASHCFG, CFG_USERMODE | ((flashaddr    )&0x0ff));
	m_fpga->writeio(R_FLASHCFG, F_END);

	// Wait for the erase to complete
	flwait();

	// Turn quad-mode read back on, so we can read next
	restore_quadio();

	// Now, let's verify that we erased the sector properly
	if (verify_erase) {
		if (m_debug)
			printf("Verifying the erase\n");
		for(int i=0; i<NPAGES; i++) {
			printf("READI[%08x + %04x]\n", R_FLASH+flashaddr+i*SZPAGEB, SZPAGEW);
			m_fpga->readi(R_FLASH+flashaddr+i*SZPAGEB, SZPAGEW, page);
			for(int j=0; j<SZPAGEW; j++)
				if (page[j] != 0xffffffff) {
					unsigned rdaddr = R_FLASH+flashaddr+i*SZPAGEB;
					
					if (m_debug)
						printf("FLASH[%07x] = %08x, not 0xffffffff as desired (%06x + %d)\n",
							R_FLASH+flashaddr+i*SZPAGEB+(j<<2),
							page[j], rdaddr,(j<<2));
					return false;
				}
		}
		if (m_debug)
			printf("Erase verified\n");
	}

	return true;
}

bool	FLASHDRVR::page_program(const unsigned addr, const unsigned len,
		const char *data, const bool verify_write) {
	DEVBUS::BUSW	buf[SZPAGEW], bswapd[SZPAGEW];
	unsigned	flashaddr = addr & 0x0ffffff;

	take_offline();

	assert(len > 0);
	assert(len <= PGLENB);
	assert(PAGEOF(addr)==PAGEOF(addr+len-1));

	if (len <= 0)
		return true;

	bool	empty_page = true;
	for(unsigned i=0; i<len; i+=4) {
		DEVBUS::BUSW v;
		v = buildword((const unsigned char *)&data[i]);
		bswapd[(i>>2)] = v;
		if (v != 0xffffffff)
			empty_page = false;
	}

	if (!empty_page) {
		// Write enable
		m_fpga->writeio(R_FLASHCFG, F_END);
		m_fpga->writeio(R_FLASHCFG, F_WREN);
		m_fpga->writeio(R_FLASHCFG, F_END);

		//
		// Write the page
		//

		// Issue the command
		m_fpga->writeio(R_FLASHCFG, F_PP);
		// The address
		m_fpga->writeio(R_FLASHCFG, CFG_USERMODE|((flashaddr>>16)&0x0ff));
		m_fpga->writeio(R_FLASHCFG, CFG_USERMODE|((flashaddr>> 8)&0x0ff));
		m_fpga->writeio(R_FLASHCFG, CFG_USERMODE|((flashaddr    )&0x0ff));

		// Write the page data itself
		for(unsigned i=0; i<len; i++)
			m_fpga->writeio(R_FLASHCFG, 
				CFG_USERMODE | CFG_WEDIR
				| (data[i] & 0x0ff));
		m_fpga->writeio(R_FLASHCFG, F_END);

		printf("Writing page: 0x%08x - 0x%08x", addr, addr+len-1);
		if ((m_debug)&&(verify_write))
			fflush(stdout);
		else
			printf("\n");

		flwait();
	}

	restore_quadio();
	if (verify_write) {

		// printf("Attempting to verify page\n");
		// NOW VERIFY THE PAGE
		m_fpga->readi(addr, len>>2, buf);
		for(unsigned i=0; i<(len>>2); i++) {
			if (buf[i] != bswapd[i]) {
				printf("\nVERIFY FAILS[%d]: %08x\n", i, (i<<2)+addr);
				printf("\t(Flash[%d]) %08x != %08x (Goal[%08x])\n", 
					(i<<2), buf[i], bswapd[i], (i<<2)+addr);
				return false;
			}
		} if (m_debug)
			printf(" -- Successfully verified\n");
	} return true;
}

bool	FLASHDRVR::write(const unsigned addr, const unsigned len,
		const char *data, const bool verify) {

	// Work through this one sector at a time.
	// If this buffer is equal to the sector value(s), go on
	// If not, erase the sector

	for(unsigned s=SECTOROF(addr); s<SECTOROF(addr+len+SECTORSZB-1);
			s+=SECTORSZB) {
		// Do we need to erase?
		bool	need_erase = false, need_program = false;
		unsigned newv = 0; // (s<addr)?addr:s;
		{
			char *sbuf = new char[SECTORSZB];
			const char *dp;	// pointer to our "desired" buffer
			unsigned	base,ln;

			base = (addr>s)?addr:s;
			ln=((addr+len>s+SECTORSZB)?(s+SECTORSZB):(addr+len))-base;
			m_fpga->readi(base, ln>>2, (uint32_t *)sbuf);
			byteswapbuf(ln>>2, (uint32_t *)sbuf);

			dp = &data[base-addr];

			for(unsigned i=0; i<ln; i++) {
				if ((sbuf[i]&dp[i]) != dp[i]) {
					if (m_debug) {
						printf("\nNEED-ERASE @0x%08x ... %08x != %08x (Goal)\n", 
							i+base-addr, sbuf[i], dp[i]);
					}
					need_erase = true;
					newv = (i&-4)+base;
					break;
				} else if ((sbuf[i] != dp[i])&&(newv == 0))
					newv = (i&-4)+base;
			}
		}

		if (newv == 0)
			continue; // This sector already matches

		// Erase the sector if necessary
		if (!need_erase) {
			if (m_debug) printf("NO ERASE NEEDED\n");
		} else {
			printf("ERASING SECTOR: %08x\n", s);
			if (!erase_sector(s, verify)) {
				printf("SECTOR ERASE FAILED!\n");
				return false;
			} newv = (s<addr) ? addr : s;
		}

		// Now walk through all of our pages in this sector and write
		// to them.
		for(unsigned p=newv; (p<s+SECTORSZB)&&(p<addr+len); p=PAGEOF(p+PGLENB)) {
			unsigned start = p, len = addr+len-start;

			// BUT! if we cross page boundaries, we need to clip
			// our results to the page boundary
			if (PAGEOF(start+len-1)!=PAGEOF(start))
				len = PAGEOF(start+PGLENB)-start;
			if (!page_program(start, len, &data[p-addr], verify)) {
				printf("WRITE-PAGE FAILED!\n");
				return false;
			}
		} if ((need_erase)||(need_program))
			printf("Sector 0x%08x: DONE%15s\n", s, "");
	}

	take_offline();

	m_fpga->writeio(R_FLASHCFG, F_WRDI);
	m_fpga->writeio(R_FLASHCFG, F_END);

	restore_quadio();

	return true;
}
