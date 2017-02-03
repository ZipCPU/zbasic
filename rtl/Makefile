##########################################################################/
##
## Filename:	Makefile
##
## Project:	ZBasic, a generic toplevel impl using the full ZipCPU
##
## Purpose:	To direct the Verilator build of the SoC sources.  The result
##		is C++ code (built by Verilator), that is then built (herein)
##	into a library.
##
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
##########################################################################/
##
## Copyright (C) 2015, Gisselquist Technology, LLC
##
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of  the GNU General Public License as published
## by the Free Software Foundation, either version 3 of the License, or (at
## your option) any later version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program.  (It's in the $(ROOT)/doc directory, run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
##
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http:##www.gnu.org/licenses/gpl.html
##
##
##########################################################################/
##
##
all:	test
YYMMDD=`date +%Y%m%d`
CXX   := g++
FBDIR := .
VDIRFB:= $(FBDIR)/obj_dir

.PHONY: test
test: $(VDIRFB)/Vbusmaster__ALL.a

CPUDR := cpu
CPUSOURCESnD := zipcpu.v cpuops.v pfcache.v pipemem.v		\
			pfcache.v idecode.v wbpriarbiter.v zipbones.v	\
	zipsystem.v zipcounter.v zipjiffies.v ziptimer.v		\
		wbdmac.v icontrol.v wbwatchdog.v busdelay.v cpudefs.v
CPUSOURCES := $(addprefix $(CPUDR)/,$(CPUSOURCESnD))

JTAGBUS := wbufifo.v wbubus.v wbucompactlines.v				\
	wbucompress.v wbudecompress.v wbudeword.v wbuexec.v		\
	wbuidleint.v wbuinput.v wbuoutput.v wbureadcw.v wbusixchar.v	\
	wbutohex.v
PERIPHERALS:= ioslave.v wbqspiflash.v llqspi.v flashconfig.v		\
	wbuart.v ufifo.v rxuart.v txuart.v rtclight.v rtcdate.v		\
	wbscope.v memdev.v sdspi.v llsdspi.v
BIGMATH:= # bigadd.v bigsmpy.v bigsub.v
SLOWSRC := busmaster.v builddate.v					\
	$(CPUSOURCES) $(JTAGBUS) $(PERIPHERALS) $(BIGMATH)

$(VDIRFB)/Vbusmaster__ALL.a: $(VDIRFB)/Vbusmaster.h $(VDIRFB)/Vbusmaster.cpp
$(VDIRFB)/Vbusmaster__ALL.a: $(VDIRFB)/Vbusmaster.mk

$(VDIRFB)/Vbusmaster.h: $(VDIRFB)/Vbusmaster.cpp
$(VDIRFB)/Vbusmaster.mk: $(VDIRFB)/Vbusmaster.cpp
$(VDIRFB)/Vbusmaster.cpp: $(SLOWSRC)
	verilator -trace -cc -y $(CPUDR) busmaster.v



$(VDIRFB)/V%__ALL.a: $(VDIRFB)/V%.mk
	cd $(VDIRFB); make -f V$*.mk

.PHONY:
archive:
	tar --transform s,^,$(YYMMDD)-rtl/, -chjf $(YYMMDD)-rtl.tjz Makefile *.v cpu/*.v

.PHONY: clean
clean:
	rm -rf $(VDIRFB)/*.mk
	rm -rf $(VDIRFB)/*.cpp
	rm -rf $(VDIRFB)/*.h
	rm -rf $(VDIRFB)/

