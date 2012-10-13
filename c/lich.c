// Source & license: see https://github.com/rentzsch/lich/tree/master/c
#include <stdint.h>
#include "lich.h"

#define nil ((void*)0)
#define must(b) do { if (!(b)) return 0; } while (0)

typedef struct Parser Parser;

struct Parser {
	char *s;
	int  n;
	Lich *j;
	int  nj;
};

static int parseelem(Parser*, Lich*, Lich**);


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
inititem(Parser *p, Lich *parent, Lich **prev, uint64_t len, char type)
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
		v->next = nil;
		v->prev = *prev;
		if (*prev) {
			(*prev)->next = v;
		}
		*prev = v;
		return v;
	}
	return nil;
}


static int
parsedata(Parser *p, Lich *parent, Lich **prev)
{
	char c;
	uint64_t len;

	must(scanlen(p, &len));
	c = *p->s++;
	inititem(p, parent, prev, len, c);
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
	Lich *kprev = nil, *vprev = nil;
	char *end = p->s + len;
	while (p->s < end) {
		must(parsedata(p, self, &kprev));
		must(parseelem(p, self, &vprev));
	}
	return 1;
}


static int
parsearray(Parser *p, Lich *self, uint64_t len)
{
	Lich *prev = nil;
	char *end = p->s + len;
	while (p->s < end) {
		must(parseelem(p, self, &prev));
	}
	return 1;
}


static int
parseelem(Parser *p, Lich *parent, Lich **prev)
{
	char c;
	Lich *v;
	uint64_t len;

	must(scanlen(p, &len));
	c = *p->s++;
	v = inititem(p, parent, prev, len, c);
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


// See lich.h for documentation.
int
lichparse(char *src, uint64_t len, Lich *part, int npart)
{
	Parser p = {};
	p.s = src;
	p.j = part;
	p.nj = npart;
	if (!parsearray(&p, nil, len)) {
		return -1;
	}
	return p.n;
}
