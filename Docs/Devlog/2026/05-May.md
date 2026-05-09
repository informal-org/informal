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
