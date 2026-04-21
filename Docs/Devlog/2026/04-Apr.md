# April 2026
## April 20, 2026 - AI experiments
For the past two months (From Jan 19, 2026 to April 20, 2026) I've been experimenting with AI coding in informal (Claude code - Opus 4.6 and now 4.7). This is a subject I'm deeply divided about. I'm not one to shy on progress - I've been an early adopter of AI at work, and it has a boon for my productivity in professional contexts.
But in the context of informal, it has been an abject failure.
If all you care about are features and results, AI will deliver. It will get you something working, with a ton of pizzazz, that glows and glistens. "Wow! This is amazing!" - and it is. It is an incredible achievement of technology that this is even possible!
But when you look under the hood, none of it was working the way I would've done it. I found myself reworking every bit of code the AI wrote. Cleaning up the mess it made of code I lovingly put together.
I've spent countless hours obsessing over every detail of informal; How do I make the AST flat and cache-efficient? How can pack the maximum amount of information into just 64 bits? Every branch in the critical path, every memory allocation, every system call. I've polished and refined every piece of this system, balanced elegance and performance.
AI just drives a bulldozer through it all to complete a prompt. Adding a struct here, sprinkling an allocation there. Reading too much into a prompt, discarding important parts of the architecture while simultaneously being hamstruck by details it should change.
When I ask it a question, it gives me the standard answers. Need an IR? Use SSA! 
It doesn't consider the problem from the ground up, it doesn't challenge assumptions or deviate past known, well-explored solutions.

I've coded a lot these past two months, more than in months before but let me count all of the things I've actually achieved:
- Upgraded Zig version.
- Rewrote the parser from a state machine a pratt parser - but I didn't like the code it generated, so I rewrote the structure of it myself and had it handle the conversion.
- Wrote a benchmark of the two versions, which was ultimately throw-away code.
- Added, removed and added back metadata tracking on grouping nodes to link everything together. There was a detail I was missing in the design, which the AI kept working around without really addressing the fundamental limitation. Once I thought through it myself, the gaps became clearer and I could design an approach.
- Rewrote a bunch of specs, which made it easier to work on the problem at a high-level and easier for AI to understand. Also added a lot more comments to the top of each file, which was also primarily for AI. Moved tests out of the main files into standalone files and removed a ton of dead code from past experiments.
- Fixed conditionals, I had it working in the past but it identified a mistake in the ARM code I was generating.
- Added support for scope shadowing. It kept adding additional stacks to maintain clean-up, and doing extra clean-ups either on scope end or in resolution. None of which was efficient. I designed a bitset approach which tracked when new declarations were shadowing old ones, and just those needed to be cleaned up.
- Added support for inline-macros. It added extra queues to track macros, when the point is that it functions just like normal functions, extra structs to track splice-points or parameter start-ends, struggled to figure out metadata on grouping and separators. I reworked it a lot to remove all of these extra bits of metadata and integrate that better into the system. I described every detail of how it should work, how to link parameter to their usage, add simplifying limitations like eager first parameters for infix operators to avoid re-queuing, how to efficiently index into splice points so it can all be O(1) - it still only got it about 80% right and slipped in bits of slop throughout. Ultimately, this was a ton of complexity - I could no longer look at the parser and understand its complete surface area. This is the kind of code-smell that typically makes me pause and rethink whether the approach itself is correct, which led me to moving this expansion post an IR.

I build Informal out of a love of this craft. It's born out of an innate desire for well built tools, for a language that fits my way of thinking. For a system I understand inside and out, which is as elegant and efficient internally as it is externally. A language that pushes the boundaries and explores new ways of programming.

But who even cares about code now? Who would even bother to learn a new language when you no longer need to write code? If this is all for moot, should I just embrace the inevitable and let it "Build the perfect programming language. Make no mistakes."? 

I am not against AI - I love the technology and will continue to use it for all of the mundane chores, the hard to debug bugs, and every bit of boilerplate glue-code. 
But for the details that matter, for the heart of this language - I want to build it myself. I want to build it right. I am going to go through every line of informal with a fine brush and do a deep-clensing. 

This may be the last chance to build something real by my own hands before these systems become too good to ignore. Before it write better code than me.

I may embrace AI code in informal again one day, when the code it writes meets my standards. But until then, I will build this the old-fashioned way. Line by line. Bit by bit.