////////////////////////////////////////////////////////////////////////////////
//
// Filename:	automaster_tb.cpp
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	This file calls and accesses the main.v function via the
//		MAIN_TB class found in main_tb.cpp.  When put together with
//	the other components here, this file will simulate (all of) the
//	host's interaction with the FPGA circuit board.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
#include <signal.h>
#include <time.h>
#include <ctype.h>
#include <string.h>
#include <stdint.h>

#include "verilated.h"
#include "design.h"
#include "cpudefs.h"

#include "testb.h"
// #include "twoc.h"

#include "port.h"

#include "main_tb.cpp"

void	usage(void) {
	fprintf(stderr, "USAGE: main_tb <options> [zipcpu-elf-file]\n");
	fprintf(stderr,
#ifdef	SDSPI_ACCESS
"\t-c <img-file>\n"
"\t\tSpecifies a memory image which will be used to make the SD-card\n"
"\t\tmore realistic.  Reads from the SD-card will be directed to\n"
"\t\t\"sectors\" within this image.\n\n"
#endif
"\t-d\tSets the debugging flag\n"
"\t-t <filename>\n"
"\t\tTurns on tracing, sends the trace to <filename>--assumed to\n"
"\t\tbe a vcd file\n"
);
}

int	main(int argc, char **argv) {
	const	char *elfload = NULL,
#ifdef	SDSPI_ACCESS
			*sdimage_file = NULL,
#endif
			*trace_file = NULL; // "trace.vcd";
	bool	debug_flag = false, willexit = false;
//	int	fpga_port = FPGAPORT, serial_port = -(FPGAPORT+1);
//	int	copy_comms_to_stdout = -1;
#ifdef	OLEDSIM_H
	Gtk::Main	main_instance(argc, argv);
#endif
	Verilated::commandArgs(argc, argv);
	MAINTB	*tb = new MAINTB;

	for(int argn=1; argn < argc; argn++) {
		if (argv[argn][0] == '-') for(int j=1;
					(j<512)&&(argv[argn][j]);j++) {
			switch(tolower(argv[argn][j])) {
#ifdef	SDSPI_ACCESS
			case 'c': sdimage_file = argv[++argn]; j = 1000; break;
#endif
			case 'd': debug_flag = true;
				if (trace_file == NULL)
					trace_file = "trace.vcd";
				break;
			// case 'p': fpga_port = atoi(argv[++argn]); j=1000; break;
			// case 's': serial_port=atoi(argv[++argn]); j=1000; break;
			case 't': trace_file = argv[++argn]; j=1000; break;
			case 'h': usage(); exit(0); break;
			default:
				fprintf(stderr, "ERR: Unexpected flag, -%c\n\n",
					argv[argn][j]);
				usage();
				break;
			}
		} else if (iself(argv[argn])) {
			elfload = argv[argn];
		} else if (0 == access(argv[argn], R_OK)) {
			sdimage_file = argv[argn];
		} else {
			fprintf(stderr, "ERR: Cannot read %s\n", argv[argn]);
			perror("O/S Err:");
			exit(EXIT_FAILURE);
		}
	}

	if (elfload) {
		/*
		if (serial_port < 0)
			serial_port = 0;
		if (copy_comms_to_stdout < 0)
			copy_comms_to_stdout = 0;
		tb = new TESTBENCH(fpga_port, serial_port,
			(copy_comms_to_stdout)?true:false, debug_flag);
		*/
		willexit = true;
	} else {
		/*
		if (serial_port < 0)
			serial_port = -serial_port;
		if (copy_comms_to_stdout < 0)
			copy_comms_to_stdout = 1;
		tb = new TESTBENCH(fpga_port, serial_port,
			(copy_comms_to_stdout)?true:false, debug_flag);
		*/
	}

	if (debug_flag) {
		printf("Opening design with\n");
		printf("\tDebug Access port = %d\n", FPGAPORT); // fpga_port);
		printf("\tSerial Console    = %d\n", FPGAPORT+1);
		/*
		printf("\tDebug comms will%s be copied to the standard output%s.",
			(copy_comms_to_stdout)?"":" not",
			((copy_comms_to_stdout)&&(serial_port == 0))
			? " as well":"");
		*/
		printf("\tVCD File         = %s\n", trace_file);
		if (elfload)
			printf("\tELF File         = %s\n", elfload);
	} if (trace_file)
		tb->opentrace(trace_file);

	tb->reset();
#ifdef	SDSPI_ACCESS
	tb->setsdcard(sdimage_file);
#endif

	if (elfload) {
		fprintf(stderr, "WARNING: Elf loading currently only works for programs starting at the reset address\n");
		tb->loadelf(elfload);

		tb->m_core->cpu_cmd_halt = 0;
		tb->m_core->VVAR(_swic__DOT__cmd_reset) = 0;
	}

	if (willexit) {
		while(!tb->done())
			tb->tick();
	} else
		while(true)
			tb->tick();

	tb->close();
	delete tb;

	return	EXIT_SUCCESS;
}

