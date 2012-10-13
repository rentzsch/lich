// Source & license: see https://github.com/kr/clich
#include <stdint.h>
#include "lich.h"

#define nil ((void*)0)
#define must(b) do { if (!(b)) return 0; } while (0)

typedef struct Parser Parser;

struct Parser {
	char *s;
	char *end;
	int  n;
	Lich *j;
	int  nj;
};

static int parseelem(Parser*, Lich*);


static int
consume(Parser *p, char c)
{
	must(*p->s++ == c);
	return 1;
}


static int
scanlen(Parser *p, uint64_t *len)
{
	char c = *p->s;
	must('0' <= c && c <= '9');
	*len = 0;
	while ('0' <= c && c <= '9') {
		p->s++;
		*len *= 10;
		*len += c - '0';
		c = *p->s;
	}
	return 1;
}


static Lich *
inititem(Parser *p, Lich *parent, uint64_t len, char type)
{
	p->n++;
	if (p->nj > 0) {
		Lich *v = p->j;
		p->j++;
		p->nj--;
		v->len = len;
		v->type = type;
		v->src = p->s;
		v->end = p->s + len;
		v->parent = parent;
		return v;
	}
	return nil;
}


static int
parsedata(Parser *p, Lich *parent)
{
	char c;
	uint64_t len;

	must(scanlen(p, &len));
	c = *p->s++;
	inititem(p, parent, len, c);
	switch (c) {
	case '<':
		p->s += len;
		must(consume(p, '>'));
		return 1;
	}
	return 0;
}


static int
parsedict(Parser *p, Lich *self, uint64_t len)
{
	char *end = p->s + len;
	while (p->s < end) {
		must(parsedata(p, self));
		must(parseelem(p, self));
	}
	return 1;
}


static int
parsearray(Parser *p, Lich *self, uint64_t len)
{
	char *end = p->s + len;
	while (p->s < end) {
		must(parseelem(p, self));
	}
	return 1;
}


static int
parseelem(Parser *p, Lich *parent)
{
	char c;
	Lich *v;
	uint64_t len;

	must(scanlen(p, &len));
	c = *p->s++;
	v = inititem(p, parent, len, c);
	switch (c) {
	case '{':
		must(parsedict(p, v, len));
		must(consume(p, '}'));
		return 1;
	case '[':
		must(parsearray(p, v, len));
		must(consume(p, ']'));
		return 1;
	case '<':
		p->s += len;
		must(consume(p, '>'));
		return 1;
	}
	return 0;
}


static int
parsedoc(Parser *p)
{
	while (p->s < p->end) {
		must(parseelem(p, nil));
	}
	return 1;
}


// Scans src and fills in elements of part with pointers to the lexical
// bounds of Lich elements.
//
// Returns the total number of elements in src (which may be 0),
// regardless of npart.
// If src is not well-formed Lich data, returns -1.
int
lichparse(char *src, uint64_t len, Lich *part, int npart)
{
	Parser p = {};
	p.s = src;
	p.end = src + len;
	p.j = part;
	p.nj = npart;
	if (!parsedoc(&p)) {
		return -1;
	}
	return p.n;
}
