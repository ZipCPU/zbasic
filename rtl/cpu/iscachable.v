////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./iscachable.v
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
// Copyright (C) 2017-2022, Gisselquist Technology, LLC
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
`default_nettype none
//
module iscachable(
		// {{{
		input	wire	[25-1:0]	i_addr,
		output	reg			o_cachable
		// }}}
	);

	always @(*)
	begin
		o_cachable = 1'b0;
		// Bus master: wb
		// Bus master: wb_sio
		// bkram
		if ((i_addr[24:0] & 25'h1e00000) == 25'h0c00000)
			o_cachable = 1'b1;
		// flash
		if ((i_addr[24:0] & 25'h1000000) == 25'h1000000)
			o_cachable = 1'b1;
	end

endmodule
