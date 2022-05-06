////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	dblpipecmdr.h
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
//	This extends the pipecmdr approach by creating two channels that share
//	the same bus: a command and a console channel.  The command channel
//	communicates with the 8'th bit set, allowing us to distinguish between
//	the two.
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
#ifndef	DBLPIPECMDR_H
#define	DBLPIPECMDR_H

#include <sys/types.h>
#include <sys/socket.h>
#include <poll.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <signal.h>

#include "port.h"
#include "testb.h"

#define	DBLPIPEBUFLEN	256

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

template <class VA>	class	DBLPIPECMDR : public TESTB<VA> {
	bool	m_debug;

	int	setup_listener(const int port) {
		struct	sockaddr_in	my_addr;
		int	skt;

		signal(SIGPIPE, SIG_IGN);

		if (m_debug) printf("Listening on port %d\n", port);

		skt = socket(AF_INET, SOCK_STREAM, 0);
		if (skt < 0) {
			perror("ERR: Could not allocate socket: ");
			exit(EXIT_FAILURE);
		}

		// Set the reuse address option
		{
			int optv = 1, er;
			er = setsockopt(skt, SOL_SOCKET, SO_REUSEADDR, &optv, sizeof(optv));
			if (er != 0) {
				perror("ERR: SockOpt Err:");
				exit(EXIT_FAILURE);
			}
		}

		memset(&my_addr, 0, sizeof(struct sockaddr_in)); // clear structure
		my_addr.sin_family = AF_INET;
		my_addr.sin_addr.s_addr = htonl(INADDR_ANY);
		my_addr.sin_port = htons(port);
	
		if (bind(skt, (struct sockaddr *)&my_addr, sizeof(my_addr))!=0) {
			perror("ERR: BIND FAILED:");
			exit(EXIT_FAILURE);
		}

		if (listen(skt, 1) != 0) {
			perror("ERR: Listen failed:");
			exit(EXIT_FAILURE);
		}

		return skt;
	}

	int	transmit(int skt, char *buf, int ln, const char *prefix,
			const char *linkid) {
		int	snt = 0;

		if (skt >= 0) {
			snt = send(skt, buf, ln, 0);
			if (snt < 0) {
				printf("Closing %s socket\n", linkid);
				close(skt);
			}
		}

		buf[ln] = '\0';
		if (prefix)
			printf("%s%s", prefix, buf);
		if ((snt > 0)&&(snt < m_cmdpos)) {
			fprintf(stderr, "%s: Only sent %d bytes of %d!\n",
				linkid, snt, m_cmdpos);
		}

		return snt;
	}

public:
	int	m_skt,	// Commands come in on this socket
		m_console,	// UART comes in/out on this socket
		m_cmd,	// Connection to the command port FD
		m_con;	// Connection to the console port FD
	char	m_conbuf[DBLPIPEBUFLEN],
		m_cmdbuf[DBLPIPEBUFLEN],
		m_rxbuf[DBLPIPEBUFLEN];
	int	m_ilen, m_rxpos, m_cmdpos, m_conpos, m_uart_wait, m_tx_busy;
	bool	m_started_flag;
	bool	m_copy;

	DBLPIPECMDR(const int port = FPGAPORT, const bool copy_to_stdout=true)
			: TESTB<VA>(), m_copy(copy_to_stdout) {
		m_debug = false;
		m_con = m_cmd = -1;
		m_skt = setup_listener(port);
		m_console = setup_listener(port+1);
		m_rxpos = m_cmdpos = m_conpos = m_ilen = 0;
		m_started_flag = false;
		m_uart_wait = 0; // Flow control into the FPGA
		m_tx_busy   = 0; // Flow control out of the FPGA
	}

	~DBLPIPECMDR(void) {
		kill();
	}

	virtual	void	kill(void) {
		// Close any active connection
		if (m_cmdpos > 0) {
			m_cmdbuf[m_cmdpos++] = '\n';
			transmit(m_cmd, m_cmdbuf, m_cmdpos, "", "CMD");
			m_cmdpos = 0;
		} if (m_cmd >= 0) {
			close(m_cmd);
		}
		if (m_conpos > 0) {
			m_conbuf[m_conpos++] = '\n';
			transmit(m_con, m_conbuf, m_conpos, "", "CON");
			m_conpos = 0;
		} if (m_con >= 0) {
			close(m_con);
		}
		if (m_skt >= 0)     close(m_skt);
		if (m_console >= 0) close(m_console);

		m_con     = -1;
		m_skt     = -1;
		m_console = -1;
		m_cmd     = -1;
	}

	virtual	void	tick(void) {
		struct	pollfd	pb[2];
		int	npb = 0, r;

		{
			// Check if we need to accept any connections
			if (m_cmd < 0) {
				pb[npb].fd = m_skt;
				pb[npb].events = POLLIN;
				npb++;
			}

			if (m_con < 0) {
				pb[npb].fd = m_console;
				pb[npb].events = POLLIN;
				npb++;
			}

			if (npb > 0) {
				int	pr;
				pr = poll(pb, npb, 0);

				assert(pr >= 0);

				if (pr > 0) {
				for(int k=0; k<npb; k++) {
					if ((pb[k].revents & POLLIN)==0)
						continue;
					if (pb[k].fd == m_skt) {
						m_cmd = accept(m_skt, 0, 0);

						if (m_cmd < 0)
							perror("CMD Accept failed:");
					} else if (pb[k].fd == m_console) {
						m_con = accept(m_console, 0, 0);
						if (m_con < 0)
							perror("CON Accept failed:");
					}
				}}
			}

			// End of trying to accept more connections
		}

		TESTB<VA>::m_core->i_rx_stb = 0;

		if (m_uart_wait == 0) {
			if (m_ilen > 0) {
				// Is there a byte in our buffer somewhere?
				TESTB<VA>::m_core->i_rx_stb = 1;
				TESTB<VA>::m_core->i_rx_data = m_rxbuf[m_rxpos++];
				m_ilen--;
			} else {
				// Is there a byte to be read here?

				npb = 0;
				if (m_cmd >= 0) {
					pb[npb].fd = m_cmd;
					pb[npb].events = POLLIN;
					npb++;
				} if (m_con >= 0) {
					pb[npb].fd = m_con;
					pb[npb].events = POLLIN;
					npb++;
				}

				r = 0;
				if (npb>0) {
					r = poll(pb, npb, 0);
					if (r < 0)
						perror("Polling error:");
				}
				if (r > 0) for(int i=0; i<npb; i++) {
					if (pb[i].revents & POLLIN) {
						int	nr;
						if (m_ilen == sizeof(m_rxbuf))
							continue;
						nr =recv(pb[i].fd, &m_rxbuf[m_ilen], sizeof(m_rxbuf)-m_ilen, MSG_DONTWAIT);
						if (pb[i].fd == m_cmd) {
							for(int j=0; j<nr; j++)
								m_rxbuf[j] |= 0x80;
						} if (nr > 0)
							m_ilen += nr;
						else if (nr <= 0) {
							close(pb[i].fd);
							if (pb[i].fd == m_cmd)
								m_cmd = -1;
							if (pb[i].fd == m_con)
								m_con = -1;
						}
					}
				}

				if (m_ilen > 0) {
					TESTB<VA>::m_core->i_rx_stb = 1;
					TESTB<VA>::m_core->i_rx_data = m_rxbuf[0];
					m_rxpos = 1; m_ilen--;
					m_started_flag = true;
				}
			} m_uart_wait = (TESTB<VA>::m_core->i_rx_stb)?UARTLEN:0;
		} else {
			// Still working on transmitting a character
			m_uart_wait = m_uart_wait - 1;
		}

		TESTB<VA>::tick();

		if (m_tx_busy == 0) {
			if (TESTB<VA>::m_core->o_tx_stb) {
				if (TESTB<VA>::m_core->o_tx_data & 0x80) {
					m_cmdbuf[m_cmdpos++] = TESTB<VA>::m_core->o_tx_data & 0x7f;
				} else
					m_conbuf[m_conpos++] = TESTB<VA>::m_core->o_tx_data & 0x7f;
				if ((m_cmdpos>0)&&((m_cmdbuf[m_cmdpos-1] == '\n')||(m_cmdpos >= DBLPIPEBUFLEN))) {
					if (transmit(m_cmd, m_cmdbuf, m_cmdpos, "> ", "CMD") < 0) {
						m_cmd = -1;
					}
					m_cmdpos = 0;
				}

				if ((m_conpos>0)&&((m_conbuf[m_conpos-1] == '\n')||(m_conpos >= DBLPIPEBUFLEN))) {
					if (transmit(m_con, m_conbuf, m_conpos, "", "CON") < 0) {
						m_con = -1;
					}
					m_conpos = 0;
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
