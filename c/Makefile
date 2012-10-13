CFLAGS ?= -Werror -Wall -Wformat=2

all: check

lich.o: lich.c lich.h

.PHONY: check
check: ct/_ctcheck
	ct/_ctcheck

ct/ct.o: ct/ct.h

test.o: ct/ct.h lich.h

ct/_ctcheck: ct/_ctcheck.o ct/ct.o lich.o test.o

ct/_ctcheck.c: test.o ct/gen
	ct/gen test.o > $@.part
	mv $@.part $@

.PHONY: clean
clean:
	rm -f *.o ct/_* ct/*.o
