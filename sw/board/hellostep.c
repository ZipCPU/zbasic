////////////////////////////////////////////////////////////////////////////////
//
// Filename:	hellostep.c
// {{{
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	The original Helllo World program.  If everything works, this
//		will print Hello World to the UART, and then halt the CPU--if
//	run with no O/S.
//
//
////////////////////////////////////////////////////////////////////////////////
//
// Gisselquist Technology asserts no ownership rights over this particular
// hello world program.
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}
#include <stdio.h>
#include "zipcpu.h"
#include "txfns.h"

void user_main(void) {
	printf("Hello, World!\n");
	zip_syscall();
}

int main(int argc, char **argv) {
	int		done = 0, success = 1;
	unsigned	user_regs[16];
	unsigned	user_stack[512];

	for(unsigned k=0; k<16; k++)
		user_regs[k] = 0;
	user_regs[15] = (unsigned)user_main;
	user_regs[14] = CC_STEP;
	user_regs[13] = (unsigned)&user_stack[512];
	zip_restore_context(user_regs);

	while(!done) {
		unsigned	ucc;

		zip_rtu();

		ucc = zip_ucc();
		if (ucc & CC_EXCEPTION) {
			txstr("\r\nEXCEPTION: CC = ");txhex(ucc); txstr("\r\n");
			txstr("\r\n");
			while((_uart->u_fifo & 0x010000) == 0)
				;
			done = 1;
			success = 0;
		} if (ucc & CC_TRAP)
			done = 1;
		else if ((ucc & CC_STEP) == 0) {
			success = 0;
			txstr("\r\nCC & STEP == 0 ?? CC = "); txhex(ucc);
			txstr("\r\n");
			while((_uart->u_fifo & 0x010000) == 0)
				;
		}
	}

	if (success)
		txstr("\r\n\r\nSUCCESS!\r\n");
}
