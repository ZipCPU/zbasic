////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	zipstate.cpp
// {{{
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	To get a quick (understandable) peek at what the ZipCPU
//		is up to without stopping the CPU.  This is basically
//	identical to a "wbregs cpu" command, save that the bit fields of the
//	result are broken out into something more human readable.
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
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "llcomms.h"
#include "regdefs.h"
#include "ttybus.h"

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

/*
unsigned int	cmd_read(FPGA *fpga, int r) {
	const unsigned int	MAXERR = 1000;
	unsigned int	errcount = 0;
	unsigned int	s;

	return	fpga->readio(R_ZIPCTRL, CPU_REGBASE + (r*4));
}
*/

void	read_regs(FPGA *fpga, unsigned *r) {
	fpga->readi(R_ZIPREGS, 32, r);
}

void	usage(void) {
	printf("USAGE: zipstate\n");
}

int main(int argc, char **argv) {
	bool	long_state = false;
	unsigned int	v;
	int	skp;

	skp=1;
	for(int argn=0; argn<argc-skp; argn++) {
		if (argv[argn+skp][0] == '-') {
			if (argv[argn+skp][1] == 'l')
				long_state = true;
			skp++; argn--;
		} else
			argv[argn] = argv[argn+skp];
	} argc -= skp;

	FPGAOPEN(m_fpga);

	if (!long_state) {
		v = m_fpga->readio(R_ZIPCTRL);

		printf("0x%08x: ", v);
		if (v & 0x0040) printf("RESET ");
		if (v & 0x0080) printf("PINT ");
		// if (v & 0x0100) printf("STEP "); // self resetting
		if((v & 0x00200)==0) printf("HALTED ");
		if (v & 0x00400) printf("HALT_REQ ");
		// if (v & 0x0800) printf("CLR-CACHE ");
		if((v & 0x03000)==0x01000) {
			printf("SW-HALT");
		} else {
			if (v & 0x01000) printf("SLEEPING ");
			if (v & 0x02000) printf("GIE(UsrMode) ");
		}
		if (v & 0x04000) printf("sBusErr ");
		if (v & 0x08000) printf("BREAK-HALT");
		printf("\n");
	} else {
		unsigned	r[32];

		printf("Reading the long-state ...\n"); fflush(stdout);
		read_regs(m_fpga, r);
		for(int i=0; i<14; i++) {
			printf("sR%-2d: 0x%08x ", i, r[i]);
			if ((i&3)==3)
				printf("\n");
		} printf("sCC : 0x%08x ", r[14]);
		printf("sPC : 0x%08x ", r[15]);
		printf("\n\n"); 

		for(int i=0; i<14; i++) {
			printf("uR%-2d: 0x%08x ", i, r[i+16]);
			if ((i&3)==3)
				printf("\n");
		} printf("uCC : 0x%08x ", r[14]);
		printf("uPC : 0x%08x ", r[15]);
		printf("\n\n"); 
	}

	delete	m_fpga;
}

