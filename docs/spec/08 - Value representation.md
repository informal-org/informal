Informal uses u64 as its only primitive value type. 

### Primitive Numbers
All values are also valid F64 numbers which can be used directly for fast math without unboxing. 
NaN floating values have 51 unused bits, which are used to pack pointers and compact values into it. 

`0 00000001010 0000000000000000000000000000000000000000000000000000` = The number 64
You can precisely represent all integers from -2^53 (−9,007,199,254,740,992) to 2^53 (9,007,199,254,740,992) in this range.

`1 11111111111 1000000000000000000000000000000000000000000000000000` = NaN
Look at all those unused bits! We're going to tag it and repurpose it to speed up the usage of many common types of values.

### Objects
We need a way to reference objects in memory. The current version of WebAssembly gives us 4GB of addressable space. With a 32 bit pointer, we can address each byte of that 4GB space. Just like NaN tagging, [Tagged Pointers](https://en.wikipedia.org/wiki/Tagged_pointer) use a technique which takes advantage of memory alignment. Since all valid addresses are multiples of 64 (8 byte alignment), all of our pointers would have `000`. There's no need for us to use a 64 bit pointer to point to a 64 bit 'object', so instead we require a min object size of 4 words (256 bytes). This gives us a smaller addressable range of about 130 million objects, which can be indexed with just 27 bits. 

Objects in Informal are allocated to per-class regions. Regions are compact, cache-efficient and are designed to be easy to garbage collect (more details later). 
Objects in Informal have no header overhead. All of the relevant info is contained within the Object Pointer and the region header (Class, GC metadata). 

|                                      | Type | Region Ptr | Object Idx | Attribute Index |
| ------------------------------| :------ | ---------------:| ----------------: | :--------------------:|
|Size (bits)                     | 3       | 16                | 27                 | 5                         |
|Addressable Entities | 8       | 65536          | 134217728 | 32                       |

The heap contains 65k "regions", with a minimum region size of 62 KB. The attribute index can be used to directly index into an object's attribute (with 1 reserved value, for larger objects).

### Object Array / Slice
We can also point to small arrays or slices of objects up to 63 elements without any boxing. 

|                                      | Type | Region Ptr | Object Idx   | Length              |
| ------------------------------| :------ | ---------------:| ----------------: | :--------------------:|
|Size (bits)                     | 3       | 16                | 27                 | 5                         |
|Addressable Entities | 8       | 65536          | 134217728 | 32                       |

An array length of 0 is used to point to larger arrays, which contain the length inline like traditional arrays. Because all objects in Informal are immutable, the metadata contained within the pointers remain relevant. Additionally, the region+index scheme allows us to do GC compaction without rewriting these pointers.

### Primitive Array / Slice
We can get a much larger addressable space for Slices of primitive types. Allowing us to point to ranges of numbers, bitsets, strings, etc.

|                                      | Type | Raw Ptr      | Length         |
| ------------------------------| :------ | ---------------:| ----------------: |
|Size (bits)                     | 3       | 29                | 19                 |
|Addressable Entities | 8       | 536870912 | 524288        |

We can index into much larger arrays of up to half a million elements and also get 64-bit word-sized pointer resolution.

### Inline Data
Our final trick is to use this space to directly store compact values inline. This reduces the total number of objects in the system, reducing GC pressure and extraneous memory lookup. 

We reserve the type code of `11` for this use-case (enabling some future bit-tricks). 

|                                      | Type |  Inline Data            |
| ------------------------------| :------ | -------------------------: |
|Size (bits)                     | 3       |  48                            |
|Addressable Entities | 8       | 281474976710656 |

Inline types:
Bitsets - Arrays of Booleans are represented as bitsets, taking just a single bit per boolean rather than an entire byte. This enables fast binary operations that'll be useful in data processing.

Symbols - Symbols are immutable constants used to represent a value or identifier, independent of its textual name. Certain constants like "nil" are just symbols. 

Small Strings - Short strings appear often in code and text-processing. Frequently used words tend to be short. You can represent about 76% of common English words with 6 characters and 84% with 7 ([frequency reference](https://math.wvu.edu/~hdiamond/Math222F17/Sigurd_et_al-2004-Studia_Linguistica.pdf)). 48 bits allow us to store 2-6 Unicode characters (1-3 bytes each) or nearly 7 ASCII characters (without the full range for the last bit).
This idea's not new - Mike Pall implemented this for [LuaJIT](http://lua-users.org/wiki/FastStringPatch) (he also popularized the use of NaN tagging and other tricks used here). 

### Wrapped Primitive Data
Many types of objects serve as wrappers around primitive types. 
A Point class could be represented as an array of 3 integers or an object with x, y, z.
Dates, colors, complex numbers and many other types are similar wrappers around primitive types. 
We can reference these objects while preserving the weapper type using this format. 

3 bit type. 29 bit pointer. 16 bit object type. 3 bit attribute index. 
You can encode wrapped objects with up to 8 attributes in this format.
The minimum object size does not apply to these primitive objects, allowing for compact
1 word or 2 word objects with zero object overhead. 

### Wrapped Primitive Arrays
3 bit type, 26 bit pointer, 16 bit object type, 6 bit length. 
References small arrays of primitive objects. With a 512 bit alignment (i.e. larger than max primitive wrapped object). 
Can address up fo 64 elements. 




