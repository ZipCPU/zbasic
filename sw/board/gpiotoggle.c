////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	gpiotoggle.c
// {{{
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	A touch of C code to see just how fast we can reasonably toggle
//		a GPIO wire.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2020-2022, Gisselquist Technology, LLC
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
#include <board.h>

#ifdef	GPIO_ACCESS

int	main(int argc, char **argv) {
// #define	CACHEHIT
#define	GPIOCMD
// #define	TWINTEST
// #define	COUNTER
// #define	FASTEST
#ifdef	CACHEHIT
	while(1) {
		//
		// In general, this would be N cycles in (50+20N) ns
		// as long as we didn't walk off of a cache line
		// 120ns ea w/o pipelined memory bus
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
	}
#endif
#ifdef	FASTEST
	while(1) {
	// 4 cycles in 130 ns, uneven duty cycle, or
	// 1 cycle  in  70ns, lopsided duty cycle (1 on, 6 off)
	// In general, this would be N cycles in (50+20N) ns
	//
	// The cost is 120ns duty cycle without the pipelined bus accesses
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
	}
#endif
#ifdef	TWINTEST
	while(1) {
	// 4 cycles in 130 ns, uneven duty cycle, or
	// 1 cycle  in  70ns, lopsided duty cycle (1 on, 6 off)
	// In general, this would be N cycles in (50+20N) ns
	//
	// The cost is 120ns duty cycle without the pipelined bus accesses
		*_gpio = GPIO_SET(1);
		*_gpio = GPIO_CLR(1);
	}
#endif
#ifdef	COUNTER
	int	counter = 0;
	while(1) {
		// Uniform duty cycle, but it now takes 160ns per loop
		// or 6.250MHz, w/ or w/o OPT_PIPEMEM
		*_gpio = (1<<16)|(counter&1);
		counter++;
	}
#endif
#ifdef	GPIOCMD
	// 120ns per loop, or 8.33MHz
	// Same w/ or w/o OPT_PIPEMEM
	int	gpiocmd = 1<<16;
	while(1) {
		*_gpio = gpiocmd;
		gpiocmd ^= 1;
	}
#endif
}

#endif // GPIO_ACCESS
