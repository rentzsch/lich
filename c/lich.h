// Source & license: see https://github.com/kr/clich
typedef struct Lich Lich;

struct Lich {
	uint64_t len;
	char     type; // one of: { [ <
	char     *src;
	char     *end; // src + len
	Lich     *parent;
};

// Scans src and fills in elements of part with pointers to the lexical
// bounds of Lich elements.
//
// Returns the total number of elements in src (which may be 0),
// regardless of npart.
// If src is not well-formed Lich data, returns -1.
int lichparse(char *src, uint64_t len, Lich *part, int npart);
