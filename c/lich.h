// Source & license: see https://github.com/rentzsch/lich/tree/master/c
typedef struct Lich Lich;

struct Lich {
	uint64_t len;
	char     type; // one of: { [ <
	char     *src;
	char     *end; // src + len
	Lich     *parent;
	Lich     *next;
	Lich     *prev;
};

// Scans src and fills in at most nelem elements of elem with
// pointers to the lexical bounds of Lich elements. Elements
// are written to elem in the order they appear in src.
//
// Returns the total number of elements in src (which may be 0),
// regardless of nelem.
// If src is not well-formed Lich data, returns -1.
int lichparse(char *src, uint64_t len, Lich *elem, int nelem);
