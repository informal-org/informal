/* 
CAT - Content Addressed Table - An efficient indexed data structure for sorted, associative data.
Tuned for strings in this case, but generally applicable.

Each layer behaves like a radix tree. The radix array is sized in powers of two and it indicates how many of the MSB bits we index by.
The radix array implements dynamic re-balancing based on a load-factor, doubling and thus splitting it's child-layers.
[A, B, C, D, ..., Z] -> [AA, AB, AC, ... ZZ] (but at the bit/byte level).

To balance radix tree depth, it's combined with a prefix-trie style structure. 
Each edge value contains the largest string prefix and a pointer to a prefix-tree. 
"H" -> [->"ello", ->[@0, @1, @2, @3, @4]]
The array index @0 points to the next layer of the radix tree for any that doesn't match the prefix. 
@1 points to the layer with one shared character prefix.
@4 points to the layer with the full prefix matching. 
Thus, we get value out of each comparison. This trie-structure is capped at 8, even though the prefix compared can be much larger.

Radix nodes consume a fixed size chunk of bytes per layer. The prefix edges consume variable sized prefix matches and any sub-elements.

*/

