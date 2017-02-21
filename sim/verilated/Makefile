################################################################################
##
## Filename: 	Makefile
##
## Project:	ZBasic, a generic toplevel impl using the full ZipCPU
##
## Purpose:	To coordinate the build of a cycle accurate, Verilator based,
##		simulation of the busmaster module.  Access to the simulation
##	is provided via the same software commands that will access the board,
##	save that the parameters are a touch different.  (See the access
##	software for more information ...)
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015-2017, Gisselquist Technology, LLC
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
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
##
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http://www.gnu.org/licenses/gpl.html
##
##
################################################################################
##
##
.PHONY: all
# Make certain the "all" target is the first and therefore the default target
all:
CXX      :=  g++
OBJDIR   :=  obj-pc
YYMMDD   := `date +%Y%m%d`
VOBJDR   := ../../rtl/obj_dir
VROOT   ?= $(shell bash -c 'verilator -V|grep VERILATOR_ROOT | head -1 | sed -e " s/^.*=\s*//"')
VINC     := -I$(VROOT)/include -I$(VROOT)/include/vltstd -I$(VOBJDR)
CFLAGS   :=  -c -g -Wall -I. $(VINC)
# Now return to the "all" target, and fill in some details
all:	$(OBJDIR)/ programs archive


.PHONY: programs
programs:	busmaster_tb

$(OBJDIR)/:
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR); fi"

CLSHEADERS:= qspiflashsim.h sdspisim.h uartsim.h zipelf.h
CLSSOURCES:= $(subst .h,.cpp,$(CLSHEADERS))
CLSOBJECTS:= $(addprefix $(OBJDIR)/,$(subst .h,.o,$(CLSHEADERS)))

SOURCES := $(CLSSOURCES)
HEADERS := $(CLSHEADERS)

$(OBJDIR)/%.o: %.cpp
	$(CXX) $(CFLAGS) $< -o $@
$(OBJDIR)/%.o: $(VROOT)/include/%.cpp
	$(CXX) $(CFLAGS) $< -o $@

busmaster_tb: $(OBJDIR)/qspiflashsim.o $(OBJDIR)/sdspisim.o
busmaster_tb: $(OBJDIR)/uartsim.o
busmaster_tb: $(OBJDIR)/verilated.o $(OBJDIR)/verilated_vcd_c.o
busmaster_tb: $(OBJDIR)/zipelf.o $(VOBJDR)/Vbusmaster__ALL.a
busmaster_tb: $(OBJDIR)/busmaster_tb.o
	$(CXX) -g -o $@ $^ -lelf


#
# The "clean" target, removing any and all remaining build products
#
.PHONY: clean
clean:
	rm -f busmaster_tb $(OBJDIR)/*.o
	rm -rf $(OBJDIR)/


#
# The "depends" target, to know what files things depend upon.  The depends
# file itself is kept in $(OBJDIR)/depends.txt
#
define	build-depends
	@echo "Building dependency file"
	@$(CXX) -I. $(VINC) -MM busmaster_tb.cpp $(SOURCES) > $(OBJDIR)/xdepends.txt
        @sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
        @rm $(OBJDIR)/xdepends.txt
endef

.PHONY: depends
depends: tags $(OBJDIR)/
	$(build-depends)

$(OBJDIR)/depends.txt: $(OBJDIR)/ depends

#
# The "tags" target
#
tags:	$(SOURCES) $(HEADERS)	
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

#
# The "archive" target
#
.PHONY: archive
archive:
	tar --transform s,^,$(YYMMDD)-vsim/, -chjf $(YYMMDD)-vsim.tjz Makefile *.cpp *.h

-include $(OBJDIR)/depends.txt
