# Sup - Informal's Super Optimizer
Optimizations are fundamentally transformations of programs into simpler, more efficient code which preserve the semantics of the original program.
It's a mapping between one code pattern to a set of equivalent code-patterns under some constraints.
 
You can break it down into these sub-problems:
* **Equivalence**: Pattern lookups, synthesis or construction of equivalent patterns.
* **Evaluation**: Cost functions and heuristics to evaluate each option.
* **Exploration**: Efficiently exploring the state space of possible transformations to construct optimized programs.

## Equivalence - Finding alternative programs
What makes two instructions or two programs equivalent? From a pure functional point of view, if two functions give the same output for all inputs, they're equivalent. But you can also take a more nuanced point of view on this: two functions give the same results for certain inputs, but are different otherwise. We can say they're partially equivalent or conditionally equivalent.

How can the program recognize such equivalences? Running each function for all possible inputs becomes intractable. The state space for a 64 bit valeu is humongous and you run into combinatorial explosion when you have multiple values. Ideally, we need an approach which scales with code, rather than scaling by the state space.

We can derive equivalences by going one level deeper than the instruction. All of the hundreds of instructions on your computer are ultimately represented by even more primitive units of computation - transistors and gates. Or more abstractly, you can represent each instruction as a series of AND/OR/NOT/PASSTHROUGH expressions mapping each bit from the input into the output. 
Once you represent an instruction as a series of these primitive transformations, you can then ask the question under which situation two such boolean expressions are equivalent. That is a NP class problem in general, but don't let that deter you. We don't need to solve that in realtime - we just need to use it to derive equivalences, and then store it in a format that can be quickly looked up.

There is a line in Hacker's Delight which inspired me to explore this super optimizing approach:

*"A function mapping words to words can be implemented with word-parallel add, subtract, and, or & not instructions if and only if each bit of the result depends only on bits at and to the right of each input operand"*

That blew my mind. It's a beautiful theorem, and delightfuly obvious once you think about it more. In general, the two instructions can only be equivalent if the unknown output bits depend on the same unknown input bits - where dependency is the set of all reachable input bits through the gate paths. Thining about instructions in this way immediately helps us disregard all unrelated instructions by recognizing they're not even looking at the same bits. 

Then you can write down each output bit as an equation from the input bits it depends on. By normalizing that expression down and simplifying it, we can compare if it's exactly equal to another instruction, and short-circuit the comparison on the first mismatched bit we find. There's more to it than that, but you get the idea...

The primary output of this step is a database of instruction equivalents. Given instruction X with operand A and B, retrieve all equivalent instructions. We keep the state space of that manageable by taking advantage of the fact that atleast *one* of the two operands must be an unknown variables. If both operators were constants, we would've evaluated the function already. So the lookup is just instruction -> operand / constant range -> operand / constant range -> list of potentially matching instructions.

## Evaluation - What's better?
If I told you these 5 instructions all gave the same result, how would you pick which one to use? Should we just look at the instruction cycle timings and pick the least one? That worked in the past, but modern CPUs are a lot more complex. They're pipelined, executing multiple instructions at once - which gives you more throughput, rather than isolated latency. Instructions also use resources - they set flags, require certain registers, and have other constraints. There may also be data and control dependencies between instructions. Caches and branch prediction also add their share of nondeterminism to the timings.

Given all of these confounding factors, the best way to compare two programs is to measure it. And while you can represent the cost of an instruction in a single, aggregate number, how would you evaluate a series of instructions? A function? An entire program?

This sub-problem is a perfect fit for machine learning models. We have ways of automatically synthesizing hundreds of programs, which can generate a massive amount of training data to tune a cost evaluation model. You can compile the same C program with different compilers, generating equivalent but different assembly. Wrap those in a benchmark utility, and then feed the results into the evaluator. Over time, when we find certain special cases where other compilers produce better results than ours, we just feed those equivalent programs into the evaluator and it can continue to tune and refine its cost metrics. 

You can generalize this to different architectures and automate the whole process of tuning a compiler. Evaluation and exploration are safe sub-problems to apply machine learning to improve the heuristics of the algorithm, without compromising of the safety provided by equivalence graphs.

## Exploration
The state space of equivalent programs is infinitely large. There are an infinite number of functions which take 1 and 2 and give 3 as a result. So efficiently exploring this space is crucial to the performance and practicality of a super-optimizing compiler. The optimizer has 
The general approach is to treat this as a variant of the shortest path problem. 
Each equivalence node is sorted by its cost. The key problem is to avoid local minimas. If the cost of taking a non-optimal node may be X, but save Y cost overall compared to the current - then that choice is only taken if X < Y. 



## Further References
- E-Graphs / Equivalence graphs
- Classical papers on super optimizers

