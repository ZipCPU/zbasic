////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./main_tb.cpp
// {{{
// Project:	ZBasic, a generic toplevel implementation using the full ZipCPU
//
// DO NOT EDIT THIS FILE!
// Computer Generated: This file is computer generated by AUTOFPGA. DO NOT EDIT.
// DO NOT EDIT THIS FILE!
//
// CmdLine:	autofpga autofpga -d -o . clock.txt global.txt version.txt buserr.txt pic.txt pwrcount.txt gpio.txt rtclight.txt rtcdate.txt busconsole.txt bkram.txt flash.txt zipmaster.txt sdspi.txt mem_flash_bkram.txt mem_bkram_only.txt
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2017-2022, Gisselquist Technology, LLC
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
//
// SIM.INCLUDE
//
// Any SIM.INCLUDE tags you define will be pasted here.
// This is useful for guaranteeing any include functions
// your simulation needs are called.
//
#include "verilated.h"
#include "Vmain.h"
#define	BASECLASS	Vmain

#include "design.h"
#include "regdefs.h"
#include "testb.h"
#include "zipelf.h"

#include "byteswap.h"
#include "dbluartsim.h"
#include "sdspisim.h"
#include "flashsim.h"
//
// SIM.DEFINES
//
// This tag is useful fr pasting in any #define values that
// might then control the simulation following.
//
////////////////////////////////////////////////////////////////////////////////
//
// ZipCPU simulation defines
// {{{
#ifndef	VVAR
#ifdef	ROOT_VERILATOR

#include "Vmain___024root.h"
#define	VVAR(A)	rootp->main__DOT_ ## A

#elif	defined(NEW_VERILATOR)
#define	VVAR(A)	main__DOT_ ## A
#else
#define	VVAR(A)	v__DOT_ ## A
#endif
#endif

#define	OPT_PIPELINED
#define	CPUVAR(A)	VVAR(_swic__DOT__thecpu__DOT__core__DOT_ ## A)

#define	cpu_reset	VVAR(_swic__DOT__cmd_reset)
#define	cpu_break 	VVAR(_swic__DOT__cpu_break)
#define	cpu_cmd_halt	VVAR(_swic__DOT__cmd_halt)
#define	cpu_ipc		CPUVAR(_ipc)
#define	cpu_pf_pc	CPUVAR(_pf_pc)
#define	cpu_upc		CPUVAR(_SET_USER_PC__DOT__r_upc)
#define	cpu_gie		CPUVAR(_SET_GIE__DOT__r_gie)
#define	cpu_iflags	CPUVAR(_w_iflags)
#define	cpu_uflags	CPUVAR(_w_uflags)
#ifdef	ROOT_VERILATOR
#define	cpu_regs	CPUVAR(_regset.m_storage)
#else
#define	cpu_regs	CPUVAR(_regset)
#endif
#define	cpu_cmd_addr	VVAR(_swic__DOT__cmd_addr)
#define	cpu_bus_err	CPUVAR(_bus_err)
#define	cpu_ibus_err	CPUVAR(_ibus_err_flag)
#define	cpu_ubus_err	CPUVAR(_r_ubus_err_flag)
#define	cpu_mem_rdaddr	CPUVAR(_domem__DOT__rdaddr)
#define	cpu_mem_wraddr	CPUVAR(_domem__DOT__wraddr)
#define	cpu_sim		CPUVAR(_alu_sim)
#define	cpu_op_valid	CPUVAR(_op_valid)
#define	cpu_alu_ce	CPUVAR(_alu_ce)
#define	cpu_new_pc	CPUVAR(_new_pc)
#define	cpu_sim_immv	CPUVAR(_alu_sim_immv)
#define	cpu_alu_pc_valid	CPUVAR(_alu_pc_valid)
#define	cpu_mem_pc_valid	CPUVAR(_mem_pc_valid)
#ifdef	OPT_PIPELINED
#define	cpu_alu_pc	CPUVAR(_GEN_ALU_PC__DOT__r_alu_pc)
#else
#define	cpu_alu_pc	CPUVAR(_SET_OP_PC__DOT__op_pc)
#endif
#define	cpu_alu_phase	CPUVAR(_GEN_ALU_PHASE__DOT__r_alu_phase)
#define	cpu_wr_ce	CPUVAR(_wr_reg_ce)
#define	cpu_wr_reg_id	CPUVAR(_wr_reg_id)
#define	cpu_wr_gpreg	CPUVAR(_wr_gpreg_vl)
// }}}
#ifndef VVAR
#ifdef  NEW_VERILATOR
#define VVAR(A) main__DOT_ ## A
#else
#define VVAR(A) v__DOT_ ## A
#endif
#endif

#define	block_ram	VVAR(_bkrami__DOT__mem)

#ifndef	VVAR
#ifdef	NEW_VERILATOR
#define	VVAR(A)	main__DOT_ ## A
#else
#define	VVAR(A)	v__DOT_ ## A
#endif
#endif

#define	sd_cmd_busy	VVAR(_sdcardi__DOT__r_cmd_busy)
#define	sd_clk		VVAR(_sdcardi__DOT__r_sdspi_clk)
#define	sd_cmd_state	VVAR(_sdcardi__DOT__r_cmd_state)
#define	sd_rsp_state	VVAR(_sdcardi__DOT__r_rsp_state)
#define	sd_ll_cmd_stb	VVAR(_sdcard__DOT__ll_cmd_stb)
#define	sd_ll_cmd_dat	VVAR(_sdcard__DOT__ll_cmd_dat)
#define	sd_ll_z_counter	VVAR(_sdcard__DOT__lowlevel__DOT__r_z_counter)
#define	sd_ll_clk_counter	VVAR(_sdcard__DOT__lowlevel__DOT__r_clk_counter)
#define	sd_ll_idle	VVAR(_sdcard__DOT__lowlevel__DOT__r_idle)
#define	sd_ll_state	VVAR(_sdcard__DOT__lowlevel__DOT__r_state)
#define	sd_ll_byte	VVAR(_sdcard__DOT__lowlevel__DOT__r_byte)
#define	sd_ll_ireg	VVAR(_sdcard__DOT__lowlevel__DOT__r_ireg)
#define	sd_ll_out_stb	VVAR(_sdcard__DOT__ll_out_stb)
#define	sd_ll_out_dat	VVAR(_sdcard__DOT__ll_out_dat)
#define	sd_lgblklen	VVAR(_sdcard__DOT__r_lgblklen)
#define	sd_fifo_rd_crc	VVAR(_sdcard__DOT__fifo_rd_crc_reg)
#define	sd_cmd_crc	VVAR(_sdcard__DOT__r_cmd_crc)
#define	sd_cmd_crc_cnt	VVAR(_sdcard__DOT__r_cmd_crc_cnt)
#define	sd_fifo_rd_crc_stb	VVAR(_sdcard__DOT__fifo_rd_crc_stb)
#define	ll_fifo_pkt_state	VVAR(_sdcard__DOT__ll_fifo_pkt_state)
#define	sd_have_data_response_token	VVAR(_sdcard__DOT__r_have_data_response_token)
#define	sd_fifo_wr_crc		VVAR(_sdcard__DOT__fifo_wr_crc_reg)
#define	sd_fifo_wr_crc_stb	VVAR(_sdcard__DOT__fifo_wr_crc_stb,)
#define	sd_ll_fifo_wr_state	VVAR(_sdcard__DOT__ll_fifo_wr_state,)
#define	sd_ll_fifo_wr_complete	VVAR(_sdcard__DOT__ll_fifo_wr_complete)
#define	sd_use_fifo	VVAR(_sdcard__DOT__r_use_fifo)
#define	sd_fifo_wr	VVAR(_sdcard__DOT__r_fifo_wr)

class	MAINTB : public TESTB<Vmain> {
public:
		// SIM.DEFNS
		//
		// If you have any simulation components, create a
		// SIM.DEFNS tag to have those components defined here
		// as part of the main_tb.cpp function.
	int	m_cpu_bombed;
	DBLUARTSIM	*m_wbu;
#ifdef	SDSPI_ACCESS
	SDSPISIM	m_sdcard;
#endif // SDSPI_ACCESS
#ifdef	FLASH_ACCESS
	FLASHSIM	*m_flash;
#endif // FLASH_ACCESS
	MAINTB(void) {
		// SIM.INIT
		//
		// If your simulation components need to be initialized,
		// create a SIM.INIT tag.  That tag's value will be pasted
		// here.
		//
		// From zip
		m_cpu_bombed = 0;
		// From wbu
		m_wbu = new DBLUARTSIM();
		m_wbu->setup(100);
		// From sdcard
#ifdef	SDSPI_ACCESS
		m_sdcard.debug(false);
#endif	// SDSPI_ACCESS
		// From flash
#ifdef	FLASH_ACCESS
		m_flash = new FLASHSIM(FLASHLGLEN, false, 0, 6);
#endif // FLASH_ACCESS
	}

	void	reset(void) {
		// SIM.SETRESET
		// If your simulation component needs logic before the
		// tick with reset set, that logic can be placed into
		// the SIM.SETRESET tag and thus pasted here.
		//
		m_core->i_cpu_reset = 1;
		TESTB<Vmain>::reset();
		// SIM.CLRRESET
		// If your simulation component needs logic following the
		// reset tick, that logic can be placed into the
		// SIM.CLRRESET tag and thus pasted here.
		//
		m_core->i_cpu_reset = 0;
	}

	void	trace(const char *vcd_trace_file_name) {
		fprintf(stderr, "Opening TRACE(%s)\n",
				vcd_trace_file_name);
		opentrace(vcd_trace_file_name);
		m_time_ps = 0;
	}

	void	close(void) {
		m_done = true;
	}

	void	tick(void) {
		TESTB<Vmain>::tick(); // Clock.size = 1
	}


	// Evaluating clock clk

	// sim_clk_tick() will be called from TESTB<Vmain>::tick()
	//   following any falling edge of clock clk
	virtual	void	sim_clk_tick(void) {
		// Default clock tick
		bool	writeout;

		//
		// SIM.TICK tags go here for SIM.CLOCK=clk
		//
		// SIM.TICK from zip
#ifdef	INCLUDE_ZIPCPU
		// ZipCPU Sim instruction support
		// {{{
		if ((m_core->cpu_sim)
			&&(!m_core->cpu_new_pc)) {
			//
			execsim(m_core->cpu_sim_immv);
		}

		if (m_cpu_bombed) {
			if (m_cpu_bombed++ > 12)
				m_done = true;
		} else if (m_core->cpu_break) {
			printf("\n\nBOMB : CPU BREAK RECEIVED\n");
			m_cpu_bombed++;
			dump(m_core->cpu_regs);
		}
		// }}}
#endif	// INCLUDE_ZIPCPU

		// SIM.TICK from wbu
		m_core->i_wbu_uart_rx = (*m_wbu)(m_core->o_wbu_uart_tx);
		// SIM.TICK from sdcard
#ifdef	SDSPI_ACCESS
		m_core->i_sd_data = m_sdcard((m_core->o_sd_data&8)?1:0,
				m_core->o_sd_sck, m_core->o_sd_cmd);
		m_core->i_sd_data &= 1;
		m_core->i_sd_data |= (m_core->o_sd_data&0x0e);
		m_core->i_sd_detect = 1;
#endif	// SDSPI_ACCESS
		// SIM.TICK from flash
#ifdef	FLASH_ACCESS
		m_core->i_qspi_dat = m_flash->simtick(
			m_core->o_qspi_cs_n,
			m_core->o_qspi_sck,
			m_core->o_qspi_dat,
			m_core->o_qspi_mod);
#endif // FLASH_ACCESS
		writeout = false;
		//
		// SIM.DBGCONDITION
		// Set writeout to true here for debug by printf access
		// to this routine
		//
		if (writeout) {
			//
			// SIM.DEBUG tags can print here, supporting
			// any attempts to debug by printf.  Following any
			// code you place here, a newline will close the
			// debug section.
			//
			//    SIM.DEBUG from sdcard
			/*
			printf(" SDSPI[%d,%d(%d),(%d)]",
				m_core->sd_cmd_busy,
				m_core->sd_clk,
				m_core->sd_cmd_state,
				m_core->sd_rsp_state);
			printf(" LL[%d,%2x->CK=%d/%2x,%s,ST=%2d,TX=%2x,RX=%2x->%d,%2x] ",
				m_core->sd_ll_cmd_stb,
				m_core->sd_ll_cmd_dat,
				m_core->sd_ll_z_counter,
				// (m_core->sd_ll_clk_counter==0)?1:0,
				m_core->sd_ll_clk_counter,
				(m_core->sd_ll_idle)?"IDLE":"    ",
				m_core->sd_ll_state,
				m_core->sd_ll_byte,
				m_core->sd_ll_ireg,
				m_core->sd_ll_out_stb,
				m_core->sd_ll_out_dat
				);
			printf(" CRC=%02x/%2d",
				m_core->sd_cmd_crc,
				m_core->sd_cmd_crc_cnt);
			printf(" SPI(%d,%d,%d/%d,%d)->?",
				m_core->o_sf_cs_n,
				m_core->o_sd_cs_n,
				m_core->o_spi_sck,
				m_core->v__DOT__sdcard_sck,
				m_core->o_spi_mosi);

			printf(" CK=%d,LN=%d",
				m_core->sd_clk,
				m_core->sd_lgblklen);


			if (m_core->sd_use_fifo){
				printf(" FIFO");
				if (m_core->sd_fifo_wr)
					printf("-WR(%04x,%d,%d,%d)",
						m_core->sd_fifo_rd_crc,
						m_core->sd_fifo_rd_crc_stb,
						m_core->sd_ll_fifo_pkt_state,
						m_core->sd_have_data_response_token);
				else
					printf("-RD(%04x,%d,%d,%d)",
						m_core->sd_fifo_wr_crc,
						m_core->sd_fifo_wr_crc_stb,
						m_core->sd_ll_fifo_wr_state,
						m_core->sd_ll_fifo_wr_complete
						);
			}
			*/
		}
	}
	inline	void	tick_clk(void) {	tick();	}

	//
	// The load function
	//
	// This function is required by designs that need the flash or memory
	// set prior to run time.  The test harness should be able to call
	// this function to load values into any (memory-type) location
	// on the bus.
	//
	bool	load(uint32_t addr, const char *buf, uint32_t len) {
		uint32_t	start, offset, wlen, base, adrln;

		//
		// Loading the bkram component
		//
		base  = 0x00c00000; // in octets
		adrln = 0x00100000;

		if ((addr >= base)&&(addr < base + adrln)) {
			// If the start access is in bkram
			start = (addr > base) ? (addr-base) : 0;
			offset = (start + base) - addr;
			wlen = (len-offset > adrln - start)
				? (adrln - start) : len - offset;
#ifdef	BKRAM_ACCESS
			// FROM bkram.SIM.LOAD
			start = start & (-4);
			wlen = (wlen+3)&(-4);

			// Need to byte swap data to get it into the memory
			char	*bswapd = new char[len+8];
			memcpy(bswapd, &buf[offset], wlen);
			byteswapbuf(len>>2, (uint32_t *)bswapd);
			memcpy(&m_core->block_ram[start], bswapd, wlen);
			delete	bswapd;
			// AUTOFPGA::Now clean up anything else
			// Was there more to write than we wrote?
			if (addr + len > base + adrln)
				return load(base + adrln, &buf[offset+wlen], len-wlen);
			return true;
#else	// BKRAM_ACCESS
			return false;
#endif	// BKRAM_ACCESS
		//
		// End of components with a SIM.LOAD tag, and a
		// non-zero number of addresses (NADDR)
		//
		}

		//
		// Loading the flash component
		//
		base  = 0x01000000; // in octets
		adrln = 0x01000000;

		if ((addr >= base)&&(addr < base + adrln)) {
			// If the start access is in flash
			start = (addr > base) ? (addr-base) : 0;
			offset = (start + base) - addr;
			wlen = (len-offset > adrln - start)
				? (adrln - start) : len - offset;
#ifdef	FLASH_ACCESS
			// FROM flash.SIM.LOAD
			m_flash->load(start, &buf[offset], wlen);
			// AUTOFPGA::Now clean up anything else
			// Was there more to write than we wrote?
			if (addr + len > base + adrln)
				return load(base + adrln, &buf[offset+wlen], len-wlen);
			return true;
#else	// FLASH_ACCESS
			return false;
#endif	// FLASH_ACCESS
		//
		// End of components with a SIM.LOAD tag, and a
		// non-zero number of addresses (NADDR)
		//
		}

		return false;
	}

	//
	// KYSIM.METHODS
	//
	// If your simulation code will need to call any of its own function
	// define this tag by those functions (or other sim code), and
	// it will be pasated here.
	//
#ifdef	INCLUDE_ZIPCPU
	// ZipCPU Access functions
	// {{{
	void	loadelf(const char *elfname) {
		ELFSECTION	**secpp, *secp;
		uint32_t	entry;

		elfread(elfname, entry, secpp);

		for(int s=0; secpp[s]->m_len; s++) {
			bool	successful_load;
			secp = secpp[s];

			successful_load = load(secp->m_start,
				secp->m_data, secp->m_len);

			if (!successful_load) {
				printf("Could not load section "
					"from %08x to %08x--no such address\n",
					secp->m_start,
					secp->m_start+secp->m_len);
			}
		} free(secpp);
	}


	bool	gie(void) {
		return (m_core->cpu_gie);
	}

	void dump(const uint32_t *regp) {
		uint32_t	uccv, iccv, ipc, upc;
		fflush(stderr);
		fflush(stdout);
		printf("ZIPM--DUMP: ");
		if (gie())
			printf("Interrupts-enabled\n");
		else
			printf("Supervisor mode\n");
		printf("\n");

		iccv = m_core->cpu_iflags;
		uccv = m_core->cpu_uflags;
		ipc = m_core->cpu_ipc;
		upc = m_core->cpu_upc;

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
		printf("sPC : %08x\n",ipc);

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
		printf("uPC : %08x\n",upc);
		printf("\n");
		fflush(stderr);
		fflush(stdout);
	}


	void	execsim(const uint32_t imm) {
		uint32_t	*regp = m_core->cpu_regs;
		int		rbase;
		rbase = (gie())?16:0;

		fflush(stdout);
		if ((imm & 0x03fffff)==0)
			return;
		// fprintf(stderr, "SIM-INSN(0x%08x)\n", imm);
		if ((imm & 0x0fffff)==0x00100) { // SIM Exit(0)
			// {{{
			close();
			// exit(0);
			m_done = true;
			// }}}
		} else if ((imm & 0x0ffff0)==0x00310) { // SIM Exit(User-Reg)
			// {{{
			// int	rnum;
			// rnum  = (imm&0x0f)+16;
			// rcode = regp[rnum] & 0x0ff;
			// if ((m_core->cpu_wr_ce)&&(m_core->cpu_wr_reg_id==rnum))
			//	rcode = m_core->cpu_wr_gpreg;
			close();
			// exit(rcode);
			// }}}
		} else if ((imm & 0x0ffff0)==0x00300) {
			// {{{
			// SIM Exit(Reg)
			// int	rnum;
			// rnum  = (imm&0x0f)+rbase;
			// rcode = regp[rnum] & 0x0ff;
			// if ((m_core->cpu_wr_ce)&&(m_core->cpu_wr_reg_id==rnum))
			//	rcode = m_core->cpu_wr_gpreg;
			close();
			// exit(rcode);
			// }}}
		} else if ((imm & 0x0fff00)==0x00100) {
			// {{{
			// SIM Exit(Imm)
			// rcode = imm & 0x0ff;
			close();
			// exit(rcode);
			// }}}
		} else if ((imm & 0x0fffff)==0x002ff) {
			// {{{
			// Full/unconditional dump
			// Now handled via $write
			// printf("SIM-DUMP\n");
			// dump(regp);
			// }}}
		} else if ((imm & 0x0ffff0)==0x00200) {
			// {{{
			// Dump a register
			// Now handled via $write
			// int	rcode, rnum;
			// rnum  = (imm&0x0f)+rbase;
			// rcode = regp[rnum];
			// if ((m_core->cpu_wr_ce)&&(m_core->cpu_wr_reg_id==rnum))
				// rcode = m_core->cpu_wr_gpreg;
			// printf("%8lu @%08x R[%2d] = 0x%08x\n", m_time_ps/1000,
				// m_core->cpu_ipc, rnum, rcode);
			// }}}
		} else if ((imm & 0x0ffff0)==0x00210) {
			// {{{
			// Dump a user register
			// Now handled via $write
			// int	rcode, rnum;
			// rnum  = (imm&0x0f)+16;
			// rcode = regp[rnum] & 0x0ff;
			// if ((m_core->cpu_wr_ce)&&(m_core->cpu_wr_reg_id==rnum))
				// rcode = m_core->cpu_wr_gpreg;
			// printf("%8lu @%08x uR[%2d] = 0x%08x\n", m_time_ps/1000,
				// m_core->cpu_ipc, rnum, rcode);
			// }}}
		} else if ((imm & 0x0ffff0)==0x00230) {
			// {{{
			// SOUT[User Reg]
			// Now handled via $write
			// int	rcode, rnum;
			// rnum  = (imm&0x0f)+16;
			// rcode = regp[rnum];
			// if ((m_core->cpu_wr_ce)&&(m_core->cpu_wr_reg_id==rnum))
				// rcode = m_core->cpu_wr_gpreg;
			// printf("%c", rcode&0x0ff);
			// }}}
		} else if ((imm & 0x0fffe0)==0x00220) {
			// {{{
			// SOUT[Reg]
			// Now handled via $write
			// int	rcode, rnum;
			// rnum  = (imm&0x0f)+rbase;
			// rcode = regp[rnum];
			// if ((m_core->cpu_wr_ce)&&(m_core->cpu_wr_reg_id==rnum))
				// rcode = m_core->cpu_wr_gpreg;
			// printf("%c", rcode&0x0ff);
			// }}}
		} else if ((imm & 0x0fff00)==0x00400) {
			// {{{
			// SOUT[Imm]
			// Now handled via $write
			// printf("%c", imm&0x0ff);
			// }}}
		} else { // if ((insn & 0x0f7c00000)==0x77800000)
			uint32_t	immv = imm & 0x03fffff;
			// Simm instruction that we dont recognize
			// if (imm)
			// printf("SIM 0x%08x\n", immv);
			printf("SIM 0x%08x (ipc = %08x, upc = %08x)\n", immv,
				m_core->cpu_ipc,
				m_core->cpu_upc);
		} fflush(stdout);
	}
	// }}}
#endif // INCLUDE_ZIPCPU
#ifdef	SDSPI_ACCESS
	void	setsdcard(const char *fn) {
		m_sdcard.load(fn);
	}
#endif // SDSPI_ACCESS

};
