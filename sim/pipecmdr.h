////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	pipecmdr.h
// {{{
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	This program attaches to a Verilated Verilog IP core.
//		It will not work apart from such a core.  Once attached,
//	it connects the simulated core to a controller via a TCP/IP pipe
//	interface designed to act like a UART.  This simple test facility
//	is thus designed to verify that the IP core that uses it works prior 
//	to such actual hardware implementation, or alternatively to help
//	debug a core after hardware implementation.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2022, Gisselquist Technology, LLC
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
#ifndef	PIPECMDR_H
#define	PIPECMDR_H

#include <sys/types.h>
#include <sys/socket.h>
#include <poll.h>
#include <unistd.h>
#include <arpa/inet.h>

#include "testb.h"

#define	PIPEBUFLEN	256

#define	i_rx_stb	i_host_rx_stb
#define	i_rx_data	i_host_rx_data
#define	o_tx_stb	o_host_tx_stb
#define	o_tx_data	o_host_tx_data
#define	i_tx_busy	i_host_tx_busy

//
// UARTLEN (a macro)
//
// Attempt to approximate our responses to the number of ticks a UART command
// would respond.
//
// At 115200 Baud, 8 bits of data, no parity and one stop bit, there will
// bit ten bits per character and therefore 8681 clocks per transfer
//	8681 ~= 100 MHz / 115200 (bauds / second) * 10 bauds / character
//
// #define	UARTLEN		8681 // Minimum ticks per character, 115200 Baud
//
// At 4MBaud, each bit takes 25 clocks.  10 bits would thus take 250 clocks
//		
#define	UARTLEN		732	// Ticks per character: 1MBaud, 81.25MHz clock

template <class VA>	class	PIPECMDR : public TESTB<VA> {
	bool	m_debug;

	void	setup_listener(const int port) {
		struct	sockaddr_in	my_addr;

		signal(SIGPIPE, SIG_IGN);

		if (m_debug) printf("Listening on port %d\n", port);

		m_skt = socket(AF_INET, SOCK_STREAM, 0);
		if (m_skt < 0) {
			perror("Could not allocate socket: ");
			exit(-1);
		}

		// Set the reuse address option
		{
			int optv = 1, er;
			er = setsockopt(m_skt, SOL_SOCKET, SO_REUSEADDR, &optv, sizeof(optv));
			if (er != 0) {
				perror("SockOpt Err:");
				exit(-1);
			}
		}

		memset(&my_addr, 0, sizeof(struct sockaddr_in)); // clear structure
		my_addr.sin_family = AF_INET;
		my_addr.sin_addr.s_addr = htonl(INADDR_ANY);
		my_addr.sin_port = htons(port);
	
		if (bind(m_skt, (struct sockaddr *)&my_addr, sizeof(my_addr))!=0) {
			perror("BIND FAILED:");
			exit(-1);
		}

		if (listen(m_skt, 1) != 0) {
			perror("Listen failed:");
			exit(-1);
		}
	}

public:
	int	m_skt, m_con;
	char	m_txbuf[PIPEBUFLEN], m_rxbuf[PIPEBUFLEN];
	int	m_ilen, m_rxpos, m_txpos, m_uart_wait, m_tx_busy;
	bool	m_started_flag;
	bool	m_copy;

	PIPECMDR(const int port, const bool copy_to_stdout=true)
			: TESTB<VA>(), m_copy(copy_to_stdout) {
		m_debug = false;
		m_con = m_skt = -1;
		setup_listener(port);
		m_rxpos = m_txpos = m_ilen = 0;
		m_started_flag = false;
		m_uart_wait = 0; // Flow control into the FPGA
		m_tx_busy   = 0; // Flow control out of the FPGA
	}

	virtual	void	kill(void) {
		// Close any active connection
		if (m_con >= 0)	close(m_con);
		if (m_skt >= 0) close(m_skt);
	}

	virtual	void	tick(void) {
		if (m_con < 0) {
			// Can we accept a connection?
			struct	pollfd	pb;

			pb.fd = m_skt;
			pb.events = POLLIN;
			poll(&pb, 1, 0);

			if (pb.revents & POLLIN) {
				m_con = accept(m_skt, 0, 0);

				if (m_con < 0)
					perror("Accept failed:");
			}
		}

		TESTB<VA>::m_core->i_rx_stb = 0;

		if (m_uart_wait == 0) {
			if (m_ilen > 0) {
				// Is there a byte in our buffer somewhere?
				TESTB<VA>::m_core->i_rx_stb = 1;
				TESTB<VA>::m_core->i_rx_data = m_rxbuf[m_rxpos++];
				m_ilen--;
			} else if (m_con > 0) {
				// Is there a byte to be read here?
				struct	pollfd	pb;
				pb.fd = m_con;
				pb.events = POLLIN;
				if (poll(&pb, 1, 0) < 0)
					perror("Polling error:");
				if (pb.revents & POLLIN) {
					if ((m_ilen =recv(m_con, m_rxbuf, sizeof(m_rxbuf), MSG_DONTWAIT)) > 0) {
						m_rxbuf[m_ilen] = '\0';
						if (m_rxbuf[m_ilen-1] == '\n') {
							m_rxbuf[m_ilen-1] = '\0';
							if (m_copy)
								printf("< \'%s\'\n", m_rxbuf);
							m_rxbuf[m_ilen-1] = '\n';
						} else if (m_copy)
							printf("< \'%s\'\n", m_rxbuf);
						TESTB<VA>::m_core->i_rx_stb = 1;
						TESTB<VA>::m_core->i_rx_data = m_rxbuf[0];
						m_rxpos = 1; m_ilen--;
						m_started_flag = true;
					} else if (m_ilen < 0) {
						// An error occurred, close the connection
						// This could also be the
						// indication of a simple
						// connection close, so we deal
						// with this quietly.
						// perror("Read error: ");
						// fprintf(stderr, "Closing connection\n");
						close(m_con);
						m_con = -1;
					} else { // the connection closed on us
						close(m_con);
						m_con = -1;
					}
				}
			} m_uart_wait = (TESTB<VA>::m_core->i_rx_stb)?UARTLEN:0;
		} else {
			// Still working on transmitting a character
			m_uart_wait = m_uart_wait - 1;
		}

		TESTB<VA>::tick();

		if (m_tx_busy == 0) {
			if ((TESTB<VA>::m_core->o_tx_stb)&&(m_con > 0)) {
				m_txbuf[m_txpos++] = TESTB<VA>::m_core->o_tx_data;
				if ((TESTB<VA>::m_core->o_tx_data == '\n')||(m_txpos >= (int)sizeof(m_txbuf))) {
					int	snt = 0;
					snt = send(m_con, m_txbuf, m_txpos, 0);
					if (snt < 0) {
						close(m_con);
						m_con = -1;
						snt = 0;
					}
					m_txbuf[m_txpos] = '\0';
					if (m_copy) printf("> %s", m_txbuf);
					if (snt < m_txpos) {
						fprintf(stderr, "Only sent %d bytes of %d!\n",
							snt, m_txpos);
					}
					m_txpos = 0;
				}
			}
		} else
			m_tx_busy--;

		if ((TESTB<VA>::m_core->o_tx_stb)&&(TESTB<VA>::m_core->i_tx_busy==0))
			m_tx_busy = UARTLEN;
		TESTB<VA>::m_core->i_tx_busy = (m_tx_busy != 0);
	}
};

#endif
