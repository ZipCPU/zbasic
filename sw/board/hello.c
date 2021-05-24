////////////////////////////////////////////////////////////////////////////////
//
// Filename:	helloworld.c
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

int main(int argc, char **argv) {
	printf("Hello, World!\n");
}
