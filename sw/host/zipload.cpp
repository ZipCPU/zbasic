////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	zipload.cpp
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	To load a program for the ZipCPU into memory, whether flash
//		or SDRAM.  This requires a working/running configuration
//	in order to successfully load.
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
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "llcomms.h"
#include "ttybus.h"
#include <design.h>
#include "regdefs.h"

#ifdef	FLASH_ACCESS
#include "flashdrvr.h"
#endif
#include "zipelf.h"
#include "byteswap.h"

FPGA	*m_fpga;

void	usage(void) {
	printf("USAGE: zipload [-hr] <zip-program-file>\n");
	printf("\n"
"\t-h\tDisplay this usage statement\n"
"\t-r\tStart the ZipCPU running from the address in the program file\n");
}

int main(int argc, char **argv) {
#ifndef	R_ZIPCTRL
	fprintf(stderr, "This design doesn\'t seem to contain a ZipCPU\n");
	return	EXIT_FAILURE;
#else
	int		skp=0;
	bool		start_when_finished = false, verbose = false;
	unsigned	entry = 0;
#ifdef	FLASH_ACCESS
	FLASHDRVR	*flash = NULL;
#endif
	const char	*bitfile = NULL, *altbitfile = NULL, *execfile = NULL;

	if (argc < 2) {
		usage();
		exit(EXIT_SUCCESS);
	}

	skp=1;
	for(int argn=0; argn<argc-skp; argn++) {
		if (argv[argn+skp][0] == '-') {
			switch(argv[argn+skp][1]) {
			case 'h':
				usage();
				exit(EXIT_SUCCESS);
				break;
			case 'r':
				start_when_finished = true;
				break;
			case 'v':
				verbose = true;
				break;
			default:
				fprintf(stderr, "Unknown option, -%c\n\n",
					argv[argn+skp][0]);
				usage();
				exit(EXIT_FAILURE);
				break;
			} skp++; argn--;
		} else {
			// Anything here must be either the program to load,
			// or a bit file to load
			argv[argn] = argv[argn+skp];
		}
	} argc -= skp;


	for(int argn=0; argn<argc; argn++) {
		if (iself(argv[argn])) {
			if (execfile) {
				printf("Too many executable files given, %s and %s\n", execfile, argv[argn]);
				usage();
				exit(EXIT_FAILURE);
			} execfile = argv[argn];
		} else { // if (isbitfile(argv[argn]))
			if (!bitfile)
				bitfile = argv[argn];
			else if (!altbitfile)
				altbitfile = argv[argn];
			else {
				printf("Unknown file name or too many files, %s\n", argv[argn]);
				usage();
				exit(EXIT_FAILURE);
			}
		}
	}

	if ((execfile == NULL)&&(bitfile == NULL)) {
		printf("No executable or bit file(s) given!\n\n");
		usage();
		exit(EXIT_FAILURE);
	}

	if ((bitfile)&&(access(bitfile,R_OK)!=0)) {
		// If there's no code file, or the code file cannot be opened
		fprintf(stderr, "Cannot open bitfile, %s\n", bitfile);
		exit(EXIT_FAILURE);
	}

	if ((altbitfile)&&(access(altbitfile,R_OK)!=0)) {
		// If there's no code file, or the code file cannot be opened
		fprintf(stderr, "Cannot open alternate bitfile, %s\n", altbitfile);
		exit(EXIT_FAILURE);
	}

	if ((execfile)&&(access(execfile,R_OK)!=0)) {
		// If there's no code file, or the code file cannot be opened
		fprintf(stderr, "Cannot open executable, %s\n", execfile);
		exit(EXIT_FAILURE);
	}

	const char *codef = (argc>0)?argv[0]:NULL;
#ifdef	FLASH_ACCESS
	char	*fbuf = new char[FLASHLEN];

	// Set the flash buffer to all ones
	memset(fbuf, -1, FLASHLEN);
#endif

	if (verbose)
		fprintf(stderr, "ZipLoad: Verbose mode on\n");
	FPGAOPEN(m_fpga);

	// Make certain we can talk to the FPGA
	try {
		unsigned v  = m_fpga->readio(R_VERSION);
		if (v < 0x20170000) {
			fprintf(stderr, "Could not communicate with board (invalid version)\n");
			exit(EXIT_FAILURE);
		}
	} catch(BUSERR b) {
		fprintf(stderr, "Could not communicate with board (BUSERR when reading VERSION)\n");
		exit(EXIT_FAILURE);
	}

	// Halt the CPU
	try {
		printf("Halting the CPU\n");
		m_fpga->writeio(R_ZIPCTRL, CPU_HALT|CPU_RESET);
	} catch(BUSERR b) {
		fprintf(stderr, "Could not halt the CPU (BUSERR)\n");
		exit(EXIT_FAILURE);
	}

#ifdef	FLASH_ACCESS
	flash = new FLASHDRVR(m_fpga);
#else
	flash = NULL;
#endif

	if (codef) try {
		ELFSECTION	**secpp = NULL, *secp;
#ifdef	FLASH_ACCESS
		unsigned	startaddr = RESET_ADDRESS;
		unsigned	codelen = 0;
#endif


		if(iself(codef)) {
			// zip-readelf will help with both of these ...
			elfread(codef, entry, secpp);
		} else {
			fprintf(stderr, "ERR: %s is not in ELF format\n", codef);
			exit(EXIT_FAILURE);
		}

		printf("Loading: %s\n", codef);
		// assert(secpp[1]->m_len = 0);
		for(int i=0; secpp[i]->m_len; i++) {
			bool	valid = false;
			secp=  secpp[i];

			// Make sure our section is either within block RAM
#ifdef	BKRAM_ACCESS
			if ((secp->m_start >= BKRAMBASE)
				&&(secp->m_start+secp->m_len
						<= BKRAMBASE+BKRAMLEN))
				valid = true;
#endif

#ifdef	FLASH_ACCESS
			// Flash
			if ((secp->m_start >= RESET_ADDRESS)
				&&(secp->m_start+secp->m_len
						<= FLASHBASE+FLASHLEN))
				valid = true;
#endif

#ifdef	SDRAM_ACCESS
			// Or SDRAM
			if ((secp->m_start >= RAMBASE)
				&&(secp->m_start+secp->m_len
						<= RAMBASE+RAMLEN))
				valid = true;
#endif
			if (!valid) {
				fprintf(stderr, "No such memory on board: 0x%08x - %08x\n",
					secp->m_start, secp->m_start+secp->m_len);
				exit(EXIT_FAILURE);
			}
		}

		for(int i=0; secpp[i]->m_len; i++) {
			secp = secpp[i];

#ifdef	SDRAM_ACCESS
			if ((secp->m_start >= RAMBASE)
				&&(secp->m_start+secp->m_len
						<= RAMBASE+RAMLEN)) {
				if (verbose)
					printf("Writing to MEM: %08x-%08x\n",
						secp->m_start,
						secp->m_start+secp->m_len);
				unsigned ln = (secp->m_len+3)&-4;
				uint32_t	*bswapd = new uint32_t[ln>>2];
				if (ln != (secp->m_len&-4))
					memset(bswapd, 0, ln);
				memcpy(bswapd, secp->m_data,  ln);
				byteswapbuf(ln>>2, bswapd);
				m_fpga->writei(secp->m_start, ln>>2, bswapd);

				continue;
			}
#endif

#ifdef	BKRAM_ACCESS
			if ((secp->m_start >= BKRAMBASE)
				  &&(secp->m_start+secp->m_len
						<= BKRAMBASE+BKRAMLEN)) {
				if (verbose)
					printf("Writing to MEM: %08x-%08x\n",
						secp->m_start,
						secp->m_start+secp->m_len);
				unsigned ln = (secp->m_len+3)&-4;
				uint32_t	*bswapd = new uint32_t[ln>>2];
				if (ln != (secp->m_len&-4))
					memset(bswapd, 0, ln);
				memcpy(bswapd, secp->m_data,  ln);
				byteswapbuf(ln>>2, bswapd);
				m_fpga->writei(secp->m_start, ln>>2, bswapd);
				continue;
			}
#endif

#ifdef	FLASH_ACCESS
			if ((secp->m_start >= FLASHBASE)
				  &&(secp->m_start+secp->m_len
						<= FLASHBASE+FLASHLEN)) {
				// Otherwise writing to flash
				if (secp->m_start < startaddr) {
					// Keep track of the first address in
					// flash, as well as the last address
					// that we will write
					codelen += (startaddr-secp->m_start);
					startaddr = secp->m_start;
				} if (secp->m_start+secp->m_len > startaddr+codelen) {
					codelen = secp->m_start+secp->m_len-startaddr;
				} if (verbose)
					printf("Sending to flash: %08x-%08x\n",
						secp->m_start,
						secp->m_start+secp->m_len);

				// Copy this data into our copy of what we want
				// the flash to look like.
				memcpy(&fbuf[secp->m_start-FLASHBASE],
					secp->m_data, secp->m_len);
			}
#endif
		}

#ifdef	FLASH_ACCESS
		if ((flash)&&(codelen>0)&&(!flash->write(startaddr, codelen, &fbuf[startaddr-FLASHBASE], true))) {
			fprintf(stderr, "ERR: Could not write program to flash\n");
			exit(EXIT_FAILURE);
		} else if ((!flash)&&(codelen > 0)) {
			fprintf(stderr, "ERR: Cannot write to flash: Driver didn\'t load\n");
			// fprintf(stderr, "flash->write(%08x, %d, ... );\n", startaddr,
			//	codelen);
		}
#endif

		if (m_fpga) m_fpga->readio(R_VERSION); // Check for bus errors

		// Now ... how shall we start this CPU?
		printf("Clearing the CPUs registers\n");
		for(int i=0; i<32; i++) {
			m_fpga->writeio(R_ZIPCTRL, CPU_HALT|i);
			m_fpga->writeio(R_ZIPDATA, 0);
		}

		m_fpga->writeio(R_ZIPCTRL, CPU_HALT|CPU_CLRCACHE);
		printf("Setting PC to %08x\n", entry);
		m_fpga->writeio(R_ZIPCTRL, CPU_HALT|CPU_sPC);
		m_fpga->writeio(R_ZIPDATA, entry);

		if (start_when_finished) {
			printf("Starting the CPU\n");
			m_fpga->writeio(R_ZIPCTRL, CPU_GO|CPU_sPC);
		} else {
			printf("The CPU should be fully loaded, you may now\n");
			printf("start it (from reset/reboot) with:\n");
			printf("> wbregs cpu 0x0f\n");
			printf("\n");
		}
	} catch(BUSERR a) {
		fprintf(stderr, "ZBASIC-BUS error: %08x\n", a.addr);
		exit(-2);
	}

	printf("CPU Status is: %08x\n", m_fpga->readio(R_ZIPCTRL));
	if (m_fpga) delete	m_fpga;

	return EXIT_SUCCESS;
#endif
}

