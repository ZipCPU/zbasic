////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./board.h
//
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
//
// Copyright (C) 2017-2020, Gisselquist Technology, LLC
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
#ifndef	BOARD_H
#define	BOARD_H

// And, so that we can know what is and isn't defined
// from within our main.v file, let's include:
#include <design.h>

#include <design.h>
#include <cpudefs.h>

#define	_HAVE_ZIPSYS
#define	PIC	_zip->z_pic

#ifdef	INCLUDE_ZIPCPU
#ifdef INCLUDE_DMA_CONTROLLER
#define	_HAVE_ZIPSYS_DMA
#endif	// INCLUDE_DMA_CONTROLLER
#ifdef INCLUDE_ACCOUNTING_COUNTERS
#define	_HAVE_ZIPSYS_PERFORMANCE_COUNTERS
#endif	// INCLUDE_ACCOUNTING_COUNTERS
#endif // INCLUDE_ZIPCPU


typedef struct  CONSOLE_S {
	unsigned	u_setup;
	unsigned	u_fifo;
	unsigned	u_rx, u_tx;
} CONSOLE;

#define	_uart_txbusy	((_uart->u_fifo & 0x10000)==0)


//
// GPIO input wires
//
#define	GPIO_IN(WIRE)	(((WIRE)>>16)&1)
//
// GPIO output wires
//
#define	GPIO_SET(WIRE)	(((WIRE)<<16)|(WIRE))
#define	GPIO_CLR(WIRE)	 ((WIRE)<<16)
//
//


#define BUSPIC(X) (1<<X)


typedef	struct	RTCLIGHT_S	{
	unsigned	r_clock, r_stopwatch, r_timer, r_alarm;
} RTCLIGHT;


#define	CLKFREQHZ	100000000


#define	SYSPIC(A)	(1<<(A))


#define	ALTPIC(A)	(1<<(A))


#define	SDSPI_SETAUX	0x0000ff
#define	SDSPI_READAUX	0x0000bf
#define	SDSPI_CMD		0x000040
#define	SDSPI_ACMD		(0x040+55) // CMD55
#define	SDSPI_FIFO_OP	0x000800	// Read only
#define	SDSPI_WRITEOP	0x000c00	// Write to the FIFO
#define	SDSPI_ALTFIFO	0x001000
#define	SDSPI_BUSY		0x004000
#define	SDSPI_ERROR		0x008000
#define	SDSPI_CLEARERR	0x008000
// #define	SDSPI_CRCERR	0x010000
// #define	SDSPI_ERRTOK	0x020000
#define	SDSPI_REMOVED	0x040000
#define	SDSPI_PRESENTN	0x080000
#define	SDSPI_RESET		0x100000	// Read only
#define	SDSPI_WATCHDOG	0x200000	// Read only
#define	SDSPI_GO_IDLE	((SDSPI_REMOVED|SDSPI_CLEARERR|SDSPI_CMD)+0)
#define	SDSPI_READ_SECTOR	((SDSPI_CMD|SDSPI_CLEARERR|SDSPI_FIFO_OP)+17)
#define	SDSPI_WRITE_SECTOR	((SDSPI_CMD|SDSPI_CLEARERR|SDSPI_WRITEOP)+24)

typedef	struct SDSPI_S {
	unsigned	sd_ctrl, sd_data, sd_fifo[2];
} SDSPI;


#ifdef	BUSCONSOLE_ACCESS
#define	_BOARD_HAS_BUSCONSOLE
static volatile CONSOLE *const _uart = ((CONSOLE *)0x00600000);
#endif	// BUSCONSOLE_ACCESS
#ifdef	GPIO_ACCESS
#define	_BOARD_HAS_GPIO
static volatile unsigned *const _gpio = ((unsigned *)0x00a0000c);
#endif	// GPIO_ACCESS
#ifdef	VERSION_ACCESS
#define	_BOARD_HAS_VERSION
static volatile unsigned *const _version = ((unsigned *)0x00a00018);
#endif	// VERSION_ACCESS
#ifdef	FLASHCFG_ACCESS
#define	_BOARD_HAS_FLASHCFG
static volatile unsigned * const _flashcfg = ((unsigned *)(0x00200000));
#endif	// FLASHCFG_ACCESS
#ifdef	BUSPIC_ACCESS
#define	_BOARD_HAS_BUSPIC
static volatile unsigned *const _buspic = ((unsigned *)0x00a00008);
#endif	// BUSPIC_ACCESS
#ifdef	RTC_ACCESS
#define	_BOARD_HAS_RTC
static volatile RTCLIGHT *const _rtc = ((RTCLIGHT *)0x00800000);
#endif	// RTC_ACCESS
#ifdef	BKRAM_ACCESS
#define	_BOARD_HAS_BKRAM
extern char	_bkram[0x00100000];
#endif	// BKRAM_ACCESS
#ifdef	FLASH_ACCESS
#define	_BOARD_HAS_FLASH
extern int _flash[1];
#endif	// FLASH_ACCESS
#define	_BOARD_HAS_BUILDTIME
static volatile unsigned *const _buildtime = ((unsigned *)0x00a00000);
#define	_BOARD_HAS_BUSERR
static volatile unsigned *const _buserr = ((unsigned *)0x00a00004);
#ifdef	PWRCOUNT_ACCESS
static volatile unsigned *const _pwrcount = ((unsigned *)0x00a00010);
#endif	// PWRCOUNT_ACCESS
#ifdef	RTCDATE_ACCESS
#define	_BOARD_HAS_RTCDATE
static volatile unsigned *const _rtcdate = ((unsigned *)10485780);
#endif	// RTCDATE_ACCESS
#ifdef	SDSPI_ACCESS
#define	_BOARD_HAS_SDSPI
static volatile SDSPI *const _sdcard = ((SDSPI *)0x00400000);
#endif	// SDSPI_ACCESS
//
// Interrupt assignments (3 PICs)
//
// PIC: buspic
#define	BUSPIC_GPIO	BUSPIC(0)
#define	BUSPIC_SDCARD	BUSPIC(1)
// PIC: syspic
#define	SYSPIC_DMAC	SYSPIC(0)
#define	SYSPIC_JIFFIES	SYSPIC(1)
#define	SYSPIC_TMC	SYSPIC(2)
#define	SYSPIC_TMB	SYSPIC(3)
#define	SYSPIC_TMA	SYSPIC(4)
#define	SYSPIC_ALT	SYSPIC(5)
#define	SYSPIC_BUS	SYSPIC(6)
#define	SYSPIC_UARTTXF	SYSPIC(7)
#define	SYSPIC_UARTRXF	SYSPIC(8)
#define	SYSPIC_SDCARD	SYSPIC(9)
// PIC: altpic
#define	ALTPIC_UIC	ALTPIC(0)
#define	ALTPIC_UOC	ALTPIC(1)
#define	ALTPIC_UPC	ALTPIC(2)
#define	ALTPIC_UTC	ALTPIC(3)
#define	ALTPIC_MIC	ALTPIC(4)
#define	ALTPIC_MOC	ALTPIC(5)
#define	ALTPIC_MPC	ALTPIC(6)
#define	ALTPIC_MTC	ALTPIC(7)
#define	ALTPIC_UARTTX	ALTPIC(8)
#define	ALTPIC_UARTRX	ALTPIC(9)
#define	ALTPIC_RTC	ALTPIC(10)
#endif	// BOARD_H
