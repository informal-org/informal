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

## May 27, 2026 - The Soul of Software and the AI dilemma
Once again, I'm wrangling with the AI Dilemma. Do I use this tool to get work done? Or do I choose to struggle?
What brings up this renewed crisis of conscience was an experience I had at work recently. I ran out of context and just felt stuck. I felt incapacitated. Like I could not work without it. The work I had done just fine without these very tools just a few months ago now felt daunting.
It is dangerous to become addicted to tools someone else can restrict and take away so easily.
Part of the problem with the work project was that I had gotten very far with using AI tools on that project. Without it, I felt like a new employee on their first day having to learn and navigate the codebase from scratch to figure out exactly what is going on where and how. Without credits, you are faced with that blank slate. Code I knew like the back of my hand just a few months ago, where I could tell you exactly which function to change to get something done, now felt distant and unfamiliar. The calculus had shifted beneath me - the AI was now more proficient with this code base than I was. The more you code with AI, the easier it becomes to make changes through AI and the harder it becomes to make those changes yourself.

Do I want to be dependent on a $100 per month subscription to have the privilege to write code for free in my spare time?

The second factor is how the code makes me feel. 
It might be a bit weird to talk about code in terms of feelings but I certainly have bits of code I’ve written in the past that I’ve been incredibly proud of. I used to open up and read it again when work gets tough - it genuinely lifted my spirits. It probably sounds weird but it’s true. 
Do I feel proud of this code I've generated over the past month? When I look at it, all I see are flaws. Oh I would’ve done this slightly differently. Of this variable isn’t named exactly how I want or I’d restructure this bit. I could nit pick and change those things and many times I do, but editing code after the fact gives you different results than doing it properly from the start. 
At the end of the day, this is code I generated, not code I wrote. It's not mine. It doesn’t feel like something I’ve created. It’s not something I feel proud of. 
And that matters a lot to me, especially for what is fundamentally a passion project. 
AI rips the passion out of it. 

The other thing is the flavor of software built by one person and beaurocratic software development. 
Software written by a single skilled developer reads like poetry. It’s cohesive. There are no wasted pasted. Everything fits together perfectly. There is a beauty and elegance to it. 
Software built by teams, even small teams, have seams. The nature of the work is to divide and conquer. One person consumes the work of the other - and as a consumer, you often have a surface level understanding of what the other piece is doing. You take what is there and build on it, like patchwork - often built on incomplete understanding or baked in assumptions. Or you agree on an interface and both build blindly and put things together at the end. And like all plans, there are always gaps. 
For small teams this is workable. The lines blur, each person takes ownership of the entire software and buff out those rough edges. It’s not quite as smooth and polished as sole software development, but it works. For large teams, software development often turns into append only programming. Things are moving so quickly that change becomes expensive. The path of least resistance is to add this one isolated bit of code here without touching the whole entire mess over there. With the dream of throwing it all away and rewriting some better v2 where we won’t change anything fundamental but somehow do it better. Such dungheaps of software stinks to use. They’re trash. The developers know it. The users can feel it. And nobody can do anything about it. 
AI gives a single developer the magical ability to develop dungheaps of software like such teams of developers. Each feature, an isolated patch on top of another.
It lets you build a lot of crap really quickly. But none of it has the elegance or beauty of software crafted by a single human and I don’t believe it ever will. Because it’s very hard to edit your way out of this pit. And these AI agents are trained to make such minimal contributions, to not touch other files beyond the scope of a prompt. It’s designed to patch, not to perfect. When faced with a problem, it works around the friction. It doesn’t address the hard, systemic issues. 
Well no problem, just prompt it to refactor.
And change even more of the code into AI written code? Anyone who has attempted such a massive refactoring on legacy systems know it’s not as simple as it looks. Once you get into it, there be dragons. And pray that the AI even tells you about them. Can you truly even review such broad and sweeping changes? 
You can only remodel a house so much. A fresh coat of paint can conceal but does not change the underlying problems.
So we just start over, right? With the learnings. Code is cheap now. So just rewrite from scratch with the new learnings.
And assuming you’ve actually learned anything from the previous experience, it might buy you a bit of time. But this pattern of development fundamentally leads you back to this same spot.

Things built by committee have differing competing tastes driving the language in different directions. A person is opinionated. A group, no matter how tight knit, is fragmented. 
That does not mean a person’s opinion doesn’t shift over time - we are human. We learn and evolve. I change my mind on things all the time - maybe too often, even.
But it’s actually harder for an organization to have that same mentality. For it to function requires compromises and agreeing to the common denominator. And often sticking with a design direction rather than constantly rehashing past discussions. 

And finally, what does it mean for software to have soul? For anything non-human to have that property, it has to be personal to someone. Someone has to care so deeply about it to pour a piece of themselves into that piece of work. That sohws throw, as love, care and passion. As tasteful, deliberate choices, with a strong sense of direction. A character reflecting its creator. What is soulful is personal. It has to be deeply meaningful and have an emotional connection to that person. Language has power beyond words strung together. Art is more than paint on a canvas, music is more than sounds. And Code... code is more than just instructions for a computer to carry out a procedure. It too is an expression of a person's soul. 

These tools are hard to quit. Honestly, it's very addictive. All of the patterns of addiction are here. "Just a little won't hurt". Until it becomes more and more and subsumes everything. Addiction feeds on habit and dopamine. It’s triggered by cues - the friction of a hard problem you’re stuck with. The feeling of that blank page staring back at you. The indecisive confusion of options. It offers quick, immediate gratification with longer term consequences.
