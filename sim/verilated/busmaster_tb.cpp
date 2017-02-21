////////////////////////////////////////////////////////////////////////////////
//
// Filename:	busmaster_tb.cpp
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	This is piped version of the testbench for the busmaster
//		verilog code.  The busmaster code is designed to be a complete
//	code set implementing all of the functionality of the XESS XuLA2
//	development board.  If done well, the programs talking to this one
//	should be able to talk to the board and apply the same tests to the
//	board itself.
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
#include "Vbusmaster.h"

#include "testb.h"
// #include "twoc.h"
#include "pipecmdr.h"
#include "qspiflashsim.h"
#include "sdspisim.h"
#include "uartsim.h"

#include "zipelf.h"
#include "port.h"

#define LGMEMSZ		28
#define LGFLASHSZ	24

#define FLASH_ADDRESS	(1<<(LGFLASHSZ))
#define FLASH_LENGTH	(1<<(LGFLASHSZ))
#define RAM_ADDRESS	(1<<(LGMEMSZ))
#define RAM_LENGTH	(1<<(LGMEMSZ))

// Add a reset line, since Vbusmaster doesn't have one
class	Vbusmasterr : public Vbusmaster {
public:
	int	i_rst;
	virtual	~Vbusmasterr() {}
};

#ifdef	DEBUG_ACCESS
#define	PARENT	PIPECMDR<Vbusmasterr>
#define	PARENTINIT	PIPECMDR(FPGAPORT),
#define	UARTPORT	(FPGAPORT+1)
#else
#define	PARENT	TESTB<Vbusmasterr>
#define	PARENTINIT
#define	UARTPORT	0
#endif


#define	CC_CLRCACHE	(1<<14)
#define	CC_PHASE_BIT	(1<<13)
#define	CC_PHASE	(1<<13)
#define	CC_FPUERR	(1<<12)
#define	CC_DIVERR	(1<<11)
#define	CC_BUSERR	(1<<10)
#define	CC_TRAP		(1<<9)
#define	CC_ILL		(1<<8)
#define	CC_BREAK	(1<<7)
#define	CC_STEP		(1<<6)
#define	CC_GIE		(1<<5)
#define	CC_SLEEP	(1<<4)
#define	CC_V		(1<<3)
#define	CC_N		(1<<2)
#define	CC_C		(1<<1)
#define	CC_Z		(1   )


// No particular "parameters" need definition or redefinition here.
class	BUSMASTER_TB : public PARENT {
public:
	unsigned long	m_tx_busy_count;
	QSPIFLASHSIM	m_flash;
	// SDSPISIM	m_sdcard;
	unsigned	m_last_led, m_last_pic, m_last_tx_state;
	time_t		m_start_time;
	bool		m_last_writeout;
	UARTSIM		m_uart;
	int		m_last_bus_owner, m_busy;
	bool		m_done;
	int		m_bomb;

	BUSMASTER_TB(void) : PARENTINIT m_uart(UARTPORT) {
		m_start_time = time(NULL);
		m_last_pic = 0;
		m_last_tx_state = 0;
		m_done = false;
		m_bomb = 0;
	}

	void	reset(void) {
		m_core->i_clk = 1;
		m_core->eval();
	}

	void	trace(const char *vcd_trace_file_name) {
		fprintf(stderr, "Opening TRACE(%s)\n", vcd_trace_file_name);
		opentrace(vcd_trace_file_name);
	}

	void	close(void) {
		TESTB<Vbusmasterr>::closetrace();
	}

/*
	void	setsdcard(const char *fn) {
		m_sdcard.load(fn);
	
		printf("LOADING SDCARD FROM: \'%s\'\n", fn);
	}
*/

	void	loadelf(const char *elfname) {
		ELFSECTION	**secpp, *secp;
		uint32_t	entry;

		elfread(elfname, entry, secpp);

		for(int s=0; secpp[s]->m_len; s++) {
			secp = secpp[s];

			if ((secp->m_start >= FLASH_ADDRESS)
				&&(secp->m_start < FLASH_LENGTH+FLASH_ADDRESS)){
				m_flash.load(secp->m_start,
						secp->m_data, secp->m_len);
			} else if ((secp->m_start >= RAM_ADDRESS)
				&&(secp->m_start < RAM_LENGTH+RAM_ADDRESS)) {
				memcpy(((char *)&m_core->v__DOT__ram__DOT__mem[0])
					+secp->m_start - RAM_ADDRESS,
					&secp->m_data[0], secp->m_len);
			}
		}
	}

	bool	gie(void) {
		return (m_core->v__DOT__swic__DOT__thecpu__DOT__r_gie);
	}

	void dump(const uint32_t *regp) {
		uint32_t	uccv, iccv;
		fflush(stderr);
		fflush(stdout);
		printf("ZIPM--DUMP: ");
		if (gie())
			printf("Interrupts-enabled\n");
		else
			printf("Supervisor mode\n");
		printf("\n");

		iccv = m_core->v__DOT__swic__DOT__thecpu__DOT__w_iflags;
		uccv = m_core->v__DOT__swic__DOT__thecpu__DOT__w_uflags;

		printf("sR0 : %08x ", regp[0]);
		printf("sR1 : %08x ", regp[1]);
		printf("sR2 : %08x ", regp[2]);
		printf("sR3 : %08x\n",regp[3]);
		printf("sR4 : %08x ", regp[4]);
		printf("sR5 : %08x ", regp[5]);
		printf("sR6 : %08x ", regp[6]);
		printf("sR7 : %08x\n",regp[7]);
		printf("sR8 : %08x ", regp[8]);
		printf("sR9 : %08x ", regp[9]);
		printf("sR10: %08x ", regp[10]);
		printf("sR11: %08x\n",regp[11]);
		printf("sR12: %08x ", regp[12]);
		printf("sSP : %08x ", regp[13]);
		printf("sCC : %08x ", iccv);
		printf("sPC : %08x\n",regp[15]);

		printf("\n");

		printf("uR0 : %08x ", regp[16]);
		printf("uR1 : %08x ", regp[17]);
		printf("uR2 : %08x ", regp[18]);
		printf("uR3 : %08x\n",regp[19]);
		printf("uR4 : %08x ", regp[20]);
		printf("uR5 : %08x ", regp[21]);
		printf("uR6 : %08x ", regp[22]);
		printf("uR7 : %08x\n",regp[23]);
		printf("uR8 : %08x ", regp[24]);
		printf("uR9 : %08x ", regp[25]);
		printf("uR10: %08x ", regp[26]);
		printf("uR11: %08x\n",regp[27]);
		printf("uR12: %08x ", regp[28]);
		printf("uSP : %08x ", regp[29]);
		printf("uCC : %08x ", uccv);
		printf("uPC : %08x\n",regp[31]);
		printf("\n");
		fflush(stderr);
		fflush(stdout);
	}


	void	execsim(const uint32_t imm) {
		uint32_t	*regp = m_core->v__DOT__swic__DOT__thecpu__DOT__regset;
		int		rbase;
		rbase = (gie())?16:0;

		fflush(stdout);
		if ((imm & 0x03fffff)==0)
			return;
		// fprintf(stderr, "SIM-INSN(0x%08x)\n", imm);
		if ((imm & 0x0fffff)==0x00100) {
			// SIM Exit(0)
			close();
			exit(0);
		} else if ((imm & 0x0ffff0)==0x00310) {
			// SIM Exit(User-Reg)
			int	rcode;
			rcode = regp[(imm&0x0f)+16] & 0x0ff;
			close();
			exit(rcode);
		} else if ((imm & 0x0ffff0)==0x00300) {
			// SIM Exit(Reg)
			int	rcode;
			rcode = regp[(imm&0x0f)+rbase] & 0x0ff;
			close();
			exit(rcode);
		} else if ((imm & 0x0fff00)==0x00100) {
			// SIM Exit(Imm)
			int	rcode;
			rcode = imm & 0x0ff;
			close();
			exit(rcode);
		} else if ((imm & 0x0fffff)==0x002ff) {
			// Full/unconditional dump
			printf("SIM-DUMP\n");
			dump(regp);
		} else if ((imm & 0x0ffff0)==0x00200) {
			// Dump a register
			int rid = (imm&0x0f)+rbase;
			printf("%8ld @%08x R[%2d] = 0x%08x\n", m_tickcount,
			m_core->v__DOT__swic__DOT__thecpu__DOT__ipc,
			rid, regp[rid]);
		} else if ((imm & 0x0ffff0)==0x00210) {
			// Dump a user register
			int rid = (imm&0x0f);
			printf("%8ld @%08x uR[%2d] = 0x%08x\n", m_tickcount,
				m_core->v__DOT__swic__DOT__thecpu__DOT__ipc,
				rid, regp[rid+16]);
		} else if ((imm & 0x0ffff0)==0x00230) {
			// SOUT[User Reg]
			int rid = (imm&0x0f)+16;
			printf("%c", regp[rid]&0x0ff);
		} else if ((imm & 0x0fffe0)==0x00220) {
			// SOUT[User Reg]
			int rid = (imm&0x0f)+rbase;
			printf("%c", regp[rid]&0x0ff);
		} else if ((imm & 0x0fff00)==0x00400) {
			// SOUT[Imm]
			printf("%c", imm&0x0ff);
		} else { // if ((insn & 0x0f7c00000)==0x77800000)
			uint32_t	immv = imm & 0x03fffff;
			// Simm instruction that we dont recognize
			// if (imm)
			printf("SIM 0x%08x\n", immv);
		} fflush(stdout);
	}

	void	tick(void) {
		if ((m_tickcount & ((1<<28)-1))==0) {
			double	ticks_per_second = m_tickcount;
			time_t	seconds_passed = time(NULL)-m_start_time;
			if (seconds_passed != 0) {
			ticks_per_second /= (double)(time(NULL) - m_start_time);
			printf(" ********   %.6f TICKS PER SECOND\n", 
				ticks_per_second);
			}
		}

		if (m_tickcount == 6000000)
			TESTB<Vbusmasterr>::closetrace();

		// Set up the bus before any clock tick
		m_core->i_qspi_dat = m_flash(m_core->o_qspi_cs_n,
					m_core->o_qspi_sck,
					m_core->o_qspi_dat);
		// sdcard_miso = m_sdcard(m_core->o_sd_cs_n, m_core->o_spi_sck,
		//			m_core->o_spi_mosi);

		m_core->i_rx_uart = m_uart(m_core->o_tx_uart,
				m_core->v__DOT__consoleport__DOT__uart_setup);
		TESTB<Vbusmasterr>::tick();

		// Sim instructions
		if ((m_core->v__DOT__swic__DOT__thecpu__DOT__op_sim)
			&&(m_core->v__DOT__swic__DOT__thecpu__DOT__op_valid)
			&&(m_core->v__DOT__swic__DOT__thecpu__DOT__alu_ce)
			&&(!m_core->v__DOT__swic__DOT__thecpu__DOT__new_pc)) {
			//
			execsim(m_core->v__DOT__swic__DOT__thecpu__DOT__op_sim_immv);
		}

#ifdef	DEBUGGING
if (m_core->v__DOT__wb_err) {
	printf("BUS-ERR: Addr = 0x%08x\n", m_core->v__DOT__wb_err);
	printf("BUS-ERR: PC   = 0x%08x / 0x%08x\n",
		m_core->v__DOT__swic__DOT__thecpu__DOT__ipc,
		m_core->v__DOT__swic__DOT__thecpu__DOT__r_upc);
} else if (m_core->v__DOT__dwb_stb) {
	char	line[128];
	static	char	lastline[128] = "";

	sprintf(line, " %s  %s [",
		(m_core->v__DOT__dwb_we) ? "W":"R",
		(m_core->v__DOT__wb_stall) ? "STALL":"     ");
	if (m_core->v__DOT__dwb_we)
		sprintf(line, "%s%08x / ", line, (m_core->v__DOT__dwb_odata));
	else	sprintf(line, "%s%8s / ", line, "");
	if (m_core->v__DOT__wb_ack)
		sprintf(line, "%s%08x ]@0x", line, m_core->v__DOT__wb_idata);
	else	sprintf(line, "%s%8s ]@0x", line, "");
	sprintf(line, "%s%08x -- 0x%08x / 0x%08x\n",line,
		(m_core->v__DOT__dwb_addr<<2),
		m_core->v__DOT__swic__DOT__thecpu__DOT__ipc,
		m_core->v__DOT__swic__DOT__thecpu__DOT__r_upc);
	if (strcmp(line, lastline)!=0) {
		printf("%s", line);
		strcpy(lastline, line);
	}
} else if (m_core->v__DOT__wb_ack) {
	printf("(%s) %5s [",
		(m_core->v__DOT__dwb_we) ? "W":"R", "");
	printf("%8s / ", "");
	printf("%08x ]   ", m_core->v__DOT__wb_idata);
	printf("%8s -- 0x%08x / 0x%08x\n", "",
		m_core->v__DOT__swic__DOT__thecpu__DOT__ipc,
		m_core->v__DOT__swic__DOT__thecpu__DOT__r_upc);
}
#endif
if (m_core->v__DOT__swic__DOT__cpu_break) {
	m_bomb++;
	dump(m_core->v__DOT__swic__DOT__thecpu__DOT__regset);
} else if (m_bomb) {
	if (m_bomb++ > 12)
		m_done = true;
	fprintf(stderr, "BREAK-BREAK-BREAK (m_bomb = %d)%s\n", m_bomb,
		(m_done)?" -- DONE!":"");
}

	}

	bool	done(void) {
		if (!m_trace)
			return m_done;
		else
			return (m_done)||(m_tickcount > 6000000);
	}
};

BUSMASTER_TB	*tb;

void	busmaster_kill(int v) {
	tb->close();
	fprintf(stderr, "KILLED!!\n");
	exit(0);
}

int	main(int argc, char **argv) {
	Verilated::commandArgs(argc, argv);
	tb = new BUSMASTER_TB;

	signal(SIGINT,  busmaster_kill);
	// tb->opentrace("trace.vcd");

	tb->reset();

	tb->loadelf(argv[1]);

	while(!tb->done())
		tb->tick();

	tb->close();
	exit(0);
}

