#include <stdint.h>
#include <string.h>
#include "ct/ct.h"
#include "lich.h"

#define nil ((void*)0)

typedef struct Valid Valid;

struct Valid {
	char *src;
	int  n;
	Lich parts[100];
};

static int r;
static Lich x[100];


char *invalid[] = {
	" 11<hello world>",
	"11<hello world> ",
	"11<hello world%",
	"11%hello world>",
	"x",
	nil,
};

Valid valid[] = {
	{"", 0, {}},
	{"11<hello world>", 1, {{11, '<', "hello world"}}},
	{"5<apple>6<banana>6<orange>", 3, {
		{5, '<', "apple"},
		{6, '<', "banana"},
		{6, '<', "orange"},
	}},
	{"26{8<greeting>11<hello world>}", 3, {
		{26, '{', "8<greeting>11<hello world>"},
		{8, '<', "greeting"},
		{11, '<', "hello world"},
	}},
	{"26[5<apple>6<banana>6<orange>]", 4, {
		{26, '[', "5<apple>6<banana>6<orange>"},
		{5, '<', "apple"},
		{6, '<', "banana"},
		{6, '<', "orange"},
	}},
	{"126{14<selling points>40[6<simple>7<general>17<human-sympathetic>]8<greeting>11<hello world>5<fruit>26[5<apple>6<banana>6<orange>]}", 13, {
		{126, '{', "14<selling points>40[6<simple>7<general>17<human-sympathetic>]8<greeting>11<hello world>5<fruit>26[5<apple>6<banana>6<orange>]"},
		{14, '<', "selling points"},
		{40, '[', "6<simple>7<general>17<human-sympathetic>"},
		{6, '<', "simple"},
		{7, '<', "general"},
		{17, '<', "human-sympathetic"},
		{8, '<', "greeting"},
		{11, '<', "hello world"},
		{5, '<', "fruit"},
		{26, '[', "5<apple>6<banana>6<orange>"},
		{5, '<', "apple"},
		{6, '<', "banana"},
		{6, '<', "orange"},
	}},
	{},
};


void
cttestcount()
{
	int i;

	for (i = 0; valid[i].src; i++) {
		Valid v;

		v = valid[i];
		r = lichparse(v.src, strlen(v.src), nil, 0);
		ctlog("valid %d: “%s”", i, v.src);
		assertf(r == v.n, "r is %d, exp %d", r, v.n);
	}
}


void
cttestparse()
{
	int i, j;

	for (i = 0; valid[i].src; i++) {
		Valid v;

		v = valid[i];
		r = lichparse(v.src, strlen(v.src), x, 100);
		ctlog("valid %d: “%s”", i, v.src);
		assertf(r == v.n, "r is %d, exp %d", r, v.n);
		for (j = 0; j < r; j++) {
			Lich exp = v.parts[j], got = x[j];
			assertf(exp.len == strlen(exp.src), "%d != “%s”", (int)exp.len, exp.src); // sanity check test data
			assertf(got.type == exp.type, "part %d: '%c' != '%c'", j, got.type, exp.type);
			assertf(got.len == exp.len, "part %d: %d != %d", j, (int)got.len, (int)exp.len);
			assertf(strncmp(got.src, exp.src, got.len) == 0, "part %d: got %*s", j, (int)got.len, got.src);
			assertf(got.end == got.src + got.len, "part %d", j);
		}
	}
}


void
cttestinvalid()
{
	int i;

	for (i = 0; invalid[i]; i++) {
		ctlog("invalid %d: “%s”", i, invalid[i]);
		r = lichparse(invalid[i], strlen(invalid[i]), nil, 0);
		assertf(r == -1, "r is %d, invalid %d", r, i);
	}
}
