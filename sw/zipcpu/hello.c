#include <stdio.h>

int main(int argc, char **argv) {
	volatile uint32_t * const uart_config = (uint32_t *)0x140;
	*uart_config = 25;
	printf("Hello, World!\n");
}
