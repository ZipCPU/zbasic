////////////////////////////////////////////////////////////////////////////////
//
// Filename:	contest.c
// {{{
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	A "connection-test".  This is a quick test of the interconnect,
//		just to make sure everything on the bus responds like we are
//	expecting it to.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2019-2021, Gisselquist Technology, LLC
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
#include "board.h"
#include "txfns.h"
#include "zipcpu.h"

#define	SKIP_BOOTLOADER

void	rwcheckm(const char *str, volatile unsigned *const a, const int mask) {
	const unsigned	NONCE = 0x12345678;
	unsigned	original, failed;
	volatile char *const cp = (volatile char *const)a;

	txstr(str);
	original = *a;
	*a = NONCE;
	failed = 0;
	if ((*a & mask) != (NONCE & mask)) {
		failed = 1;
	} if (!failed) {
		*a = ~NONCE;
		if ((*a & mask) != (~NONCE & mask)) {
			failed = 1;
		}
	} if (!failed) {
		*a = mask;
		if ((*a & mask) != mask) {
			failed = 1;
		}
	} if (!failed) {
		*a =  0;
		if ((*a & mask) != 0) {
			failed = 1;
		}
	}

	for(int k=0; (k<4)&&(!failed); k++) {
		unsigned	v, cmsk, wmsk;

		cmsk = (mask >> (8*(3-k))) & 0x0ff;
		if (cmsk == 0)
			continue;
		wmsk = mask & (~(cmsk << (8*(3-k))));

		cp[k] = -1;
		if ((cp[k] & cmsk) != cmsk)
			failed = 1;
		else if ((*a & mask) & wmsk)
			failed = 1;
		cp[k] = 0;
		if (0 != (mask & *a))
			failed = 1;
	}

	if (!failed) {
		*a =  original;
		if (*a != original) {
			failed = 1;
		}
	}

	if (failed)
		txstr(" *** UNEXPECTED ***");
	else
		txstr("(Good)");
	txstr("\r\n");
}

void	rwcheck(const char *str, volatile unsigned *const a) {
	rwcheckm(str, a, -1);
}

void	scopecheck(const char *str, volatile unsigned *const a) {
	const unsigned	NONCE = 0xdbeef, MASK=0x0fffff;
	unsigned	original, mask, ln, failed, v;

	txstr(str);
	original = *a;

	ln = (original >> 20)&0x01f;
	if ((ln < 3)||(ln > 20)) {
		txstr(" *** UNEXPECTED ***\r\n");
		return;
	}

	failed = 0;
	*a = NONCE;
	if ((*a & MASK) != (NONCE&MASK))
		failed = 1;
	if (!failed) {
		*a = (~NONCE)&MASK;
		if (((v = *a) & MASK) != ((~NONCE)&MASK))
			failed = 1;
	} if (!failed) {
		*a = MASK;	// Write all ones
		if (((v = *a) & MASK) != MASK)
			failed = 2;
	} if (!failed) {
		*a =  0;	// Write all zeros
		if (((v = *a) & MASK) != 0)
			failed = 3;
	} if (!failed) {
		*a =  original;	// Return to initial
		if (((v = *a) ^ original)& 0x0fffffff)
			failed = 4;
	}

	if (failed)
		txstr(" *** UNEXPECTED ***");
	else
		txstr("(Good)");

	txstr("\r\n");
}

int main(int argc, char **argv) {
	unsigned pwr;
	// char *_sdram = _streamram;

	txstr(
"+----------------------------------+\n"
"|-   Hardware Connectivity Check  -|\n"
"+----------------------------------+\n\n");

	{
		volatile int	a;

		rwcheck("STACK-CHK: ", &a);
	}

	rwcheck("BKRAM-CHK: ", (unsigned *)_bkram);
	// rwcheck("SDRAM-CHK: ", (unsigned *)_sdram);

	txstr("VERSION  : "); txhex(*_version);   txstr("\r\n");
	txstr("BUILDTIME: "); txhex(*_buildtime); txstr("\r\n");
	txstr("PWRCOUNT : "); txhex(pwr = *_pwrcount); txstr("\r\n");
	{
		const	unsigned TESTDATE = 0x19951231;
		txstr("RTCDate  : "); txhex(*_rtcdate);
			if (*_rtcdate != *_version)
				txstr(" --- UNEXPECTED");
			*_rtcdate = TESTDATE;
			if (*_rtcdate != TESTDATE)
				txstr(" --- FAILS! (1)");
			*_rtcdate = *_version;
			if (*_rtcdate != *_version)
				txstr(" --- FAILS! (2)");
			txstr("\r\n");
	}

	{
		// const	unsigned TESTTIME = 0x19951231;
		txstr("RTC Clock: "); txhex(_rtc->r_clock); txstr("\r\n");
		txstr("StopWatch: "); txhex(_rtc->r_stopwatch); txstr("\r\n");
		txstr("RTC Timer: "); txhex(_rtc->r_timer); txstr("\r\n");
		txstr("RTC Alarm: "); txhex(_rtc->r_alarm); txstr("\r\n");
	}

	{ // Flash check
		unsigned	v;

		// Don't run this program under flash--it will crash
		// Turn on and then off configuration mode, read the
		// result--make certain you can read the configuration
		// register bits.  This does not actually talk to the flash.
// #warning "This will crash if running under flash"
		*_flashcfg = 0x1f00;
		v = *_flashcfg;
		*_flashcfg = 0;
		txstr("FLASHCFG : "); txhex(v);
		if ((v & 0x1ff00) != 0x1a00)	// 0x1a?? comes from controller
			txstr(" *** UNEXPECTED ***");
		txstr("\r\n");
	}

	txstr("UART     : "); txhex(_uart->u_setup); txstr(", "); txhex(_uart->u_fifo); txstr("\r\n");
#ifdef	_BOARD_HAS_ZIPSCOPE
	scopecheck("ZIPSCOPE : ", (unsigned *)&_zipscope->s_ctrl);
	_zipscope->s_ctrl = 0;
#endif


	// Should really check the SD-Card
	// RTCDate

	txstr("GPIO     : "); txhex(*_gpio); txstr("\r\n");
	if (*_pwrcount == pwr) {
		txstr("PWRCOUNT : "); txhex(*_pwrcount);
		txstr(" *** DEAD *** \r\n");
	} else {
		txstr("PWRCOUNT : "); txhex(*_pwrcount);
		txstr("\r\n");
	}

	while(_uart->u_tx & 0x0100)
		;
//	asm("NEXIT 0");
		txstr("halting\r\n");
	zip_halt();
}
