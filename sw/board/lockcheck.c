#include <stdio.h>
#include <stdlib.h>
#include "txfns.h"
#include "zipcpu.h"
#include "board.h"

const unsigned	NUM_TASKS = 4;

typedef	struct	TASKT_S {
	unsigned volatile *regs;
	unsigned	*stackp;
} TASKT;

volatile char		atomic;
volatile unsigned	shared_resource;

void	user_task(int task_id, int *loops) {
	unsigned	task_fail = 0;
	*loops = 0;
	while(*loops < 1024) {
		if (!__atomic_test_and_set(&atomic, __ATOMIC_RELAXED)) {
			shared_resource = task_id;
			for(int k=0; k<5; k++) {
				// if (shared_resource != task_id) LED = RED;
				if (shared_resource != task_id)
					task_fail = 1;
				if (atomic != 1)
					task_fail = 1;
			}

			*loops = *loops + 1;
			atomic = 0;
		}
	}

	while (__atomic_test_and_set(&atomic, __ATOMIC_RELAXED)) {}

	printf("Task #%d: COMPLETE\n", task_id);
	atomic = 0;

	if (task_fail)
		*loops = -1;
	zip_syscall();
	(*_gpio) = GPIO_SET(2);
	while(1)
		txchr('!');
}

// And a main task that steps each task
int	main(int argc,char **argv) {
	TASKT	TASK[NUM_TASKS];
	unsigned	task_loops[NUM_TASKS];
	unsigned	success = 1;

	atomic = 0;
	shared_resource = 0;

	// Step up tasks
	for(int taskn=0; taskn < NUM_TASKS; taskn++) {
		TASK[taskn].regs  = malloc(sizeof(int)*16);
		TASK[taskn].stackp= malloc(sizeof(int)*512)
					+ sizeof(int)*512;
		for(int r=0; r<13; r++)
			TASK[taskn].regs[r] = 0;
		TASK[taskn].regs[15] = (unsigned)user_task;
		TASK[taskn].regs[14] = CC_STEP;
		TASK[taskn].regs[13] = (unsigned)TASK[taskn].stackp;
		TASK[taskn].regs[ 1] = taskn;	// The task ID
		TASK[taskn].regs[ 2] = (unsigned)&task_loops[taskn];
	}

	(*_gpio) = GPIO_SET(1);

	// Then run them
	while(1) {
		int	completed;

		completed = 0;
		for(int taskn=0; taskn < NUM_TASKS; taskn++) {
			if (TASK[taskn].regs[14] & (CC_TRAP | CC_EXCEPTION)) {
				completed++;
			} else {
				zip_restore_context((void *)TASK[taskn].regs);
				// zip_ucc() |= STEP;//What's the syntax here?!?
				zip_rtu();
				zip_save_context((void *)TASK[taskn].regs);
				if (zip_ucc() & (CC_EXCEPTION))
					success = 0;
			}
		}

		if (completed >= NUM_TASKS)
			break;
	}

	if (success) {
		for(int taskn=0; taskn < NUM_TASKS; taskn++) {
			printf("  LOOPS[%2d] = 0x%08x\n", taskn, task_loops[taskn]);
			if (task_loops[taskn] == 0xffffffff)
				success = 0;
		}

		if (success)
			printf("SUCCESS!\n");
		else
			printf("TASK FAILURE\n");
	} else
		printf("TEST FAILURE!\n");
}
