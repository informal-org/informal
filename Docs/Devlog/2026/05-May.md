# May 2026
## May 09, 2026 - Back into the tarpit
"Beware of the Turing tar-pit in which everything is possible but nothing of interest is easy."

Coding is hard. Expressing yourself, clearly, logically, and building something coherent and working is hard.
The temptation of AI looms over every change: "I bet AI could do this bit, very easily". "Maybe I should just see how it'd approach this problem".
It's tempting to resort to it when faced with the strain of a difficult problem. It's tempting to yield to it when faced with the effort of a boring problem.
I've stuck to my resolve for the past 2-3 weeks, removing the AI code and building the next step - the IR - by hand. It's helped me refine my thoughts on the problem and see through the complexity, but in terms of actual functioning code written, I have very little to show.
An algorithm in concept, a data structure in design, and a scattering of half written utilities and helpers.
I rarely get to do the hours of deep, focused coding anymore. Instead, I write detailed breakdowns of what exactly I need in my notes in bed, and try to knock out a small portion of that code - a utility, a scaffolding, a single switch-case - when I can find 5 minutes in between parenting duties.
Nothing is as easy as it seems.
The machine looms over me, dangling a carrot. A way out.
What matters? The result? Or the achievement?
Is a house built with power tools and machinery, still built by its craftsmen? Does it even matter to those who live there, as long as care and diligence is shown to every detail.
I've read about how Antirez built the redis array type with codex, https://antirez.com/news/164, and his views on AI (https://antirez.com/news/158). How Mitchell Hashimoto uses it in Ghostty - https://mitchellh.com/writing/my-ai-adoption-journey Armin Ronacher's blogs on AI. What Kenneth Reitz writes.
These are all programmers I respect very much, using AI in meaningful ways. 
It is hard to go back to a world before AI. You can shut yourself off from it and do things the old way, but it's largely performative. A demonstration that you've still got it, that coding edge.
To sand and polish by hand, arduously, when a belt sander is available. 
To drill a hole by hand when electrical drills are available.
To dig with a shovel when excavators are available.

There is still a time and place for it. There is a special value in handmade goods. But for professional, industrial work - I would be limiting myself and what I can do by completely ignoring AI tools.

"Now you can do things you never would've dreamed of before".
And it stels a bit of joy from those dreams I have held close for years.

Everything is possible now. But still, yet - nothing is as easy as it seems. Code is cheap now, but has costs yet unaccounted for.

Every problem still deserves thought and attention. Craft still requires someone to care about the details.

------
## May 09, 2026
I remember why I abandoned this technology. Immediately after the writing above, I prompted GPT 5.5 to implement the use-def chaining I had outlined in the IR. I had the structure setup, and similar patterns already established. And it went and wrote a whole another loop over all nodes to find how many identifiers there are - that was completely unnecessary. What should've been a simple change (no more than a few dozen lines), ended up as a complex vomit of code. I reset the changes back to a clean-slate.
One step forward, two steps back.


## May 25, 2026
I've made significant progress in the past month. We now have an IR layer, a proper register allocator (not the hacked together linear allocator without spills I had before), and a lot more metadata pieces like dependency tracking. Each piece deserves its own post, but let me give a brief overview and the path to get here.

When we last checked in, two weeks and 3 days ago, I had parsed code, fed into a very basic form of the IR. The IR format I had was novel, and while inspired by sea-of-nodes, I personally haven't seen any other existing compiler using this same approach of storing things by kind and throwing away the kind of operation altogether. It's a bit insane, and it was hard to get AI coding tools to make sense of it. Any high-level prompt would result in it trying to add back bulky structs like approaches seen in other compilers. It would work, but it misses the point altogether.

Going back from the IR into linear form was much harder than I expected. It took me a while to figure out an algorithm that I was satisfied with. Solving the general problem becomes a graph problem, and graphs with their linked, pointer heavy structure is counter to the flat style we've maintained so far (there are alternative matrix-like representations, but it again scales up in complexity).

The key insight was to limit myself to a fixed maximum size for blocks. A block can have at most 64 elements. That is the kind of simplifying constraint which breaks a problem wide open, and the kind of bold direction the AI is not going to make. 

Limited to 64 bits, you could now track how elements depend on each other though a bitset and in linear time, using bitwise ops, traverse that set to reconstruct a linear order. Standard topological sort, with better performance characteristics. Easy enough in concept.

I gave it the pseudocode for the algorithm and it coded up a several hundred line monstrosity. You see, I was working with a simpler subset of the problem contained to a single block while the AI tries to helpfully handle the more general case, coding up insane approaches to recognize block boundaries, additional loops just to find the output, and all kinds of shortcuts for each sub-problem that this nice linear time algorithm quickly became n^2.

I threw it away and started over, solving each roadblock that it stumbled on, setting up building blocks piece by piece. An efficient way to recognize block boundaries. Its naiive approaches added things into several new lists with large block structures. I can represent block contents with just two u64 bitsets - what kinds are present and how many of each kind (initially a very large bitset per kind, but later on a smaller bitset per block). I simplified the IRQ, split out kind ranges into a separate abstraction, setup an abstraction for looping over blocks, setup a separate dependency map, rearranged the order it's stored in to make local indexing simpler. These are all broad storkes I could take now which would've been harder to restructure by hand. But at the same time, any time I give it a general specification to build, I see it fail by filling in the gaps with nonsense or reading too much into one small aspect of it. But code is cheap now. You can throw it away and start over at an earlier step. The register allocation was a similar push and pull. See where complexity is sneaking in, throw away the code, build more foundational pieces that layout the problem in an easier to access way and then repeat. None of this is 'vibe coded'. I'm intimately involved in solving every problem, structuring every aspect of the system, reviewing every line of code and revising it over and over again until it meets my standards.

Overall, I'm pleased with the progress I'm making and pleased with the overall state of the system. I can look at the code and understand it. Yes, it's complex - but it's intentional complexity that I've opted into. It's my complexity, not the AI's.

There is much more to do. I'm exploring a new direction to eliminate for and if entirely from the language. Use APL like rank polymorphism for looping and use matching for all conditions and enforce this. This forces you to decompose all problems into smaller, named subsets - which improves the readability of what exactly each bit is doing, and allows you to test the internals of a function like never before. It's a constraint that leads to an entirely different style of programming, one I'm quite optimistic about.
