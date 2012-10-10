# Lich 0.1

Lich is a data format that is:

* **Simple:** Lich only has three element types: data, arrays and dictionaries. Each element follows the same syntax (size, open marker, content, close marker).

* **General:** Lich's arrays and dictionaries are Just Enough to support self-describing data and general structure inspection and editing tools.

* **Human-sympathetic:** Lich is mostly directly readable by humans in hex/ASCII data dumps and even text editors. Lich's markers were chosen to easily allow humans to discover the beginning and ending of elements. The brackets and braces are immediately familiar to anyone with HTML/XML and JSON experience.

* **Binary:** Binary data such as images and public keys are directly represented sans any need for encoding or escaping and their associated code-complexity and size-bloat. Lich is a compact format designed for space-constrained environments such as UDP packets.

Lich isn't for everyone since it's:

* **Untyped:** Data is directly represented in binary format. No direct attempt is made to provide hints to the reader what the data describes. That said, ASCII can be directly displayed in the Lich stream and dictionary keys often provide enough context to puzzle out a blob's meaning.

* **Tedious to Write by Hand:** Lich's size-first format enables its security and efficiency, but it's tedious for humans to count lengths and keep them consistent. Updating a deeply-nested element in a text editor is the worst thing about Lich.

* **Terse:** Lich disallows whitespace, making human visual parsing more difficult.

* **Rare:** Lich is the new kid on the block, targeting a specific niche. JSON can do everything Liche can do with better tool & API support and human readability/editability, albeit in far more space+time.

### Examples

Here's "hello world" in ASCII:

	11<hello world>

Lich happily supports UTF-8, but writing Lich streams by hand in a text editor is problematic with non-ASCII strings since UTF-8 is multi-byte (making it easy to get the lengths wrong). So we'll stick with ASCII here.

Here's a dictionary with the same string under a key of "greeting":

	26{8<greeting>11<hello world>}

Here's what the same data would look like in JSON:

	{"greeting": "hello world"}

JSON wins the beauty contest, but Lich can efficiently host binary data (you probably have to resort to Base64 to do that in JSON).

Here's an array of fruits:

	26[5<apple>6<banana>6<orange>]

Same thing in JSON:

	["apple", "banana", "orange"]

And of course you can nest structures:

	126{14<selling points>40[6<simple>7<general>19<human-sympathetic>]8<greeting>11<hello world>5<fruit>26[5<apple>6<banana>6<orange>]}

And in JSON:

	{
		"selling points": ["simple", "general", "human-sympathetic"],
		"greeting": "hello world",
		"fruit: ["apple", "banana", "orange"]
	}

### Grammar

Here's a pseudo-BNF grammar for Lich:

	document            ::=  elements*
	element             ::=  data_element | array_element | dictionary_element
	data_element        ::=  size '<' byte* '>'
	array_element       ::=  size '[' element* ']'
	dictionary_element  ::=  size '{' key_value* '}'
	key_value           ::=  data_element element
	size                ::=  [0-9]{1,20} # Note: must fit into an uint64_t (<= 18,446,744,073,709,551,615 (2^64-1))

### Implementation Notes

Lich should be able to be implemented in any practical language. Contributions welcome.

LichCocoa (in the `cocoa/` directory) is an implementation of Lich in Objective-C for Cocoa. It should work on both Mac and iOS. It can encode and decode NSData, NSArray and NSDictionaries to Lich and back.

Expected-valid and expected-invalid encoding and decoding examples reside in `loch-tests.json`. Run `rake` in Lich's project directory to build `TestLichCocoa`, a helper tool, and run through the test examples.

### Canonical Format

Lich is a straight-forward data format with little leeway, but if you need to generate a canonical stream for crypto purposes, there's one additional generation rule:

* Dictionary key-value pairs are sorted data-wise by their key.

The LichCocoa implementation automatically does this for you when generating Lich streams (but doesn't enforce dictionary key ordering when parsing).

### Endianess

Because Lich encodes sizes in ASCII digits, its format is endian neutral (data element content bytes can be in little-endian or big-endian format). That said, Lich strongly recommends storing data in network order (big endian).

### The Name

I didn't know what to name a new data format, so I had my [password generating application](http://www.selznick.com/products/passwordwallet/) show me random words. Lich was the third word. I hadn't heard of it before, but I liked that it was short.

I looked up the definition (a type of undead creature) and thought it fit well with the idea of a serialization format -- "live" objects are serialized to it, reanimating in another process in another time.

How ghoulishly poetic.

### Inspirations

* [S-expressions](http://en.wikipedia.org/wiki/S_expression)
* [netstrings](http://en.wikipedia.org/wiki/Netstrings)
* [Property Lists](http://en.wikipedia.org/wiki/Property_list)
* [HTML](http://en.wikipedia.org/wiki/Html)/[XML](http://en.wikipedia.org/wiki/Xml)
* [JSON](http://en.wikipedia.org/wiki/Json)
* [bencode](http://en.wikipedia.org/wiki/Bencode)

### See Also

* [Tagged Netstrings](http://tnetstrings.org/) (thanks to [
Benjamin Pollack](https://twitter.com/bitquabit/status/253961353402925057))

### Version History

### v0.1: Thu Oct 04 2012

* Initial Announcement.