////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rtcdate.v
//
// Project:	A Wishbone Controlled Real--time Clock Core
//
// Purpose:
//	This core provides a real-time date function that can be coupled with
//	a real-time clock.  The date provided is in Binary Coded Decimal (bcd)
//	form, and available for reading and writing over the Wishbone Bus.
//
// WARNING: Race conditions exist when updating the date across the Wishbone
//	bus at or near midnight.  (This should be obvious, but it bears
//	stating.)  Specifically, if the update command shows up at the same
//	clock as the ppd clock, then the ppd clock will be ignored and the
//	new date will be the date of the day following midnight.  However,
// 	if the update command shows up one clock before the ppd, then the date
//	may be updated, but may have problems dealing with the last day of the
//	month or year.  To avoid race conditions, update the date sometime
//	after the stroke of midnight and before 5 clocks before the next
// 	midnight.  If you are concerned that you might hit a race condition,
//	just read the clock again (5+ clocks later) to make certain you set
//	it correctly.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2018, Gisselquist Technology, LLC
//
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
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
module rtcdate(i_clk, i_ppd, i_wb_cyc_stb, i_wb_we, i_wb_data, i_wb_sel,
		o_wb_ack, o_wb_stall, o_wb_data);
	parameter [0:0]		F_OPT_CLK2FFLOGIC = 1'b0;
	input	wire		i_clk;
	// A one part per day signal, i.e. basically a clock enable line that
	// controls when the beginning of the day happens.  This line should
	// be high on the very last second of any day in order for the rtcdate
	// module to always have the right date.
	input	wire		i_ppd;
	// Wishbone inputs
	input	wire		i_wb_cyc_stb, i_wb_we;
	input	wire	[31:0]	i_wb_data;
	input	wire	[3:0]	i_wb_sel;
	// Wishbone outputs
	output	reg		o_wb_ack;
	output	wire		o_wb_stall;
	output	wire	[31:0]	o_wb_data;

	wire		update;
	reg	[9:0]	r_block_updates;
	initial	r_block_updates = 10'h3ff;
	always @(posedge i_clk)
		if ((i_wb_we)&&(i_wb_cyc_stb))
			r_block_updates <= 10'h3ff;
		else
			r_block_updates <= { r_block_updates[8:0], 1'b0 };
	assign	update = (i_ppd)&&(!r_block_updates[9]);

	reg	[5:0]	r_day;
	reg	[4:0]	r_mon;
	reg	[13:0]	r_year;

	reg		last_day_of_month, last_day_of_year, is_leap_year;
	reg	[5:0]	days_per_month;
	initial	days_per_month = 6'h31; // Remember, this is BCD
	always @(posedge i_clk)
	begin // Clock 3
		case(r_mon)
		5'h01: days_per_month <= 6'h31; // Jan
		5'h02: days_per_month <= (is_leap_year)? 6'h29:6'h28;
		5'h03: days_per_month <= 6'h31; // March
		5'h04: days_per_month <= 6'h30; // April
		5'h05: days_per_month <= 6'h31; // May
		5'h06: days_per_month <= 6'h30; // June
		5'h07: days_per_month <= 6'h31; // July
		5'h08: days_per_month <= 6'h31; // August
		5'h09: days_per_month <= 6'h30; // Sept
		5'h10: days_per_month <= 6'h31; // October
		5'h11: days_per_month <= 6'h30; // November
		5'h12: days_per_month <= 6'h31; // December
		default: days_per_month <= 6'h31; // Invalid month
		endcase
	end

	initial	last_day_of_month = 1'b0;
	always @(posedge i_clk) // Clock 4
		last_day_of_month <= (r_day >= days_per_month);

	initial	last_day_of_year = 1'b0;
	always @(posedge i_clk) // Clock 5
		last_day_of_year <= (last_day_of_month) && (r_mon == 5'h12);


	reg	year_divisible_by_four, century_year, four_century_year;
	initial	year_divisible_by_four = 1'b0;
	initial	century_year      = 1'b0;
	initial	four_century_year = 1'b0;
	initial	is_leap_year      = 1'b0;
	always @(posedge i_clk) // Clock 1
		year_divisible_by_four<= ((!r_year[0])&&(r_year[4]==r_year[1]));
	always @(posedge i_clk) // Clock 1
		century_year <= (r_year[7:0] == 8'h00);
	always @(posedge i_clk) // Clock 1
		four_century_year <= ((!r_year[8])&&((r_year[12]==r_year[9])));
	always @(posedge i_clk) // Clock 2
		is_leap_year <= (year_divisible_by_four)&&((!century_year)
			||((century_year)&&(four_century_year)));

	// Adjust the day of month
	reg	[5:0]	next_day, fixd_day;
	initial	next_day = 6'h01;
	always @(posedge i_clk)
		if (last_day_of_month)
			next_day <= 6'h01;
		else if (r_day[3:0] != 4'h9)
			next_day <= { r_day[5:4], (r_day[3:0]+4'h1) };
		else
			next_day <= { (r_day[5:4]+2'h1), 4'h0 };

	initial	fixd_day = 6'h01;
	always @(posedge i_clk)
	begin
		if ((r_day == 0)||(r_day > days_per_month))
			fixd_day <= 6'h01;
		else if (r_day[3:0] > 4'h9)
		begin
			fixd_day[3:0] <= 4'h0;
			fixd_day[5:4] <= r_day[5:4] + 1'b1;
		end else
			fixd_day <= r_day;
	end

	initial	r_day = 6'h01;
	always @(posedge i_clk)
	begin // Depends upon 9 inputs
		if (update)
			r_day <= next_day;
		else if (r_block_updates[5:4] == 2'b10)
			r_day <= fixd_day;

		if ((i_wb_cyc_stb)&&(i_wb_we)&&(!i_wb_data[7])&&(i_wb_sel[0]))
			r_day <= i_wb_data[5:0];
	end

	// Adjust the month of the year
	reg	[4:0]	next_mon, fixd_mon;
	initial	next_mon = 5'h01;
	always @(posedge i_clk)
		if (last_day_of_year)
			next_mon <= 5'h01;
		else if ((last_day_of_month)&&(r_mon[3:0] != 4'h9))
			next_mon <= { r_mon[4], (r_mon[3:0] + 4'h1) };
		else if (last_day_of_month)
		begin
			next_mon[3:0] <= 4'h0;
			next_mon[4] <= 1;
		end else
			next_mon <= r_mon;

	initial	fixd_mon = 5'h01;
	always @(posedge i_clk)
		if ((r_mon == 0)||(r_mon > 5'h12)||(r_mon[3:0] > 4'h9))
			fixd_mon <= 5'h01;
		else
			fixd_mon <= r_mon;
	initial	r_mon = 5'h01;
	always @(posedge i_clk)
	begin // Depeds upon 9 inputs
		if (update)
			r_mon <= next_mon;
		else if (r_block_updates[8:7] == 2'b10)
			r_mon <= fixd_mon;

		if ((i_wb_cyc_stb)&&(i_wb_we)&&(!i_wb_data[15])&&(i_wb_sel[1]))
			r_mon <= i_wb_data[12:8];
	end

	// Adjust the year
	reg	[13:0]	next_year;
	reg	[2:0]	next_year_c;
	initial	next_year   = 14'h2000;
	initial	next_year_c = 0;
	always @(posedge i_clk)
	begin // Takes 5 clocks to propagate
		next_year_c[0] <= (r_year[ 3: 0]>=4'h9);
		next_year_c[1] <= (r_year[ 7: 4]>4'h9)||((r_year[ 7: 4]==4'h9)&&(next_year_c[0]));
		next_year_c[2] <= (r_year[11: 8]>4'h9)||((r_year[11: 8]==4'h9)&&(next_year_c[1]));
		next_year[ 3: 0] <= (next_year_c[0])? 4'h0:(r_year[ 3: 0]+4'h1);
		next_year[ 7: 4] <= (next_year_c[1])? 4'h0:
					(next_year_c[0])?(r_year[ 7: 4]+4'h1)
					: (r_year[7:4]);
		next_year[11: 8] <= (next_year_c[2])? 4'h0:
					(next_year_c[1])?(r_year[11: 8]+4'h1)
					: (r_year[11: 8]);
		next_year[13:12] <= (next_year_c[2])?(r_year[13:12]+2'h1):r_year[13:12];


		if ((i_wb_cyc_stb)&&(i_wb_we)&&(!i_wb_data[31])
				&&(i_wb_sel[3:2]==2'b11))
			next_year_c <= 3'h0;
	end

	initial	r_year = 14'h2000;
	always @(posedge i_clk)
	begin // 11 inputs
		// Deal with any out of bounds conditions
		if (r_year[3:0] > 4'h9)
			r_year[3:0] <= 4'h0;
		if (r_year[7:4] > 4'h9)
			r_year[7:4] <= 4'h0;
		if (r_year[11:8] > 4'h9)
			r_year[11:8] <= 4'h0;
		if ((update)&&(last_day_of_year))
			r_year <= next_year;

		if ((i_wb_cyc_stb)&&(i_wb_we)&&(!i_wb_data[31])
				&&(i_wb_sel[3:2]==2'b11))
			r_year <= i_wb_data[29:16];
	end

	always @(posedge i_clk)
		o_wb_ack <= (i_wb_cyc_stb);
	assign	o_wb_stall = 1'b0;
	assign	o_wb_data = { 2'h0, r_year, 3'h0, r_mon, 2'h0, r_day };

	// Make Verilator happy
	// verilator lint_off UNUSED
	wire	[3:0]	unused;
	assign	unused = { i_wb_data[30], i_wb_data[14:13], i_wb_data[6] };
	// verilator lint_on  UNUSED

`ifdef	FORMAL
`ifdef	RTCDATE
`define	ASSUME	assume
	reg	f_last_clk;
	initial	assume(f_last_clk == 1);
	initial	assume(i_clk == 0);
	always @($global_clock)
	begin
		assume(i_clk != f_last_clk);
		f_last_clk <= !f_last_clk;
	end
`else
`define	ASSUME	assert
`endif
	reg	f_past_valid;
	initial	f_past_valid = 1'b0;
	always @(posedge i_clk)
		f_past_valid <= 1'b1;

	initial	`ASSUME(!i_wb_cyc_stb);
	initial	assume(!i_wb_we);
	initial	assume(!i_wb_sel);
	initial	`ASSUME(!i_ppd);

	generate if (F_OPT_CLK2FFLOGIC)
	begin
		always @($global_clock)
		if (!$rose(i_clk))
		begin
			`ASSUME($stable(i_ppd));
			`ASSUME($stable(i_wb_cyc_stb));
			`ASSUME($stable(i_wb_we));
			`ASSUME($stable(i_wb_data));
			`ASSUME($stable(i_wb_sel));

			if (f_past_valid)
			begin
				assert($stable(o_wb_ack));
				assert($stable(o_wb_stall));
				assert($stable(o_wb_data));
			end
		end
	end endgenerate

	always @(posedge i_clk)
		if (f_past_valid)
			assert(o_wb_ack == $past(i_wb_cyc_stb));

	reg	[8:0]	f_past_ppd;
	initial	f_past_ppd = 8'h00;
	always @(posedge i_clk)
		if (i_ppd)
			f_past_ppd <= 9'h1ff;
		else
			f_past_ppd <= { f_past_ppd[7:0], 1'b0 };
	always @(posedge i_clk)
		if (|f_past_ppd)
			`ASSUME(!i_ppd);

	always @(posedge i_clk)
	if (!r_block_updates[9])
	begin
		assert(r_day[3:0] <= 4'h9);
		assert(r_day > 0);
		assert(r_day <= days_per_month);
		assert(days_per_month > 6'h27);
		assert(days_per_month[3:0] <= 4'h9);
		if ((f_past_valid)&&(!$past(i_ppd)))
		begin
			assert((r_mon == 5'h02)||
				(days_per_month == 6'h31)||(days_per_month == 6'h30));
			assert((r_mon != 5'h02)||
				(days_per_month == 6'h28)||(days_per_month == 6'h29));
		end

		if (r_mon[4])
		begin
			assert(r_mon[3:2]==0);
			assert(r_mon[1:0]!=2'b11);
		end else begin
			assert(r_mon[3:0]<=4'h9);
		end

		assert(r_year[ 3: 0] <= 4'h9);
		assert(r_year[ 7: 4] <= 4'h9);
		assert(r_year[11: 8] <= 4'h9);
	end

`endif
endmodule
