all: dry2
CC=zip-gcc
RAW=dry.c
# SCORE = (CLKSPD*NRUNS*TICKS)/1757
# TICKS = 0x5a320 (100 runs), 0xd6d (1 run)
# DMIPS/MHZ = (1e6 * NRUNS / TICKS / 1757)
#
# Runs:	   1	0x000e79 (was 5a320)
# Runs:  100	0x05a48f
# Runs:  100	0x03366e ( 4k cache)
# Runs:  100	0x033263 (16k cache)
# Runs:  100	0x033263 (32k cache)
# Runs: 1000	0x1ff79f (32k cache)
# Runs: 1000	0x6d122a (SingleFetch, block RAM)
# Runs:  100	0xb53897 (SingleFetch, insns in flash), 0.0048 DMIPS/MHz
# Runs:  100	0x944c3a (DoubleFetch, insns in flash), 0.0058 DMIPS/MHz
CORES  := $(HOME)/work/rnd/opencores
ZBASIC := $(CORES)/zbasic/trunk
# LDSCRIPT  := $(ZBASIC)/sw/board/boardram.ld
LDSCRIPT  := $(ZBASIC)/sw/board/board.ld
# LDSCRIPT  := flash.ld
ZBASICLIB := $(ZBASIC)/sw/zlib/libzbasic.a
ZLIBD  := -L$(ZBASIC)/sw/zlib
LFLAGS := -T $(LDSCRIPT) $(ZLIBD) -lc -lm -lzbasic -lgcc
INCD   := -I$(ZBASIC)/sw/zlib -I$(ZBASIC)/sw/board -I$(ZBASIC)/rtl
CFLAGS=-O3 $(INCD)
dry1.o: dry.c
	$(CC) -c $(CFLAGS) $(RAW) -o dry1.o
dry2: dry1.o dry.c
	$(CC) -DPASS2 $(CFLAGS) $(RAW) dry1.o $(LFLAGS) -o dry2
dry2.txt: dry2
	zip-objdump -Dr dry2 > dry2.txt
.PHONY: dry.txt
dry.txt:
	@echo "Cannot make dry.txt, did you mean to ask me to make dry2.txt?"

clean:
	rm -f dry1.o dry2

test: dry2
	$(ZBASIC)/sim/verilated/main_tb ./dry2
