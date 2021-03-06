////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	sdtest.c
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	This small program tests the SD card, proving whether it does
//		(or doesn't) work from a CPU standpoint.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
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
#include <stdio.h>
#include <stdlib.h>
#include "board.h"
#include "zipsys.h"

#define	SDSPI_READREG	0x0200
#define	SDSPI_WAIT_WHILE_BUSY	while(_sdcard->sd_ctrl & SDSPI_BUSY)

//
//
// Book recommen ds sequence of: CMD0, (CMD8), CMD58, ACMD41(wait), CMD58
//	for startup
//

int	debug_data[128];

void main(int argc, char **argv) {
#ifdef	_BOARD_HAS_SDSPI
	int	*data = debug_data;
	int	i, j;
	unsigned	v;

	printf("\n\nSDSPI testing program\n\n");

	for(i=0; i<sizeof(debug_data)/sizeof(debug_data[0]); i++)
		data[i] = 0;

	// Clear any prior pending errors
	_sdcard->sd_data = 0;
	_sdcard->sd_ctrl = SDSPI_CLEARERR|SDSPI_READAUX;

	printf("Initializing the SD-Card\n  CMD0 - the INIT command\n");
	_sdcard->sd_data = 0;
	_sdcard->sd_ctrl = SDSPI_CMD+0; // CMD zero
	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl)!= 1)
		printf("\t?? Ctrl-RSP  : %08x (!=  1 ?\?)\n", v);
	if ((v = _sdcard->sd_ctrl)!= 1)
		printf("\t?? Ctrl-DATA : %08x (!= -1 ?\?)\n", v);

	// Now let's change speed, and repeat
	//	Clock speed is FPGA clock divided by (2*(VAL+1))
	//	Hence if VAL=1, and the FPGA clock is 80MHz, clock speed
	//		is then 80MHz/4 = 20MHz
	printf("Testing the AUX register\n");
	_sdcard->sd_data = 0x0301;	// 128 word block length, 25MHz clock
	_sdcard->sd_data = 0x0363;	// 128 word block length, 400kHz clock
	_sdcard->sd_ctrl = SDSPI_SETAUX; // Write config data, read last config data
	_sdcard->sd_ctrl = SDSPI_READAUX; // Read  current config data

	_sdcard->sd_data = 0x0701;	// 128 word block length, 
	_sdcard->sd_ctrl = SDSPI_SETAUX; // Write config data, read last config data
	_sdcard->sd_ctrl = SDSPI_READAUX; // Read  current config data

	if ((v = _sdcard->sd_ctrl)!= 1)
		printf("\t?? Ctrl-RSP  : %08x (!= 1?\?)\n", v);
	if ((v = _sdcard->sd_data)!= 0x070701)
		printf("\t?? Ctrl-DATA : %08x (!= 0x070701 ?\?)\n", v);

	printf("  CMD1 - SEND_OP_COND, send operational conditions (voltage)\n");
	_sdcard->sd_data = 0x40000000;
	_sdcard->sd_ctrl = SDSPI_CMD+1; // CMD one -- SEND_OP_COND
	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl)!= 1)
		printf("\t?? Ctrl-RSP  : %08x (!=  1 ?\?)\n", v);
	if ((v = _sdcard->sd_data)!= -1)
		printf("\t?? Ctrl-DATA : %08x (!= -1 ?\?)\n", v);

	printf("  CMD8 - SEND_IF_COND, send interface condition\n");
	_sdcard->sd_data = 0x001a5;
	_sdcard->sd_ctrl = (SDSPI_CMD|SDSPI_READREG)+8; // CMD eight -- SEND_IF_COND
	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl)!= 1)
		printf("\t?? Ctrl-RSP  : %08x (!=      1 ?\?)\n", v);
	if ((v = _sdcard->sd_data)!= 0x01a5)
		printf("\t?? Ctrl-DATA : %08x (!= 0x01a5 ?\?)\n", v);


	{ int	dev_busy;
		do {
			// Now we need to issue an ACMD41 until such time as
			// the in_idle_state turns to zero
			printf(" ACMD\n");
			_sdcard->sd_data = 0;
			_sdcard->sd_ctrl = SDSPI_ACMD;
			SDSPI_WAIT_WHILE_BUSY;

			printf(" ACMD41\n");
			_sdcard->sd_data = 0x40000000;
			_sdcard->sd_ctrl = SDSPI_CMD + 41; // 0x69; // 0x040+41;
			SDSPI_WAIT_WHILE_BUSY;

			dev_busy = _sdcard->sd_ctrl&1;
		} while(dev_busy);
	}

	printf("Finished waiting for startup to complete\n");
	if ((v = _sdcard->sd_ctrl)!= 0)
		printf("\t?? Ctrl-RSP  : %08x (!=  0?\?)\n", v);
	if ((v = _sdcard->sd_data)!= -1)
		printf("\t?? Ctrl-DATA : %08x (!= -1?\?)\n", v);

	printf("  CMD58 - READ-OCR\n");
	// After the card is ready, we must send a READ_OCR command next
	// The card will respond with an R7
	_sdcard->sd_data = 0x0;
	_sdcard->sd_ctrl = (SDSPI_CMD|SDSPI_READREG) + 58; // 0x027a;
	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl)!= 0)
		printf("\t?? Ctrl-RSP  : %08x (!= 0?\?)\n", v);

	v = _sdcard->sd_data;
	printf("    OCR = 0x%08x%s\n", v, (v!=0x40ff8000)?"Shouldnt this be 0x40ff8000?":"");

	// 1'b1 Card poerw up status bit (1'b1 = no longer busy)
	// 1'b1 Card capacity status, CCS (1'b1 = higher capacity ...)
	// 1'b0 UHS-II card status (not a UHS-2 card)
	// 4'h0 Reserved
	// 1'b0 Switching to 1.8V not accepted
	// 8'hff -- 2.8-3.6 volts allowed
	// 1'b1 -- 2.7-2.8 volts allowed (as well)
	// 7'h0 -- reserved
	// 1'b0 -- reserved for low voltage range
	// 7'h0 -- reserved

	printf("Changing clock to high speed\n");

	_sdcard->sd_data = 0x0201;	// 4 word block length, 25MHz clock
	_sdcard->sd_ctrl = SDSPI_SETAUX; // Write config data, read last config data
	_sdcard->sd_ctrl = SDSPI_READAUX; // Read config data, read last config data
	if ((v = _sdcard->sd_data) != 0x070201)
		printf("\tERR: Aux register set to %08x, should be %08x\n", v, 0x070201);

	// CMD nine -- SEND_CSD_COND, send to FIFO #0
	//   Requires FIFO support
	printf(" CMD9 - SEND_CSD_COND\n");
	_sdcard->sd_data = 0;
	_sdcard->sd_ctrl = (SDSPI_CLEARERR|SDSPI_FIFO_OP|SDSPI_CMD) + 9; // 0x08849;
	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl) != 0)
		printf("\tERR: CMD-RESPONSE = %08x, not 0 as expected\n", v);
	if ((v = _sdcard->sd_data) != 0xffffffff)
		printf("\tERR: CMD-DATA     = %08x, not -1 as expected\n", v);

	// CMD ten -- SEND_CID_COND, send to FIFO #1
	//   Requires reading from FIFO
	//   First, set the FIFO length of interest
	printf(" CMD10 - SEND_CID_COND\n");
	_sdcard->sd_data = 0x0201;	// 4 word block length, 25MHz clock
	_sdcard->sd_ctrl = SDSPI_SETAUX; // Write config data, read last config data
	_sdcard->sd_ctrl = SDSPI_READAUX; // Read config data
	*data++ = _sdcard->sd_data; // 0x070201
	_sdcard->sd_data = 0x0;
	_sdcard->sd_ctrl = (SDSPI_CLEARERR|SDSPI_ALTFIFO|SDSPI_FIFO_OP|SDSPI_CMD)+10; // 0x0984a;

	// Read out the CSD condition
	printf("\tCtrl-RSP: %08x\n", _sdcard->sd_ctrl);	
	if ((v = _sdcard->sd_data) != 0xffffffff)
		printf("\tCtrl-DAT: %08x (!= -1 as expected ?\?)\n", v);
	printf("\tCSD_COND: ");
	for(i=0; i<4; i++)
		printf(" %08x", _sdcard->sd_fifo[0]);
	printf("\n");

	// 40,0e,00,32, 5b,59,00,00, e8,37,7f,80, 0a,40,00,23,
	// CSD_STRUCTURE = 2'b01	(CSD version 2.0)
	// 6'h00 (Reserved)
	//
	// TAAC = 0x0e (always 0x0e in v2)
	//
	// NSAC = 0x00 (always 0 in v2)
	//
	// TRAN_SPEED=0x32 (25MHz max operating speed)
	//
	// CCC = 0x5b5
	// READ_BL_LEN = 0x9, max block read length is 512 bytes
	//
	// READ_BL_PARTIAL	= 0
	// WRITE_BLK_MISALIGN	= 0
	// READ_BLK_MISALIGN	= 0
	// DSR_IMP		= 0
	// 2'b00 (reserved)
	// C_SIZE		= 22'h00e837=>(59447+1)/2MB = 29,724MB
	//
	//
	// 1'b0 (reserved)
	// ERASE_BLK_EN		= 1'b1 (Host can erase units of 512 bytes)
	// SECTOR_SIZE		= 7'b11_1111_1	(128 write blocks, 64kB ea)
	// WP_GRP_SIZE		= 7'h00 (one erase sector)
	//
	// WP_GRP_ENABLE	= 1'b0 (No group write protection possible)
	// 2'b00 (reserved)
	// R2W_FACTOR		= 3'b010 (writes are 4x slower than reads)
	// WRITE_BL_LEN		= 4'h9 (512 bytes)
	// WRITE_BL_PARTIAL	= 1'b0 (Only 512 byte units may be written)
	// 5'h00 (reserved)
	//
	// FILE_FORMAT_GRP	= 1'b0 (HD type file system w/partition tbl)
	// COPY			= 1'b0 (Contents are original, not copied)
	// PERM_WRITE_PROTECT	= 1'b0 (No permanent write protect)
	// TMP_WRITE_PROTECT	= 1'b0 (No temporary write protect)
	// FILE_FORMAT		= 2'b00 (As above, HD typ fmt, w/ partition tbl)
	// 2'b00 (reserved)
	//
	// CRC	= { 7'h11, 1'b1 }
	//
	// Derived values:
	// 	BLOCK_LEN = 2^READ_BL_LEN = 512
	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl) != 0x01000) // Expecting 0x01000 for FIFO ID (B)
		printf("\tERR: CMD-RESPONSE = %08x, not 0x01000 as expected\n", v);
	if ((v = _sdcard->sd_data) != 0xffffffff)
		printf("\tERR: CMD-DATA     = %08x, not -1 as expected\n", v);

	printf("  CMD13 - SEND_STATUS\n");
	_sdcard->sd_data = 0x0;
	_sdcard->sd_ctrl = (SDSPI_CLEARERR|SDSPI_READREG|SDSPI_CMD)+ 13; // 0x0824d; // CMD thirteen -- SEND_STATUS 

	// Read out the CID condition
	printf("\tCID : ");
	for(i=0; i<4; i++)
		printf("%08x ", _sdcard->sd_fifo[1]);
	printf("\n");
	// 03,53,44,53, 44,33,32,47, 30,7c,13,03, 66,00,ea,25,
	// MID = 0x03; // Manufacturer ID
	// OID = 0x5344; // OEM/Application ID
	// PNM = 0x5344333247 = "SD32G" // Product Name
	// PRV = 0x30;	// Product Revision
	// PSN = 0x7c130366; // Product Serial Number
	// Reserved= 4'h0
	// MDT = 0x0ea // Manufacturing Date, (October, 2014)
	// CRC = 0x25 = {7'h12, 1'b1}

	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl) != 0) // 0
		printf("\tERR: CMD-RESPONSE = %08x, not 0 as expected\n", v);
	if ((v = _sdcard->sd_data) != 0x00ffffff) // Finally, read the cards status
		printf("\tERR: CMD-DATA     = %08x, not 0x00ffffff as expected\n", v);


	printf("  CMD10 - SEND_CID_COND\n");
	// One last shot at the SEND_CID_COND command, looking at the CRC
	_sdcard->sd_data = 0x0200;	// 128 word block length, 25MHz clock
	_sdcard->sd_ctrl = SDSPI_SETAUX;// Write config data, read last config data
	_sdcard->sd_data = 0x0;	// Read from position zero
	_sdcard->sd_ctrl = (SDSPI_CLEARERR|SDSPI_ALTFIFO|SDSPI_FIFO_OP|SDSPI_CMD)+10; // 0x0184a;
	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl) != 0x01000) // SDSPI_ALTFIFO
		printf("\tERR: CMD-RESPONSE = %08x, not 0x%x as expected\n", v, SDSPI_ALTFIFO);
	if ((v = _sdcard->sd_data) != 0xffffffff) // Finally, read the cards status
		printf("\tERR: CMD-DATA     = %08x, not 0xffff_ffff as expected\n", v);

	printf("\tCID: ");
	for(int i=0; i<4; i++)
		printf(" %08x", _sdcard->sd_fifo[1]);
	printf("\n");
	// 03,53,44,53, 44,33,32,47, 30,7c,13,03, 66,00,ea,25,
	// Interpretation given above



	printf("  CMD55 - Read SCR\n");
	// Let's read the SCR register
	_sdcard->sd_data = 0x0100;	// 128 word block length, 25MHz clock
	_sdcard->sd_ctrl = SDSPI_SETAUX;// Write config data, read last config data
	_sdcard->sd_data = 0;
	_sdcard->sd_ctrl = (SDSPI_CLEARERR|SDSPI_ACMD); // Go to alt command set
	SDSPI_WAIT_WHILE_BUSY;

	printf("  CMD51\n");
	_sdcard->sd_data = 0x0;	// Read from position zero
	_sdcard->sd_ctrl = (SDSPI_CLEARERR|SDSPI_FIFO_OP|SDSPI_CMD)+51; // 0x0184a;
	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl) != 0)
		printf("\tERR: CMD-RESPONSE = %08x, not 0 as expected\n", v);
	if ((v = _sdcard->sd_data) != 0xffffffff)
		printf("\tERR: CMD-DATA     = %08x, not -1 as expected\n", v);

	printf("\tSCR : ");
	for(int i=0; i<2; i++)
		printf("%08x ", _sdcard->sd_fifo[0]);
	printf("\n");


//
//
// READ SECTOR
//
//

	printf("Read a sector\n");
	// Now, let's try reading from the card (gasp!)  Let's read from
	// position zero (wherever that is)
	_sdcard->sd_data = 0x0701;	// 128 word block length, 20MHz clock
	_sdcard->sd_ctrl = SDSPI_SETAUX;// Write config data, read last config data
	_sdcard->sd_data = 0x0;	// Read from position zero
	_sdcard->sd_ctrl = SDSPI_READ_SECTOR;	// CMD 17, into FIFO 0
	SDSPI_WAIT_WHILE_BUSY;

	printf("\tFirst sectors read response-----------\n");
	printf("\tCtrl-RSP: %08x\n", _sdcard->sd_ctrl);
	printf("\tCtrl-DAT: %08x\n", _sdcard->sd_data);

	for(j=0; j<32; j++) {
		printf("\tDATA : ");
		for(i=0; i<4; i++)
			printf("%08x ", _sdcard->sd_fifo[0]);
		printf("\n");
	}

	//
	// Let's read the next four blocks
	for(i=0; i<4; i++) {
		printf("Read sector: #%d\n", i);
		_sdcard->sd_data = i+1;
		_sdcard->sd_ctrl = SDSPI_READ_SECTOR;
		SDSPI_WAIT_WHILE_BUSY;

		printf("\tCtrl-RSP: %08x\n", _sdcard->sd_ctrl);
		printf("\tCtrl-DAT: %08x\n", _sdcard->sd_data);
		for(int k=0; k<32; k++) {
			printf("\tDATA[%03x] : ", k*16);
			for(j=0; j<4; j++)
				printf("%08x ", _sdcard->sd_fifo[0]);
			printf("\n");
		}
	}

//
//
// WRITE SECTOR
//
//
	// For our next test, let us write and then read sector 2.
	_sdcard->sd_data = 0x0701;	// 128 word block length, 20MHz clock

	// Write config data, read last config data
	// This also resets our FIFO to the beginning, so we can start
	// writing into it from the beginning.
	_sdcard->sd_ctrl = SDSPI_SETAUX;
	// Set our data to all FF's.  That way we know the CRC, and can verify
	// that the proper CRC is sent in Verilator: 0x7fa1.
	// _sdcard->sd_fifo[0] = 0x01020304;
	// _sdcard->sd_fifo[0] = 0xffffffff;
	// _sdcard->sd_fifo[0] = 0x05060708;
	printf("Write sector 2\n");
	for(int i=0; i<128; i++)
		_sdcard->sd_fifo[0] = 0x0; // ffffffff;
	_sdcard->sd_ctrl = SDSPI_SETAUX;
	for(int i=0; i<128; i++)
		_sdcard->sd_fifo[1] = 0;
	_sdcard->sd_data = 0x2;	// Write to sector 2
	_sdcard->sd_ctrl = SDSPI_WRITE_SECTOR;

	SDSPI_WAIT_WHILE_BUSY;

	printf("\tCtrl-RSP: %08x ( == 0x0400 ?\?)\n", _sdcard->sd_ctrl);
	printf("\tCtrl-DAT: %08x ( == -1 ?\?)\n", _sdcard->sd_data);

	printf("Read sector 3\n");
	// Now, let's read sector 3, and then read sector 2
	_sdcard->sd_data = 3;
	_sdcard->sd_ctrl = SDSPI_READ_SECTOR;
	SDSPI_WAIT_WHILE_BUSY;
	if (_sdcard->sd_ctrl & 0x08000) {
		_sdcard->sd_data = 3;
		_sdcard->sd_ctrl = SDSPI_READ_SECTOR;
		SDSPI_WAIT_WHILE_BUSY;

		if ((v = _sdcard->sd_ctrl)!=0)
		printf("\tERR Ctrl-RSP: %08x (was expecting 0x%x)\n", _sdcard->sd_ctrl, 0);
		printf("\tCtrl-RSP: %08x\n", _sdcard->sd_ctrl);
		if ((v = _sdcard->sd_data) != 0xffffffff)
			printf("\tERR Ctrl-DAT: %08x ( == -1 ?\?)\n", _sdcard->sd_data);
	} else {
		printf("\tCtrl-RSP: %08x\n", _sdcard->sd_ctrl);
		if ((v = _sdcard->sd_data) != 0xffffffff)
			printf("\tERR Ctrl-DAT: %08x ( == -1 ?\?)\n", _sdcard->sd_data);
	}

	printf("Read sector 2\n");
	_sdcard->sd_data = 2;
	_sdcard->sd_ctrl = SDSPI_READ_SECTOR|SDSPI_ALTFIFO;
	for(i=0; i<128; i++)
		*data++ = _sdcard->sd_fifo[0];
	// Wait for the read operation to complete
	SDSPI_WAIT_WHILE_BUSY;

	if ((v = _sdcard->sd_ctrl) != SDSPI_ALTFIFO)
		printf("\tERR Ctrl-RSP: %08x (was expecting 0x%x)\n", _sdcard->sd_ctrl, SDSPI_ALTFIFO);
	if ((v = _sdcard->sd_data) != 0xffffffff)
		printf("\tERR Ctrl-DAT: %08x ( == -1 ?\?)\n", _sdcard->sd_data);


	// Set the FIFO back to zero
	_sdcard->sd_data = 0;
	_sdcard->sd_ctrl = SDSPI_READAUX;
	// Read sector two out of the FIFO
	for(int i=0; i<128; i++)
		*data++ = _sdcard->sd_fifo[1];

	if ((v = _sdcard->sd_ctrl) != SDSPI_ALTFIFO)
		printf("\tERR Ctrl-RSP: %08x (Expecting a %08x)\n", _sdcard->sd_ctrl, SDSPI_ALTFIFO);
	if ((v = _sdcard->sd_data) != 0xffffffff)
		printf("\tERR Ctrl-DAT: %08x ( == -1 ?\?)\n", _sdcard->sd_data);

	printf("Test is complete\n");
	printf("Test is complete\n");
	printf("Test is complete\n");
	printf("Test is complete\n");

#else
	printf("This board has no SDSPI built in\n");
#endif
}

