////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	readstack.cpp
// {{{
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	Reads the stack information from the VCD file
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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>
#include <string>
#include <unordered_map>
#include <vector>

typedef	std::string	*STRINGP, STRING;
typedef	struct VELEM_S {
	STRING	m_key;
	STRINGP	m_name, m_full_name;
	int	m_width;
	int	m_value;
	struct	VELEM_S *m_next;
} VELEM, *VELEMP;

typedef	std::pair<STRING,VELEMP>		KEYVALUE;
typedef	std::unordered_map<STRING, VELEMP>	VLIST;	// key, name, width, value

class	HISTORY : public VLIST {
	long	m_ticks;
public:
	// void HISTORY(void) { }

	/*
	void HISTORY(HISTORY &cp) {
	}
	*/

	/*
	HISTORY &operator=(HISTORY &cp) {
	}
	*/

	int	value(STRING &ky) {
		assert(ky.length()>0);
		// m_h.find(key), returns fm.end() if not found
		iterator	kv = find(ky);
		if (kv != end()) {
			VELEM	*v = kv->second;
			return (v->m_value);
		} else
			return 0;
	}

	int	set(STRING &ky, int val) {
		iterator	kv = find(ky);
		if (kv != end()) {
			VELEM	*v = kv->second;
			v->m_value = val;
			return v->m_value;
		} else {
			//printf("NOT-FOUND, %s, not setting to %d\n", ky.c_str(),
			//	val);
			return 0;
		}
	}

	STRING	getkey(STRING &name) {
		iterator	kv;
		//printf("Looking up key, %s\n", name.c_str());
		for(kv = begin(); kv != end(); kv++) {
			VELEM	*v = kv->second;
			//printf("\tComparing against %s\n", v->m_name->c_str());
			if (0 == strcmp(name.c_str(), v->m_name->c_str())) {
				// printf("\tFound\n");
				return v->m_key;
			}

			while(v=v->m_next) {
				if (0 == strcmp(name.c_str(),
						v->m_name->c_str())) {
					//printf("\tFound\n");
					return v->m_key;
				}
			}

		} printf("NOT FOUND!, %s\n", name.c_str());
		return STRING("");
	}

	void	setclock(long ticks) {
		m_ticks = ticks;
	}

	long	clock(void) {
		return m_ticks;
	}
};

void	parse_clock(FILE *fp, HISTORY *h) {
	const	char	DELIMITERS[] = " \t\n";
	char	line[256];
	int	linesz = sizeof(line), ln;

	while(fgets(line, linesz, fp)) {
		ln = strlen(line);
		while((ln > 0)&&((isspace(line[ln-1]))||(line[ln-1]=='\n')))
			line[--ln] = '\0';
		if ('#' == line[0]) {
			h->setclock(atol(&line[1]));
			return;
		} else if ('0' == line[0]) {
			STRING	ky = STRING(&line[1]);
			h->set(ky, 0);
			//printf("Val = %d, line %s\n", h->set(ky, 0), line);
		} else if ('1' == line[0]) {
			STRING	ky = STRING(&line[1]);
			h->set(ky, 1);
			// printf("Val = %d, 1-line? %s\n", h->set(ky, 1), line);
		} else if ('b' == line[0]) {
			STRING	ky;
			int	v = 0;
			char	*ptr = &line[1];
			while(('0'==*ptr)||('1'==*ptr)||('z'==*ptr)) {
				v = (v<<1)|(('1' == *ptr)?1:0);
				ptr++;
			} ptr = strtok(ptr, DELIMITERS);

			ky = STRING(ptr);
			h->set(ky, v);
		} else {
			ln = strlen(line);
			while((ln > 0)&&((isspace(line[ln-1]))||(line[ln-1]=='\n')))
				line[--ln] = '\0';
			if (strlen(line) > 0)
				fprintf(stderr, "WARNING: Unrecognized line, %s\n", line);
		}
	}

	printf("EOF\n");
}

void	parse_header(FILE *fp, HISTORY *h) {
	const	char	DELIMITERS[] = " \t\n";
	char	line[256], linecp[512];
	int	linesz = sizeof(line);
	int	m_depth = 0;
	char	*ptr;
	std::vector<STRING>	stack;

	while(NULL != (ptr = fgets(line, linesz, fp))) {
		strcpy(linecp, line);
		ptr = strtok(line, DELIMITERS);
		if (NULL == ptr)
			continue;
		if (0 == strcmp(ptr, "$var")) {
			char	*ky;
			VELEM	*ve;
			
			ptr = strtok(NULL, DELIMITERS);
			if (0 != strcmp(ptr, "wire")) {
				fprintf(stderr, "WARNING: Unknown variable type, %s\n", ptr);
			}

			ve = new VELEM;

			ptr = strtok(NULL, DELIMITERS);
			ve->m_width = atoi(ptr);
			assert(ve->m_width > 0);

			ptr = strtok(NULL, DELIMITERS);
			ve->m_key = STRING(ptr);

			ptr = strtok(NULL, DELIMITERS);
			if (!ptr[0])
				ve->m_name = new STRING("");
			else
				ve->m_name = new STRING(ptr);

			ptr = strtok(NULL, DELIMITERS);
			if ((ptr)&&(ptr[0] == '['))
				ptr = strtok(NULL, DELIMITERS);

			if ((ptr)&&(0 == strcmp(ptr, "$end"))
				&&(ve->m_key[0])
				&&((*ve->m_name)[0])
				&&(ve->m_width <= 32)) {

				ve->m_full_name = new STRING(stack[0]);
				for(int k=1; k<stack.size(); k++)
					(*ve->m_full_name) += "__DOT__" + stack[k];
				(*ve->m_full_name) += "__DOT__" + (*ve->m_name);
				ve->m_value = 0;
				ve->m_next = NULL;

				printf("Adding %s,%s\n",
					ve->m_key.c_str(),
					ve->m_name->c_str());

				HISTORY::iterator kvp;
				kvp = h->find(ve->m_key);
				if (kvp != h->end()) {
					ve->m_next = kvp->second;
					kvp->second = ve;
				} else
					h->insert(KEYVALUE(ve->m_key, ve));
			} else {
				/*
				fprintf(stderr, "WARNING: Skipping %s\n",
					((*ve->m_name)[0])? ve->m_name->c_str() : "(unknown)");
				if (!ptr)
					fprintf(stderr, "\tptr = NULL\n");
				else if (0 != strcmp(ptr, "$end"))
					fprintf(stderr, "\tNo $end\n");
				if (!ve->m_key[0])
					fprintf(stderr, "\tNo key\n");
				if ((*ve->m_name)[0]==0)
					fprintf(stderr, "\tNo name\n");
				if (ve->m_width > 32)
					fprintf(stderr, "\tWidth, %d, too large\n",
						ve->m_width);
				*/
				delete	ve;
			}
			// fm.insert(KEYVALUE(mkey, value)
		} else if (0 == strcmp(ptr, "$scope")) {
			m_depth++;
			ptr = strtok(NULL, DELIMITERS);
			if (0 != strcmp(ptr, "module")) {
				fprintf(stderr, "WARNING: Unknown scope type, %s\n", ptr);
			}
			ptr = strtok(NULL, DELIMITERS);
			stack.push_back(STRING(ptr));
		} else if (0 == strcmp(ptr, "$upscope")) {
			m_depth--;
			stack.pop_back();
		} else if (0 == strcmp(ptr, "$enddefinitions")) {
			assert(m_depth == 0);
			break;
		} else {
			// Ignore
		}
	}

	if ((feof(fp))||(ferror(fp))) {
		fprintf(stderr, "ERROR: Could not find the end of the definition section\n");
		exit(EXIT_FAILURE);
	}
}

int main(int argc, char **argv) {
	FILE	*fp = fopen("trace.vcd", "r");
	HISTORY	h;
	STRING	ipc, stb, we, data, adr, npc, jmp, eb, ie;
	STRING	rg[32];
	int	tkaddr, trakd;
	tkaddr = 0x0eff5bc;

	assert(NULL != fp);
	parse_header(fp, &h);

	STRING	ky;

	printf("Getting registers\n");
	for(int k=0; k<32; k++) {
		char	buffer[64];
		sprintf(buffer, "regset(%d)", k);
		ky = STRING(buffer);
		rg[k] = h.getkey(ky);
		assert(rg[k][0]);
	}
	printf("Getting signls\n");
	ky = STRING("gie");		ie  = h.getkey(ky); assert(  ie[0]!=0);
	ky = STRING("zip_stb");		stb = h.getkey(ky); assert( stb[0]!=0);
	ky = STRING("zip_we");		we  = h.getkey(ky); assert(  we[0]!=0);
	ky = STRING("zip_data");	data= h.getkey(ky); assert(data[0]!=0);
	ky = STRING("zip_addr");	adr = h.getkey(ky); assert( adr[0]!=0);
	ky = STRING("pf_request_address");jmp = h.getkey(ky);assert(jmp[0]!=0);
	ky = STRING("dcd_early_branch_stb"); eb = h.getkey(ky); assert(  eb[0]!=0);
	//ky = STRING("i_new_pc");	npc = h.getkey(ky); assert( npc[0]!=0);
	ky = STRING("new_pc");	npc = h.getkey(ky); assert( npc[0]!=0);
	ky = STRING("ipc");	ipc = h.getkey(ky); assert( ipc[0]!=0);

	ky = STRING("%K");
	h.set(ky,2);
	assert(h.value(ky)==2);

	printf("Starting\n");
	int	ipcv, stbv, wev, datav, adrv, npcv, jmpv, ebv, iev,
		rgv[32];
	while(!feof(fp)) {
		bool	changed;

		parse_clock(fp, &h);

		changed = false;

		if (h.value(ipc) != ipcv) {
			changed = true;
			ipcv = h.value(ipc);
		} if (h.value(stb) != stbv) {
			changed = true;
			stbv = h.value(stb);
		} if (h.value(we) != wev) {
			changed = true;
			wev = h.value(we);
		} if (h.value(adr) != adrv) {
			changed = true;
			adrv = h.value(adr);
		} if (h.value(data) != datav) {
			changed = true;
			datav = h.value(data);
		} if (h.value(npc) != npcv) {
			changed = true;
			npcv = h.value(npc);
		} if (h.value(jmp) != jmpv) {
			changed = true;
			jmpv = h.value(jmp);
		} if (h.value(eb) != ebv) {
			changed = true;
			ebv = h.value(eb);
		} if (h.value(ie) != iev) {
			changed = true;
			iev = h.value(ie);
		} for(int k=0; k<32; k++) {
			int	v;
			v = h.value(rg[k]);
			if (v != rgv[k]) {
				rgv[k] = v;
				changed = true;
			}
		}

		if (changed) {
			printf("@%08ld: [%08x] ",
				(h.clock()/1000)-5, ipcv);

			if (iev) {
				printf("Usr ");
				for(int k=0; k<13; k++)
					printf("R[%2d]=0x%08x ", k, rgv[16+k]);
				printf(" SP  =0x%08x ", rgv[16+13]);
			} else {
				printf("Svr ");
				for(int k=0; k<13; k++)
					printf("R[%2d]=0x%08x ", k, rgv[k]);
				printf(" SP  =0x%08x ", rgv[13]);
			} if ((npcv)||(ebv)) {
				printf(" JMP[0x%08x] ", jmpv);
			} else
				printf("%17s","");
			if (stbv) {
				if (wev) {
					if ((adrv << 2)==tkaddr)
						trakd = datav;
					printf(" WE @0x%08x <- 0x%08x",
						adrv<<2, datav);
				} else
					printf(" RD @0x%08x ", adrv<<2);
			} else
				printf("%15s","");

			// printf("MEM[0x%08x] = 0x%08x", tkaddr, trakd);

			printf("\n");
		}
	}

	fclose(fp);
}
