////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./regdefs.cpp
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
// Copyright (C) 2017-2021, Gisselquist Technology, LLC
// {{{
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
#include <strings.h>
#include <ctype.h>
#include "regdefs.h"

const	REGNAME	raw_bregs[] = {
	{ R_FLASHCFG      ,	"FLASHCFG" 	},
	{ R_FLASHCFG      ,	"QSPIC"    	},
	{ R_SDSPI_CTRL    ,	"SDCARD"   	},
	{ R_SDSPI_DATA    ,	"SDDATA"   	},
	{ R_SDSPI_FIFOA   ,	"SDFIFOA"  	},
	{ R_SDSPI_FIFOA   ,	"SDFIF0"   	},
	{ R_SDSPI_FIFOA   ,	"SDFIFA"   	},
	{ R_SDSPI_FIFOB   ,	"SDFIFOB"  	},
	{ R_SDSPI_FIFOB   ,	"SDFIF1"   	},
	{ R_SDSPI_FIFOB   ,	"SDFIFB"   	},
	{ R_CONSOLE_FIFO  ,	"UFIFO"    	},
	{ R_CONSOLE_UARTRX,	"RX"       	},
	{ R_CONSOLE_UARTTX,	"TX"       	},
	{ R_CLOCK         ,	"CLOCK"    	},
	{ R_TIMER         ,	"TIMER"    	},
	{ R_STOPWATCH     ,	"STOPWATCH"	},
	{ R_CKALARM       ,	"ALARM"    	},
	{ R_CKALARM       ,	"CKALARM"  	},
	{ R_CKSPEED       ,	"CKSPEED"  	},
	{ R_BUILDTIME     ,	"BUILDTIME"	},
	{ R_BUSERR        ,	"BUSERR"   	},
	{ R_PIC           ,	"PIC"      	},
	{ R_GPIO          ,	"GPIO"     	},
	{ R_GPIO          ,	"GPI"      	},
	{ R_GPIO          ,	"GPO"      	},
	{ R_PWRCOUNT      ,	"PWRCOUNT" 	},
	{ R_RTCDATE       ,	"RTCDATE"  	},
	{ R_RTCDATE       ,	"DATE"     	},
	{ R_VERSION       ,	"VERSION"  	},
	{ R_BKRAM         ,	"RAM"      	},
	{ R_FLASH         ,	"FLASH"    	},
	{ R_ZIPCTRL       ,	"CPU"      	},
	{ R_ZIPCTRL       ,	"ZIPCTRL"  	},
	{ R_ZIPREGS       ,	"ZIPREGS"  	},
	{ R_ZIPS0         ,	"SR0"      	},
	{ R_ZIPS1         ,	"SR1"      	},
	{ R_ZIPS2         ,	"SR2"      	},
	{ R_ZIPS3         ,	"SR3"      	},
	{ R_ZIPS4         ,	"SR4"      	},
	{ R_ZIPS5         ,	"SR5"      	},
	{ R_ZIPS6         ,	"SR6"      	},
	{ R_ZIPS7         ,	"SR7"      	},
	{ R_ZIPS8         ,	"SR8"      	},
	{ R_ZIPS9         ,	"SR9"      	},
	{ R_ZIPS10        ,	"SR10"     	},
	{ R_ZIPS11        ,	"SR11"     	},
	{ R_ZIPS12        ,	"SR12"     	},
	{ R_ZIPSSP        ,	"SSP"      	},
	{ R_ZIPSSP        ,	"SR13"     	},
	{ R_ZIPCC         ,	"ZIPCC"    	},
	{ R_ZIPCC         ,	"CC"       	},
	{ R_ZIPCC         ,	"SCC"      	},
	{ R_ZIPCC         ,	"SR14"     	},
	{ R_ZIPPC         ,	"ZIPPC"    	},
	{ R_ZIPPC         ,	"PC"       	},
	{ R_ZIPPC         ,	"SPC"      	},
	{ R_ZIPPC         ,	"SR15"     	},
	{ R_ZIPUSER       ,	"ZIPUSER"  	},
	{ R_ZIPU0         ,	"UR0"      	},
	{ R_ZIPU1         ,	"UR1"      	},
	{ R_ZIPU2         ,	"UR2"      	},
	{ R_ZIPU3         ,	"UR3"      	},
	{ R_ZIPU4         ,	"UR4"      	},
	{ R_ZIPU5         ,	"UR5"      	},
	{ R_ZIPU6         ,	"UR6"      	},
	{ R_ZIPU7         ,	"UR7"      	},
	{ R_ZIPU8         ,	"UR8"      	},
	{ R_ZIPU9         ,	"UR9"      	},
	{ R_ZIPU10        ,	"SR10"     	},
	{ R_ZIPU11        ,	"SR11"     	},
	{ R_ZIPU12        ,	"SR12"     	},
	{ R_ZIPUSP        ,	"USP"      	},
	{ R_ZIPUSP        ,	"UR13"     	},
	{ R_ZIPUCC        ,	"ZIPUCC"   	},
	{ R_ZIPUCC        ,	"UCC"      	},
	{ R_ZIPUPC        ,	"ZIPUPC"   	},
	{ R_ZIPUPC        ,	"UPC"      	},
	{ R_ZIPSYSTEM     ,	"ZIPSYSTEM"	},
	{ R_ZIPSYSTEM     ,	"ZIPSYS"   	}
};

// REGSDEFS.CPP.INSERT for any bus masters
// And then from the peripherals
// And finally any master REGS.CPP.INSERT tags
#define	RAW_NREGS	(sizeof(raw_bregs)/sizeof(bregs[0]))

const	REGNAME		*bregs = raw_bregs;
const	int	NREGS = RAW_NREGS;

unsigned	addrdecode(const char *v) {
	if (isalpha(v[0])) {
		for(int i=0; i<NREGS; i++)
			if (strcasecmp(v, bregs[i].m_name)==0)
				return bregs[i].m_addr;
#ifdef	R_ZIPCTRL
		if (strcasecmp(v, "CPU")==0)
			return R_ZIPCTRL;
#endif	// R_ZIPCTRL
#ifdef	R_ZIPDATA
		if (strcasecmp(v, "CPUD")==0)
			return R_ZIPDATA;
#endif	// R_ZIPDATA
		fprintf(stderr, "Unknown register: %s\n", v);
		exit(-2);
	} else
		return strtoul(v, NULL, 0);
}

const	char *addrname(const unsigned v) {
	for(int i=0; i<NREGS; i++)
		if (bregs[i].m_addr == v)
			return bregs[i].m_name;
	return NULL;
}

