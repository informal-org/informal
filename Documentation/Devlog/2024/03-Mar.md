# March 2024

## Mar 23
I've accidentlaly designed an OOP language. Let me explain.
Informal was always built on pure, immutable, functional core. I added objects as a way of managing isolated state and concurrency, but it was relegated as a special-case. But there was always a gap - at some level, you need to build the immutable functional things out of something. You need to translate that into hardware. Into real-world systems, and there was a semantic mismatch there which was bugging me.
Objects are that mapping to real world processes. Objects and functions are both equally powerful concepts. You can represent either one in terms of the other. But at the end of the day, the underlying hardware executing the program operates as a process - a series of instructions operating on memory. If we make objects the foundation, then we build up all other notions on top of it - including functions. 
What I'm defining as an object here is not the class-based Java style of objects - that OOP is concerned with modelling a domain as a class hierarchy - which has a lot of problems I won't get into here.
No - objects and classes in Informal are from the smalltalk family of objects - which are isolated, actor-like processes which encapsulate state and interact through messages.
Crucially, messages are *not* the same as functions. A message is a one way interaction between two objects. It is that arrow connecting one to the other. It doesn't require the object to respond to it. With one way messages, you can build higher-level types of communication patterns - like 1:1 call-response, 1:N broadcasts or iterator patterns, or other coordination systems. It is a more primitive unit of control-flow which can encode all types of behavior the system requires - from conditions, functions, exceptions, and concurrent actors.
Objects in Informal represent behavior or protocols between systems. It is that fabric in between things where all of the emergent properties happen - and also the layer which is typically invisible and unstructured. Informal formalizes these behaviors in a way you can analyze.
Each function will have a "process" method - serving as its main point of entry.
Within the process method, it can receive messages and specify what type it expects. It can send out other messages, and then expect particular replies. At the end of the process, it can terminate or continue by recursing back.
What this encodes is the interaction between system. If a process *expects* an "ack" message, but the other part of the system doesn't send it or sends it out of order, we can staticaly catch that. If there are two concurrent systems which are interacting with the system, it can enforce what the valid series of operations are at each state and catch race conditions at compile time. The system must be deterministically well behaved in all cases to fit the protocol.
This informally encodes a kind of linear type - encoding a series of operations in a particular order. That can catch issues like acquiring memory, without releasing it, or use-after-free, and more importantly - you can use it to model the expected processes in your own programs.
This gives us a way to fundamentally model mutable state, IO and many other pesky problems. These are the effects.
With objects as the basis, many other parts of the compiler fall into place. For example, managing scope, type-checking, "assignment" and more. You can represent all of those things completely in-language as just compile-time evaluated code. Giving you a very clean system that is homoiconic and self-represented.
Sometimes adding things makes the problem dramtically simpler across a broad spectrum of problems. That usually indicates it is the right design choice. Total minimalism is not the design principle - there's a difference between simplicity and minimalism. You can build hyper minimal systems out of very few primitives, but it is a mind-bending, convoluted puzzle to put together working systems out of that. Add concepts which simplify, and remove that which adds complexity.


## March 25
### Symbol resolution data structure
The standard data structures used to maintain scopes are either a linked hash-map with parent pointers to previous scopes, trees, immutable maps like hash array mapped tries. 
Here's another option optimized for fast lookup, minimal memory and single pass resolution of forward references.
At any depth in the code, the only symbols that are relevant are those in its parent hierarchy. And once a scope is closed, its symbols are no longer needed anywhere. That is analogous to how stack frames work - you open up a frame for a depth, and then free it when exiting a scope. Ofcourse, linearly searching through that stack isn't going to be fast enough, but we can use the same idea with other underlying structures as long as we know which elements belong in the current depth.
For fast resolution, you need to be able to lookup a key without scaling by depth. And we need to minimize the cost of opening up small scopes (like conditions) near the bottom of the AST. 
We can do this by putting all of the keys in a single hashmap with a bitset per depth indicating if the key is present at that depth. When you open up a new scope, all you need to allocate is that small bitset. When you lookup a symbol, it's just a hash table lookup. When you declare a new symbol, set a 1 at the key-index in the bitset for your depth, lookup the location and if it's already populated (i.e. shadowing or collisions), push off the previous value into a linked list. Thus, lookups always get you the latest value, but you have the values from the parent scopes available in the linked list. When a scope is closed, we don't need to cleanup *all* entries, just the ones which were populated before - you can easily find that by AND-ing the bitset for the current depth with bitsets from prior levels (OR-ing them all together to collapse duplicates). You iterate to just those entries and pop the linked list to restore the previous value. Et voila! You're back to the hash map you had before this scope.
Now how do we resolve forward resolution? When a local variable references something from a higher scope you haven't seen yet, add it into the hashmap and set a bit to indicate it's a missing key for depth N. Now, when something declares that value at a later point, you can check if it was defined at depth N or lower - in which case, it's the reference we were looking for. Traverse through those link links and pop all of the unresolved references. Allowing references to resolve linearly as you come across declarations.
Couple of optimizations:
This algorithm works with various types of underlying storage. You can apply it to trees, radix/prefix tries, etc. as well. 
When there are tens of thousands of references in a sourcecode, allocating the bitset per layer can get expensive if we need 1KB of bits. You can reduce this in two ways. 
One - most symbols come from external hashmaps - populate that into a separate static hashmap - you'll then need two lookups, but it shrinks the active symbol table dramatically.
Two - Recognize that the bitsets for a layer will be sparse and define it hierarchically. I initially planned to split up the hashmap itself into a hierarchy, but you don't actually need to do that. Bitset hierarchies are something I'm finding broadly useful. When you enter a new scope, just allocate a single 64 bit value indicating the 'slices' where this scope has values. When a new value is added, set a 1 in that bit, then add the second layer to the bitset indicating the sub-slice - and so on until you can resolve to the exact node you want. These layers are ordered by the popcount order - so you have to shift it on insertion to maintain that order - but indexing into a certain array element is just mask + popcount + index offset. This remains compact and handles the sparsity well. You only need a small stack to maintain this. Resizing the hashmap gets complicated but is certainly do-able. 

### Recursive descent with shunting yard / shift reduce expression parser
After trying out many other kinds of parsing techniques, I've come back to where I initially started but with a much clearer understanding of the problem space. What I want is just a plain recursive descent to handle higher-level structures in code, with a shunting-yard or shift/reduce style parser for the expressions. It maintains an operator stack, and uses a parser-driven lexer to minimize intermediate storage. You branch into recursive sub-expressions based on the top-level token type you see - i.e. I see a number, what's the valid actions for each kind of token that can appear after it. You just do a lookup by token type to determine whether it should output it, pop elements from the stack, whether it indicates an error, or whether that token type has custom code handling. Since the number of tokens are small, you can encode each of these 'maps' as just bitsets - fitting a lot of parsing logic into a few 64 bit values. Similar 'maps' can also indicate which elements from the operator stack to flush (encoding the result of precedence + associtivity or other rules). So most of this is table driven, but a different kind of table driven parser than the generalized parser I was designing before. By wrapping this whole approach in 'recursive' descent, you maintain the readability, flexibility and error handling of just raw code but avoid a lot of the pathlogical recursive cases. The output of this is just a postorder bytecode stack, which combined with the above symbol resolution gives you something that's almost ready to execute.
